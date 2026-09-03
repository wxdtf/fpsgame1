#!/usr/bin/env bash
#
# Post-merge verification on a Mac.
#
# Makes a local clone identical to the remote main branch (the remote wins; local
# changes and stray commits are backed up first), validates the level data,
# builds the app with the newest installed Xcode (betas included), and either
# launches it for a play-test or runs a headless start-up smoke test.
#
# Usage:
#   tools/verify_local.sh                   # sync this clone to origin/main, validate, build, launch
#   tools/verify_local.sh --dir ~/wxdtf/FPS # use (or create) the clone at that path instead
#   tools/verify_local.sh --no-sync         # keep the working tree as it is
#   tools/verify_local.sh --no-launch       # build, run the 8-second smoke test, don't open the app
#   tools/verify_local.sh --unsigned        # CI-style unsigned build (no app sandbox)
#
# Without a clone yet, or from a folder that is not one:
#   curl -fsSL https://raw.githubusercontent.com/wxdtf/fpsgame1/main/tools/verify_local.sh \
#       | bash -s -- --dir ~/wxdtf/FPS
#
# --dir accepts an existing clone, a folder that merely contains the clone (Xcode keeps
# the repository inside the project folder it creates, whatever that folder is called),
# an empty or missing folder (it is cloned), or a folder holding a non-git copy of the
# project (moved to <dir>.backup-<timestamp>, then cloned). Any other folder is left
# alone and reported.
#
# Environment overrides:
#   XCODE_APP=/Applications/Xcode-beta.app        force a specific Xcode (its Metal toolchain is
#                                                 downloaded if missing; by default an Xcode that
#                                                 already has one is preferred over a newer one without)
#   BRANCH=main REMOTE=origin                     what to sync to
#   REPO_URL=git@github.com:wxdtf/fpsgame1.git    where to clone from (default: HTTPS GitHub URL)
#   CONFIGURATION=Debug                           build configuration
#
# Exit status is non-zero if any step fails, so it can be chained in other tooling.

set -euo pipefail

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }
fail() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
    if [[ -f "$0" ]]; then
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    else
        echo "usage: verify_local.sh [--dir PATH] [--no-sync] [--no-launch] [--unsigned]"
    fi
}

SYNC=1
LAUNCH=1
UNSIGNED=0
DIR="${DIR:-}"
while (( $# )); do
    case "$1" in
        --dir) [[ $# -ge 2 ]] || fail "--dir needs a path"; DIR="$2"; shift ;;
        --dir=*) DIR="${1#--dir=}" ;;
        --no-sync) SYNC=0 ;;
        --no-launch) LAUNCH=0 ;;
        --unsigned) UNSIGNED=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done
case "$DIR" in
    "~") DIR="$HOME" ;;
    "~/"*) DIR="$HOME/${DIR#"~/"}" ;;
esac
[[ "$DIR" == "/" ]] || DIR="${DIR%/}"

BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
REPO_URL="${REPO_URL:-https://github.com/wxdtf/fpsgame1.git}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SMOKE_SECONDS="${SMOKE_SECONDS:-8}"
# First commit of the project's history: identifies a clone whatever its folder or remote is called
ROOT_COMMIT="8f14a441ad0596ab4bc6cec8b7f77db79973c32a"

[[ "$(uname)" == "Darwin" ]] || fail "this script builds with Xcode and must run on macOS"

# ---------------------------------------------------------------- 1. locate the clone

# True if the directory belongs to a checkout of this project
is_project_clone() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1 || return 1
    [[ "$(git -C "$dir" rev-list --max-parents=0 HEAD 2>/dev/null)" == *"$ROOT_COMMIT"* ]] && return 0
    git -C "$dir" remote -v 2>/dev/null | grep -q 'fpsgame1'
}

# Which directory to verify: --dir, else the clone this script lives in, else the current directory's
if [[ -n "$DIR" ]]; then
    REPO="$DIR"
elif [[ -f "$0" ]] && here="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)"; then
    REPO="$here"
elif here="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    REPO="$here"
else
    fail "not inside a git clone; run this from inside one, or pass --dir <path> to create or sync a clone there"
fi

stamp="$(date +%Y%m%d-%H%M%S)"

if is_project_clone "$REPO"; then
    REPO="$(git -C "$REPO" rev-parse --show-toplevel)"
