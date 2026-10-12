//
//  fpsgame1App.swift
//  fpsgame1
//
//  Created by Jack Wang on 2026-02-27.
//

import SwiftUI

#if os(iOS)
import UIKit

/// Landscape only, including the first frame. The Info.plist orientations say the
/// same thing; this stops SwiftUI from flashing a portrait layout on launch.
final class LandscapeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
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
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 600)
        #endif
    }
}
