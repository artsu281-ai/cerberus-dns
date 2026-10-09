import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var manager: DNSManager
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var themeMgr = ThemeManager.shared
    @State private var upstream1: String = "1.1.1.1"
    @State private var upstream2: String = "1.0.0.1"
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Native macOS Preferences Top Bar
            HStack(spacing: 8) {
                PreferencesTabButton(
                    title: L("settings.tab.general"),
                    icon: "gearshape.fill",
                    isSelected: manager.selectedSettingsSubTab == 0
                ) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.selectedSettingsSubTab = 0 }
                }
                
                PreferencesTabButton(
                    title: L("settings.tab.network"),
                    icon: "network",
                    isSelected: manager.selectedSettingsSubTab == 1
                ) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.selectedSettingsSubTab = 1 }
                }
                
                PreferencesTabButton(
                    title: L("settings.tab.about"),
                    icon: "info.circle.fill",
                    isSelected: manager.selectedSettingsSubTab == 2
                ) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { manager.selectedSettingsSubTab = 2 }
                }
            }
            .padding(8)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider().opacity(0.3)
            
            // MARK: - Content Area
            ZStack {
                Theme.windowBackground
                    .ignoresSafeArea()
                
                if manager.selectedSettingsSubTab == 0 {
                    generalSettingsTab
                } else if manager.selectedSettingsSubTab == 1 {
                    networkSettingsTab
                } else {
                    aboutSettingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 560, minHeight: 460)
        .onAppear {
            upstream1 = manager.upstream1
            upstream2 = manager.upstream2
        }
    }
    
    // MARK: - Tab 1: General Settings
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Appearance & Theme Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.appearance"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    HStack(spacing: 10) {
                        ForEach(AppAppearance.allCases) { appMode in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    themeMgr.appearance = appMode
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: appMode.iconName)
                                        .font(.system(size: 12))
                                    Text(appMode.title)
                                        .font(.system(size: 12, weight: themeMgr.appearance == appMode ? .semibold : .regular))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(themeMgr.appearance == appMode ? Theme.accent : Color.primary.opacity(0.05))
                                .foregroundColor(themeMgr.appearance == appMode ? Theme.onAccent : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 2. Accent Color Palette Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.theme_accent"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 10) {
                        ForEach(AccentPalette.allCases) { pal in
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    themeMgr.accentPalette = pal
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(pal.color)
                                        .frame(width: 10, height: 10)
                                    Text(pal.title)
                                        .font(.system(size: 11.5, weight: themeMgr.accentPalette == pal ? .bold : .regular))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(themeMgr.accentPalette == pal ? pal.color.opacity(0.18) : Color.primary.opacity(0.05))
                                .foregroundColor(themeMgr.accentPalette == pal ? pal.color : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(themeMgr.accentPalette == pal ? pal.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 3. Background Style Mode
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.theme_bg"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    let isDark = Theme.isDarkAppearance
                    let modes: [(mode: AppBackgroundMode, title: String)] = isDark ? [
                        (.standard, "macOS Glass"),
                        (.obsidian, "Obsidian Dark"),
                        (.oledBlack, "OLED Pure Black")
                    ] : [
                        (.standard, "macOS Glass"),
                        (.ceramic, tr("Керамика (Nordic)", "Nordic Ceramic", "Керамика (Nordic)")),
                        (.pureWhite, tr("Белоснежный", "Pure Porcelain", "Аппак"))
                    ]
                    
                    HStack(spacing: 10) {
                        ForEach(modes, id: \.mode) { item in
                            let isSelected = (themeMgr.backgroundMode == item.mode) ||
                                (!isDark && item.mode == .ceramic && themeMgr.backgroundMode == .obsidian) ||
                                (!isDark && item.mode == .pureWhite && themeMgr.backgroundMode == .oledBlack) ||
                                (isDark && item.mode == .obsidian && themeMgr.backgroundMode == .ceramic) ||
                                (isDark && item.mode == .oledBlack && themeMgr.backgroundMode == .pureWhite)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    themeMgr.backgroundMode = item.mode
                                }
                            }) {
                                Text(item.title)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Theme.accent : Color.primary.opacity(0.05))
                                    .foregroundColor(isSelected ? Theme.onAccent : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 4. Sidebar Size Setting
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.sidebar_size"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 10) {
                        ForEach(SidebarSize.allCases) { sz in
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    themeMgr.sidebarSize = sz
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: sz == .small ? "text.alignleft" : (sz == .medium ? "list.bullet" : "list.dash"))
                                        .font(.system(size: 11))
                                    Text(sz.title)
                                        .font(.system(size: 12, weight: themeMgr.sidebarSize == sz ? .semibold : .regular))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(themeMgr.sidebarSize == sz ? Theme.accent : Color.primary.opacity(0.05))
                                .foregroundColor(themeMgr.sidebarSize == sz ? Theme.onAccent : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 3. Language Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.language"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 10) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button(action: {
                                l10n.currentLanguage = lang
                            }) {
                                HStack(spacing: 6) {
                                    CustomCountryFlag(code: lang.rawValue, width: 18, height: 12)
                                    Text(lang.title)
                                        .font(.system(size: 12, weight: l10n.currentLanguage == lang ? .semibold : .regular))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(l10n.currentLanguage == lang ? Theme.accent : Color.primary.opacity(0.05))
                                .foregroundColor(l10n.currentLanguage == lang ? Theme.onAccent : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 4. Privileged Helper & Touch ID
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Привилегированный помощник (Без пароля)", "Privileged Helper (Passwordless)", "Артыкчылыктуу жардамчы (Сырсөзсүз)"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(manager.isHelperInstalled ? Theme.statusGreen.opacity(0.15) : Color.primary.opacity(0.06))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: manager.isHelperInstalled ? "touchid" : "lock.shield")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(manager.isHelperInstalled ? Theme.statusGreen : .secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(helperStatusColor)
                                    .frame(width: 6, height: 6)
                                Text(helperStatusTitle)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            
                            Text(helperStatusSubtitle)
                                .font(.system(size: 10.5))
                                .foregroundColor(manager.isHelperStale ? Theme.statusOrange : .secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            // Небезопасный помощник надо переустановить, а не
                            // просто удалить — иначе действия снова начнут
                            // спрашивать пароль, и пользователь вернёт старый.
                            if manager.isHelperStale {
                                Button(action: { manager.installPrivilegedHelper() }) {
                                    Text(tr("Переустановить", "Reinstall", "Кайра орнотуу"))
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.statusOrange)
                                        .foregroundColor(Theme.readableForeground(on: Theme.statusOrange))
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: {
                                if manager.isHelperInstalled {
                                    manager.removePrivilegedHelper()
                                } else {
                                    manager.installPrivilegedHelper()
                                }
                            }) {
                                Text(manager.isHelperInstalled ?
                                     (tr("Удалить", "Uninstall", "Жок кылуу")) :
                                     (tr("Установить (1 раз)", "Install (Once)", "Орнотуу (1 жолу)")))
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(manager.isHelperInstalled ? Color.red.opacity(0.12) : Theme.accent)
                                    .foregroundColor(manager.isHelperInstalled ? .red : Theme.onAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }

                // Разделение зон с Tailscale — включённое состояние надо
                // показывать и уметь отменить, иначе человек не поймёт, кто
                // создал /etc/resolver/ts.net и почему Tailscale не управляет DNS.
                if let ts = manager.tailscale, ts.installed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("Tailscale", "Tailscale", "Tailscale"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill((ts.splitEnabled ? Theme.statusGreen : Color.secondary).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: ts.splitEnabled ? "arrow.triangle.branch" : "arrow.triangle.merge")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(ts.splitEnabled ? Theme.statusGreen : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ts.splitEnabled
                                     ? (tr("Зоны разведены", "Zones are split", "Зоналар бөлүнгөн"))
                                     : (tr("Зоны не разведены", "Zones are not split", "Зоналар бөлүнгөн эмес")))
                                    .font(.system(size: 12, weight: .bold))
                                Text(ts.splitEnabled
                                     ? (tr("Имена \(ts.suffix) идут в Tailscale, остальные запросы — через фильтр.", "\(ts.suffix) names go to Tailscale, everything else through the filter.", "\(ts.suffix) аттары Tailscale'ге барат, калган сурамдар — чыпка аркылуу."))
                                     : (tr("Tailscale управляет всем DNS. Пока это так, фильтрация не действует.", "Tailscale handles all DNS. While it does, filtering has no effect.", "Tailscale бардык DNS'ти башкарат. Ушундай турганда чыпкалоо иштебейт.")))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 8)

                            Button(action: {
                                if ts.splitEnabled { manager.disableTailscaleSplit() }
                                else { manager.enableTailscaleSplit() }
                            }) {
                                Text(ts.splitEnabled
                                     ? (tr("Отменить", "Undo", "Артка кайтаруу"))
                                     : (tr("Развести", "Split", "Бөлүү")))
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(ts.splitEnabled ? Color.red.opacity(0.12) : Theme.accent)
                                    .foregroundColor(ts.splitEnabled ? .red : Theme.onAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!ts.running)
                            .opacity(ts.running ? 1 : 0.5)
                        }
                        .padding(12)
                        .background(Theme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                }

                // Повторный запуск мастера.
                // Без этого мастер недостижим после первого раза: на уже
                // настроенной машине он намеренно не показывается, и проверить
                // его — или заново убедиться, что фильтр работает, — нечем.
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Первый запуск", "First run", "Биринчи ишке киргизүү"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.accent.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Пройти настройку заново", "Run setup again", "Жөндөөнү кайра өтүү"))
                                .font(.system(size: 12, weight: .bold))
                            Text(tr("Мастер включит фильтр и проверит на двенадцати рекламных доменах, что он действительно работает.", "The wizard turns the filter on and verifies against twelve real ad domains that it actually works.", "Мастер чыпканы күйгүзүп, анын чын эле иштеп жатканын он эки жарнама доменинде текшерет."))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Button(action: { manager.showOnboarding = true }) {
                            Text(tr("Открыть", "Open", "Ачуу"))
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Theme.accent)
                                .foregroundColor(Theme.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 5. Behavior Group
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Система и уведомления", "System & Notifications", "Система жана билдирмелер"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: L("settings.autostart"),
                            subtitle: L("settings.autostart.sub"),
                            isOn: $manager.autoLaunchAtLogin
                        )
                        
                        Divider().opacity(0.2)
                        
                        SettingsToggleRow(
                            title: L("settings.notifications"),
                            subtitle: L("settings.notifications.sub"),
                            isOn: $manager.notificationsEnabled
                        )
                        
                        Divider().opacity(0.2)
                        
                        SettingsToggleRow(
                            title: L("settings.autoupdate"),
                            subtitle: tr("Еженедельная проверка обновлений правил OISD", "Weekly rule updates from OISD & StevenBlack", "OISD эрежелеринин жаңыртууларын жума сайын текшерүү"),
                            isOn: $manager.autoUpdateRules
                        )
                        
                        Divider().opacity(0.2)
                        
                        SettingsToggleRow(
                            title: L("settings.sounds"),
                            subtitle: tr("Аудио-отклик при переключении защиты", "Audio feedback on protection toggles", "Коргоону которгондо үн менен билдирүү"),
                            isOn: $manager.soundEffectsEnabled
                        )
                    }
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // 6. Shortcuts Group
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Горячие клавиши", "Keyboard Shortcuts", "Ыкчам баскычтар"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        SettingsShortcutRow(key: "⌘ S", title: tr("Включить / выключить защиту", "Toggle Protection", "Коргоону күйгүзүү / өчүрүү"))
                        Divider().opacity(0.2)
                        SettingsShortcutRow(key: "⌘ K", title: tr("Палитра быстрых команд", "Command Palette", "Ыкчам буйруктар палитрасы"))
                        Divider().opacity(0.2)
                        SettingsShortcutRow(key: "⌘ 2", title: tr("Инспектор DNS-запросов", "Live Query Inspector", "DNS сурамдарынын инспектору"))
                        Divider().opacity(0.2)
                        SettingsShortcutRow(key: "⌘ R", title: tr("Обновить статус и пинг", "Refresh Status & Ping", "Абалды жана пингди жаңыртуу"))
                        Divider().opacity(0.2)
                        SettingsShortcutRow(key: "⌘ F", title: tr("Сбросить кэш DNS", "Flush DNS Cache", "DNS кэшин тазалоо"))
                    }
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }
    
    // MARK: - Tab 2: Network Settings
    private var networkSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Вышестоящие DNS (Upstream)", "Upstream DNS Resolvers", "Жогорку DNS (Upstream)"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text(tr("Основной сервер:", "Primary DNS:", "Негизги сервер:"))
                                .font(.system(size: 12))
                                .frame(width: 140, alignment: .leading)
                            TextField("1.1.1.1", text: $upstream1)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                            if !isUpstream1Valid {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.statusRed)
                                    .font(.system(size: 11))
                            }
                        }
                        
                        HStack {
                            Text(tr("Резервный сервер:", "Secondary DNS:", "Камдык сервер:"))
                                .font(.system(size: 12))
                                .frame(width: 140, alignment: .leading)
                            TextField("1.0.0.1", text: $upstream2)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                            if !isUpstream2Valid {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.statusRed)
                                    .font(.system(size: 11))
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                manager.saveUpstreamDNS(dns1: upstream1, dns2: upstream2)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(tr("Применить вышестоящие DNS", "Apply Upstream DNS", "Жогорку DNS'ти колдонуу"))
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.accent)
                                .foregroundColor(Theme.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!isUpstream1Valid || !isUpstream2Valid)
                            .opacity((!isUpstream1Valid || !isUpstream2Valid) ? 0.5 : 1.0)
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Служебные действия", "Maintenance Actions", "Кызматтык аракеттер"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 10) {
                        Button(action: { manager.flushDNS() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "trash.circle")
                                Text(L("btn.flush"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { manager.refreshStatus() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                Text(L("btn.refresh"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }
    
    // MARK: - Tab 3: Rich Bento-style About Dashboard
    private var aboutSettingsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero Header
                VStack(spacing: 8) {
                    if let icon = loadAppIcon() {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Theme.accent.opacity(0.25), radius: 10, x: 0, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.accent)
                                .frame(width: 72, height: 72)
                                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 4)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(Theme.onAccent)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(L("app.title"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        
                        HStack(spacing: 6) {
                            Text(appVersionString)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                        }
                    }
                    
                    Text(tr("Нативный блокировщик рекламы, трекеров и фишинга для macOS с локальным кэшированием и отказоустойчивыми туннелями.", "High-performance native DNS ad-blocker, anti-tracking shield, and fail-safe VPN proxies for macOS.", "macOS үчүн нативдүү жарнама, трекер жана фишинг бөгөттөгүчү — локалдык кэштөө жана үзгүлтүккө туруктуу туннелдер менен."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 460)
                }
                .padding(.top, 8)
                
                UpdateSettingsRow()
                    .frame(maxWidth: 520)

                // Privacy & Trust Badges
                HStack(spacing: 10) {
                    AboutBadge(
                        icon: "lock.shield.fill",
                        title: tr("100% On-Device", "100% On-Device", "100% түзмөктө"),
                        subtitle: tr("Без облачных логов", "No cloud logging", "Булуттагы логдорсуз"),
                        color: Theme.accent
                    )
                    AboutBadge(
                        icon: "eye.slash.fill",
                        title: tr("Zero Telemetry", "Zero Telemetry", "Телеметрия жок"),
                        subtitle: tr("Без трекеров и SDK", "No analytics SDKs", "Трекерлерсиз жана SDK'сыз"),
                        color: Theme.statusBlue
                    )
                    AboutBadge(
                        icon: "checkmark.seal.fill",
                        title: tr("Open Source", "Open Source", "Ачык код"),
                        subtitle: tr("Лицензия MIT", "MIT License", "MIT лицензиясы"),
                        color: Theme.statusPurple
                    )
                }
                .frame(maxWidth: 520)
                
                // Specifications Bento Grid
                HStack(alignment: .top, spacing: 12) {
                    // Column 1: Core Engine
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.accent)
                            Text(tr("Ядро фильтрации", "Core Engine", "Чыпкалоо өзөгү"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        VStack(spacing: 8) {
                            AboutInfoRow(
                                label: tr("DNS Резолвер", "DNS Resolver", "DNS резолвер"),
                                value: "dnsmasq v2.90"
                            )
                            AboutInfoRow(
                                label: tr("Шифрование DNS", "DNS Encryption", "DNS шифрлөө"),
                                value: "DoH / TLS 1.3"
                            )
                            AboutInfoRow(
                                label: tr("Протоколы VPN", "VPN Protocols", "VPN протоколдору"),
                                value: "VLESS / Shadowsocks"
                            )
                            AboutInfoRow(
                                label: tr("Помощник", "Privileged Helper", "Жардамчы"),
                                value: manager.isHelperInstalled ? (tr("Активен (v3.0)", "Active (v3.0)", "Активдүү (v3.0)")) : (tr("Не установлен", "Missing", "Орнотулган эмес")),
                                highlight: manager.isHelperInstalled ? Theme.statusGreen : Theme.statusOrange
                            )
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // Column 2: System & Footprint
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "gauge.medium")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.accent)
                            Text(tr("Система и Ресурсы", "System & Metrics", "Система жана ресурстар"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        VStack(spacing: 8) {
                            AboutInfoRow(
                                label: tr("Архитектура", "Architecture", "Архитектура"),
                                value: "Apple Silicon (arm64)"
                            )
                            AboutInfoRow(
                                label: tr("Память (RAM)", "RAM Usage", "Эс тутум (RAM)"),
                                value: "< 25 MB"
                            )
                            AboutInfoRow(
                                label: tr("Нагрузка CPU", "CPU Idle", "CPU жүктөмү"),
                                value: "0.0% (~0s wakeups)"
                            )
                            AboutInfoRow(
                                label: tr("Списки правил", "Blocklists", "Эрежелер тизмелери"),
                                value: "OISD Big / StevenBlack"
                            )
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 520)
                
                // Action Buttons Row
                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            manager.selectedTab = .faq
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                            Text(tr("База знаний и FAQ", "Knowledge Base & FAQ", "Билим базасы жана FAQ"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            manager.selectedTab = .diagnostics
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stethoscope")
                            Text(tr("Диагностика", "Diagnostics", "Диагностика"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: openStateDirectory) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                            Text(tr("Папка данных", "State Folder", "Маалымат папкасы"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 520)
                
                // Copyright & Community
                VStack(spacing: 3) {
                    Button(action: {
                        if let url = URL(string: "https://constanta.kg") { NSWorkspace.shared.open(url) }
                    }) {
                        Text("© 2026 Constanta.kg · " + tr("Сделано в Кыргызстане", "Made in Kyrgyzstan", "Кыргызстанда жасалган") + " · MIT")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("constanta.kg")
                    
                    Text(tr("Создано для приватного, быстрого и чистого интернета на macOS.", "Crafted for a private, lightning-fast, and clean internet on macOS.", "macOS'то купуя, ылдам жана таза интернет үчүн түзүлгөн."))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.top, 2)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func openStateDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let stateDir = home.appendingPathComponent(".local/state/cerberus-dns")
        if FileManager.default.fileExists(atPath: stateDir.path) {
            NSWorkspace.shared.open(stateDir)
        } else {
            NSWorkspace.shared.open(home)
        }
    }
    
    private var isRu: Bool { l10n.currentLanguage == .ru }

    private var appVersionString: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
        let bld = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3042"
        #if arch(arm64)
        let arch = "Apple Silicon"
        #else
        let arch = "Intel x86_64"
        #endif
        return tr("Версия \(ver) (сборка \(bld)) • \(arch)", "Version \(ver) (Build \(bld)) • Native \(arch)", "Версия \(ver) (жыйнак \(bld)) • \(arch)")
    }

    private var helperStatusColor: Color {
        if !manager.isHelperInstalled { return .secondary }
        return manager.isHelperStale ? Theme.statusOrange : Theme.statusGreen
    }

    private var helperStatusTitle: String {
        if !manager.isHelperInstalled {
            return tr("Помощник не установлен", "Helper not installed", "Жардамчы орнотулган эмес")
        }
        if manager.isHelperLegacy {
            return tr("Помощник небезопасен", "Helper is insecure", "Жардамчы коопсуз эмес")
        }
        if manager.isHelperStale {
            return tr("Помощник устарел", "Helper is outdated", "Жардамчы эскирген")
        }
        return tr("Помощник активен", "Helper installed", "Жардамчы активдүү")
    }

    private var helperStatusSubtitle: String {
        if !manager.isHelperInstalled {
            return tr("Установите помощник один раз, чтобы переключать защиту без ввода пароля.", "Install the privileged helper once to manage DNS and VPN without entering your password every time.", "Коргоону сырсөз киргизбей которуу үчүн жардамчыны бир жолу орнотуңуз.")
        }
        if manager.isHelperLegacy {
            return tr("Установлен помощник старого образца: он запускает движок из каталога приложения с правами root, а такой каталог доступен на запись без пароля. Переустановите помощник.", "A legacy helper is installed: it runs the engine from the application directory as root, and that directory is writable without a password. Please reinstall it.", "Эски үлгүдөгү жардамчы орнотулган: ал кыймылдаткычты колдонмонун каталогунан root укуктары менен ишке киргизет, ал эми мындай каталогго сырсөзсүз эле жазууга болот. Жардамчыны кайра орнотуңуз.")
        }
        if manager.isHelperStale {
            return tr("Версия помощника не совпадает с версией движка в приложении. Переустановите его.", "The installed helper does not match the engine shipped with this app. Please reinstall it.", "Жардамчынын версиясы колдонмодогу кыймылдаткычтын версиясына дал келбейт. Аны кайра орнотуңуз.")
        }
        return tr("Переключение DNS, VPN и сброс кэша выполняются без запроса пароля.", "DNS, VPN and cache actions run without repeated password prompts.", "DNS, VPN которуу жана кэшти тазалоо сырсөз суралбай аткарылат.")
    }

    private var isUpstream1Valid: Bool {
        let clean = upstream1.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty || DNSManager.isValidIP(clean)
    }

    private var isUpstream2Valid: Bool {
        let clean = upstream2.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty || DNSManager.isValidIP(clean)
    }

    private func loadAppIcon() -> NSImage? {
        return AppPaths.appIcon
    }
}

// MARK: - Preferences Tab Button
struct PreferencesTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.accent : Color.primary.opacity(0.05))
            .foregroundColor(isSelected ? Theme.onAccent : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                .scaleEffect(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings Shortcut Row
struct SettingsShortcutRow: View {
    let key: String
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            
            Spacer()
            
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

// MARK: - About Info Row
struct AboutInfoRow: View {
    let label: String
    let value: String
    var isMono: Bool = true
    var highlight: Color? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .medium, design: isMono ? .monospaced : .default))
                .foregroundColor(highlight ?? .primary)
        }
    }
}

// MARK: - About Badge
struct AboutBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
