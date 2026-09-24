    //
//  ContentView.swift
//  testproject
//
//  Created by Jack Wang on 2026-02-27.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

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
        #if os(iOS)
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
            } else if let image = viewModel.frameImage {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(
                        CGFloat(GameConstants.windowWidth) / CGFloat(GameConstants.windowHeight),
                        contentMode: .fit
                    )
            }

            // HUD overlay, fitted to the same 16:10 box the renderer letterboxes into
            HUDView(viewModel: viewModel)
                .fitDesignSize()

            // Input capture (transparent overlay): keyboard and mouse on the Mac, a
            // hardware keyboard on iPad; touches pass through it to the controls below
            GameInputView(inputManager: viewModel.inputManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if os(iOS)
            TouchControlsView(inputManager: viewModel.inputManager)
            #endif
        }
    }
}

#Preview {
    ContentView()
}
