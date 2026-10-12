//
//  fpsgame1App.swift
//  fpsgame1
//
//  Created by Jack Wang on 2026-02-27.
//

import SwiftUI

#if os(iOS)
import UIKit

/// Landscape only, and black before the menu draws. Info.plist says the same
/// things: landscape orientations, and a black launch screen (`LaunchBackground`)
/// so the phone does not flash white in light mode.
final class LandscapeAppDelegate: NSObject, UIApplicationDelegate {
    override init() {
        super.init()
        // The system window is white until SwiftUI paints the menu. Set this
        // before any window exists so the first frame stays black.
        UIWindow.appearance().backgroundColor = .black
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        paintWindowsBlack(application)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        paintWindowsBlack(application)
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }

    private func paintWindowsBlack(_ application: UIApplication) {
        for scene in application.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.backgroundColor = .black }
        }
    }
}
#endif

@main
struct fpsgame1App: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(LandscapeAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.black.ignoresSafeArea())
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 600)
        #endif
    }
}
