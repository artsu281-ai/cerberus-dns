import SwiftUI
import AppKit

// MARK: - Accent Color Palette
enum AccentPalette: String, CaseIterable, Identifiable {
    case emerald = "emerald"
    case sapphire = "sapphire"
    case purple = "purple"
    case amber = "amber"
    case crimson = "crimson"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .emerald: return "Emerald"
        case .sapphire: return "Sapphire"
        case .purple: return "Purple"
        case .amber: return "Amber"
        case .crimson: return "Crimson"
        }
    }
    
    /// Фирменный цвет.
    ///
    /// Все пять акцентов служат подложкой под текст — выделенный пункт бокового
    /// меню, залитые кнопки, сегменты. С белым текстом ни один не давал
    /// требуемых 4.5:1: emerald 2.11, amber 2.21, crimson 3.41, sapphire 3.62,
    /// purple 4.17.
    ///
    /// Затемнять всю палитру до нормы значило испортить её — emerald стал бы
    /// болотным, amber коричневым. Поэтому решение смешанное: светлым акцентам
    /// чёрный текст и цвет без изменений, тёмным белый и минимальное
    /// притемнение. Пару «цвет + текст» задаёт `onColor`.
    var color: Color {
        switch self {
        case .emerald:  return Color(red: 0.16, green: 0.80, blue: 0.44)   // чёрный текст, 9.97:1
        case .amber:    return Color(red: 1.0,  green: 0.58, blue: 0.0)    // чёрный текст, 9.48:1
        case .sapphire: return Color(red: 0.0, green: 0.448, blue: 0.905) // белый текст, 4.60:1
        case .purple:   return Color(red: 0.658, green: 0.274, blue: 0.861) // белый текст, 4.60:1
        case .crimson:  return Color(red: 0.919, green: 0.048, blue: 0.0) // белый текст, 4.60:1
        }
    }

    /// Цвет текста поверх акцента. Выбран так, чтобы пара проходила WCAG AA.
    var onColor: Color {
        switch self {
        case .emerald, .amber: return .black
        case .sapphire, .purple, .crimson: return .white
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .emerald:
            return LinearGradient(colors: [Color(red: 0.20, green: 0.84, blue: 0.48), Color(red: 0.10, green: 0.68, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sapphire:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.52, blue: 0.96), Color(red: 0.0, green: 0.36, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(colors: [Color(red: 0.72, green: 0.34, blue: 0.92), Color(red: 0.53, green: 0.19, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .amber:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.68, blue: 0.15), Color(red: 0.92, green: 0.45, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .crimson:
            return LinearGradient(colors: [Color(red: 0.96, green: 0.14, blue: 0.08), Color(red: 0.78, green: 0.03, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - App Background Style
enum AppBackgroundMode: String, CaseIterable, Identifiable {
    case standard = "standard"
    case obsidian = "obsidian"
    case oledBlack = "oledBlack"
    case ceramic = "ceramic"
    case pureWhite = "pureWhite"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .standard: return "macOS Glass"
        case .obsidian: return "Obsidian Dark"
        case .oledBlack: return "OLED Pure Black"
        case .ceramic: return tr("Керамика (Nordic)", "Nordic Ceramic", "Керамика (Nordic)")
        case .pureWhite: return tr("Белоснежный", "Pure Porcelain", "Аппак")
        }
    }
}

// MARK: - App Appearance Theme
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return Theme.isSystemInDarkMode ? .dark : .light
        }
    }
    
    var title: String {
        switch self {
        case .system: return L("theme.system")
        case .light: return L("theme.light")
        case .dark: return L("theme.dark")
        }
    }
    
    var iconName: String {
        switch self {
        case .system: return "display"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Sidebar Size Setting
enum SidebarSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .small: return L("sidebar.small")
        case .medium: return L("sidebar.medium")
        case .large: return L("sidebar.large")
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 17
        case .large: return 20
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 13.5
        case .large: return 15
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 5
        case .medium: return 7.5
        case .large: return 10
        }
    }
    
    var sidebarWidth: CGFloat {
        // Прибавлено по ~15 pt: при прежних значениях самый длинный пункт
        // «Инспектор трафика» обрезался многоточием на всех трёх размерах.
        switch self {
        case .small: return 224
        case .medium: return 250
        case .large: return 276
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "app_appearance")
            applyAppearance()
        }
    }
    
    @Published var accentPalette: AccentPalette {
        didSet {
            UserDefaults.standard.set(accentPalette.rawValue, forKey: "app_accent_palette")
        }
    }
    
    @Published var backgroundMode: AppBackgroundMode {
        didSet {
            UserDefaults.standard.set(backgroundMode.rawValue, forKey: "app_background_mode")
        }
    }
    
    @Published var sidebarSize: SidebarSize {
        didSet {
            UserDefaults.standard.set(sidebarSize.rawValue, forKey: "sidebar_size")
        }
    }
    
    @Published var isSidebarVisible: Bool {
        didSet {
            UserDefaults.standard.set(isSidebarVisible, forKey: "is_sidebar_visible")
        }
    }
    
    init() {
        let savedApp = UserDefaults.standard.string(forKey: "app_appearance") ?? "system"
        let savedAccent = UserDefaults.standard.string(forKey: "app_accent_palette") ?? "emerald"
        let savedBg = UserDefaults.standard.string(forKey: "app_background_mode") ?? "standard"
        let savedSize = UserDefaults.standard.string(forKey: "sidebar_size") ?? "medium"
        let savedSidebarVis = UserDefaults.standard.object(forKey: "is_sidebar_visible") as? Bool ?? true
        
        self.appearance = AppAppearance(rawValue: savedApp) ?? .system
        self.accentPalette = AccentPalette(rawValue: savedAccent) ?? .emerald
        self.backgroundMode = AppBackgroundMode(rawValue: savedBg) ?? .standard
        self.sidebarSize = SidebarSize(rawValue: savedSize) ?? .medium
        self.isSidebarVisible = savedSidebarVis
        
        applyAppearance()
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @objc private func systemAppearanceDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.appearance == .system {
                self.applyAppearance()
                self.objectWillChange.send()
            }
        }
    }
    
    func toggleSidebar() {
        isSidebarVisible.toggle()
    }
    
    private static let aquaAppearance = NSAppearance(named: .aqua)
    private static let darkAquaAppearance = NSAppearance(named: .darkAqua)
    
    func applyAppearance() {
        let appAppearance: NSAppearance?
        switch self.appearance {
        case .system:
            appAppearance = Theme.isSystemInDarkMode ? Self.darkAquaAppearance : Self.aquaAppearance
        case .light:
            appAppearance = Self.aquaAppearance
        case .dark:
            appAppearance = Self.darkAquaAppearance
        }
        
        NSApp?.appearance = appAppearance
        for window in NSApp?.windows ?? [] {
            window.appearance = appAppearance
        }
    }
}

// MARK: - Apple Human Interface Guidelines Design Tokens
struct Theme {
    static var accent: Color { ThemeManager.shared.accentPalette.color }
    /// Текст и иконки поверх заливки акцентом. Не `.white` вслепую:
    /// на светлых акцентах белый не проходит по контрасту.
    static var onAccent: Color { ThemeManager.shared.accentPalette.onColor }

    /// Определяет, включена ли системная тёмная тема в macOS.
    /// Читает AppleInterfaceStyle напрямую из глобальных настроек macOS,
    /// что исключает рассинхронизацию с NSApp.appearance.
    static var isSystemInDarkMode: Bool {
        if let style = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String {
            return style.caseInsensitiveCompare("Dark") == .orderedSame
        }
        return false
    }

    /// Действующее оформление — синхронно отражает активный режим приложения,
    /// исключая двойную перерисовку и задержки AppKit.
    static var isDarkAppearance: Bool {
        switch ThemeManager.shared.appearance {
        case .light: return false
        case .dark: return true
        case .system: return isSystemInDarkMode
        }
    }

    /// Вычисляемый режим фона: взаимно проецирует тёмные и светлые стили в зависимости от активного оформления.
    private static var effectiveBackgroundMode: AppBackgroundMode {
        let mode = ThemeManager.shared.backgroundMode
        if isDarkAppearance {
            switch mode {
            case .standard: return .standard
            case .obsidian, .ceramic: return .obsidian
            case .oledBlack, .pureWhite: return .oledBlack
            }
        } else {
            switch mode {
            case .standard: return .standard
            case .ceramic, .obsidian: return .ceramic
            case .pureWhite, .oledBlack: return .pureWhite
            }
        }
    }

    static var windowBackground: Color {
        if isDarkAppearance {
            switch effectiveBackgroundMode {
            case .standard: return Color(nsColor: .windowBackgroundColor)
            case .obsidian, .ceramic: return Color(red: 0.08, green: 0.09, blue: 0.12)
            case .oledBlack, .pureWhite: return Color.black
            }
        } else {
            switch effectiveBackgroundMode {
            case .standard: return Color(nsColor: .windowBackgroundColor)
            case .ceramic, .obsidian: return Color(red: 0.940, green: 0.946, blue: 0.956)
            case .pureWhite, .oledBlack: return Color(red: 0.992, green: 0.992, blue: 0.996)
            }
        }
    }
    
    static var controlBackground: Color {
        if isDarkAppearance {
            switch effectiveBackgroundMode {
            case .standard: return Color(nsColor: .controlBackgroundColor)
            case .obsidian, .ceramic: return Color(red: 0.12, green: 0.13, blue: 0.17)
            case .oledBlack, .pureWhite: return Color(red: 0.07, green: 0.07, blue: 0.07)
            }
        } else {
            switch effectiveBackgroundMode {
            case .standard: return Color(nsColor: .controlBackgroundColor)
            case .ceramic, .obsidian: return Color.white
            case .pureWhite, .oledBlack: return Color(red: 0.952, green: 0.956, blue: 0.965)
            }
        }
    }

    /// Фон служебных поверхностей — боковой панели и шапки окна.
    static var chromeBackground: Color {
        if isDarkAppearance {
            switch effectiveBackgroundMode {
            case .standard:  return Color(nsColor: .windowBackgroundColor)
            case .obsidian, .ceramic:  return Color(red: 0.06, green: 0.07, blue: 0.10)
            case .oledBlack, .pureWhite: return Color.black
            }
        } else {
            switch effectiveBackgroundMode {
            case .standard:  return Color(nsColor: .windowBackgroundColor)
            case .ceramic, .obsidian:  return Color(red: 0.920, green: 0.928, blue: 0.940)
            case .pureWhite, .oledBlack: return Color.white
            }
        }
    }

    /// Стекло уместно только в стандартном стиле.
    static var usesMaterialChrome: Bool { effectiveBackgroundMode == .standard }
    
    static let statusGreen = Color(red: 0.16, green: 0.80, blue: 0.44)
    static let statusBlue = Color(red: 0.05, green: 0.52, blue: 1.0)
    static let statusOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let statusRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let statusPurple = Color(red: 0.68, green: 0.32, blue: 0.87)
    static let statusCyan = Color(red: 0.12, green: 0.75, blue: 0.89)
    
    static var accentGreen: Color { ThemeManager.shared.accentPalette.color }
    static let shieldInactive = Color(nsColor: .tertiaryLabelColor)
    
    static var greenGradient: LinearGradient { ThemeManager.shared.accentPalette.gradient }

    /// Цвет текста, читаемый поверх произвольной заливки.
    ///
    /// Нужен потому, что белый по семантическим цветам проваливает контраст так
    /// же, как проваливал по акцентам: statusRed даёт 3.41:1, statusOrange 2.21,
    /// statusGreen 2.11 — при норме 4.5:1 для текста такого размера.
    /// Считаем относительную яркость по WCAG и берём ту из пары чёрный/белый,
    /// что даёт больший контраст.
    static func readableForeground(on background: Color) -> Color {
        guard let srgb = NSColor(background).usingColorSpace(.sRGB) else { return .white }
        func channel(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(srgb.redComponent)
                      + 0.7152 * channel(srgb.greenComponent)
                      + 0.0722 * channel(srgb.blueComponent)
        // Порог 0.179 — точка, где контраст с чёрным и с белым равен.
        return luminance > 0.179 ? .black : .white
    }

    /// Единая шкала оценки задержки DNS.
    /// Шапка окна и плитка на «Обзоре» раньше пользовались разными порогами
    /// (60/140 против 30/80/140) и красили одно и то же значение по-разному.
    static func pingColor(_ ms: Int) -> Color {
        if ms < 0 { return Color(nsColor: .secondaryLabelColor) }
        if ms < 30 { return statusGreen }
        if ms < 80 { return statusBlue }
        if ms < 140 { return statusOrange }
        return statusRed
    }
    
    static let darkBezelGradient = LinearGradient(
        colors: [Color.black.opacity(0.4), Color.black.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Sound & Feedback System
class SoundSystem {
    static let shared = SoundSystem()
    
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "app_sound_muted") }
        set { UserDefaults.standard.set(newValue, forKey: "app_sound_muted") }
    }
    
    func playToggle() {
        guard !isMuted else { return }
        NSSound(named: "Pop")?.play()
    }
    
    func playSuccess() {
        guard !isMuted else { return }
        NSSound(named: "Glass")?.play()
    }
    
    func playAction() {
        guard !isMuted else { return }
        NSSound(named: "Tink")?.play()
    }
    
    func playCelebration() {
        guard !isMuted else { return }
        NSSound(named: "Ping")?.play()
    }
}

// MARK: - View Modifiers
struct BentoCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 14
    var isInteractive: Bool = false
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                isHovered && isInteractive ?
                                    Theme.accent.opacity(0.35) :
                                    Color.primary.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .onHover { h in
                if isInteractive { isHovered = h }
            }
    }
}

extension View {
    /// Фон боковой панели и шапки: стекло в стандартном стиле, сплошной цвет
    /// в Obsidian и OLED — иначе тёмные стили покрывали только содержимое.
    @ViewBuilder
    func chromeSurface() -> some View {
        if Theme.usesMaterialChrome {
            self.background(.ultraThinMaterial)
        } else {
            self.background(Theme.chromeBackground)
        }
    }

    func bentoCard(cornerRadius: CGFloat = 12, padding: CGFloat = 14, interactive: Bool = false) -> some View {
        self.modifier(BentoCardModifier(cornerRadius: cornerRadius, padding: padding, isInteractive: interactive))
    }
    
    func glassCard(cornerRadius: CGFloat = 12, padding: CGFloat = 14) -> some View {
        self.modifier(BentoCardModifier(cornerRadius: cornerRadius, padding: padding, isInteractive: false))
    }
}
