import AppKit
import SwiftUI
import PerchCore

extension PerchTheme {
    var appearance: NSAppearance? {
        switch self { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) }
    }
}

private func adaptiveColor(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> NSColor {
    NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let hex = isDark ? dark : light
        return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                       blue: CGFloat(hex & 255) / 255, alpha: isDark ? darkAlpha : lightAlpha)
    }
}

extension PerchAccent {
    // Reuse immutable native colors; the appearance provider resolves on demand.
    private static let colors: [PerchAccent: NSColor] = [
        .blue: adaptiveColor(light: 0x075FB7, dark: 0x47A8FF),
        .purple: adaptiveColor(light: 0x7440BB, dark: 0xB495FF),
        .pink: adaptiveColor(light: 0xB52D64, dark: 0xF58AB4),
        .orange: adaptiveColor(light: 0x9C5200, dark: 0xF8AF62),
        .green: adaptiveColor(light: 0x26713D, dark: 0x78CD95),
        .teal: adaptiveColor(light: 0x00706B, dark: 0x66CCC1)
    ]
    var nsColor: NSColor { Self.colors[self]! }
    var color: Color { Color(nsColor: nsColor) }
}

enum Palette {
    static let primary = Color(nsColor: adaptiveColor(light: 0x1E2228, dark: 0xF0F0F0))
    static let secondary = Color(nsColor: adaptiveColor(light: 0x555C67, dark: 0xABB0B8))
    static let rule = Color(nsColor: adaptiveColor(light: 0x000000, dark: 0xFFFFFF))
    static let background = Color(nsColor: adaptiveColor(light: 0xF2F3F5, dark: 0x191B1E))
    static let surface = Color(nsColor: adaptiveColor(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.045, darkAlpha: 0.055))
    static let tile = Color(nsColor: adaptiveColor(light: 0xFFFFFF, dark: 0x000000, lightAlpha: 0.85, darkAlpha: 0.76))
    static let field = Color(nsColor: adaptiveColor(light: 0xFFFFFF, dark: 0x000000, lightAlpha: 0.8, darkAlpha: 0.34))
    static let railTint = Color(nsColor: adaptiveColor(light: 0xFFFFFF, dark: 0x000000, lightAlpha: 0.45, darkAlpha: 0.36))
    static let panelTint = Color(nsColor: adaptiveColor(light: 0xFFFFFF, dark: 0x000000, lightAlpha: 0.66, darkAlpha: 0.30))
    static let onAccent = Color(nsColor: adaptiveColor(light: 0xFFFFFF, dark: 0x101820))
    static let warning = Color(nsColor: adaptiveColor(light: 0x985000, dark: 0xFFBA70))
    static let error = Color(nsColor: adaptiveColor(light: 0xAE3030, dark: 0xFFBAA0))
}

extension AppStore {
    var accentColor: Color { data.preferences.accent.color }
    var accentNSColor: NSColor { data.preferences.accent.nsColor }
}

struct PerchSurface: View {
    @EnvironmentObject var store: AppStore
    var rail = false
    var body: some View {
        if store.data.preferences.glassBackground {
            DockMaterial().overlay(rail ? Palette.railTint : Palette.panelTint)
        } else { Palette.background }
    }
}

struct AppearanceSettings: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance").font(.headline)
            Picker("Theme", selection: $store.data.preferences.theme) {
                ForEach(PerchTheme.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            HStack(spacing: 10) {
                Text("Accent").font(.system(size: 12))
                Spacer(minLength: 0)
                ForEach(PerchAccent.allCases, id: \.self) { accent in
                    let selected = store.data.preferences.accent == accent
                    Button { store.data.preferences.accent = accent } label: {
                        Circle().fill(accent.color).frame(width: 21, height: 21)
                            .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.onAccent) } }
                            .padding(3)
                            .overlay(Circle().strokeBorder(selected ? Palette.primary.opacity(0.7) : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).help(accent.rawValue.capitalized)
                        .accessibilityLabel("\(accent.rawValue.capitalized) accent")
                        .accessibilityValue(selected ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Toggle("Glass background", isOn: $store.data.preferences.glassBackground)
            Text("Turn off for solid panels.").font(.caption).foregroundStyle(Palette.secondary)
        }
    }
}
