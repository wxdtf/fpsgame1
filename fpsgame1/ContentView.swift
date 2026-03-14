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
            case .menu:
                TitleScreenView(onStart: {
                    viewModel.showBriefing()
                })

            case .briefing:
                BriefingScreenView(level: viewModel.currentLevel, onStart: {
                    viewModel.startFromBriefing()
                })

            case .playing:
                gamePlayView

            case .paused:
                gamePlayView
                PauseOverlayView()

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
                    onContinue: {
                        viewModel.advanceToNextLevel()
                    }
                )
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onDisappear {
            viewModel.stopGame()
        }
    }

    private var gamePlayView: some View {
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
            GameInputView(inputManager: viewModel.inputManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
