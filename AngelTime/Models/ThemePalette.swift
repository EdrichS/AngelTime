import SwiftUI

struct ThemeColor: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: UInt32

    var color: Color { Color(hex: hex) }
}

/// Preset colors for each mode. The first three are pomofocus's defaults.
enum ThemePalette {
    static let colors: [ThemeColor] = [
        ThemeColor(id: "tomato", name: "Tomato", hex: 0xBA4949),
        ThemeColor(id: "teal", name: "Teal", hex: 0x38858A),
        ThemeColor(id: "steel", name: "Steel", hex: 0x397097),
        ThemeColor(id: "plum", name: "Plum", hex: 0x845A84),
        ThemeColor(id: "moss", name: "Moss", hex: 0x5E7D4A),
        ThemeColor(id: "amber", name: "Amber", hex: 0xA8732D),
        ThemeColor(id: "slate", name: "Slate", hex: 0x4E5A6B),
        ThemeColor(id: "rose", name: "Rose", hex: 0xA64D6B),
    ]

    static func defaultID(for mode: TimerMode) -> String {
        switch mode {
        case .pomodoro: "tomato"
        case .shortBreak: "teal"
        case .longBreak: "steel"
        }
    }

    static func color(id: String) -> Color {
        (colors.first { $0.id == id } ?? colors[0]).color
    }

    static func isValid(id: String) -> Bool {
        colors.contains { $0.id == id }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
