    //
//  ContentView.swift
//  testproject
//
//  Created by Jack Wang on 2026-02-27.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.gameState {
            case .playing:
                gamePlayView

            case .paused:
                gamePlayView
                PauseOverlayView(selectedIndex: viewModel.pauseMenuIndex,
                                 onSelect: { viewModel.choosePauseMenuItem($0) })
                    .fitDesignSize()

            default:
                // Menu screens are laid out for 960×600 and shrink to fit smaller hosts
                menuScreen
                    .fitDesignSize()
            }
        }
        .onAppear { viewModel.handleScenePhase(scenePhase) }
        .onChange(of: scenePhase) { _, phase in
            viewModel.handleScenePhase(phase)
        }
        #if os(iOS)
        // The first swipe only reveals the home indicator, so a thumb on FIRE
        // does not leave the app.
        .defersSystemGestures(on: .bottom)
        .persistentSystemOverlays(.hidden)
        #endif
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 500)
        #endif
        .onDisappear {
            viewModel.stopGame()
        }
    }

    @ViewBuilder
    private var menuScreen: some View {
        switch viewModel.gameState {
        case .settings:
            SettingsView(settings: viewModel.settings, onBack: { viewModel.closeSettings() })

        case .characterSelect:
            CharacterSelectView(
                initialID: viewModel.character.id,
                onSelect: { viewModel.chooseCharacter($0) },
                onBack: { viewModel.backToMenu() }
            )

        case .briefing:
            BriefingScreenView(level: viewModel.currentLevel, operative: viewModel.character,
                               difficulty: viewModel.settings.difficulty, onStart: {
                viewModel.startFromBriefing()
            })

        case .dead:
            DeathScreenView(onRestart: {
                viewModel.restartWithBriefing()
            })

        case .levelComplete:
            VictoryScreenView(
                killCount: viewModel.killCount,
                totalEnemies: viewModel.totalEnemies,
                elapsedTime: viewModel.elapsedTime,
                currentLevel: viewModel.currentLevel,
                isFinalLevel: viewModel.isFinalLevel,
                result: viewModel.lastLevelResult,
                record: viewModel.lastRecordUpdate,
                onContinue: {
                    viewModel.advanceToNextLevel()
                }
            )

        case .campaignComplete:
            CampaignCompleteView(
                results: viewModel.levelResults,
                operative: viewModel.character.name,
                onContinue: {
                    viewModel.returnToMenu()
                }
            )

        default:
            TitleScreenView(
                settings: viewModel.settings,
                onStart: { viewModel.showCharacterSelect() },
                onSettings: { viewModel.showSettings() }
            )
        }
    }

    private var gamePlayView: some View {
        ZStack {
            // Game rendering output: Metal presents straight into its own view
            // (letterboxed by the post kernel); the CPU fallback hands SwiftUI an image.
            if viewModel.usesMetalView {
                MetalGameView(viewModel: viewModel)
                    .ignoresSafeArea()
            } else if let image = viewModel.frameImage {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(
                        CGFloat(GameConstants.windowWidth) / CGFloat(GameConstants.windowHeight),
                        contentMode: .fit
                    )
                    .ignoresSafeArea()
            }

            // HUD overlay, fitted to the same 16:10 box the renderer letterboxes into.
            // Edge to edge, like the picture; the status bar itself clears the home indicator.
            HUDView(viewModel: viewModel)
                .fitDesignSize()
                .ignoresSafeArea()

            // Input capture (transparent overlay): keyboard and mouse on the Mac, a
            // hardware keyboard on iPad; touches pass through it to the controls below
            GameInputView(inputManager: viewModel.inputManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            #if os(iOS)
            if viewModel.gameState == .playing {
                TouchControlsView(inputManager: viewModel.inputManager)
                    .ignoresSafeArea()
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