elif [[ -d "$REPO" ]] && nested="$(
        for sub in "$REPO"/*/; do
            sub="${sub%/}"
            [[ -e "$sub/.git" ]] || continue
            if is_project_clone "$sub"; then printf '%s' "$sub"; break; fi
        done)" && [[ -n "$nested" ]]; then
    # Xcode keeps the repository inside the project folder it created, so the
    # given folder may only contain the clone
    warn "$REPO is not a git repository, but $nested is a clone of the project; using it"
    REPO="$nested"
elif [[ -e "$REPO" ]] && [[ -n "$(ls -A "$REPO" 2>/dev/null)" ]]; then
    (( SYNC )) || fail "$REPO is not a clone of the project (and --no-sync prevents replacing it)"
    [[ -d "$REPO/fpsgame1.xcodeproj" ]] || fail "$REPO exists but is not a clone or a copy of the project; move it aside or pass a different --dir"
    backup="$REPO.backup-$stamp"
    mv "$REPO" "$backup"
    warn "$REPO held a copy of the project without git history; moved it to $backup"
    log "Cloning $REPO_URL into $REPO"
    git clone --origin "$REMOTE" --branch "$BRANCH" "$REPO_URL" "$REPO"
else
    (( SYNC )) || fail "$REPO does not exist (and --no-sync prevents cloning it)"
    log "Cloning $REPO_URL into $REPO"
    mkdir -p "$REPO"
    git clone --origin "$REMOTE" --branch "$BRANCH" "$REPO_URL" "$REPO"
fi
cd "$REPO"
REPO="$(pwd -P)"
echo "Clone: $REPO"

# ---------------------------------------------------------------- 2. sync
if (( SYNC )); then
    log "Syncing $REPO to $REMOTE/$BRANCH"
    if url="$(git remote get-url "$REMOTE" 2>/dev/null)"; then
        echo "Remote $REMOTE: $url"
    else
        warn "remote '$REMOTE' is missing; adding $REPO_URL"
        git remote add "$REMOTE" "$REPO_URL"
    fi
    git fetch --prune "$REMOTE" "$BRANCH"
    target="$(git rev-parse "$REMOTE/$BRANCH")"

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

    if ! git checkout -q -B "$BRANCH" "$target" 2>/dev/null; then
        # e.g. the branch is checked out in another worktree of this repository
        warn "Could not check out branch $BRANCH here; using a detached checkout of $REMOTE/$BRANCH instead"
        git checkout -q --detach "$target"
    fi
    git clean -fd >/dev/null
    echo "Now at: $(git log -1 --oneline)"
else
    log "Skipping sync; verifying the working tree as it is ($(git log -1 --oneline))"
fi
[[ -d fpsgame1.xcodeproj ]] || fail "fpsgame1.xcodeproj not found in $REPO"

# ---------------------------------------------------------------- 3. levels
log "Validating level data"
python3 tools/validate_levels.py

# ---------------------------------------------------------------- 4. Xcode
log "Selecting Xcode"

xcode_version() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null || echo 0
}
# Since Xcode 26 the Metal compiler is a separate download; Raycaster.metal cannot build without it
has_metal_toolchain() {
    DEVELOPER_DIR="$1/Contents/Developer" xcrun -sdk macosx metal --version >/dev/null 2>&1
}

if [[ -n "${XCODE_APP:-}" ]]; then
    [[ -d "$XCODE_APP" ]] || fail "XCODE_APP not found: $XCODE_APP"
    xcode_app="$XCODE_APP"
else
    # Newest CFBundleShortVersionString first, so Xcode-beta wins when it is newer;
    # but an Xcode whose Metal toolchain is installed beats a newer one without it
    candidates=()
    while IFS= read -r app; do
        [[ -n "$app" ]] && candidates+=("$app")
    done < <(
        for app in /Applications/Xcode*.app; do
            [[ -d "$app" ]] || continue
            printf '%s\t%s\n' "$(xcode_version "$app")" "$app"
        done | sort -rV | cut -f2-
    )
    (( ${#candidates[@]} )) || fail "no Xcode found in /Applications"
    xcode_app=""
    for app in "${candidates[@]}"; do
        if has_metal_toolchain "$app"; then xcode_app="$app"; break; fi
    done
    if [[ -z "$xcode_app" ]]; then
        xcode_app="${candidates[0]}"
    elif [[ "$xcode_app" != "${candidates[0]}" ]]; then
        warn "Skipping ${candidates[0]}: its Metal toolchain is not installed. Using $xcode_app instead;"
        warn "set XCODE_APP=${candidates[0]} to use it anyway (the toolchain is downloaded first)."
    fi
fi
export DEVELOPER_DIR="$xcode_app/Contents/Developer"
echo "Using $xcode_app"
xcodebuild -version | sed -n '1p'
sdk="$(xcodebuild -showsdks 2>/dev/null | grep -i 'macosx' | tail -n 1 | sed 's/^[[:space:]]*//' || true)"
echo "SDK: ${sdk:-unknown}"

if ! has_metal_toolchain "$xcode_app"; then
    warn "$xcode_app has no Metal toolchain installed, and Raycaster.metal needs it."
    warn "Downloading it now (a one-time, large download; Xcode > Settings > Components does the same)."
    xcodebuild -downloadComponent MetalToolchain \
        || fail "could not download the Metal toolchain; install 'Metal Toolchain' in Xcode > Settings > Components, or set XCODE_APP to an Xcode that has it"
    has_metal_toolchain "$xcode_app" \
        || fail "the Metal toolchain is still missing after the download; install it in Xcode > Settings > Components"
    echo "Metal toolchain installed"
fi

# ---------------------------------------------------------------- 5. build
log "Building fpsgame1 ($CONFIGURATION)"
sign_args=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
if (( UNSIGNED )); then
    sign_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
fi
# Build only this Mac's architecture: faster, and no ONLY_ACTIVE_ARCH warning from a target-only build
xcodebuild \
    -project fpsgame1.xcodeproj \
    -target fpsgame1 \
    -configuration "$CONFIGURATION" \
    -arch "$(uname -m)" \
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

# ---------------------------------------------------------------- 6. run
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
