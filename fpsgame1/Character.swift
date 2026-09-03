//
//  Character.swift
//  fpsgame1
//
//  Playable marines. Each one has a name, a personality, a distinct status-bar
//  portrait and a starting loadout that pushes a different playstyle.
//

import Foundation

/// 8-bit colour triple used by the character and portrait definitions
struct RGB: Equatable {
    let r: Int
    let g: Int
    let b: Int
}

/// Facial features DoomFace uses to draw a character's status-bar portrait
struct FaceLook: Equatable {
    enum HairStyle {
        case cropped
        case mohawk
        case bald
    }

    var hairStyle: HairStyle = .cropped
    var hair = RGB(r: 60, g: 40, b: 25)
    var hairLight = RGB(r: 85, g: 55, b: 35)
    var skin = RGB(r: 220, g: 180, b: 140)
    var iris = RGB(r: 70, g: 110, b: 60)
    /// Colour of a headband across the forehead, if any
    var headband: RGB? = nil
    var scar: Bool = false
    var stubble: Bool = false

    static let standard = FaceLook()
}

struct PlayerCharacter: Identifiable, Equatable {
    let id: String
    let name: String
    let title: String
    let tagline: String
    let bio: String
    /// Weapon the marine deploys with (fist and pistol are always carried)
    let startingWeapon: WeaponType
    let startingAmmo: [AmmoType: Int]
    let startingArmor: Int
    let moveSpeedMultiplier: Double
    /// HUD and menu accent colour
    let accent: RGB
    let look: FaceLook

    /// One-line loadout summary for menus, e.g. "SHOTGUN · 12 SHELLS"
    var loadoutText: String {
        switch startingWeapon {
        case .shotgun: return "SHOTGUN · \(startingAmmo[.shells] ?? 0) SHELLS"
        case .chaingun: return "CHAINGUN · \(startingAmmo[.bullets] ?? 0) ROUNDS"
        case .rocketLauncher: return "LAUNCHER · \(startingAmmo[.rockets] ?? 0) ROCKETS"
        case .pistol: return "PISTOL · \(startingAmmo[.bullets] ?? 0) ROUNDS"
        case .fist: return "FISTS"
        }
    }

    static let sarge = PlayerCharacter(
        id: "sarge",
        name: "SARGE",
        title: "THE VETERAN",
        tagline: "By the book. Then by the shotgun.",
        bio: "Twenty years of UAC deployments. Steady hands, a flak vest, and a shotgun he never signs back in.",
        startingWeapon: .shotgun,
        startingAmmo: [.bullets: 50, .shells: 12, .rockets: 0],
        startingArmor: 25,
        moveSpeedMultiplier: 1.0,
        accent: RGB(r: 120, g: 175, b: 70),
        look: FaceLook(
            hairStyle: .cropped,
            hair: RGB(r: 60, g: 40, b: 25),
            hairLight: RGB(r: 85, g: 55, b: 35),
            skin: RGB(r: 220, g: 180, b: 140),
            iris: RGB(r: 70, g: 110, b: 60),
            headband: nil,
            scar: false,
            stubble: true
        )
    )

    static let viper = PlayerCharacter(
        id: "viper",
        name: "VIPER",
        title: "THE RUNNER",
        tagline: "Never stand still.",
        bio: "Recon specialist. Travels light, moves fast, and lets the chaingun do the talking.",
        startingWeapon: .chaingun,
        startingAmmo: [.bullets: 90, .shells: 0, .rockets: 0],
        startingArmor: 0,
        moveSpeedMultiplier: 1.2,
        accent: RGB(r: 70, g: 200, b: 210),
        look: FaceLook(
            hairStyle: .mohawk,
            hair: RGB(r: 25, g: 25, b: 30),
            hairLight: RGB(r: 55, g: 55, b: 65),
            skin: RGB(r: 165, g: 120, b: 90),
            iris: RGB(r: 80, g: 60, b: 40),
            headband: RGB(r: 70, g: 200, b: 210),
            scar: false,
            stubble: false
        )
    )

    static let grimm = PlayerCharacter(
        id: "grimm",
        name: "GRIMM",
        title: "THE DEMOLISHER",
        tagline: "If it's still standing, fire again.",
        bio: "Demolitions. Slow, heavily armoured, and already loading the next rocket.",
        startingWeapon: .rocketLauncher,
        startingAmmo: [.bullets: 50, .shells: 0, .rockets: 6],
        startingArmor: 50,
        moveSpeedMultiplier: 0.9,
        accent: RGB(r: 230, g: 110, b: 50),
        look: FaceLook(
            hairStyle: .bald,
            hair: RGB(r: 120, g: 60, b: 30),
            hairLight: RGB(r: 150, g: 80, b: 40),
            skin: RGB(r: 205, g: 160, b: 130),
            iris: RGB(r: 90, g: 90, b: 100),
            headband: nil,
            scar: true,
            stubble: true
        )
    )

    static let all: [PlayerCharacter] = [sarge, viper, grimm]

    /// Look up a marine by id, falling back to Sarge
    static func named(id: String) -> PlayerCharacter {
        all.first { $0.id == id } ?? sarge
    }
}
