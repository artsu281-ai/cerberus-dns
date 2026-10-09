import Cocoa
import SwiftUI
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var cancellables = Set<AnyCancellable>()
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Проверка обновлений: не чаще раза в сутки, выключается в настройках.
        Task { @MainActor in await UpdateChecker.shared.checkIfDue() }

        // Иконку Dock задаёт CFBundleIconFile (AppIcon.icns) — трогать её не нужно.
        // Присваивание `NSApp.applicationIconImage` рисует картинку во всю плитку
        // Dock, без стандартного отступа macOS, поэтому после запуска иконка
        // заметно «подрастала» относительно соседних.
        
        // Setup Main Window
        let contentView = MainView()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.setFrameAutosaveName("DNSBlockMainWindow_v3")
        window.title = "Cerberus DNS"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 900, height: 580)
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.isReleasedWhenClosed = false

        // Восстанавливаем сохранённую геометрию и проверяем её.
        // Раньше `center()` вызывался до `setFrameAutosaveName`, поэтому
        // сохранённый кадр применялся поверх центрирования — а если монитор
        // с прошлого раза отключили, окно уезжало за край экрана вместе с
        // боковой панелью и его нельзя было вернуть мышью.
        if !window.setFrameUsingName(window.frameAutosaveName) {
            window.center()
        }
        constrainWindowToVisibleScreen()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Setup System Menu Bar with Popover and Full Application Menu
        setupMenuBar()
        setupApplicationMainMenu()
        
        // Subscribe to state changes for menu bar icon updates
        Publishers.CombineLatest3(DNSManager.shared.$isProtected, DNSManager.shared.$isPaused, DNSManager.shared.$mode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        // Главное меню строится один раз при запуске, поэтому переключатель
        // RU/EN на него не влиял — пересобираем его при смене языка.
        // Контекстное меню в строке состояния создаётся заново на каждый показ
        // и подхватывает язык само.
        LocalizationManager.shared.$currentLanguage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupApplicationMainMenu()
            }
            .store(in: &cancellables)
    }
    
    /// Возвращает окно в пределы видимой области текущего экрана.
    private func constrainWindowToVisibleScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame

        frame.size.width = min(max(frame.width, window.minSize.width), visible.width)
        frame.size.height = min(max(frame.height, window.minSize.height), visible.height)

        if !visible.contains(frame) {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }

        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }
    
    // MARK: - Menu Bar Popover Setup
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 300, height: 380)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                manager: DNSManager.shared,
                onOpenMainWindow: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.showMainWindow()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )
        self.popover = pop
    }
    
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let isProtected = DNSManager.shared.isProtected
        let isPaused = DNSManager.shared.isPaused
        
        let iconName: String
        if isPaused {
            iconName = "timer"
        } else if isProtected {
            iconName = "shield.fill"
        } else {
            iconName = "shield.slash"
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Cerberus DNS")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            popover?.performClose(nil)
            showStatusBarContextMenu(for: sender)
        } else {
            togglePopover(sender)
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let pop = popover, let button = statusItem?.button else { return }
        if pop.isShown {
            pop.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showStatusBarContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: tr("Открыть Cerberus DNS", "Open Cerberus DNS", "Cerberus DNS'ти ачуу"), action: #selector(showMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let isProtected = DNSManager.shared.isProtected
        let toggleItem = NSMenuItem(
            title: isProtected ? tr("Отключить защиту", "Disable protection", "Коргоону өчүрүү") : tr("Включить защиту", "Enable protection", "Коргоону күйгүзүү"),
            action: #selector(toggleProtectionFromMenu),
            keyEquivalent: "s"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let pauseItem = NSMenuItem(title: tr("Пауза на 15 минут", "Pause for 15 minutes", "15 мүнөткө тыным"), action: #selector(pause15FromMenu), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        // VPN submenu
        let vpnMenuItem = NSMenuItem(title: tr("Узлы VPN и прокси", "VPN & proxy nodes", "VPN жана прокси түйүндөрү"), action: nil, keyEquivalent: "")
        let vpnSubMenu = NSMenu(title: tr("Узлы VPN и прокси", "VPN & proxy nodes", "VPN жана прокси түйүндөрү"))
        
        for node in DNSManager.shared.allNodes {
            let item = NSMenuItem(
                title: "\(node.name) (\(node.kindBadge))",
                action: #selector(connectVPNFromMenu(_:)),
                keyEquivalent: ""
            )
            item.representedObject = node
            item.target = self
            if DNSManager.shared.vpnActive && DNSManager.shared.activeNodeId == node.id {
                item.state = .on
            }
            vpnSubMenu.addItem(item)
        }
        
        if DNSManager.shared.vpnActive {
            vpnSubMenu.addItem(NSMenuItem.separator())
            let discItem = NSMenuItem(title: tr("Отключить VPN", "Disconnect VPN", "VPN'ди ажыратуу"), action: #selector(disconnectVPNFromMenu), keyEquivalent: "")
            discItem.target = self
            vpnSubMenu.addItem(discItem)
        }
        
        vpnMenuItem.submenu = vpnSubMenu
        menu.addItem(vpnMenuItem)
        
        let flushItem = NSMenuItem(title: tr("Сбросить кэш DNS", "Flush DNS cache", "DNS кэшин тазалоо"), action: #selector(flushFromMenu), keyEquivalent: "f")
        flushItem.target = self
        menu.addItem(flushItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: tr("Завершить Cerberus DNS", "Quit Cerberus DNS", "Cerberus DNS'тен чыгуу"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc func connectVPNFromMenu(_ sender: NSMenuItem) {
        if let node = sender.representedObject as? VPNNode {
            DNSManager.shared.connectToVPNNode(node)
        }
    }
    
    @objc func disconnectVPNFromMenu() {
        DNSManager.shared.disconnectVPN()
    }
    
    @objc func toggleProtectionFromMenu() {
        DNSManager.shared.toggleProtection()
    }
    
    @objc func pause15FromMenu() {
        DNSManager.shared.pauseProtection(for: .min15)
    }
    
    @objc func flushFromMenu() {
        DNSManager.shared.flushDNS()
    }
    
    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Standard macOS Application Menu Bar
    private func setupApplicationMainMenu() {
        let mainMenu = NSMenu()
        
        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        let aboutItem = NSMenuItem(title: tr("О программе Cerberus DNS", "About Cerberus DNS", "Cerberus DNS жөнүндө"), action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: tr("Настройки...", "Settings...", "Жөндөөлөр..."), action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let servicesItem = NSMenuItem(title: tr("Службы", "Services", "Кызматтар"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: tr("Службы", "Services", "Кызматтар"))
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        appMenu.addItem(withTitle: tr("Скрыть Cerberus DNS", "Hide Cerberus DNS", "Cerberus DNS'ти жашыруу"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: tr("Скрыть остальные", "Hide others", "Башкаларын жашыруу"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: tr("Показать все", "Show all", "Баарын көрсөтүү"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: tr("Завершить Cerberus DNS", "Quit Cerberus DNS", "Cerberus DNS'тен чыгуу"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: tr("Файл", "File", "Файл"))
        let newRuleItem = NSMenuItem(title: tr("Новое правило...", "New rule...", "Жаңы эреже..."), action: #selector(openAddRule), keyEquivalent: "n")
        newRuleItem.target = self
        fileMenu.addItem(newRuleItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Закрыть окно", "Close window", "Терезени жабуу"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // 3. Edit Menu (Standard macOS Copy / Paste / Undo / Select All)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: tr("Правка", "Edit", "Түзөтүү"))
        // Стандартные действия редактирования ходят по цепочке респондеров как
        // `undo:` / `redo:`. `#selector(UndoManager.undo)` даёт селектор `undo`
        // без двоеточия — такие пункты меню всегда оставались неактивными.
        editMenu.addItem(withTitle: tr("Отменить", "Undo", "Артка кайтаруу"), action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: tr("Повторить", "Redo", "Кайталоо"), action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: tr("Вырезать", "Cut", "Кесүү"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: tr("Скопировать", "Copy", "Көчүрүү"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: tr("Вставить", "Paste", "Коюу"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: tr("Удалить", "Delete", "Жок кылуу"), action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: tr("Выбрать все", "Select all", "Баарын тандоо"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // 4. View Menu (Navigation & Appearance)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: tr("Вид", "View", "Көрүнүш"))
        
        // Порядок и клавиши берутся из самого AppTab, поэтому меню, подписи в
        // боковой панели и реальные сочетания больше не могут разойтись.
        // Прежде меню назначало ⌘2 профилям, боковая панель подписывала им ⌘3,
        // а вкладка «Инспектор трафика» в меню отсутствовала вовсе.
        for tab in AppTab.allCases {
            viewMenu.addItem(createNavMenuItem(title: tab.localizedTitle, tab: tab, key: tab.shortcutNumber))
        }
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let sidebarItem = NSMenuItem(title: tr("Скрыть / показать боковое меню", "Toggle sidebar", "Каптал менюну жашыруу / көрсөтүү"), action: #selector(toggleSidebarFromMenu), keyEquivalent: "\\")
        sidebarItem.target = self
        viewMenu.addItem(sidebarItem)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        // Submenu: Appearance
        let themeSubItem = NSMenuItem(title: tr("Тема оформления", "Appearance", "Жасалгалоо темасы"), action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: tr("Тема оформления", "Appearance", "Жасалгалоо темасы"))
        for (title, selector) in [(tr("Системная", "System", "Системалык"), #selector(setThemeSystem)),
                                  (tr("Светлая", "Light", "Жарык"), #selector(setThemeLight)),
                                  (tr("Тёмная", "Dark", "Караңгы"), #selector(setThemeDark))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            themeMenu.addItem(item)
        }
        themeSubItem.submenu = themeMenu
        viewMenu.addItem(themeSubItem)
        
        // Submenu: Sidebar Size
        let sizeSubItem = NSMenuItem(title: tr("Размер бокового меню", "Sidebar size", "Каптал менюнун өлчөмү"), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: tr("Размер бокового меню", "Sidebar size", "Каптал менюнун өлчөмү"))
        for (title, selector) in [(tr("Компактный", "Compact", "Чакан"), #selector(setSizeSmall)),
                                  (tr("Стандартный", "Standard", "Стандарттуу"), #selector(setSizeMedium)),
                                  (tr("Крупный", "Large", "Ири"), #selector(setSizeLarge))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            sizeMenu.addItem(item)
        }
        sizeSubItem.submenu = sizeMenu
        viewMenu.addItem(sizeSubItem)
        
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // 5. Actions Menu
        let actionsMenuItem = NSMenuItem()
        let actionsMenu = NSMenu(title: tr("Действия", "Actions", "Аракеттер"))
        for (title, selector, key) in [(tr("Включить / выключить защиту", "Toggle protection", "Коргоону күйгүзүү / өчүрүү"), #selector(toggleProtectionKey), "s"),
                                       (tr("Палитра команд...", "Command palette...", "Буйруктар палитрасы..."), #selector(openCommandPaletteKey), "k"),
                                       (tr("Очистить кэш DNS", "Flush DNS cache", "DNS кэшин тазалоо"), #selector(flushCacheKey), "f"),
                                       (tr("Обновить статус", "Refresh status", "Абалды жаңыртуу"), #selector(refreshStatusKey), "r")] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            actionsMenu.addItem(item)
        }
        
        let updateRulesItem = NSMenuItem(title: tr("Обновить базы блокировки", "Update blocklists", "Бөгөттөө базаларын жаңыртуу"), action: #selector(updateRulesKey), keyEquivalent: "u")
        updateRulesItem.keyEquivalentModifierMask = [.command, .shift]
        updateRulesItem.target = self
        actionsMenu.addItem(updateRulesItem)
        
        actionsMenuItem.submenu = actionsMenu
        mainMenu.addItem(actionsMenuItem)
        
        // 6. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: tr("Окно", "Window", "Терезе"))
        windowMenu.addItem(withTitle: tr("Свернуть", "Minimise", "Кичирейтүү"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: tr("Масштаб", "Zoom", "Масштаб"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: tr("Главное окно", "Main window", "Башкы терезе"), action: #selector(showMainWindow), keyEquivalent: "")
        windowMenu.addItem(withTitle: tr("Все окна на передний план", "Bring all to front", "Бардык терезелерди алдыга чыгаруу"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        
        // 7. Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: tr("Справка", "Help", "Жардам"))
        let faqItem = NSMenuItem(title: tr("База знаний и FAQ", "Knowledge base & FAQ", "Билим базасы жана FAQ"), action: #selector(goToFAQ), keyEquivalent: "?")
        faqItem.target = self
        helpMenu.addItem(faqItem)
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    private func createNavMenuItem(title: String, tab: AppTab, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(navTabAction(_:)), keyEquivalent: key)
        item.target = self
        item.representedObject = tab
        return item
    }
    
    @objc private func navTabAction(_ sender: NSMenuItem) {
        if let tab = sender.representedObject as? AppTab {
            showMainWindow()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                DNSManager.shared.selectedTab = tab
            }
        }
    }
    
    // MARK: - Menu Actions
    @objc func openPreferences() {
        showMainWindow()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            DNSManager.shared.selectedTab = .settings
        }
    }
    
    /// Переключает на вкладку «О программе» в настройках главного окна.
    @objc func openAbout() {
        showMainWindow()
        DNSManager.shared.selectedSettingsSubTab = 2
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            DNSManager.shared.selectedTab = .settings
        }
    }
    
    @objc func toggleSidebarFromMenu() {
        showMainWindow()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            ThemeManager.shared.toggleSidebar()
        }
    }
    
    @objc func openAddRule() {
        showMainWindow()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            DNSManager.shared.selectedTab = .rules
            DNSManager.shared.showAddRuleSheet = true
        }
    }
    
    @objc func goToDashboard() { navTabAction(createNavMenuItem(title: "", tab: .dashboard, key: "")) }
    @objc func goToProfiles() { navTabAction(createNavMenuItem(title: "", tab: .profiles, key: "")) }
    @objc func goToVPN() { navTabAction(createNavMenuItem(title: "", tab: .vpn, key: "")) }
    @objc func goToDiagnostics() { navTabAction(createNavMenuItem(title: "", tab: .diagnostics, key: "")) }
    @objc func goToRules() { navTabAction(createNavMenuItem(title: "", tab: .rules, key: "")) }
    @objc func goToTools() { navTabAction(createNavMenuItem(title: "", tab: .tools, key: "")) }
    @objc func goToFAQ() { navTabAction(createNavMenuItem(title: "", tab: .faq, key: "")) }
    
    @objc func setThemeSystem() { ThemeManager.shared.appearance = .system }
    @objc func setThemeLight() { ThemeManager.shared.appearance = .light }
    @objc func setThemeDark() { ThemeManager.shared.appearance = .dark }
    
    @objc func setSizeSmall() { ThemeManager.shared.sidebarSize = .small }
    @objc func setSizeMedium() { ThemeManager.shared.sidebarSize = .medium }
    @objc func setSizeLarge() { ThemeManager.shared.sidebarSize = .large }
    
    @objc func toggleProtectionKey() { DNSManager.shared.toggleProtection() }
    @objc func openCommandPaletteKey() { DNSManager.shared.showCommandPalette.toggle() }
    @objc func flushCacheKey() { DNSManager.shared.flushDNS() }
    @objc func refreshStatusKey() { DNSManager.shared.refreshStatus() }
    @objc func updateRulesKey() { DNSManager.shared.updateBlocklists() }
    
    /// Счётчики пишутся с задержкой; при выходе дописываем немедленно.
    func applicationWillTerminate(_ notification: Notification) {
        DNSManager.shared.saveAnalyticsNow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
