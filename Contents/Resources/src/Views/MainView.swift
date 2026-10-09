import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject private var manager = DNSManager.shared
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject private var themeMgr = ThemeManager.shared
    
    var body: some View {
        // Внешний ZStack: тосты, индикатор занятости и палитра команд должны
        // накрывать всё окно. Раньше они жили внутри области контента, поэтому
        // затемнение под палитрой обрывалось на границе боковой панели.
        ZStack {
        HStack(spacing: 0) {
            // MARK: - Collapsible Native macOS Sidebar
            if themeMgr.isSidebarVisible {
                VStack(spacing: 0) {
                    // App Branding & Collapse Action
                    HStack(spacing: 10) {
                        if let appIcon = loadAppIcon() {
                            Image(nsImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1.5)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.accentGreen)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.onAccent)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("app.title"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text(L("app.version"))
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    
                    // Navigation Items
                    VStack(spacing: 2) {
                        ForEach(AppTab.allCases) { tab in
                            SidebarNavigationRow(
                                tab: tab,
                                isSelected: manager.selectedTab == tab,
                                size: themeMgr.sidebarSize,
                                action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        manager.selectedTab = tab
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                    
                    // Sidebar Footer Status Badge
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            // Подвал повторял «Защита включена» даже когда весь
                            // DNS-трафик шёл мимо фильтра — теперь состояние одно
                            // и то же во всех трёх местах интерфейса.
                            Circle()
                                .fill(sidebarStatusColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: sidebarStatusColor.opacity(0.5), radius: 3)
                            
                            Text(sidebarStatusText)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        
                        if manager.isProtected {
                            Text(manager.isProtectionBypassed
                                 ? (tr("DNS перехвачен извне", "DNS overridden externally", "DNS сырттан кармалып алынган"))
                                 : manager.currentProfile.title)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .frame(width: themeMgr.sidebarSize.sidebarWidth)
                .chromeSurface()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
                Divider().opacity(0.3)
            }
            
            // MARK: - Detail Content Area
            ZStack {
                Theme.windowBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Unified macOS Toolbar Header
                    HStack(spacing: 10) {
                        // 1. Sidebar Toggle Button [ ◨ ] (Standard macOS HIG)
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                themeMgr.toggleSidebar()
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(themeMgr.isSidebarVisible ? .secondary : Theme.accent)
                                .frame(width: 28, height: 28)
                                .background(themeMgr.isSidebarVisible ? Color.primary.opacity(0.04) : Theme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Скрыть / показать боковое меню (⌘ \\)", "Toggle Sidebar (⌘ \\)", "Каптал менюну жашыруу / көрсөтүү (⌘ \\)"))
                        .accessibilityLabel(tr("Скрыть или показать боковое меню", "Toggle sidebar", "Каптал менюну жашыруу же көрсөтүү"))
                        
                        // 2. Active Section Breadcrumb & Title
                        HStack(spacing: 6) {
                            Image(systemName: manager.selectedTab.iconName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.accent)
                            
                            Text(manager.selectedTab.localizedTitle)
                                .font(.system(size: 14.5, weight: .bold))
                        }
                        
                        Spacer()
                        
                        // 3. Live Latency & Refresh Badge (Height: 28)
                        Button(action: { manager.refreshStatus() }) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.pingColor(manager.currentPingMs))
                                    .frame(width: 6, height: 6)
                                Text(manager.currentPingMs >= 0 ? "\(manager.currentPingMs) ms" : "DNS")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                if manager.dnsOverridden {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Theme.statusRed)
                                }
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(manager.dnsOverridden
                              ? (tr("DNS перехвачен: \(manager.effectiveResolver) — \(manager.overrideSource)", "DNS overridden: \(manager.effectiveResolver) — \(manager.overrideSource)", "DNS кармалып алынган: \(manager.effectiveResolver) — \(manager.overrideSource)"))
                              : (tr("Задержка DNS • Кликните для обновления (⌘ R)", "DNS Latency • Click to refresh (⌘ R)", "DNS кечигүүсү • Жаңыртуу үчүн басыңыз (⌘ R)")))
                        .accessibilityLabel(tr("Обновить статус DNS", "Refresh DNS status", "DNS абалын жаңыртуу"))
                        .accessibilityValue(manager.currentPingMs >= 0
                                            ? (tr("задержка \(manager.currentPingMs) миллисекунд", "\(manager.currentPingMs) milliseconds", "кечигүү \(manager.currentPingMs) миллисекунд"))
                                            : (tr("задержка не измерена", "latency unknown", "кечигүү өлчөнгөн жок")))
                        
                        // 4. Language Segmented Switcher [ RU | KG | EN ] (Height: 28)
                        HStack(spacing: 2) {
                            ForEach([(AppLanguage.ru, "RU"), (.ky, "KG"), (.en, "EN")], id: \.0) { lang, label in
                                Button(action: { l10n.currentLanguage = lang }) {
                                    Text(label)
                                        .font(.system(size: 11, weight: l10n.currentLanguage == lang ? .bold : .medium))
                                        .padding(.horizontal, 7)
                                        .frame(height: 24)
                                        .background(l10n.currentLanguage == lang ? Theme.accent : Color.clear)
                                        .foregroundColor(l10n.currentLanguage == lang ? Theme.onAccent : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(lang.title)
                            }
                        }
                        .padding(2)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .help(tr("Переключить язык интерфейса", "Switch interface language", "Интерфейс тилин которуу"))
                        
                        // 5. Flush DNS Cache Button (Height: 28)
                        Button(action: { manager.flushDNS() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(tr("Сброс DNS", "Flush DNS", "DNS тазалоо"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Очистить локальный DNS-кэш (⌘ F)", "Flush local DNS cache (⌘ F)", "Локалдык DNS-кэшти тазалоо (⌘ F)"))
                        
                        // 6. Quick Search Button (Height: 28)
                        Button(action: { manager.showCommandPalette.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(tr("Поиск", "Search", "Издөө"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Палитра команд и быстрый поиск (⌘ K)", "Command palette & search (⌘ K)", "Буйруктар палитрасы жана тез издөө (⌘ K)"))
                        
                        // 7. Settings Button (Exact 28 x 28)
                        Button(action: { manager.selectedTab = .settings }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(manager.selectedTab == .settings ? Theme.accent : .secondary)
                                .frame(width: 28, height: 28)
                                .background(manager.selectedTab == .settings ? Theme.accent.opacity(0.15) : Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Настройки (⌘ ,)", "Settings (⌘ ,)", "Жөндөөлөр (⌘ ,)"))
                        .accessibilityLabel(tr("Настройки", "Settings", "Жөндөөлөр"))
                    }
                    .padding(.leading, themeMgr.isSidebarVisible ? 16 : 76)
                    .padding(.trailing, 16)
                    .frame(height: 50)
                    .chromeSurface()
                    
                    Divider().opacity(0.2)

                    UpdateBanner()
                    
                    // Selected Tab Content (Adaptive Frame)
                    Group {
                        switch manager.selectedTab {
                        case .dashboard:
                            DashboardView(manager: manager)
                        case .inspector:
                            QueryInspectorView(manager: manager)
                        case .profiles:
                            ProfilesView(manager: manager)
                        case .vpn:
                            VPNView(manager: manager)
                        case .diagnostics:
                            DiagnosticsView(manager: manager)
                        case .rules:
                            RulesView(manager: manager)
                        case .tools:
                            ToolsView(manager: manager)
                        case .faq:
                            FAQView(manager: manager)
                        case .settings:
                            SettingsView(manager: manager)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
            }
        }

        // Индикатор длительной операции. `isBusy` / `busyMessage` выставлялись
        // при каждом привилегированном вызове, но не были подключены ни к
        // одному экрану — запрос пароля и работа движка шли без единого
        // признака в интерфейсе.
        if manager.isBusy {
            BusyOverlayView(message: manager.busyMessage)
                .transition(.opacity)
                .zIndex(90)
        }

        // Всплывающее уведомление
        if let banner = manager.statusBanner {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.accent)
                    Text(banner)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(95)
        }

        // Мастер первого запуска. Перекрывает окно целиком: показывать
        // девять вкладок за полупрозрачным листом — ровно та растерянность,
        // от которой мастер и должен избавить.
        if manager.showOnboarding {
            OnboardingView(manager: manager)
                .transition(.opacity)
                .zIndex(200)
        }

        // Палитра команд (⌘K)
        if manager.showCommandPalette {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { manager.showCommandPalette = false }

                CommandPaletteView(manager: manager, isPresented: $manager.showCommandPalette)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            .zIndex(100)
        }
        }
        .preferredColorScheme(themeMgr.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeMgr.appearance)
        .animation(.easeInOut(duration: 0.25), value: themeMgr.backgroundMode)
        .animation(.easeInOut(duration: 0.25), value: themeMgr.accentPalette)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: manager.statusBanner)
        .animation(.easeInOut(duration: 0.18), value: manager.isBusy)
        .animation(.easeInOut(duration: 0.22), value: manager.showOnboarding)
        .frame(minWidth: 900, minHeight: 580)
    }
    
    private func loadAppIcon() -> NSImage? {
        return AppPaths.appIcon
    }

    private var sidebarStatusColor: Color {
        if manager.isProtectionBypassed { return Theme.statusOrange }
        return manager.isProtected ? Theme.accentGreen : Theme.shieldInactive
    }

    private var sidebarStatusText: String {
        if manager.isProtectionBypassed {
            return tr("Не действует", "Not in effect", "Иштебей жатат")
        }
        return manager.isProtected ? L("status.protected") : L("status.unprotected")
    }
}

// MARK: - Sidebar Row Component (Responsive Size)
struct SidebarNavigationRow: View {
    let tab: AppTab
    let isSelected: Bool
    let size: SidebarSize
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: size.iconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.onAccent : (isHovered ? .primary : .secondary))
                    .frame(width: size.iconSize + 2)
                
                Text(tab.localizedTitle)
                    .font(.system(size: size.fontSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.onAccent : (isHovered ? .primary : .secondary))
                    .lineLimit(1)
                
                Spacer()
                
                Text("⌘\(tab.shortcutNumber)")
                    .font(.system(size: size.fontSize - 3, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? Theme.onAccent.opacity(0.8) : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, size.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.accent : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Busy Overlay
/// Модальный индикатор для операций, которые уходят в движок и требуют прав
/// администратора. Перекрывает окно целиком, чтобы за время запроса пароля
/// нельзя было запустить вторую привилегированную операцию.
struct BusyOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)

                Text(message.isEmpty ? tr("Выполняется операция...", "Working...", "Операция аткарылууда...") : message)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        }
        // Блокируем клики по интерфейсу под оверлеем.
        .contentShape(Rectangle())
        .onTapGesture { }
    }
}
