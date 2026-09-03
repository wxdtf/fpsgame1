#!/usr/bin/env bash
#
# Post-merge verification on a Mac.
#
# Makes this clone identical to the remote main branch (the remote wins; local
# changes and stray commits are backed up first), validates the level data,
# builds the app with the newest installed Xcode (betas included), and either
# launches it for a play-test or runs a headless start-up smoke test.
#
# Usage:
#   tools/verify_local.sh                 # sync to origin/main, validate, build, launch
#   tools/verify_local.sh --no-sync       # keep the working tree as it is
#   tools/verify_local.sh --no-launch     # build, run the 8-second smoke test, don't open the app
#   tools/verify_local.sh --unsigned      # CI-style unsigned build (no app sandbox)
#
# Environment overrides:
#   XCODE_APP=/Applications/Xcode-beta.app   force a specific Xcode
#   BRANCH=main REMOTE=origin                what to sync to
#   CONFIGURATION=Debug                      build configuration
#
# Exit status is non-zero if any step fails, so it can be chained in other tooling.

set -euo pipefail

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

SYNC=1
LAUNCH=1
UNSIGNED=0
for arg in "$@"; do
    case "$arg" in
        --no-sync) SYNC=0 ;;
        --no-launch) LAUNCH=0 ;;
        --unsigned) UNSIGNED=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $arg" >&2; usage; exit 2 ;;
    esac
done

BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SMOKE_SECONDS="${SMOKE_SECONDS:-8}"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }
fail() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "this script builds with Xcode and must run on macOS"

# The clone to verify: the one this script lives in, else the current directory's
# (so a copy of the script can be run from anywhere inside a clone)
REPO="${REPO:-$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel)}"
cd "$REPO"

# ---------------------------------------------------------------- 1. sync
if (( SYNC )); then
    log "Syncing $REPO to $REMOTE/$BRANCH"
    git fetch --prune "$REMOTE" "$BRANCH"
    target="$(git rev-parse "$REMOTE/$BRANCH")"
    stamp="$(date +%Y%m%d-%H%M%S)"

    # Anything not committed (tracked or untracked, ignored files excluded) is kept in a stash
    if [[ -n "$(git status --porcelain)" ]]; then
        git stash push --include-untracked -m "verify_local backup $stamp" >/dev/null
        warn "Local changes were stashed as 'verify_local backup $stamp' (see: git stash list)"
    fi

    # Local commits the remote does not have are kept on a backup branch
    head="$(git rev-parse HEAD)"
    if ! git merge-base --is-ancestor "$head" "$target"; then
        git branch "backup/local-$stamp" "$head"
        warn "Local commits not on $REMOTE/$BRANCH were saved to branch backup/local-$stamp"
    fi

    git checkout -q -B "$BRANCH" "$target"
    git clean -fd >/dev/null
    echo "Now at: $(git log -1 --oneline)"
else
    log "Skipping sync; verifying the working tree as it is ($(git log -1 --oneline))"
fi

# ---------------------------------------------------------------- 2. levels
log "Validating level data"
python3 tools/validate_levels.py

# ---------------------------------------------------------------- 3. Xcode
log "Selecting Xcode"
if [[ -n "${XCODE_APP:-}" ]]; then
    [[ -d "$XCODE_APP" ]] || fail "XCODE_APP not found: $XCODE_APP"
    xcode_app="$XCODE_APP"
else
    # Newest CFBundleShortVersionString wins, so Xcode-beta is used when it is newer
    xcode_app="$(
        for app in /Applications/Xcode*.app; do
            [[ -d "$app" ]] || continue
            version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || echo 0)"
            printf '%s\t%s\n' "$version" "$app"
        done | sort -V | tail -n 1 | cut -f2-
    )"
    [[ -n "$xcode_app" ]] || fail "no Xcode found in /Applications"
fi
export DEVELOPER_DIR="$xcode_app/Contents/Developer"
echo "Using $xcode_app"
xcodebuild -version | sed -n '1p'
sdk="$(xcodebuild -showsdks 2>/dev/null | grep -i 'macosx' | tail -n 1 | sed 's/^[[:space:]]*//' || true)"
echo "SDK: ${sdk:-unknown}"

# ---------------------------------------------------------------- 4. build
log "Building fpsgame1 ($CONFIGURATION)"
sign_args=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
if (( UNSIGNED )); then
    sign_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
fi
xcodebuild \
    -project fpsgame1.xcodeproj \
    -target fpsgame1 \
    -configuration "$CONFIGURATION" \
    -quiet \
    "${sign_args[@]}" \
    build

APP="$REPO/build/$CONFIGURATION/fpsgame1.app"
if [[ ! -d "$APP" ]]; then
    # Older/newer xcodebuild defaults may place products elsewhere under build/
    APP="$(find "$REPO/build" -type d -name fpsgame1.app -print -quit 2>/dev/null || true)"
fi
[[ -n "$APP" && -d "$APP" ]] || fail "build product fpsgame1.app not found under $REPO/build"
echo "Built $APP"

# ---------------------------------------------------------------- 5. run
if (( LAUNCH )); then
    log "Launching for a play-test"
    open "$APP"
    cat <<'CHECKLIST'
Play-test checklist:
  - Title -> character select: arrows / 1 2 3 switch cards, Enter deploys, Esc goes back
  - Briefing names the operative; HUD shows the name and the matching portrait
  - Starting weapon matches the marine (Sarge shotgun, Viper chaingun, Grimm launcher)
  - Rockets (key 5) explode on walls and enemies, hurt you at point-blank range
  - E1M3: nukage floors tick damage; red key gates the vault door, blue key the lower levels
  - E1M4: red -> blue -> yellow doors; Baron roars, shows a health bar, claws up close
  - Finish E1M4 -> campaign summary -> Enter returns to the title
CHECKLIST
else
    log "Smoke test: running the app for ${SMOKE_SECONDS}s"
    "$APP/Contents/MacOS/fpsgame1" &
    app_pid=$!
    sleep "$SMOKE_SECONDS"
    if kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
        echo "App was still running after ${SMOKE_SECONDS}s: start-up OK"
    else
        wait "$app_pid" || fail "the app exited during start-up (status $?)"
        fail "the app exited during start-up"
    fi
fi

log "Verification complete"
