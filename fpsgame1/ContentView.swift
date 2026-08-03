    //
//  ContentView.swift
//  testproject
//
//  Created by Jack Wang on 2026-02-27.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.gameState {
            case .menu:
                TitleScreenView(
                    hasSavedCampaign: viewModel.hasSavedCampaign,
                    savedCampaignSummary: viewModel.savedCampaignSummary,
                    careerSummary: viewModel.careerSummary,
                    acceptsEnter: !showSettings,
                    onNewGame: { viewModel.startNewCampaign() },
                    onContinue: { viewModel.continueCampaign() },
                    onSettings: { showSettings = true }
                )

            case .briefing:
                BriefingScreenView(level: viewModel.currentLevel, isResume: viewModel.isResumingSession, onStart: {
                    viewModel.startFromBriefing()
                })

            case .playing:
                gamePlayView(captureCursor: true, acceptsInput: true)

            case .paused:
                gamePlayView(captureCursor: false, acceptsInput: !showSettings)
                PauseOverlayView(
                    onResume: { viewModel.resumeGame() },
                    onSettings: { showSettings = true },
                    onQuitToMenu: { viewModel.returnToMenu() }
                )

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
                    difficultyName: viewModel.currentDifficultyName,
                    bestTime: viewModel.levelBestTime,
                    isNewBest: viewModel.isNewLevelBest,
                    onContinue: {
                        viewModel.advanceToNextLevel()
                    }
                )

            case .campaignComplete:
                CampaignCompleteView(
                    difficultyName: viewModel.currentDifficultyName,
                    kills: viewModel.campaignKills,
                    totalEnemies: viewModel.campaignEnemies,
                    elapsedTime: viewModel.campaignElapsedTime,
                    bestTime: viewModel.campaignBestTime,
                    isNewBest: viewModel.isNewCampaignBest,
                    onNewCampaign: { viewModel.newCampaign() }
                )
            }

            if showSettings {
                SettingsView(
                    settings: viewModel.settings,
                    difficultyLocked: viewModel.gameState != .menu,
                    onChanged: { viewModel.applySettings() },
                    onClose: { showSettings = false }
                )
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onDisappear {
            viewModel.stopGame()
        }
    }

    private func gamePlayView(captureCursor: Bool, acceptsInput: Bool) -> some View {
        ZStack {
            // Game rendering output
            if let image = viewModel.frameImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(
                        CGFloat(GameConstants.windowWidth) / CGFloat(GameConstants.windowHeight),
                        contentMode: .fit
                    )
            }

            // HUD overlay
            HUDView(viewModel: viewModel)

            // Input capture (transparent overlay)
            GameInputView(
                inputManager: viewModel.inputManager,
                shouldCaptureCursor: captureCursor,
                acceptsInput: acceptsInput
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
