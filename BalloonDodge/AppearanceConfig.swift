import SwiftUI
import UIKit

// MARK: - Balloon Styles

struct BalloonStyleDefinition: Identifiable, Equatable {
    let id: Int
    let name: String
    let color: UIColor
    let cost: Int
}

enum BalloonStyles {
    static let all: [BalloonStyleDefinition] = [
        BalloonStyleDefinition(id: 0, name: "Classic Red", color: .systemRed, cost: 0),
        BalloonStyleDefinition(id: 1, name: "Ocean Blue", color: .systemBlue, cost: 150),
        BalloonStyleDefinition(id: 2, name: "Lime Pop", color: .systemGreen, cost: 250),
        BalloonStyleDefinition(id: 3, name: "Sunset Orange", color: .systemOrange, cost: 400),
        BalloonStyleDefinition(id: 4, name: "Neon Purple", color: .systemPurple, cost: 600),
        BalloonStyleDefinition(id: 5, name: "Neon Teal", color: .systemTeal, cost: 600),
        BalloonStyleDefinition(id: 6, name: "Golden Skin", color: UIColor(red: 255.0/255.0, green: 215.0/255.0, blue: 0.0/255.0, alpha: 1.0), cost: 1000),
        BalloonStyleDefinition(id: 7, name: "Gold Ghost Skin", color: UIColor(red: 255.0/255.0, green: 215.0/255.0, blue: 0.0/255.0, alpha: 0.5), cost: 2000),
        BalloonStyleDefinition(id: 8, name: "Neon Ghost Skin", color: UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.5), cost: 2000),
        BalloonStyleDefinition(id: 9, name: "Pink Pop", color: UIColor(red: 1.0, green: 0.07, blue: 0.94, alpha: 1.0), cost: 2500),
    ]
    
    static func style(for id: Int) -> BalloonStyleDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

// MARK: - Arrow Styles

struct ArrowStyleDefinition: Identifiable, Equatable {
    let id: Int
    let name: String
    let shaftColor: UIColor
    let headColor: UIColor
    let featherColor: UIColor
    let cost: Int
}

enum ArrowStyles {
    static let all: [ArrowStyleDefinition] = [
        ArrowStyleDefinition(
            id: 0,
            name: "Wood & Steel",
            shaftColor: UIColor(red: 0.82, green: 0.65, blue: 0.40, alpha: 1),
            headColor: UIColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1),
            featherColor: UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1),
            cost: 0
        ),
        ArrowStyleDefinition(
            id: 1,
            name: "Shadow Arrows",
            shaftColor: UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1),
            headColor: UIColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 1),
            featherColor: UIColor.systemTeal,
            cost: 150
        ),
        ArrowStyleDefinition(
            id: 2,
            name: "Golden Tips",
            shaftColor: UIColor(red: 0.60, green: 0.45, blue: 0.25, alpha: 1),
            headColor: UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1),
            featherColor: UIColor.systemRed,
            cost: 200
        ),
        ArrowStyleDefinition(
            id: 3,
            name: "Frostbite",
            shaftColor: UIColor(red: 0.70, green: 0.80, blue: 0.95, alpha: 1),
            headColor: UIColor(red: 0.80, green: 0.90, blue: 1.00, alpha: 1),
            featherColor: UIColor.systemCyan,
            cost: 400
        ),
        ArrowStyleDefinition(
            id: 4,
            name: "Lazer Arrows",
            shaftColor: UIColor.red,
            headColor: UIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            featherColor: UIColor.red,
            cost: 600
        ),
        ArrowStyleDefinition(
            id: 5,
            name: "Neon Darts",
            shaftColor: UIColor(red: 1.0, green: 0.07, blue: 0.94, alpha: 1.0),
            headColor: UIColor.systemTeal,
            featherColor: UIColor.systemPurple,
            cost: 600
        ),
        ArrowStyleDefinition(
            id: 6,
            name: "Ocean Blue",
            shaftColor: .white,
            headColor: UIColor(red: 68/255, green: 137/255, blue: 255/255, alpha: 1.0),
            featherColor: UIColor.systemGreen,
            cost: 400
        ),
        ArrowStyleDefinition(
            id: 7,
            name: "Green Arrows",
            shaftColor: UIColor(red: 0.925, green: 0.953, blue: 0.620, alpha: 1.0),
            headColor: .systemGreen,
            featherColor: UIColor.green,
            cost: 1000
        ),
        ArrowStyleDefinition(
            id: 8,
            name: "Danger Zone",
            shaftColor: UIColor(red: 255.0 / 255.0, green: 186.0 / 255.0, blue: 8.0 / 255.0, alpha: 1.0),
            headColor: UIColor(red: 255.0 / 255.0, green: 125.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0),
            featherColor: UIColor.red,
            cost: 2000
        ),
    ]
    
    static func style(for id: Int) -> ArrowStyleDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

// MARK: - Background Styles

struct BackgroundStyleDefinition: Identifiable, Equatable {
    let id: Int
    let name: String
    let color: UIColor
    let cost: Int
}

enum BackgroundStyles {
    static let all: [BackgroundStyleDefinition] = [
        BackgroundStyleDefinition(id: 0, name: "Deep Space", color: .black, cost: 0),
        BackgroundStyleDefinition(id: 1, name: "Twilight", color: UIColor(red: 0.07, green: 0.09, blue: 0.20, alpha: 1), cost: 150),
        BackgroundStyleDefinition(id: 2, name: "Dusk Violet", color: UIColor(red: 0.17, green: 0.09, blue: 0.25, alpha: 1), cost: 400),
        BackgroundStyleDefinition(id: 3, name: "Retro Grid", color: UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1), cost: 600),
        BackgroundStyleDefinition(id: 4, name: "Soft Sky", color: UIColor(red: 0.35, green: 0.60, blue: 0.90, alpha: 1), cost: 1000)
    ]
    
    static func style(for id: Int) -> BackgroundStyleDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

// MARK: - Helpers

// MARK: - Helpers

extension Color {
    init(uiColor: UIColor) {
        // This is the native SwiftUI way to convert.
        // It handles all color spaces (RGB, P3, Grayscale) automatically.
        self.init(uiColor)
    }
}

