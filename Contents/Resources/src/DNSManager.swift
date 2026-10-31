import Foundation
import SwiftUI
import Combine
import AppKit
import UserNotifications
import ServiceManagement

class DNSManager: ObservableObject {
    static let shared = DNSManager()
    
    // MARK: - Published State
    @Published var isProtected: Bool = false
    @Published var mode: String = "off"
    @Published var currentProfileId: String = "adguard"
    @Published var isRunningService: Bool = false
    @Published var domainsCount: Int = 0
    @Published var lastUpdated: String = ""
    @Published var isAdBlocked: Bool = false
    @Published var currentPingMs: Int = -1
    @Published var networkServices: [NetworkServiceInfo] = []

    /// Резолвер, который система опрашивает на самом деле.
    @Published var effectiveResolver: String = ""
    @Published var effectiveInterface: String = ""
    /// Настроенный DNS перебит сторонним резолвером (VPN, Tailscale и т.п.).
    @Published var dnsOverridden: Bool = false
    @Published var overrideSource: String = ""

    /// Состояние Tailscale и разделения зон.
    @Published var tailscale: TailscaleInfo? = nil

    /// Перехват устроил Tailscale, и его можно развести с фильтром по зонам.
    var canFixTailscaleConflict: Bool {
        dnsOverridden && (tailscale?.canEnableSplit ?? false)
            && overrideSource.localizedCaseInsensitiveContains("tailscale")
    }

    /// Защита настроена, но фактически не действует.
    /// Здесь и лежала главная неправда интерфейса: приложение писало
    /// «Защита активна», опираясь на файл состояния, тогда как система
    /// ходила мимо настроенного DNS и не блокировалось ничего.
    var isProtectionBypassed: Bool {
        isProtected && dnsOverridden
    }
    
    // Latency History Sparkline
    @Published var latencyHistory: [LatencyPoint] = []
    
    // VPN & Proxy State
    @Published var vpnActive: Bool = false
    @Published var socksEnabled: Bool = false
    @Published var httpEnabled: Bool = false
    @Published var socksHost: String = "127.0.0.1"
    @Published var socksPort: String = "10808"
    @Published var httpHost: String = "127.0.0.1"
    @Published var httpPort: String = "8080"
    @Published var ipInfo: IPInfo? = nil
    @Published var isFetchingIP: Bool = false
    
    // Встроенное VPN-ядро (sing-box по ссылке подписки)
    @Published var vpnCore = VPNCoreStatus()
    @Published var vpnCoreBusy: Bool = false

    // VPN Nodes & Auto-Failover Pool
    /// Список до первого ответа движка.
    ///
    /// Прежние значения выдавали публичные резолверы за VPN-выходы в конкретных
    /// странах и содержали выдуманные задержки (12/38/44 мс), которые пользователь
    /// видел как результат замера. Теперь это те же узлы, что отдаёт движок,
    /// с `latencyMs: -1` — «ещё не измерено».
    @Published var availableNodes: [VPNNode] = [
        VPNNode(id: "warp_edge",    name: "Cloudflare 1.1.1.1", country: "WW", flag: "⚡️", host: "1.1.1.1",      port: "53",    protocolType: "dns",    isRecommended: true,  latencyMs: -1, isOnline: true),
        VPNNode(id: "nl_amsterdam", name: "AdGuard DNS",        country: "WW", flag: "🛡",  host: "94.140.14.14", port: "53",    protocolType: "dns",    isRecommended: true,  latencyMs: -1, isOnline: true),
        VPNNode(id: "de_frankfurt", name: "Cloudflare 1.0.0.1", country: "WW", flag: "⚡️", host: "1.0.0.1",      port: "53",    protocolType: "dns",    isRecommended: false, latencyMs: -1, isOnline: true),
        VPNNode(id: "fi_helsinki",  name: "Mullvad DNS",        country: "SE", flag: "🇸🇪", host: "194.242.2.3",  port: "53",    protocolType: "dns",    isRecommended: false, latencyMs: -1, isOnline: true),
        VPNNode(id: "se_stockholm", name: "Quad9",              country: "CH", flag: "🇨🇭", host: "9.9.9.9",      port: "53",    protocolType: "dns",    isRecommended: false, latencyMs: -1, isOnline: true),
        VPNNode(id: "us_newyork",   name: "Google Public DNS",  country: "US", flag: "🇺🇸", host: "8.8.8.8",      port: "53",    protocolType: "dns",    isRecommended: false, latencyMs: -1, isOnline: true),
        VPNNode(id: "local_v2ray",  name: tr("Локальный клиент (Xray / sing-box / Clash)", "Local client (Xray / sing-box / Clash)", "Жергиликтүү клиент (Xray / sing-box / Clash)"),
                country: "RU", flag: "💻", host: "127.0.0.1", port: "10808", protocolType: "socks5", isRecommended: false, latencyMs: -1, isOnline: true)
    ]
    @Published var customNodes: [VPNNode] = []
    @Published var activeNodeId: String = "warp_edge"
    @Published var routingMode: TrafficRoutingMode = .ruleBased {
        didSet {
            guard !isRestoringState, oldValue != routingMode else { return }
            UserDefaults.standard.set(routingMode.rawValue, forKey: "traffic_routing_mode")
            applyRoutingMode(routingMode)
        }
    }
    /// Поднято на время восстановления настроек из UserDefaults, чтобы
    /// `didSet` не показывал баннер и не проигрывал звук на старте приложения.
    private var isRestoringState = false
    @Published var forceProxyDomains: [String] = []
    @Published var forceDirectDomains: [String] = []
    @Published var showAddNodeSheet: Bool = false
    @Published var autoFailoverEnabled: Bool {
        didSet { UserDefaults.standard.set(autoFailoverEnabled, forKey: "auto_failover_enabled") }
    }
    @Published var isCheckingNodes: Bool = false
    
    // Онбординг
    /// Показывать первый запуск. Решение принимается один раз, после первого
    /// ответа движка: если защита уже настроена, мастер не показывается вовсе.
    @Published var showOnboarding: Bool = false
    private var didEvaluateOnboarding = false
    private static let onboardingKey = "onboarding_completed_v1"

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        showOnboarding = false
    }

    // UI Modals & Navigation
    @Published var selectedTab: AppTab = .dashboard
    @Published var selectedSettingsSubTab: Int = 0
    @Published var isBusy: Bool = false
    @Published var busyMessage: String = ""
    @Published var statusBanner: String? = nil
    @Published var showCommandPalette: Bool = false
    @Published var showSettingsSheet: Bool = false
    @Published var showAddRuleSheet: Bool = false
    @Published var vpnSubTab: Int = 0
    
    // Diagnostic & Benchmark State
    @Published var logEntries: [LogEntry] = []
    @Published var diagnosticResults: [DiagnosticItem] = []
    @Published var isDiagnosing: Bool = false
    @Published var speedTestResults: [SpeedTestItem] = []
    @Published var isSpeedTesting: Bool = false
    @Published var fullSpeedtestResult: NetworkSpeedtestResult? = nil
    @Published var isFullSpeedtesting: Bool = false
    /// Этап замера скорости как значение, а не как текст.
    /// Прогресс-анимация раньше сравнивала `speedtestPhase.contains("Замер пинга")` —
    /// перевод этой строки на английский молча сломал бы логику шкалы.
    enum SpeedtestStage {
        case idle, ping, download, upload, done, failedConnection, failedDecode

        var title: String {
            switch self {
            case .idle:             return tr("Готов", "Ready", "Даяр")
            case .ping:             return tr("Замер пинга и джиттера...", "Measuring ping and jitter...", "Пинг жана джиттерди өлчөө...")
            case .download:         return tr("Скачивание (Download Test)...", "Download test...", "Жүктөп алуу (Download Test)...")
            case .upload:           return tr("Отдача (Upload Test)...", "Upload test...", "Жөнөтүү (Upload Test)...")
            case .done:             return tr("Готово", "Finished", "Даяр")
            case .failedConnection: return tr("Ошибка соединения", "Connection failed", "Туташуу катасы")
            case .failedDecode:     return tr("Ошибка обработки", "Could not read the result", "Иштетүү катасы")
            }
        }
    }

    @Published var speedtestStage: SpeedtestStage = .idle
    var speedtestPhase: String { speedtestStage.title }
    @Published var liveSpeedGauge: Double = 0.0
    
    // User Rules & Config
    @Published var whitelistDomains: [String] = []
    @Published var blacklistDomains: [String] = []
    @Published var customDNSServers: String = "77.88.8.8 77.88.8.1"
    @Published var upstream1: String = "1.1.1.1" {
        didSet { UserDefaults.standard.set(upstream1, forKey: "upstream_dns_1") }
    }
    @Published var upstream2: String = "1.0.0.1" {
        didSet { UserDefaults.standard.set(upstream2, forKey: "upstream_dns_2") }
    }
    @Published var isHelperInstalled: Bool = false
    /// Root-копия движка старее того, что лежит в бандле, либо помощник
    /// установлен по небезопасной старой схеме.
    @Published var isHelperStale: Bool = false
    /// Помощник установлен старой версией приложения и исполняет движок
    /// из каталога, доступного пользователю на запись.
    @Published var isHelperLegacy: Bool = false
    
    // Pro Features
    @Published var queries: [DNSQueryLogItem] = []
    /// Поток запросов сгенерирован, а не прочитан из журнала dnsmasq.
    /// Реальный журнал существует только в локальном режиме; облачные
    /// резолверы ничего не пишут на этой машине. Раньше приложение показывало
    /// придуманные запросы под меткой LIVE, не различая эти два случая.
    @Published var isQueryStreamSimulated: Bool = true
    @Published var isStreamFrozen: Bool = false
    @Published var analytics: AnalyticsStats = AnalyticsStats() {
        didSet { scheduleAnalyticsSave() }
    }

    // ── Накопительная статистика и недельная сводка
    //
    // Раньше счётчики жили только в памяти и обнулялись при каждом запуске:
    // карточка «Экономия трафика» после перезапуска всегда показывала 0.0 МБ,
    // сколько бы приложение ни отработало.
    private static let analyticsKey = "analytics_total_v1"
    private static let digestDateKey = "digest_last_sent"
    private static let digestBaselineKey = "digest_baseline_v1"
    private var analyticsSaveWorkItem: DispatchWorkItem?

    private func scheduleAnalyticsSave() {
        // Именно throttle, а не debounce. Запросы в потоке идут чаще, чем окно
        // ожидания, и вариант с отменой предыдущего таймера не срабатывал бы
        // никогда: следующее изменение отменяло запись раньше, чем она успевала
        // произойти. Здесь первый же таймер доживает до конца, а последующие
        // изменения просто ничего не планируют.
        guard analyticsSaveWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.analyticsSaveWorkItem = nil
            self.saveAnalyticsNow()
        }
        analyticsSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    /// Немедленная запись — при выходе из приложения терять счётчики незачем.
    func saveAnalyticsNow() {
        guard let data = try? JSONEncoder().encode(analytics) else { return }
        UserDefaults.standard.set(data, forKey: Self.analyticsKey)
    }

    private func restoreAnalytics() {
        guard let data = UserDefaults.standard.data(forKey: Self.analyticsKey),
              let saved = try? JSONDecoder().decode(AnalyticsStats.self, from: data) else { return }
        analytics = saved
    }

    /// Показатели за неделю — разница с отметкой на момент прошлой сводки.
    var weeklyDelta: AnalyticsStats {
        let base = (UserDefaults.standard.data(forKey: Self.digestBaselineKey))
            .flatMap { try? JSONDecoder().decode(AnalyticsStats.self, from: $0) } ?? AnalyticsStats()
        var delta = AnalyticsStats()
        delta.totalQueries = max(0, analytics.totalQueries - base.totalQueries)
        delta.blockedQueries = max(0, analytics.blockedQueries - base.blockedQueries)
        delta.dataSavedMB = max(0, analytics.dataSavedMB - base.dataSavedMB)
        delta.timeSavedSec = max(0, analytics.timeSavedSec - base.timeSavedSec)
        delta.topTrackers = analytics.topTrackers
        return delta
    }

    /// Отправляет сводку и сдвигает отметку. `force` — для проверки вручную.
    func sendWeeklyDigest(force: Bool = false) {
        let last = UserDefaults.standard.object(forKey: Self.digestDateKey) as? Double
        let weekPassed = last.map { Date().timeIntervalSince1970 - $0 >= 7 * 24 * 3600 } ?? true

        guard force || weekPassed else { return }
        let delta = weeklyDelta
        // Пустая сводка — не сводка; молчим, а не шлём «заблокировано 0».
        guard force || delta.blockedQueries > 0 else { return }

        let top = delta.topTrackers.first.map { " \($0.domain) — \($0.count)." } ?? ""
        let body = tr("За неделю перехвачено \(delta.blockedQueries) из \(delta.totalQueries) запросов, это \(String(format: "%.0f", delta.blockRatioPct))%. Чаще всех:\(top)",
                      "This week \(delta.blockedQueries) of \(delta.totalQueries) queries were blocked, \(String(format: "%.0f", delta.blockRatioPct))%. Most frequent:\(top)", "Бир жумада \(delta.totalQueries) сурамдын \(delta.blockedQueries) кармалды, бул \(String(format: "%.0f", delta.blockRatioPct))%. Эң көп:\(top)")

        if notificationsEnabled && notificationsAuthorized && notificationsAvailable {
            let content = UNMutableNotificationContent()
            content.title = tr("🛡 Cerberus DNS за неделю", "🛡 Cerberus DNS this week", "🛡 Cerberus DNS бир жумада")
            content.body = body
            content.sound = nil
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "digest-\(Int(Date().timeIntervalSince1970))",
                                      content: content, trigger: nil))
        }
        showBanner(body)
        appendLog(tr("Недельная сводка: \(body)", "Weekly digest: \(body)", "Жумалык корутунду: \(body)"))

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.digestDateKey)
        if let data = try? JSONEncoder().encode(analytics) {
            UserDefaults.standard.set(data, forKey: Self.digestBaselineKey)
        }
    }

    @Published var isPaused: Bool = false
    @Published var pauseRemainingSeconds: Int = 0
    /// Переключатель в настройках — чего хочет пользователь.
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled") }
    }
    /// Разрешение, выданное macOS. Это отдельная величина: раньше ответ системы
    /// затирал пользовательскую настройку при каждом запуске.
    @Published var notificationsAuthorized: Bool = false
    
    // User Settings
    @Published var soundEffectsEnabled: Bool {
        didSet {
            SoundSystem.shared.isMuted = !soundEffectsEnabled
            UserDefaults.standard.set(soundEffectsEnabled, forKey: "sound_effects_enabled")
        }
    }
    @Published var autoLaunchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunchAtLogin, forKey: "auto_launch_login")
            setLaunchAtLogin(enabled: autoLaunchAtLogin)
        }
    }
    @Published var autoUpdateRules: Bool {
        didSet {
            UserDefaults.standard.set(autoUpdateRules, forKey: "auto_update_rules")
            DispatchQueue.global(qos: .utility).async { [weak self] in
                _ = self?.runRootCommand(args: [self?.autoUpdateRules == true ? "--enable-autoupdate" : "--disable-autoupdate"])
            }
        }
    }
    
    private var timer: AnyCancellable?
    private var queryStreamTimer: Timer?
    private var pauseTimer: Timer?
    private var pauseExpiryDate: Date?
    private let enginePath: String
    private var failoverConsecutiveErrors = 0
    
    init() {
        let soundPref = UserDefaults.standard.object(forKey: "sound_effects_enabled") as? Bool ?? true
        let notifPref = UserDefaults.standard.object(forKey: "notifications_enabled") as? Bool ?? true
        self.soundEffectsEnabled = soundPref
        self.notificationsEnabled = notifPref
        self.autoLaunchAtLogin = UserDefaults.standard.bool(forKey: "auto_launch_login")
        self.autoUpdateRules = UserDefaults.standard.object(forKey: "auto_update_rules") as? Bool ?? true
        self.autoFailoverEnabled = UserDefaults.standard.object(forKey: "auto_failover_enabled") as? Bool ?? true
        self.customDNSServers = UserDefaults.standard.string(forKey: "custom_dns_servers") ?? "77.88.8.8 77.88.8.1"
        self.upstream1 = UserDefaults.standard.string(forKey: "upstream_dns_1") ?? "1.1.1.1"
        self.upstream2 = UserDefaults.standard.string(forKey: "upstream_dns_2") ?? "1.0.0.1"
        
        self.enginePath = AppPaths.enginePath
        
        SoundSystem.shared.isMuted = !soundPref
        
        appendLog("Cerberus DNS v3.0 Pro")
        checkHelperStatus()
        refreshStatus()
        refreshVPNStatus()
        refreshVPNCore()
        fetchIPInfo()
        loadCustomVPNData()
        benchmarkVPNNodes(silent: true)
        loadCustomLists()
        restoreAnalytics()
        checkTailscale()
        checkBrowserDoH()
        // Проверяем при запуске: приложение живёт в строке меню и может
        // работать неделями, но перезапуск — самый надёжный момент.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.sendWeeklyDigest()
        }
        startLiveQueryStream()
        checkPendingPause()
        requestNotificationPermissions()
        
        // Timer for real-time monitoring and Auto-Failover Watchdog
        timer = Timer.publish(every: 8.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshStatus(silent: true)
                self?.refreshVPNStatus(silent: true)
                self?.refreshVPNCore()
                self?.checkAutoFailoverWatchdog()
            }
    }
    
    // MARK: - Logging
    func appendLog(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), text: message, isError: isError)
            self.logEntries.append(entry)
            if self.logEntries.count > 300 {
                self.logEntries.removeFirst(50)
            }
        }
    }
    
    func showBanner(_ text: String) {
        DispatchQueue.main.async {
            self.statusBanner = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                if self.statusBanner == text {
                    self.statusBanner = nil
                }
            }
        }
    }
    
    // MARK: - Current Profile Helper
    var currentProfile: DNSProfile {
        if !isProtected {
            return DNSProfile(
                id: "off",
                title: tr("Защита выключена", "Protection is off", "Коргоо өчүрүлгөн"),
                subtitle: tr("Используется системный DNS", "Using the system DNS", "Системалык DNS колдонулууда"),
                servers: tr("DHCP / Провайдер", "DHCP / ISP", "DHCP / Провайдер"),
                icon: "shield.slash",
                badge: tr("Неактивно", "Inactive", "Активдүү эмес"),
                color: Theme.shieldInactive,
                isLocal: false,
                description: tr("Запросы отправляются напрямую вашему интернет-провайдеру без фильтрации рекламы и трекеров.",
                             "Queries go straight to your ISP with no ad or tracker filtering.", "Сурамдар жарнама жана трекерлер чыпкаланбастан түз эле интернет-провайдериңизге жөнөтүлөт."),
                features: [tr("Фильтрация отключена", "Filtering disabled", "Чыпкалоо өчүрүлгөн")]
            )
        }
        return DNSProfile.allProfiles.first(where: { $0.id == currentProfileId }) ?? DNSProfile.allProfiles[0]
    }
    
    // MARK: - Status Refresh

    /// Один опрос статуса за раз.
    ///
    /// Обновление вызывается из таймера, по кнопке, при открытии вкладок и
    /// после каждой привилегированной операции. Наложившиеся вызовы порождали
    /// по своему процессу движка и гонялись за право записать состояние —
    /// побеждал не последний по факту, а последний по случайности.
    private let statusLock = NSLock()
    private var statusRefreshInFlight = false

    func refreshStatus(silent: Bool = false) {
        statusLock.lock()
        if statusRefreshInFlight {
            statusLock.unlock()
            // Явное обновление не глотаем совсем: пользователь нажал кнопку и
            // ждёт реакции, поэтому даём отработать уже идущему опросу.
            return
        }
        statusRefreshInFlight = true
        statusLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer {
                self.statusLock.lock()
                self.statusRefreshInFlight = false
                self.statusLock.unlock()
            }
            
            // Периодический опрос идёт в кратком режиме: он вдвое дешевле и
            // даёт то же самое, кроме списка сетевых служб, который меняется
            // раз в жизни и обновляется при явном обновлении.
            let output = self.runCommand(args: silent ? ["--status-json", "--brief"] : ["--status-json"])
            guard let data = output.data(using: .utf8) else {
                if !silent { self.appendLog(tr("Не удалось получить статус", "Could not read the status", "Абалды алуу мүмкүн болгон жок"), isError: true) }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let res = try decoder.decode(EngineStatusResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.mode = res.mode ?? "off"
                    self.isProtected = (self.mode != "off" && !self.mode.isEmpty)
                    self.currentProfileId = res.profile ?? (self.mode == "full" ? "local_dnsmasq" : "adguard")
                    self.isRunningService = res.running ?? false
                    self.domainsCount = res.domains ?? 0
                    self.lastUpdated = res.updated ?? ""
                    self.isAdBlocked = res.blocked ?? false
                    self.effectiveResolver = res.effectiveResolver ?? ""
                    self.effectiveInterface = res.effectiveInterface ?? ""
                    let wasOverridden = self.dnsOverridden
                    self.dnsOverridden = res.dnsOverridden ?? false
                    self.overrideSource = res.overrideSource ?? ""
                    self.dohBlockingEnabled = res.dohBlocking ?? false
                    if self.dnsOverridden && !wasOverridden {
                        // Опрашиваем Tailscale только когда перехват реально
                        // случился: запуск его CLI на каждом обновлении статуса
                        // раз в восемь секунд — лишняя работа впустую.
                        self.checkTailscale()
                        self.appendLog(tr("⚠️ Системный DNS перехвачен: \(self.effectiveResolver) — \(self.overrideSource). Фильтрация не применяется.", "⚠️ System DNS overridden by \(self.effectiveResolver) — \(self.overrideSource). Filtering is not applied.", "⚠️ Системалык DNS кармалып алынды: \(self.effectiveResolver) — \(self.overrideSource). Чыпкалоо колдонулбайт."), isError: true)
                    }
                    let newPing = res.pingMs ?? -1
                    self.currentPingMs = newPing

                    // Мастер первого запуска: показываем только тем, у кого
                    // защита ещё не настроена. Существующей установке он не
                    // нужен, поэтому и решаем после ответа движка, а не до.
                    if !self.didEvaluateOnboarding {
                        self.didEvaluateOnboarding = true
                        if !self.hasCompletedOnboarding {
                            if self.isProtected {
                                self.completeOnboarding()
                            } else {
                                self.showOnboarding = true
                            }
                        }
                    }
                    // В кратком режиме список приходит как null — оставляем прежний,
                    // иначе вкладка «Инструменты» опустела бы между обновлениями.
                    if let services = res.services { self.networkServices = services }
                    
                    // Add to Sparkline history
                    if newPing >= 0 {
                        self.latencyHistory.append(LatencyPoint(timestamp: Date(), latencyMs: newPing))
                        if self.latencyHistory.count > 15 {
                            self.latencyHistory.removeFirst()
                        }
                    }
                }
            } catch {
                if !silent { self.appendLog(tr("Ошибка разбора JSON: \(error.localizedDescription)", "JSON parse error: \(error.localizedDescription)", "JSON талдоо катасы: \(error.localizedDescription)"), isError: true) }
            }
        }
    }
    
    // MARK: - VPN & Proxy Status
    private var vpnRefreshInFlight = false

    func refreshVPNStatus(silent: Bool = false) {
        statusLock.lock()
        if vpnRefreshInFlight { statusLock.unlock(); return }
        vpnRefreshInFlight = true
        statusLock.unlock()

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            defer {
                self.statusLock.lock()
                self.vpnRefreshInFlight = false
                self.statusLock.unlock()
            }
            let out = self.runCommand(args: ["--vpn-status-json"])
            guard let data = out.data(using: .utf8) else { return }
            
            do {
                let res = try JSONDecoder().decode(VPNStatusResponse.self, from: data)
                DispatchQueue.main.async {
                    self.vpnActive = res.vpnActive ?? false
                    self.socksEnabled = res.socksEnabled ?? false
                    self.httpEnabled = res.httpEnabled ?? false
                    if let s = res.socksServer, !s.isEmpty { self.socksHost = s }
                    if let p = res.socksPort, !p.isEmpty { self.socksPort = p }
                    if let s = res.httpServer, !s.isEmpty { self.httpHost = s }
                    if let p = res.httpPort, !p.isEmpty { self.httpPort = p }
                }
            } catch {}
        }
    }
    
    // MARK: - Benchmark VPN Nodes
    func benchmarkVPNNodes(silent: Bool = false) {
        if !silent { isCheckingNodes = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--test-vpn-nodes-json"])
            
            // Замеряем пользовательские узлы напрямую в Swift
            var updatedCustom = self.customNodes
            for i in 0..<updatedCustom.count {
                let p = Int(updatedCustom[i].port) ?? 443
                let ms = self.measureTCPConnectLatency(host: updatedCustom[i].host, port: p)
                updatedCustom[i].latencyMs = ms
                updatedCustom[i].isOnline = (ms >= 0)
            }
            
            guard let data = out.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.customNodes = updatedCustom
                    self.isCheckingNodes = false
                }
                return
            }
            
            do {
                let nodes = try JSONDecoder().decode([VPNNode].self, from: data)
                DispatchQueue.main.async {
                    self.customNodes = updatedCustom
                    guard !nodes.isEmpty else {
                        self.isCheckingNodes = false
                        return
                    }
                    self.availableNodes = nodes
                    self.isCheckingNodes = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.customNodes = updatedCustom
                    self.isCheckingNodes = false
                    if !silent {
                        self.appendLog(tr("Не удалось разобрать список узлов: \(error.localizedDescription)", "Could not parse the node list: \(error.localizedDescription)", "Түйүндөр тизмесин талдоо мүмкүн болгон жок: \(error.localizedDescription)"), isError: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Connect to Specific VPN / Proxy Node

    /// Подключение к узлу.
    ///
    /// Разводка по типу узла, а не по списку захардкоженных идентификаторов.
    /// Прежняя версия для любого нераспознанного узла выполняла
    /// `--apply-socks5-proxy <host> <port>`; для встроенных «узлов» это означало
    /// прописать системный SOCKS-прокси на DNS-сервер (например 8.8.8.8:53),
    /// после чего сеть в системе переставала работать вовсе.
    func connectToVPNNode(_ node: VPNNode) {
        guard !isBusy else { return }
        activeNodeId = node.id
        isBusy = true
        busyMessage = tr("Подключаю узел [\(node.kindBadge)] \(node.name)...", "Connecting to [\(node.kindBadge)] \(node.name)...", "[\(node.kindBadge)] \(node.name) түйүнүн туташтырып жатам...")
        appendLog(tr("Подключение к узлу: \(node.name) (\(node.kindBadge) \(node.host):\(node.port))", "Connecting to \(node.name) (\(node.kindBadge) \(node.host):\(node.port))", "Түйүнгө туташуу: \(node.name) (\(node.kindBadge) \(node.host):\(node.port))"))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var success = false
            var failureReason = ""

            switch node.kind {
            case .dns:
                // Публичный резолвер: применяем его как DNS, а не как прокси.
                if node.id == "warp_edge",
                   let cloudflare = DNSProfile.allProfiles.first(where: { $0.id == "cloudflare_security" }) {
                    success = self.runRootCommand(args: ["--apply-profile", cloudflare.id])
                } else if !node.host.isEmpty {
                    success = self.runRootCommand(args: ["--apply-profile", "custom", node.host])
                } else {
                    failureReason = tr("у узла не задан адрес сервера", "the node has no server address", "түйүндүн сервер дареги көрсөтүлгөн эмес")
                }

            case .proxy:
                guard let port = Int(node.port), port > 0, port < 65536, port != 53 else {
                    failureReason = tr("недопустимый порт прокси «\(node.port)»", "invalid proxy port “\(node.port)”", "прокси порту жараксыз: «\(node.port)»")
                    break
                }

                switch node.protocolType {
                case "socks5":
                    if node.host == "127.0.0.1" || node.host == "localhost" {
                        if !self.isLocalPortListening(port) {
                            failureReason = tr("локальный SOCKS5-клиент не запущен на порту \(port)", "local SOCKS5 client is not running on port \(port)", "жергиликтүү SOCKS5 клиенти \(port) портунда иштебей турат")
                            self.appendLog(tr("✘ Ошибка: порт 127.0.0.1:\(port) закрыт. Запустите клиент перед подключением.", "✘ Error: port 127.0.0.1:\(port) is closed. Launch your client before connecting.", "✘ Ката: 127.0.0.1:\(port) порту жабык. Туташуудан мурун клиентти иштетиңиз."), isError: true)
                            break
                        }
                    }
                    success = self.runRootCommand(args: ["--apply-socks5-proxy", node.host, node.port])
                case "http":
                    success = self.runRootCommand(args: ["--apply-http-proxy", node.host, node.port])
                default:
                    let localPortStr = self.socksPort.isEmpty ? "10808" : self.socksPort
                    let localPort = Int(localPortStr) ?? 10808
                    if !self.isLocalPortListening(localPort) {
                        failureReason = tr("локальный клиент (Xray / sing-box) не запущен на порту \(localPort)", "local client (Xray / sing-box) is not listening on port \(localPort)", "жергиликтүү клиент (Xray / sing-box) \(localPort) портунда иштебей турат")
                        self.appendLog(tr("✘ Ошибка: порт 127.0.0.1:\(localPort) закрыт. Запустите клиент Xray / sing-box для работы узла \(node.protocolType.uppercased()).", "✘ Error: port 127.0.0.1:\(localPort) is closed. Launch Xray / sing-box before connecting \(node.protocolType.uppercased()).", "✘ Ката: 127.0.0.1:\(localPort) порту жабык. \(node.protocolType.uppercased()) түйүнү иштеши үчүн Xray / sing-box клиентин иштетиңиз."), isError: true)
                        break
                    }
                    self.appendLog(tr("Узел \(node.protocolType.uppercased()) перенаправлен на локальный клиент 127.0.0.1:\(localPort)", "\(node.protocolType.uppercased()) routed to local client 127.0.0.1:\(localPort)", "\(node.protocolType.uppercased()) түйүнү 127.0.0.1:\(localPort) жергиликтүү клиентине багытталды"))
                    success = self.runRootCommand(args: ["--apply-socks5-proxy", "127.0.0.1", localPortStr])
                }
            }

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    if node.kind == .proxy { self.vpnActive = true }
                    self.showBanner(tr("Подключено: \(node.name) [\(node.kindBadge)]", "Connected: \(node.name) [\(node.kindBadge)]", "Туташты: \(node.name) [\(node.kindBadge)]"))
                    self.appendLog(tr("✔ Активен узел: \(node.name)", "✔ Active node: \(node.name)", "✔ Активдүү түйүн: \(node.name)"))
                    self.fetchIPInfo()
                    SoundSystem.shared.playSuccess()
                } else {
                    let suffix = failureReason.isEmpty ? "" : " — \(failureReason)"
                    self.showBanner(tr("Не удалось подключить «\(node.name)»\(suffix)", "Could not connect to “\(node.name)”\(suffix)", "«\(node.name)» туташтыруу мүмкүн болгон жок\(suffix)"))
                    self.appendLog(tr("✘ Узел \(node.name) не подключён\(suffix)", "✘ Node \(node.name) not connected\(suffix)", "✘ \(node.name) түйүнү туташкан жок\(suffix)"), isError: true)
                }
                self.refreshStatus()
                self.refreshVPNStatus()
            }
        }
    }

    // MARK: - Встроенное VPN-ядро

    /// Вызов движка от пользователя с кодом возврата. `runCommand` отдаёт только
    /// stdout, а здесь от успеха шага зависит, делать ли следующий.
    private func runEngineChecked(_ args: [String], timeout: TimeInterval = 240) -> (ok: Bool, out: String) {
        let r = runProcess(launchPath: "/bin/bash", arguments: [enginePath] + args, timeout: timeout)
        let text = (r.stdout + "\n" + r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return (r.succeeded, text)
    }

    /// Последняя содержательная строка вывода движка без ANSI-раскраски - для баннера.
    private func lastLine(_ text: String) -> String {
        let line = text.split(separator: "\n").last.map(String.init) ?? ""
        let plain = line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ✔✘!▸"))
        return EngineText.localize(plain)
    }

    func refreshVPNCore() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--vpn-core-status-json"], timeout: 15)
            guard let data = out.data(using: .utf8),
                  let status = try? JSONDecoder().decode(VPNCoreStatus.self, from: data) else { return }
            DispatchQueue.main.async { if self.vpnCore != status { self.vpnCore = status } }
        }
    }

    /// Подключение одной кнопкой: ядро (если его ещё нет) → подписка → запуск →
    /// системный прокси. Порядок важен: прокси включается ПОСЛЕДНИМ и только когда
    /// порт уже слушает, иначе человек на секунды-минуты остаётся без сети вовсе.
    func connectEmbeddedVPN(subscription: String? = nil) {
        guard !vpnCoreBusy else { return }
        vpnCoreBusy = true
        appendLog(tr("Встроенный VPN: подключение…", "Embedded VPN: connecting…", "Камтылган VPN: туташууда…"))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var failure = ""

            if let url = subscription?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
                let r = self.runEngineChecked(["--vpn-sub-set", url], timeout: 15)
                if !r.ok { failure = self.lastLine(r.out) }
            }
            if failure.isEmpty && !self.vpnCore.isInstalled {
                DispatchQueue.main.async { self.busyMessage = tr("Скачиваю VPN-ядро…", "Downloading the VPN core…", "VPN өзөгүн жүктөп жатам…") }
                let r = self.runEngineChecked(["--vpn-core-install"])
                if !r.ok { failure = self.lastLine(r.out) }
            }
            if failure.isEmpty {
                // Недоступная подписка - не отказ, если профиль уже сохранён: это и есть
                // случай «адрес подписки заблокировали», ради которого профиль кэшируется.
                let r = self.runEngineChecked(["--vpn-sub-update"], timeout: 90)
                if !r.ok { failure = self.lastLine(r.out) }
            }
            if failure.isEmpty {
                let r = self.runEngineChecked(["--vpn-core-start"], timeout: 30)
                if !r.ok { failure = self.lastLine(r.out) }
            }
            if failure.isEmpty {
                let port = String(self.vpnCore.port ?? 10808)
                if !self.runRootCommand(args: ["--apply-socks5-proxy", "127.0.0.1", port]) {
                    // Права не дали - ядро без прокси бесполезно, не оставляем его висеть.
                    _ = self.runEngineChecked(["--vpn-core-stop"], timeout: 15)
                    failure = tr("не удалось включить системный прокси", "could not enable the system proxy", "системалык проксини күйгүзүү мүмкүн болгон жок")
                }
            }

            DispatchQueue.main.async {
                self.vpnCoreBusy = false
                if failure.isEmpty {
                    self.vpnActive = true
                    self.showBanner(tr("VPN подключён", "VPN connected", "VPN туташты"))
                    self.appendLog(tr("✔ Встроенный VPN активен", "✔ Embedded VPN is active", "✔ Камтылган VPN активдүү"))
                    SoundSystem.shared.playSuccess()
                    self.fetchIPInfo()
                } else {
                    self.showBanner(tr("VPN не подключён — \(failure)", "VPN not connected — \(failure)", "VPN туташкан жок — \(failure)"))
                    self.appendLog(tr("✘ Встроенный VPN: \(failure)", "✘ Embedded VPN: \(failure)", "✘ Камтылган VPN: \(failure)"), isError: true)
                }
                self.refreshVPNCore()
                self.refreshVPNStatus()
            }
        }
    }

    /// Отключение в обратном порядке: сначала снять прокси, потом гасить ядро.
    func disconnectEmbeddedVPN() {
        guard !vpnCoreBusy else { return }
        vpnCoreBusy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let proxyOff = self.runRootCommand(args: ["--apply-proxy-off"])
            if proxyOff { _ = self.runEngineChecked(["--vpn-core-stop"], timeout: 15) }
            DispatchQueue.main.async {
                self.vpnCoreBusy = false
                if proxyOff {
                    self.vpnActive = false
                    self.showBanner(tr("VPN отключён — прямое соединение", "VPN off — direct connection", "VPN ажыратылды — түз туташуу"))
                    SoundSystem.shared.playToggle()
                    self.fetchIPInfo()
                } else {
                    // Ядро НЕ гасим: прокси остался включён, без ядра пропал бы интернет.
                    self.showBanner(tr("Не удалось снять системный прокси — VPN оставлен включённым",
                                       "Could not remove the system proxy — VPN left on", "Системалык проксини алып салуу мүмкүн болгон жок — VPN күйгүзүлгөн бойдон калды"))
                }
                self.refreshVPNCore()
                self.refreshVPNStatus()
            }
        }
    }

    func updateEmbeddedVPNProfile() {
        guard !vpnCoreBusy else { return }
        vpnCoreBusy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var r = self.runEngineChecked(["--vpn-sub-update"], timeout: 90)
            // Новый профиль подхватывается только перезапуском ядра.
            if r.ok && self.vpnCore.isUp { r = self.runEngineChecked(["--vpn-core-start"], timeout: 30) }
            DispatchQueue.main.async {
                self.vpnCoreBusy = false
                self.showBanner(self.lastLine(r.out))
                self.refreshVPNCore()
            }
        }
    }

    /// Чей DNS главнее внутри VPN: туннель (приватно) или фильтр Cerberus (без рекламы).
    func setEmbeddedVPNDNSMode(_ mode: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard self.runEngineChecked(["--vpn-dns-mode", mode], timeout: 10).ok else { return }
            DispatchQueue.main.async { self.updateEmbeddedVPNProfile() }
        }
    }

    // MARK: - Network & Port Diagnostics
    func isLocalPortListening(_ port: Int) -> Bool {
        guard port > 0 && port < 65536 else { return false }
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return res == 0
    }

    func measureTCPConnectLatency(host: String, port: Int) -> Int {
        guard port > 0 && port < 65536 else { return -1 }
        guard let hostEntry = gethostbyname(host), let addrList = hostEntry.pointee.h_addr_list else { return -1 }
        guard let firstAddr = addrList[0] else { return -1 }

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return -1 }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        memcpy(&addr.sin_addr, firstAddr, MemoryLayout<in_addr>.size)
        
        let t0 = CFAbsoluteTimeGetCurrent()
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if res == 0 {
            let elapsed = CFAbsoluteTimeGetCurrent() - t0
            return max(1, Int(elapsed * 1000.0))
        }
        return -1
    }

    static func isValidIP(_ ip: String) -> Bool {
        DomainValidator.isValidIP(ip)
    }

    func saveUpstreamDNS(dns1: String, dns2: String) {
        let clean1 = dns1.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean2 = dns2.trimmingCharacters(in: .whitespacesAndNewlines)
        let target1 = clean1.isEmpty ? "1.1.1.1" : clean1
        let target2 = clean2.isEmpty ? "1.0.0.1" : clean2
        guard Self.isValidIP(target1) else {
            showBanner(tr("Некорректный IP-адрес основного DNS: \(clean1)", "Invalid primary DNS IP: \(clean1)", "Негизги DNS'тин IP дареги туура эмес: \(clean1)"))
            return
        }
        guard Self.isValidIP(target2) else {
            showBanner(tr("Некорректный IP-адрес резервного DNS: \(clean2)", "Invalid secondary DNS IP: \(clean2)", "Камдык DNS'тин IP дареги туура эмес: \(clean2)"))
            return
        }
        upstream1 = target1
        upstream2 = target2
        _ = runRootCommand(args: ["--set-upstreams", upstream1, upstream2])
        showBanner(tr("Вышестоящие DNS сохранены: \(upstream1), \(upstream2)", "Upstream DNS saved: \(upstream1), \(upstream2)", "Жогорку деңгээлдеги DNS сакталды: \(upstream1), \(upstream2)"))
        appendLog(tr("Вышестоящие DNS обновлены: \(upstream1), \(upstream2)", "Upstream DNS updated: \(upstream1), \(upstream2)", "Жогорку деңгээлдеги DNS жаңыртылды: \(upstream1), \(upstream2)"))
    }
    
    // MARK: - Modern Protocols & Custom Node Store
    func loadCustomVPNData() {
        isRestoringState = true
        defer { isRestoringState = false }

        if let savedMode = UserDefaults.standard.string(forKey: "traffic_routing_mode"),
           let mode = TrafficRoutingMode(rawValue: savedMode) {
            self.routingMode = mode
        }
        self.forceProxyDomains = UserDefaults.standard.stringArray(forKey: "force_proxy_domains") ?? [
            "youtube.com", "instagram.com", "twitter.com", "x.com", "notion.so", "chatgpt.com", "openai.com"
        ]
        self.forceDirectDomains = UserDefaults.standard.stringArray(forKey: "force_direct_domains") ?? [
            "gosuslugi.ru", "sberbank.ru", "tbank.ru", "yandex.ru", "vk.com", "mail.ru", "kinopoisk.ru"
        ]
        
        if let data = UserDefaults.standard.data(forKey: "custom_vpn_nodes"),
           let nodes = try? JSONDecoder().decode([VPNNode].self, from: data) {
            self.customNodes = nodes
        }
    }
    
    func saveCustomVPNData() {
        if let data = try? JSONEncoder().encode(customNodes) {
            UserDefaults.standard.set(data, forKey: "custom_vpn_nodes")
        }
        UserDefaults.standard.set(forceProxyDomains, forKey: "force_proxy_domains")
        UserDefaults.standard.set(forceDirectDomains, forKey: "force_direct_domains")
    }
    
    func addCustomNode(_ node: VPNNode) {
        customNodes.removeAll { $0.id == node.id }
        customNodes.insert(node, at: 0)
        saveCustomVPNData()
        appendLog(tr("Добавлен узел: [\(node.kindBadge)] \(node.name)", "Node added: [\(node.kindBadge)] \(node.name)", "Түйүн кошулду: [\(node.kindBadge)] \(node.name)"))
        showBanner(tr("Узел «\(node.name)» сохранён", "Node “\(node.name)” saved", "«\(node.name)» түйүнү сакталды"))
        SoundSystem.shared.playSuccess()
    }
    
    func deleteCustomNode(_ id: String) {
        customNodes.removeAll { $0.id == id }
        saveCustomVPNData()
        appendLog(tr("Удалён узел: \(id)", "Node removed: \(id)", "Түйүн жок кылынды: \(id)"))
        showBanner(tr("Узел удалён", "Node removed", "Түйүн жок кылынды"))
        SoundSystem.shared.playAction()
    }
    
    func importFromClipboard() -> Bool {
        guard let clipText = NSPasteboard.general.string(forType: .string) else {
            showBanner(tr("Буфер обмена пуст", "Clipboard is empty", "Алмашуу буфери бош"))
            return false
        }
        
        if let parsed = parseProxyLink(clipText) {
            addCustomNode(parsed)
            return true
        } else {
            showBanner(tr("Неверный формат ссылки (vless://, ss://, trojan://)", "Unsupported link format (vless://, ss://, trojan://)", "Шилтеменин форматы туура эмес (vless://, ss://, trojan://)"))
            appendLog(tr("Не удалось распознать ссылку прокси в буфере", "Could not parse a proxy link from the clipboard", "Буфердеги прокси шилтемесин таануу мүмкүн болгон жок"), isError: true)
            return false
        }
    }
    
    /// Разбор ссылки на прокси.
    ///
    /// Страна и флаг больше не подставляются по схеме ссылки: раньше любой
    /// `vless://` объявлялся немецким, а `ss://` — нидерландским, независимо
    /// от того, где стоит сервер. Ссылка страну не содержит, поэтому честнее
    /// не знать её, чем сообщить выдуманную.
    func parseProxyLink(_ rawLink: String) -> VPNNode? {
        let trimmed = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        
        let nodeName = url.fragment?.removingPercentEncoding ?? "Custom Server"
        let host = url.host ?? ""
        let port = url.port != nil ? String(url.port!) : "443"
        let user = url.user ?? ""
        
        var queryParams: [String: String] = [:]
        if let components = URLComponents(string: trimmed), let queryItems = components.queryItems {
            for item in queryItems {
                queryParams[item.name.lowercased()] = item.value ?? ""
            }
        }
        
        if scheme == "vless" {
            let security = queryParams["security"] ?? "reality"
            let sni = queryParams["sni"] ?? queryParams["server_name"] ?? ""
            let pbk = queryParams["pbk"] ?? queryParams["public_key"] ?? ""
            let sid = queryParams["sid"] ?? queryParams["short_id"] ?? ""
            let flow = queryParams["flow"] ?? "xtls-rprx-vision"
            let transport = queryParams["type"] ?? queryParams["transport"] ?? "tcp"
            
            return VPNNode(
                id: "vless_\(UUID().uuidString.prefix(8))",
                name: nodeName.isEmpty ? "VLESS Reality Node" : nodeName,
                country: "WW",
                flag: "🌐",
                host: host,
                port: port,
                protocolType: "vless",
                isRecommended: true,
                latencyMs: -1,
                isOnline: true,
                uuid: user,
                password: nil,
                security: security,
                sni: sni,
                publicKey: pbk,
                shortId: sid,
                flow: flow,
                transport: transport,
                isCustom: true
            )
        } else if scheme == "ss" {
            return VPNNode(
                id: "ss_\(UUID().uuidString.prefix(8))",
                name: nodeName.isEmpty ? "Shadowsocks Node" : nodeName,
                country: "WW",
                flag: "🌐",
                host: host.isEmpty ? "127.0.0.1" : host,
                port: port.isEmpty ? "8388" : port,
                protocolType: "shadowsocks",
                isRecommended: false,
                latencyMs: -1,
                isOnline: true,
                password: user,
                isCustom: true
            )
        } else if scheme == "trojan" {
            return VPNNode(
                id: "trojan_\(UUID().uuidString.prefix(8))",
                name: nodeName.isEmpty ? "Trojan Node" : nodeName,
                country: "WW",
                flag: "🌐",
                host: host,
                port: port,
                protocolType: "trojan",
                isRecommended: false,
                latencyMs: -1,
                isOnline: true,
                password: user,
                sni: queryParams["sni"] ?? host,
                isCustom: true
            )
        } else if scheme == "hysteria2" || scheme == "hy2" {
            return VPNNode(
                id: "hy2_\(UUID().uuidString.prefix(8))",
                name: nodeName.isEmpty ? "Hysteria 2 Node" : nodeName,
                country: "WW",
                flag: "🌐",
                host: host,
                port: port,
                protocolType: "hysteria2",
                isRecommended: false,
                latencyMs: -1,
                isOnline: true,
                password: user,
                sni: queryParams["sni"] ?? host,
                isCustom: true
            )
        } else if scheme == "socks5" || scheme == "socks" {
            return VPNNode(
                id: "socks5_\(UUID().uuidString.prefix(8))",
                name: nodeName.isEmpty ? "SOCKS5 Proxy" : nodeName,
                country: "WW",
                flag: "🌐",
                host: host,
                port: port.isEmpty ? "1080" : port,
                protocolType: "socks5",
                isRecommended: false,
                latencyMs: -1,
                isOnline: true,
                isCustom: true
            )
        }
        return nil
    }
    
    /// Разделение трафика по доменам приложением не реализовано.
    ///
    /// Функция сообщала «Применён режим маршрутизации» и не делала ничего.
    /// Чтобы делать это по-настоящему, нужен PAC-файл или сетевое расширение:
    /// системный SOCKS-прокси в macOS задаётся целиком, без разбора по доменам.
    /// Выбор сохраняется — списки доменов пригодятся, когда механизм появится, —
    /// но выдавать сохранение за применение больше не будем.
    var routingIsEnforced: Bool { false }

    func applyRoutingMode(_ mode: TrafficRoutingMode) {
        appendLog(tr("Выбран режим маршрутизации: \(mode.title). Разделение трафика по доменам пока не выполняется.",
                     "Routing mode selected: \(mode.title). Per-domain traffic splitting is not enforced yet.", "Багыттоо режими тандалды: \(mode.title). Трафикти домендер боюнча бөлүү азырынча аткарылбайт."))
        showBanner(tr("Режим сохранён — разделение по доменам пока не работает",
                      "Mode saved — per-domain splitting does not work yet", "Режим сакталды — домендер боюнча бөлүү азырынча иштебейт"))
        SoundSystem.shared.playAction()
    }
    
    func addForceProxyDomain(_ domain: String) {
        guard let clean = DomainValidator.sanitized(domain) else {
            showBanner(tr("Некорректное доменное имя", "Invalid domain name", "Домендик ат туура эмес"))
            return
        }
        guard !forceProxyDomains.contains(clean) else { return }
        forceProxyDomains.append(clean)
        saveCustomVPNData()
    }
    
    func removeForceProxyDomain(_ domain: String) {
        forceProxyDomains.removeAll { $0 == domain }
        saveCustomVPNData()
    }
    
    func addForceDirectDomain(_ domain: String) {
        guard let clean = DomainValidator.sanitized(domain) else {
            showBanner(tr("Некорректное доменное имя", "Invalid domain name", "Домендик ат туура эмес"))
            return
        }
        guard !forceDirectDomains.contains(clean) else { return }
        forceDirectDomains.append(clean)
        saveCustomVPNData()
    }
    
    func removeForceDirectDomain(_ domain: String) {
        forceDirectDomains.removeAll { $0 == domain }
        saveCustomVPNData()
    }
    
    // MARK: - Auto-Failover Watchdog (Авто-фоллбек)
    /// Все узлы: встроенные плюс добавленные пользователем.
    /// Меню в строке состояния, палитра команд и авто-фоллбек раньше видели
    /// только встроенные, из-за чего собственные узлы были недоступны отовсюду,
    /// кроме вкладки «VPN и Прокси».
    var allNodes: [VPNNode] {
        customNodes + availableNodes
    }

    var activeNode: VPNNode? {
        allNodes.first(where: { $0.id == activeNodeId })
    }

    private func checkAutoFailoverWatchdog() {
        guard vpnActive, autoFailoverEnabled, !isBusy else { return }

        let currentNode = activeNode
        // Узел считается плохим, если сорван замер DNS ЛИБО сам узел не отвечает.
        // Прежнее условие требовало и того, и другого одновременно, причём
        // отсутствующий узел давал `0 < 0` — фоллбек не срабатывал никогда.
        let pingBad = currentPingMs < 0 || currentPingMs > 1500
        let nodeBad = currentNode.map { !$0.isOnline || $0.latencyMs < 0 } ?? false
        guard pingBad || nodeBad else {
            failoverConsecutiveErrors = 0
            return
        }

        failoverConsecutiveErrors += 1
        guard failoverConsecutiveErrors >= 2 else { return }
        failoverConsecutiveErrors = 0

        let candidates = allNodes
            .filter { $0.id != activeNodeId && $0.isOnline && $0.latencyMs > 0 }
            .sorted { $0.latencyMs < $1.latencyMs }

        guard let fallbackNode = candidates.first else {
            appendLog(tr("⚡️ Авто-фоллбек: узел \(currentNode?.name ?? activeNodeId) недоступен, но живых запасных узлов нет", "⚡️ Failover: \(currentNode?.name ?? activeNodeId) is down and no healthy backup node is available", "⚡️ Авто-алмаштыруу: \(currentNode?.name ?? activeNodeId) түйүнү жеткиликсиз, бирок иштеп турган запастагы түйүндөр жок"), isError: true)
            return
        }

        appendLog(tr("⚡️ Авто-фоллбек: узел \(currentNode?.name ?? activeNodeId) недоступен. Переключаемся на \(fallbackNode.name)...", "⚡️ Failover: \(currentNode?.name ?? activeNodeId) is down. Switching to \(fallbackNode.name)...", "⚡️ Авто-алмаштыруу: \(currentNode?.name ?? activeNodeId) түйүнү жеткиликсиз. \(fallbackNode.name) түйүнүнө өтөбүз..."), isError: true)
        showBanner(tr("⚡️ Авто-фоллбек: \(fallbackNode.flag) \(fallbackNode.name) (\(fallbackNode.latencyMs) мс)", "⚡️ Failover: \(fallbackNode.flag) \(fallbackNode.name) (\(fallbackNode.latencyMs) ms)", "⚡️ Авто-алмаштыруу: \(fallbackNode.flag) \(fallbackNode.name) (\(fallbackNode.latencyMs) мс)"))
        connectToVPNNode(fallbackNode)
    }
    
    // MARK: - Fetch IP Info
    func fetchIPInfo() {
        isFetchingIP = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--get-ip-info-json"])
            guard let data = out.data(using: .utf8) else {
                DispatchQueue.main.async { self.isFetchingIP = false }
                return
            }
            
            do {
                let info = try JSONDecoder().decode(IPInfo.self, from: data)
                DispatchQueue.main.async {
                    self.ipInfo = info
                    self.isFetchingIP = false
                }
            } catch {
                DispatchQueue.main.async { self.isFetchingIP = false }
            }
        }
    }
    
    // MARK: - Apply SOCKS5 Proxy
    func applySocks5Proxy(host: String, port: String) {
        isBusy = true
        busyMessage = tr("Включаю SOCKS5-прокси \(host):\(port)...", "Enabling SOCKS5 proxy \(host):\(port)...", "SOCKS5 проксини күйгүзүп жатам \(host):\(port)...")
        appendLog(tr("Активация SOCKS5-туннеля: \(host):\(port)", "Enabling SOCKS5 tunnel: \(host):\(port)", "SOCKS5 туннелин активдештирүү: \(host):\(port)"))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--apply-socks5-proxy", host, port])
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.socksEnabled = true
                    self.vpnActive = true
                    self.showBanner(tr("SOCKS5-прокси включён (\(host):\(port))", "SOCKS5 proxy enabled (\(host):\(port))", "SOCKS5 прокси күйгүзүлдү (\(host):\(port))"))
                    self.appendLog(tr("✔ SOCKS5-туннель активен", "✔ SOCKS5 tunnel is active", "✔ SOCKS5 туннели активдүү"))
                    self.fetchIPInfo()
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось включить SOCKS5", "Could not enable SOCKS5", "SOCKS5'ти күйгүзүү мүмкүн болгон жок"))
                }
                self.refreshVPNStatus()
            }
        }
    }
    
    // MARK: - Apply HTTP Proxy
    func applyHttpProxy(host: String, port: String) {
        isBusy = true
        busyMessage = tr("Включаю HTTP/HTTPS-прокси \(host):\(port)...", "Enabling HTTP/HTTPS proxy \(host):\(port)...", "HTTP/HTTPS проксини күйгүзүп жатам \(host):\(port)...")
        appendLog(tr("Активация HTTP-прокси: \(host):\(port)", "Enabling HTTP proxy: \(host):\(port)", "HTTP проксини активдештирүү: \(host):\(port)"))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--apply-http-proxy", host, port])
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.httpEnabled = true
                    self.vpnActive = true
                    self.showBanner(tr("HTTP/HTTPS-прокси включён", "HTTP/HTTPS proxy enabled", "HTTP/HTTPS прокси күйгүзүлдү"))
                    self.appendLog(tr("✔ HTTP-прокси активен", "✔ HTTP proxy is active", "✔ HTTP прокси активдүү"))
                    self.fetchIPInfo()
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось включить HTTP-прокси", "Could not enable the HTTP proxy", "HTTP проксини күйгүзүү мүмкүн болгон жок"))
                }
                self.refreshVPNStatus()
            }
        }
    }
    
    // MARK: - Disable All Proxies
    func disconnectVPN() {
        disableAllProxies()
    }
    
    func disableAllProxies() {
        isBusy = true
        busyMessage = tr("Отключаю все прокси и туннели...", "Disabling all proxies and tunnels...", "Бардык прокси жана туннелдерди ажыратып жатам...")
        appendLog(tr("Отключение прокси...", "Disabling proxies...", "Проксини ажыратуу..."))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--apply-proxy-off"])
            // Общий выключатель гасит и встроенное ядро: иначе оно остаётся висеть под
            // launchd и занимает слот устройства в подписке, хотя трафик через него не идёт.
            if success && self.vpnCore.isUp { _ = self.runEngineChecked(["--vpn-core-stop"], timeout: 15) }
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.refreshVPNCore()
                    self.vpnActive = false
                    self.socksEnabled = false
                    self.httpEnabled = false
                    self.showBanner(tr("Прокси отключены — прямое соединение", "Proxies disabled — direct connection", "Прокси ажыратылды — түз туташуу"))
                    self.appendLog(tr("✔ Туннели и прокси отключены", "✔ Tunnels and proxies disabled", "✔ Туннелдер жана прокси ажыратылды"))
                    self.fetchIPInfo()
                    SoundSystem.shared.playToggle()
                } else {
                    self.showBanner(tr("Не удалось отключить прокси", "Could not disable the proxies", "Проксини ажыратуу мүмкүн болгон жок"))
                }
                self.refreshVPNStatus()
            }
        }
    }
    
    // MARK: - Apply Profile
    /// `completion` нужен мастеру первого запуска: он ждёт результата,
    /// чтобы перейти к проверке, а не гадать по таймеру.
    func applyProfile(_ profile: DNSProfile, customServers: String? = nil, completion: ((Bool) -> Void)? = nil) {
        isBusy = true
        busyMessage = tr("Применяю профиль «\(profile.title)»...", "Applying the “\(profile.title)” profile...", "«\(profile.title)» профилин колдонуп жатам...")
        appendLog(tr("Активация профиля: \(profile.title) (\(profile.id))", "Applying profile: \(profile.title) (\(profile.id))", "Профилди активдештирүү: \(profile.title) (\(profile.id))"))
        
        let candidateCustom = customServers ?? (profile.id == "custom" ? (self.customDNSServers.isEmpty ? "77.88.8.8 77.88.8.1" : self.customDNSServers) : nil)
        var cleanCustom: String? = nil
        if let custom = candidateCustom {
            let normalized = custom
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: ";", with: " ")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !normalized.isEmpty {
                cleanCustom = normalized
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var args = ["--apply-profile", profile.id]
            if let custom = cleanCustom {
                args.append(custom)
            }
            
            let success = self.runRootCommand(args: args)
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.currentProfileId = profile.id
                    self.isProtected = true
                    if profile.id == "custom", let custom = cleanCustom {
                        self.customDNSServers = custom
                        UserDefaults.standard.set(custom, forKey: "custom_dns_servers")
                    }
                    if profile.id != "off" { self.lastActiveProfileId = profile.id }
                    self.showBanner(tr("Профиль «\(profile.title)» включён", "Profile “\(profile.title)” enabled", "«\(profile.title)» профили күйгүзүлдү"))
                    self.appendLog(tr("✔ Профиль «\(profile.title)» активен", "✔ Profile “\(profile.title)” is active", "✔ «\(profile.title)» профили активдүү"))
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось применить профиль", "Could not apply the profile", "Профилди колдонуу мүмкүн болгон жок"))
                    self.appendLog(tr("✘ Не удалось применить профиль \(profile.title)", "✘ Could not apply profile \(profile.title)", "✘ \(profile.title) профилин колдонуу мүмкүн болгон жок"), isError: true)
                }
                self.refreshStatus()
                completion?(success)
            }
        }
    }
    
    // MARK: - Toggle Protection
    func toggleProtection() {
        if isProtected {
            turnOff()
        } else {
            enableProtection(profileId: lastActiveProfileId)
        }
    }

    /// Включает защиту конкретным профилем. Раньше выбор шёл по индексам
    /// `allProfiles[0]` / `[1]`, то есть ломался от любой перестановки списка.
    func enableProtection(profileId: String) {
        let profile = DNSProfile.allProfiles.first(where: { $0.id == profileId })
            ?? DNSProfile.allProfiles.first(where: { $0.id == "adguard" })
            ?? DNSProfile.allProfiles[0]
        if profile.id == "custom" {
            applyProfile(profile, customServers: customDNSServers)
        } else {
            applyProfile(profile)
        }
    }

    /// Последний осознанно выбранный профиль — то, к чему надо вернуться
    /// после выключения защиты или окончания паузы.
    private(set) var lastActiveProfileId: String {
        get { UserDefaults.standard.string(forKey: "last_active_profile") ?? "adguard" }
        set { UserDefaults.standard.set(newValue, forKey: "last_active_profile") }
    }
    
    // MARK: - Turn Off
    func turnOff() {
        isBusy = true
        busyMessage = tr("Отключаю фильтрацию DNS...", "Disabling DNS filtering...", "DNS чыпкалоосун өчүрүп жатам...")
        appendLog(tr("Отключение защиты...", "Disabling protection...", "Коргоону өчүрүү..."))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--apply-off"])
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.isProtected = false
                    self.showBanner(tr("Защита отключена, системный DNS восстановлен", "Protection disabled, system DNS restored", "Коргоо өчүрүлдү, системалык DNS калыбына келтирилди"))
                    self.appendLog(tr("✔ Фильтрация DNS отключена", "✔ DNS filtering disabled", "✔ DNS чыпкалоосу өчүрүлдү"))
                    SoundSystem.shared.playToggle()
                } else {
                    self.showBanner(tr("Не удалось отключить защиту", "Could not disable protection", "Коргоону өчүрүү мүмкүн болгон жок"))
                    self.appendLog(tr("✘ Ошибка при возврате настроек DNS", "✘ Could not restore the DNS settings", "✘ DNS жөндөөлөрүн кайтарууда ката кетти"), isError: true)
                }
                self.refreshStatus()
            }
        }
    }
    
    // MARK: - Flush Cache
    func flushDNS() {
        isBusy = true
        busyMessage = tr("Сбрасываю кэш DNS macOS...", "Flushing the macOS DNS cache...", "macOS DNS кэшин тазалап жатам...")
        appendLog(tr("Очистка системного кэша DNS...", "Flushing the system DNS cache...", "Системалык DNS кэшин тазалоо..."))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runRootCommand(args: ["--flush-dns"])
            
            DispatchQueue.main.async {
                self.isBusy = false
                self.showBanner(tr("DNS-кэш очищен", "DNS cache flushed", "DNS кэши тазаланды"))
                self.appendLog(tr("✔ Кэш DNS сброшен (dscacheutil + mDNSResponder)", "✔ DNS cache flushed (dscacheutil + mDNSResponder)", "✔ DNS кэши тазаланды (dscacheutil + mDNSResponder)"))
                SoundSystem.shared.playAction()
                self.refreshStatus()
            }
        }
    }
    
    // MARK: - Браузерный DoH

    @Published var browserDoH: [BrowserDoHInfo] = []
    /// Блокировка стороннего DoH включена.
    @Published var dohBlockingEnabled: Bool = false

    /// Браузеры, которые ходят мимо фильтра.
    var doHBypassingBrowsers: [BrowserDoHInfo] {
        browserDoH.filter { $0.bypasses }
    }

    /// Включает или выключает блокировку стороннего DNS-over-HTTPS.
    ///
    /// Правила живут в конфигурации локального резолвера, поэтому действуют
    /// только в локальном режиме. Ключевое из них — домен-канарейка: Firefox
    /// проверяет его перед включением своего DoH и отключает DoH сам, если тот
    /// не резолвится.
    func setDoHBlocking(_ enabled: Bool) {
        guard !isBusy else { return }
        isBusy = true
        busyMessage = enabled
            ? tr("Включаю блокировку стороннего DoH...", "Blocking third-party DoH...", "Бөтөн DoH'ту бөгөттөөнү күйгүзүп жатам...")
            : tr("Выключаю блокировку стороннего DoH...", "Unblocking third-party DoH...", "Бөтөн DoH'ту бөгөттөөнү өчүрүп жатам...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: [enabled ? "--doh-block-on" : "--doh-block-off"])

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.dohBlockingEnabled = enabled
                    if enabled && self.mode != "full" {
                        // Честно: отметка сохранена, но пока правил негде применить.
                        self.showBanner(tr("Отметка сохранена — правила заработают в локальном режиме",
                                           "Saved — the rules take effect in local mode", "Белги сакталды — эрежелер жергиликтүү режимде иштей баштайт"))
                    } else {
                        self.showBanner(enabled
                            ? tr("Сторонний DoH заблокирован", "Third-party DoH blocked", "Бөтөн DoH бөгөттөлдү")
                            : tr("Блокировка стороннего DoH выключена", "Third-party DoH blocking is off", "Бөтөн DoH'ту бөгөттөө өчүрүлдү"))
                    }
                } else {
                    self.showBanner(tr("Не удалось изменить настройку", "Could not change the setting", "Жөндөөнү өзгөртүү мүмкүн болгон жок"))
                }
                self.refreshStatus()
                self.checkBrowserDoH()
            }
        }
    }

    func checkBrowserDoH() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--doh-status-json"], timeout: 20)
            guard let data = out.data(using: .utf8),
                  let list = try? JSONDecoder().decode([BrowserDoHInfo].self, from: data) else { return }
            DispatchQueue.main.async {
                self.browserDoH = list
                let bad = list.filter { $0.bypasses }.map { $0.browser }
                if !bad.isEmpty {
                    self.appendLog(tr("⚠️ Мимо фильтра ходит собственный DoH: \(bad.joined(separator: ", "))",
                                      "⚠️ Bypassing the filter via their own DoH: \(bad.joined(separator: ", "))", "⚠️ Чыпканы айланып өзүнчө DoH иштейт: \(bad.joined(separator: ", "))"),
                                   isError: true)
                }
            }
        }
    }

    // MARK: - Tailscale

    func checkTailscale() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--tailscale-status-json"], timeout: 20)
            guard let data = out.data(using: .utf8),
                  let info = try? JSONDecoder().decode(TailscaleInfo.self, from: data) else { return }
            DispatchQueue.main.async { self.tailscale = info }
        }
    }

    /// Разводит Tailscale и фильтр по зонам.
    ///
    /// Движок применяет настройку, а затем проверяет, что имена tailnet всё ещё
    /// резолвятся, и откатывается сам, если нет: остаться без доступа к своим
    /// машинам — цена выше, чем непоказанная реклама.
    func enableTailscaleSplit() {
        guard !isBusy else { return }
        isBusy = true
        busyMessage = tr("Развожу зоны Tailscale и фильтра...", "Splitting Tailscale and filter zones...", "Tailscale менен чыпканын зоналарын бөлүп жатам...")
        appendLog(tr("Настройка совместной работы с Tailscale...", "Configuring coexistence with Tailscale...", "Tailscale менен бирге иштөөнү жөндөө..."))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--tailscale-split-on"])

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    let suffix = self.tailscale?.suffix ?? "ts.net"
                    self.showBanner(tr("Готово: имена \(suffix) идут в Tailscale, остальное фильтруется",
                                       "Done: \(suffix) names go to Tailscale, everything else is filtered", "Даяр: \(suffix) аттары Tailscale'ге кетет, калганы чыпкаланат"))
                    self.appendLog(tr("✔ Зоны разведены: \(suffix) → Tailscale, прочее → фильтр",
                                      "✔ Zones split: \(suffix) → Tailscale, the rest → filter", "✔ Зоналар бөлүндү: \(suffix) → Tailscale, калганы → чыпка"))
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось развести зоны — настройки возвращены как были",
                                       "Could not split the zones — settings were restored", "Зоналарды бөлүү мүмкүн болгон жок — жөндөөлөр мурунку абалына кайтарылды"))
                    self.appendLog(tr("✘ Разделение зон не применено, движок откатил изменения",
                                      "✘ Zone split not applied, the engine rolled back", "✘ Зоналарды бөлүү колдонулган жок, кыймылдаткыч өзгөртүүлөрдү артка кайтарды"), isError: true)
                }
                self.checkTailscale()
                self.refreshStatus()
            }
        }
    }

    func disableTailscaleSplit() {
        guard !isBusy else { return }
        isBusy = true
        busyMessage = tr("Возвращаю управление DNS в Tailscale...", "Handing DNS back to Tailscale...", "DNS башкарууну Tailscale'ге кайтарып жатам...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--tailscale-split-off"])

            DispatchQueue.main.async {
                self.isBusy = false
                self.showBanner(success
                    ? tr("Tailscale снова управляет DNS", "Tailscale manages DNS again", "Tailscale кайрадан DNS'ти башкарат")
                    : tr("Не удалось вернуть настройки", "Could not restore the settings", "Жөндөөлөрдү кайтаруу мүмкүн болгон жок"))
                self.checkTailscale()
                self.refreshStatus()
            }
        }
    }

    // MARK: - Restart Local Resolver
    /// Настоящий перезапуск dnsmasq. Кнопка «Перезапустить службу»
    /// раньше вызывала `refreshStatus()` и ничего не перезапускала.
    func restartLocalService() {
        guard !isBusy else { return }
        isBusy = true
        busyMessage = tr("Перезапускаю локальный резолвер...", "Restarting the local resolver...", "Жергиликтүү резолверди кайра иштетип жатам...")
        appendLog(tr("Перезапуск службы dnsmasq...", "Restarting the dnsmasq service...", "dnsmasq кызматын кайра иштетүү..."))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--restart-service"])

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.showBanner(tr("Локальный резолвер перезапущен", "Local resolver restarted", "Жергиликтүү резолвер кайра иштетилди"))
                    self.appendLog(tr("✔ dnsmasq перезапущен, кэш сброшен", "✔ dnsmasq restarted, cache flushed", "✔ dnsmasq кайра иштетилди, кэш тазаланды"))
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Перезапуск не выполнен — локальный режим не активен", "Restart skipped — local mode is not active", "Кайра иштетүү аткарылган жок — жергиликтүү режим активдүү эмес"))
                    self.appendLog(tr("✘ Перезапуск dnsmasq не выполнен: локальный режим выключен или dnsmasq не установлен", "✘ dnsmasq not restarted: local mode is off or dnsmasq is not installed", "✘ dnsmasq кайра иштетилген жок: жергиликтүү режим өчүк же dnsmasq орнотулган эмес"), isError: true)
                }
                self.refreshStatus()
            }
        }
    }

    // MARK: - Run Live Diagnostics
    func runDiagnostics() {
        guard !isDiagnosing else { return }
        isDiagnosing = true
        checkBrowserDoH()
        appendLog(tr("Запуск проверки блокировки 12 тестовых доменов...", "Checking 12 test domains for blocking...", "12 тест доменинде бөгөттөөнү текшерүү башталды..."))
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let output = self.runCommand(args: ["--test-domains-json"])
            
            guard let data = output.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.isDiagnosing = false
                    self.appendLog(tr("Не удалось получить результат проверки", "Could not read the check result", "Текшерүүнүн жыйынтыгын алуу мүмкүн болгон жок"), isError: true)
                }
                return
            }
            
            do {
                let items = try JSONDecoder().decode([DiagnosticItem].self, from: data)
                DispatchQueue.main.async {
                    self.diagnosticResults = items
                    self.isDiagnosing = false
                    let checked = items.filter { !$0.isControl && !$0.didFail }
                    let failedCount = items.filter { $0.didFail }.count
                    let blockedCount = checked.filter { $0.blocked }.count
                    let percent = checked.isEmpty ? 0 : Int(round(Double(blockedCount) / Double(checked.count) * 100))
                    var summary = tr("✔ Проверка завершена: заблокировано \(blockedCount) из \(checked.count) (\(percent)%)", "✔ Check finished: \(blockedCount) of \(checked.count) blocked (\(percent)%)", "✔ Текшерүү бүттү: \(checked.count) ичинен \(blockedCount) бөгөттөлдү (\(percent)%)")
                    if failedCount > 0 { summary += tr(", не проверено: \(failedCount)", ", not checked: \(failedCount)", ", текшерилген жок: \(failedCount)") }
                    self.appendLog(summary)
                    self.showBanner(tr("Диагностика: заблокировано \(percent)% рекламных доменов",
                                            "Diagnostics: \(percent)% of ad domains blocked", "Диагностика: жарнамалык домендердин \(percent)% бөгөттөлдү"))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDiagnosing = false
                    self.appendLog(tr("Ошибка декодирования: \(error.localizedDescription)", "Decoding error: \(error.localizedDescription)", "Декоддоо катасы: \(error.localizedDescription)"), isError: true)
                }
            }
        }
    }
    
    // MARK: - Run Speed Test
    func runSpeedTest() {
        guard !isSpeedTesting else { return }
        isSpeedTesting = true
        appendLog(tr("Запуск замера скорости DNS-серверов...", "Benchmarking DNS resolvers...", "DNS серверлеринин ылдамдыгын өлчөө башталды..."))
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let output = self.runCommand(args: ["--test-speed-json"])
            
            guard let data = output.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.isSpeedTesting = false
                    self.appendLog(tr("Не удалось получить замер скорости", "Could not read the benchmark result", "Ылдамдыкты өлчөөнүн жыйынтыгын алуу мүмкүн болгон жок"), isError: true)
                }
                return
            }
            
            do {
                let items = try JSONDecoder().decode([SpeedTestItem].self, from: data)
                DispatchQueue.main.async {
                    self.speedTestResults = items.sorted {
                        if $0.latencyMs < 0 { return false }
                        if $1.latencyMs < 0 { return true }
                        return $0.latencyMs < $1.latencyMs
                    }
                    self.isSpeedTesting = false
                    if let fastest = self.speedTestResults.first(where: { $0.latencyMs >= 0 }) {
                        self.appendLog(tr("✔ Самый быстрый DNS: \(fastest.name) (\(fastest.latencyMs) мс)", "✔ Fastest resolver: \(fastest.name) (\(fastest.latencyMs) ms)", "✔ Эң ылдам DNS: \(fastest.name) (\(fastest.latencyMs) мс)"))
                        self.showBanner(tr("Быстрее всех: \(fastest.name) — \(fastest.latencyMs) мс", "Fastest: \(fastest.name) — \(fastest.latencyMs) ms", "Эң ылдамы: \(fastest.name) — \(fastest.latencyMs) мс"))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSpeedTesting = false
                    self.appendLog(tr("Ошибка разбора теста скорости: \(error.localizedDescription)", "Benchmark parse error: \(error.localizedDescription)", "Ылдамдык тестин талдоо катасы: \(error.localizedDescription)"), isError: true)
                }
            }
        }
    }
    
    // MARK: - Run Full Network Speedtest Pro
    func runFullSpeedtest() {
        guard !isFullSpeedtesting else { return }
        isFullSpeedtesting = true
        speedtestStage = .ping
        liveSpeedGauge = 0.0
        appendLog(tr("🚀 Speedtest Pro: замер пропускной способности сети...", "🚀 Speedtest Pro: measuring network bandwidth...", "🚀 Speedtest Pro: тармактын өткөрүү жөндөмдүүлүгүн өлчөө..."))
        
        // Simulated live progress animation ticker
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self = self, self.isFullSpeedtesting else {
                timer.invalidate()
                return
            }
            if self.speedtestStage == .ping {
                self.liveSpeedGauge = Double.random(in: 10...30)
            } else if self.speedtestStage == .download {
                self.liveSpeedGauge = min(150.0, self.liveSpeedGauge + Double.random(in: 8...22))
            } else {
                self.liveSpeedGauge = max(15.0, self.liveSpeedGauge * 0.95 + Double.random(in: 2...8))
            }
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.speedtestStage = .download
            }
            
            let output = self.runCommand(args: ["--run-full-speedtest"])
            
            guard let data = output.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.isFullSpeedtesting = false
                    self.speedtestStage = .failedConnection
                    self.appendLog(tr("Не удалось получить данные Speedtest", "Could not read the speedtest data", "Speedtest маалыматтарын алуу мүмкүн болгон жок"), isError: true)
                }
                return
            }
            
            do {
                let res = try JSONDecoder().decode(NetworkSpeedtestResult.self, from: data)
                guard !res.didFail else {
                    // Раньше движок при сбое подставлял правдоподобные числа,
                    // и приложение показывало их как измерение.
                    DispatchQueue.main.async {
                        self.isFullSpeedtesting = false
                        self.speedtestStage = .failedConnection
                        self.fullSpeedtestResult = nil
                        let why = res.reason ?? tr("причина неизвестна", "reason unknown", "себеби белгисиз")
                        self.showBanner(tr("Замер не выполнен: \(why)", "Speedtest failed: \(why)", "Өлчөө аткарылган жок: \(why)"))
                        self.appendLog(tr("✘ Замер скорости не выполнен: \(why)",
                                          "✘ Speedtest did not complete: \(why)", "✘ Ылдамдыкты өлчөө аткарылган жок: \(why)"), isError: true)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.fullSpeedtestResult = res
                    self.isFullSpeedtesting = false
                    self.speedtestStage = .done
                    self.liveSpeedGauge = res.downloadMbps
                    let up = res.hasUpload ? "\(res.uploadMbps)" : tr("не измерено", "not measured", "өлчөнгөн жок")
                    self.appendLog(tr("✔ Замер завершён: 📥 \(res.downloadMbps) Мбит/с, 📤 \(up), ⚡️ \(res.pingMs) мс (джиттер \(res.jitterMs) мс, потери \(res.packetLossPct)%)",
                                      "✔ Speedtest finished: 📥 \(res.downloadMbps) Mbps, 📤 \(up), ⚡️ \(res.pingMs) ms (jitter \(res.jitterMs) ms, loss \(res.packetLossPct)%)", "✔ Өлчөө бүттү: 📥 \(res.downloadMbps) Мбит/с, 📤 \(up), ⚡️ \(res.pingMs) мс (джиттер \(res.jitterMs) мс, жоготуулар \(res.packetLossPct)%)"))
                    self.showBanner(tr("Speedtest: 📥 \(res.downloadMbps) Мбит/с | ⚡️ \(res.pingMs) мс", "Speedtest: 📥 \(res.downloadMbps) Mbps | ⚡️ \(res.pingMs) ms", "Speedtest: 📥 \(res.downloadMbps) Мбит/с | ⚡️ \(res.pingMs) мс"))
                    SoundSystem.shared.playCelebration()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isFullSpeedtesting = false
                    self.speedtestStage = .failedDecode
                    self.appendLog(tr("Ошибка декодирования Speedtest: \(error.localizedDescription)", "Speedtest decoding error: \(error.localizedDescription)", "Speedtest декоддоо катасы: \(error.localizedDescription)"), isError: true)
                }
            }
        }
    }
    func updateBlocklists() {
        isBusy = true
        busyMessage = tr("Скачиваю и обновляю базы блокировки OISD / StevenBlack...", "Downloading and updating the OISD / StevenBlack blocklists...", "OISD / StevenBlack бөгөттөө базаларын жүктөп алып, жаңыртып жатам...")
        appendLog(tr("Обновление баз блокировки...", "Updating the blocklists...", "Бөгөттөө базаларын жаңыртуу..."))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--update"])
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.showBanner(tr("Базы блокировки обновлены", "Blocklists updated", "Бөгөттөө базалары жаңыртылды"))
                    self.appendLog(tr("✔ Базы доменов обновлены", "✔ Domain databases updated", "✔ Домен базалары жаңыртылды"))
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось обновить базы", "Could not update the blocklists", "Базаларды жаңыртуу мүмкүн болгон жок"))
                    self.appendLog(tr("✘ Ошибка обновления базы", "✘ Blocklist update failed", "✘ Базаны жаңыртуу катасы"), isError: true)
                }
                self.refreshStatus()
            }
        }
    }
    
    // MARK: - Whitelist & Blacklist
    func loadCustomLists() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let wout = self.runCommand(args: ["--get-whitelist"])
            let bout = self.runCommand(args: ["--get-blacklist"])
            
            let wlines = wout.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let blines = bout.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            
            DispatchQueue.main.async {
                self.whitelistDomains = wlines
                self.blacklistDomains = blines
            }
        }
    }
    
    func addWhitelistDomain(_ domain: String) {
        guard let clean = DomainValidator.sanitized(domain) else {
            showBanner(tr("«\(domain)» не похоже на доменное имя", "“\(domain)” is not a valid domain name", "«\(domain)» домендик атка окшобойт"))
            appendLog(tr("Отклонено правило: «\(domain)»", "Rule rejected: “\(domain)”", "Эреже четке кагылды: «\(domain)»"), isError: true)
            return
        }
        guard !whitelistDomains.contains(clean) else {
            showBanner(tr("\(clean) уже в списке", "\(clean) is already in the list", "\(clean) тизмеде мурунтан эле бар"))
            return
        }
        isBusy = true
        busyMessage = tr("Добавляю \(clean) в белый список...", "Adding \(clean) to the whitelist...", "\(clean) доменин ак тизмеге кошуп жатам...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runRootCommand(args: ["--add-whitelist", clean])
            DispatchQueue.main.async {
                self.isBusy = false
                self.loadCustomLists()
                self.showBanner(tr("\(clean) добавлен в белый список", "\(clean) added to the whitelist", "\(clean) ак тизмеге кошулду"))
                self.appendLog(tr("Добавлен в белый список: \(clean)", "Added to the whitelist: \(clean)", "Ак тизмеге кошулду: \(clean)"))
                SoundSystem.shared.playAction()
            }
        }
    }
    
    func removeWhitelistDomain(_ domain: String) {
        isBusy = true
        busyMessage = tr("Удаляю \(domain) из белого списка...", "Removing \(domain) from the whitelist...", "\(domain) доменин ак тизмеден алып салып жатам...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runRootCommand(args: ["--remove-whitelist", domain])
            DispatchQueue.main.async {
                self.isBusy = false
                self.loadCustomLists()
                self.showBanner(tr("\(domain) удалён из белого списка", "\(domain) removed from the whitelist", "\(domain) ак тизмеден алып салынды"))
                self.appendLog(tr("Удалён из белого списка: \(domain)", "Removed from the whitelist: \(domain)", "Ак тизмеден алып салынды: \(domain)"))
            }
        }
    }
    
    func addBlacklistDomain(_ domain: String) {
        guard let clean = DomainValidator.sanitized(domain) else {
            showBanner(tr("«\(domain)» не похоже на доменное имя", "“\(domain)” is not a valid domain name", "«\(domain)» домендик атка окшобойт"))
            appendLog(tr("Отклонено правило: «\(domain)»", "Rule rejected: “\(domain)”", "Эреже четке кагылды: «\(domain)»"), isError: true)
            return
        }
        guard !blacklistDomains.contains(clean) else {
            showBanner(tr("\(clean) уже в списке", "\(clean) is already in the list", "\(clean) тизмеде мурунтан эле бар"))
            return
        }
        isBusy = true
        busyMessage = tr("Добавляю \(clean) в чёрный список...", "Adding \(clean) to the blacklist...", "\(clean) доменин кара тизмеге кошуп жатам...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runRootCommand(args: ["--add-blacklist", clean])
            DispatchQueue.main.async {
                self.isBusy = false
                self.loadCustomLists()
                self.showBanner(tr("\(clean) добавлен в чёрный список", "\(clean) added to the blacklist", "\(clean) кара тизмеге кошулду"))
                self.appendLog(tr("Добавлен в чёрный список: \(clean)", "Added to the blacklist: \(clean)", "Кара тизмеге кошулду: \(clean)"))
                SoundSystem.shared.playAction()
            }
        }
    }
    
    func removeBlacklistDomain(_ domain: String) {
        isBusy = true
        busyMessage = tr("Удаляю \(domain) из чёрного списка...", "Removing \(domain) from the blacklist...", "\(domain) доменин кара тизмеден алып салып жатам...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runRootCommand(args: ["--remove-blacklist", domain])
            DispatchQueue.main.async {
                self.isBusy = false
                self.loadCustomLists()
                self.showBanner(tr("\(domain) удалён из чёрного списка", "\(domain) removed from the blacklist", "\(domain) кара тизмеден алып салынды"))
                self.appendLog(tr("Удалён из чёрного списка: \(domain)", "Removed from the blacklist: \(domain)", "Кара тизмеден алып салынды: \(domain)"))
            }
        }
    }
    
    // MARK: - Full Uninstall
    func uninstallAll() {
        isBusy = true
        busyMessage = tr("Удаляю все компоненты и сбрасываю настройки...", "Removing all components and resetting settings...", "Бардык компоненттерди жок кылып, жөндөөлөрдү баштапкы абалга келтирип жатам...")
        appendLog(tr("Запуск полного удаления...", "Starting full removal...", "Толук жок кылуу башталды..."))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = self.runRootCommand(args: ["--apply-remove"])
            
            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.showBanner(tr("Cerberus DNS удалён, настройки сети восстановлены", "Cerberus DNS removed, network settings restored", "Cerberus DNS жок кылынды, тармак жөндөөлөрү калыбына келтирилди"))
                    self.appendLog(tr("✔ Все компоненты удалены, настройки сети восстановлены", "✔ All components removed, network settings restored", "✔ Бардык компоненттер жок кылынды, тармак жөндөөлөрү калыбына келтирилди"))
                } else {
                    self.showBanner(tr("Не удалось выполнить удаление", "Removal failed", "Жок кылуу мүмкүн болгон жок"))
                }
                // Движок удаляет и помощник; без перепроверки интерфейс считал
                // бы его установленным.
                self.checkHelperStatus()
                self.refreshStatus()
            }
        }
    }
    
    // MARK: - Command Palette Actions Provider
    func getCommandPaletteItems() -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        
        // Protection Toggle
        items.append(CommandPaletteItem(
            id: "cmd_toggle_protection",
            title: isProtected ? tr("Выключить защиту", "Disable protection", "Коргоону өчүрүү") : tr("Включить защиту DNS", "Enable DNS protection", "DNS коргоосун күйгүзүү"),
            subtitle: isProtected ? tr("Вернуть стандартные DNS провайдера", "Restore your ISP’s default DNS", "Провайдердин стандарттуу DNS'ин кайтаруу") : tr("Включить блокировку рекламы и трекеров", "Turn on ad and tracker blocking", "Жарнама жана трекерлерди бөгөттөөнү күйгүзүү"),
            category: tr("Защита", "Protection", "Коргоо"),
            icon: isProtected ? "shield.slash.fill" : "shield.fill",
            iconColor: isProtected ? Theme.statusRed : Theme.accentGreen,
            shortcut: "⌘ S",
            action: { [weak self] in self?.toggleProtection() }
        ))
        
        // Flush Cache
        items.append(CommandPaletteItem(
            id: "cmd_flush_dns",
            title: tr("Очистить DNS-кэш macOS", "Flush the macOS DNS cache", "macOS DNS кэшин тазалоо"),
            subtitle: tr("Сбросить кэш резолвера dscacheutil и mDNSResponder", "Reset the dscacheutil and mDNSResponder caches", "dscacheutil жана mDNSResponder резолвер кэшин тазалоо"),
            category: tr("Инструменты", "Tools", "Куралдар"),
            icon: "trash.circle.fill",
            iconColor: Theme.statusOrange,
            shortcut: "⌘ F",
            action: { [weak self] in self?.flushDNS() }
        ))
        
        // Refresh Status
        items.append(CommandPaletteItem(
            id: "cmd_refresh_status",
            title: tr("Обновить статус и пинг", "Refresh status and latency", "Абалды жана пингди жаңыртуу"),
            subtitle: tr("Проверить активный DNS и задержку соединения", "Check the active resolver and its latency", "Активдүү DNS'ти жана туташуунун кечигүүсүн текшерүү"),
            category: tr("Обзор", "Overview", "Сереп"),
            icon: "arrow.clockwise",
            iconColor: Theme.statusBlue,
            shortcut: "⌘ R",
            action: { [weak self] in self?.refreshStatus() }
        ))
        
        // Узлы VPN / прокси — включая пользовательские
        for node in allNodes {
            items.append(CommandPaletteItem(
                id: "cmd_node_\(node.id)",
                title: tr("Подключить: \(node.name)", "Connect: \(node.name)", "Туташтыруу: \(node.name)"),
                subtitle: node.kindBadge + " • " + (node.latencyMs >= 0 ? tr("\(node.latencyMs) мс", "\(node.latencyMs) ms", "\(node.latencyMs) мс") : tr("Проверка...", "Testing...", "Текшерүү...")),
                category: tr("VPN и прокси", "VPN & proxy", "VPN жана прокси"),
                icon: "bolt.shield.fill",
                iconColor: node.protocolType == "vless" ? Theme.accent : Color(red: 0.65, green: 0.40, blue: 0.85),
                countryCode: node.country.isEmpty ? node.id : node.country,
                shortcut: nil,
                action: { [weak self] in self?.connectToVPNNode(node) }
            ))
        }
        
        // Недельная сводка. Нужна и как обычная команда, и чтобы её вообще
        // можно было увидеть, не прождав неделю.
        items.append(CommandPaletteItem(
            id: "cmd_weekly_digest",
            title: tr("Показать сводку за неделю", "Show the weekly summary", "Жумалык корутундуну көрсөтүү"),
            subtitle: tr("Сколько запросов перехвачено и кто лидировал", "How many queries were blocked and who led", "Канча сурам кармалды жана кайсылары алдыда болду"),
            category: tr("Обзор", "Overview", "Сереп"),
            icon: "calendar.badge.clock",
            iconColor: Theme.statusBlue,
            shortcut: nil,
            action: { [weak self] in self?.sendWeeklyDigest(force: true) }
        ))

        // Diagnostics
        items.append(CommandPaletteItem(
            id: "cmd_run_diagnostics",
            title: tr("Запустить диагностику блокировки рекламы", "Run the ad-blocking diagnostic", "Жарнама бөгөттөө диагностикасын баштоо"),
            subtitle: tr("Проверить резолв 12 реальных трекеров и рекламных доменов", "Resolve 12 real ad and tracker domains", "12 чыныгы трекер жана жарнамалык домендин резолвун текшерүү"),
            category: tr("Диагностика", "Diagnostics", "Диагностика"),
            icon: "waveform.path.ecg",
            iconColor: Theme.statusOrange,
            shortcut: nil,
            action: { [weak self] in self?.runDiagnostics() }
        ))
        
        // Speed test
        items.append(CommandPaletteItem(
            id: "cmd_run_speed_test",
            title: tr("Запустить бенчмарк скорости DNS", "Benchmark DNS resolvers", "DNS ылдамдык бенчмаркын баштоо"),
            subtitle: tr("Замерить задержку до серверов Cloudflare, AdGuard, Quad9, Google", "Measure latency to Cloudflare, AdGuard, Quad9 and Google", "Cloudflare, AdGuard, Quad9, Google серверлерине чейинки кечигүүнү өлчөө"),
            category: tr("Диагностика", "Diagnostics", "Диагностика"),
            icon: "bolt.fill",
            iconColor: Theme.accentGreen,
            shortcut: nil,
            action: { [weak self] in self?.runSpeedTest() }
        ))
        
        // Profiles
        for p in DNSProfile.allProfiles {
            items.append(CommandPaletteItem(
                id: "cmd_profile_\(p.id)",
                title: tr("Переключить профиль: \(p.title)", "Switch profile: \(p.title)", "Профилди которуу: \(p.title)"),
                subtitle: p.subtitle,
                category: tr("Профили DNS", "DNS profiles", "DNS профилдери"),
                icon: p.icon,
                iconColor: p.color,
                shortcut: nil,
                action: { [weak self] in self?.applyProfile(p) }
            ))
        }
        
        return items
    }
    
    // MARK: - Privileged Helper Management

    /// Root-владельческая копия движка, которую запускает помощник.
    static let helperEnginePath = "/usr/local/libexec/adblock-dns-engine.sh"
    static let helperSudoersPath = "/etc/sudoers.d/dnsblocker_helper"

    func checkHelperStatus() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let probe = self.runProcess(launchPath: "/usr/bin/sudo",
                                        arguments: ["-n", Self.helperPath, "--version"],
                                        timeout: 15)
            let installed = probe.succeeded

            // Устаревание определяется по контрольной сумме файла, а не по
            // строке VERSION. Версию правят руками, то есть не правят: root-копия
            // молча оставалась старой после каждого изменения движка, и новые
            // команды через помощника просто не работали.
            func sha256Like(_ value: String) -> Bool {
                value.count == 64 && value.allSatisfy { $0.isHexDigit }
            }
            let helperHash = self.runProcess(launchPath: "/usr/bin/sudo",
                                             arguments: ["-n", Self.helperPath, "--self-hash"],
                                             timeout: 15)
                .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let bundleHash = self.runCommand(args: ["--self-hash"], timeout: 15)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Помощник старой сборки на `--self-hash` отвечает текстом ошибки —
            // это тоже признак устаревания, поэтому проверяем форму ответа.
            let versionMismatch = installed
                && sha256Like(bundleHash)
                && !(sha256Like(helperHash) && helperHash == bundleHash)

            // Помощник старого образца запускал движок прямо из бандла
            // приложения — из каталога, доступного пользователю на запись,
            // с NOPASSWD-правами. Признак: нет root-копии в /usr/local/libexec.
            let legacyLayout = installed
                && !FileManager.default.fileExists(atPath: Self.helperEnginePath)

            DispatchQueue.main.async {
                self.isHelperInstalled = installed
                self.isHelperLegacy = legacyLayout
                self.isHelperStale = versionMismatch || legacyLayout
                if legacyLayout {
                    self.appendLog(tr("⚠️ Установлен помощник старого образца: он запускает движок из каталога приложения с правами root. Переустановите помощник.", "⚠️ A legacy helper is installed: it runs the engine from the app directory as root. Please reinstall it.", "⚠️ Эски үлгүдөгү жардамчы орнотулган: ал кыймылдаткычты колдонмонун каталогунан root укуктары менен иштетет. Жардамчыны кайра орнотуңуз."), isError: true)
                } else if versionMismatch {
                    self.appendLog(tr("Root-копия движка не совпадает с версией в приложении — требуется переустановка помощника",
                                      "The root engine copy does not match the one in the app — the helper needs reinstalling", "Кыймылдаткычтын root-көчүрмөсү колдонмодогу версияга дал келбейт — жардамчыны кайра орнотуу керек"), isError: true)
                }
            }
        }
    }

    func installPrivilegedHelper(completion: ((Bool) -> Void)? = nil) {
        isBusy = true
        busyMessage = tr("Устанавливаю привилегированный помощник...", "Installing the privileged helper...", "Артыкчылыктуу жардамчы орнотулууда...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Обёртка запускает root-копию движка, а не файл внутри бандла.
            // Прежняя версия исполняла скрипт из папки пользователя с
            // NOPASSWD-правами на всю группу admin: любой процесс от имени
            // пользователя мог переписать этот скрипт и получить root.
            let wrapper = """
            #!/bin/bash
            exec /bin/bash \(Self.helperEnginePath) "$@"
            """

            // sudoers ограничен текущим пользователем, а не всей группой admin.
            let user = NSUserName()
            let sudoers = "\(user) ALL=(ALL) NOPASSWD: \(Self.helperPath)\n"

            let wrapperB64 = Data(wrapper.utf8).base64EncodedString()
            let sudoersB64 = Data(sudoers.utf8).base64EncodedString()
            let engineQuoted = "'" + self.enginePath.replacingOccurrences(of: "'", with: "'\\''") + "'"

            // Содержимое передаётся в base64, чтобы не воевать с двойным
            // экранированием AppleScript → bash на кавычках и переводах строк.
            let steps = [
                "/bin/mkdir -p /usr/local/bin /usr/local/libexec /etc/sudoers.d",
                "/usr/bin/install -o root -g wheel -m 0755 \(engineQuoted) \(Self.helperEnginePath)",
                "printf %s \(wrapperB64) | /usr/bin/base64 -D -o \(Self.helperPath)",
                "/usr/sbin/chown root:wheel \(Self.helperPath)",
                "/bin/chmod 0755 \(Self.helperPath)",
                "printf %s \(sudoersB64) | /usr/bin/base64 -D -o \(Self.helperSudoersPath)",
                "/usr/sbin/chown root:wheel \(Self.helperSudoersPath)",
                "/bin/chmod 0440 \(Self.helperSudoersPath)",
                // Битый файл в sudoers.d ломает sudo целиком — проверяем и откатываем.
                "{ /usr/sbin/visudo -cf \(Self.helperSudoersPath) >/dev/null || { /bin/rm -f \(Self.helperSudoersPath); exit 1; }; }"
            ]
            let shellCommand = steps.joined(separator: " && ")
            let scriptSource = "do shell script \"\(shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

            var errorDict: NSDictionary?
            var success = false
            var failureMessage = ""
            if let scriptObject = NSAppleScript(source: scriptSource) {
                _ = scriptObject.executeAndReturnError(&errorDict)
                if errorDict == nil {
                    success = true
                } else {
                    let code = errorDict?[NSAppleScript.errorNumber] as? Int ?? 0
                    failureMessage = code == -128
                        ? tr("Установка помощника отменена", "Helper installation cancelled", "Жардамчыны орнотуу жокко чыгарылды")
                        : (errorDict?[NSAppleScript.errorMessage] as? String ?? tr("неизвестная ошибка", "unknown error", "белгисиз ката"))
                }
            }

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.isHelperInstalled = true
                    self.isHelperStale = false
                    self.showBanner(tr("Помощник установлен — пароль больше не потребуется", "Helper installed — no more password prompts", "Жардамчы орнотулду — сырсөз мындан ары суралбайт"))
                    self.appendLog(tr("✔ Привилегированный помощник установлен (root-копия движка: \(Self.helperEnginePath))", "✔ Privileged helper installed (root-owned engine copy: \(Self.helperEnginePath))", "✔ Артыкчылыктуу жардамчы орнотулду (кыймылдаткычтын root-көчүрмөсү: \(Self.helperEnginePath))"))
                    SoundSystem.shared.playSuccess()
                } else {
                    self.showBanner(tr("Не удалось установить помощник", "Could not install the helper", "Жардамчыны орнотуу мүмкүн болгон жок"))
                    self.appendLog(tr("✘ Установка помощника: \(failureMessage)", "✘ Helper installation: \(failureMessage)", "✘ Жардамчыны орнотуу: \(failureMessage)"), isError: true)
                }
                self.checkHelperStatus()
                completion?(success)
            }
        }
    }

    func removePrivilegedHelper(completion: ((Bool) -> Void)? = nil) {
        isBusy = true
        busyMessage = tr("Удаляю привилегированный помощник...", "Removing the privileged helper...", "Артыкчылыктуу жардамчы жок кылынууда...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let rm = "/bin/rm -f \(Self.helperPath) \(Self.helperEnginePath) \(Self.helperSudoersPath)"
            let scriptSource = "do shell script \"\(rm)\" with administrator privileges"
            var errorDict: NSDictionary?
            var success = false
            if let scriptObject = NSAppleScript(source: scriptSource) {
                _ = scriptObject.executeAndReturnError(&errorDict)
                success = (errorDict == nil)
            }

            DispatchQueue.main.async {
                self.isBusy = false
                if success {
                    self.isHelperInstalled = false
                    self.isHelperStale = false
                    self.showBanner(tr("Помощник удалён", "Helper removed", "Жардамчы жок кылынды"))
                    self.appendLog(tr("✔ Привилегированный помощник и root-копия движка удалены", "✔ Privileged helper and root engine copy removed", "✔ Артыкчылыктуу жардамчы жана кыймылдаткычтын root-көчүрмөсү жок кылынды"))
                } else {
                    self.showBanner(tr("Не удалось удалить помощник", "Could not remove the helper", "Жардамчыны жок кылуу мүмкүн болгон жок"))
                }
                completion?(success)
            }
        }
    }

    // MARK: - Process Execution Helpers

    /// Путь к root-помощнику, установленному через `installPrivilegedHelper()`.
    static let helperPath = "/usr/local/bin/dnsblock-engine"

    /// Результат запуска внешнего процесса.
    struct ProcessResult {
        let stdout: String
        let stderr: String
        let status: Int32
        var succeeded: Bool { status == 0 }
    }

    /// Запускает процесс, раздельно и параллельно вычитывая stdout и stderr.
    ///
    /// Две правки против прежней версии:
    /// 1. stdout и stderr больше не пишутся в одну трубу — иначе любое
    ///    предупреждение bash попадало в середину JSON и ломало разбор;
    /// 2. трубы разгребаются в фоне, а не после `waitUntilExit()` — процесс с
    ///    выводом больше буфера трубы (64 КБ) иначе вставал намертво и
    ///    подвешивал интерфейс вместе с флагом `isBusy`.
    @discardableResult
    private func runProcess(launchPath: String,
                            arguments: [String],
                            timeout: TimeInterval = 120) -> ProcessResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        task.standardInput = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return ProcessResult(stdout: "", stderr: error.localizedDescription, status: -1)
        }

        var outData = Data()
        var errData = Data()
        let lock = NSLock()
        let group = DispatchGroup()

        for (pipe, isStdout) in [(outPipe, true), (errPipe, false)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                lock.lock()
                if isStdout { outData = data } else { errData = data }
                lock.unlock()
                group.leave()
            }
        }

        var timedOut = false
        if group.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            task.terminate()
            // Если процесс не завершился по SIGTERM за 1.5 секунды, принудительно убиваем
            if task.isRunning {
                Thread.sleep(forTimeInterval: 1.5)
                if task.isRunning {
                    kill(task.processIdentifier, SIGKILL)
                }
            }
            _ = group.wait(timeout: .now() + 2)
        }
        task.waitUntilExit()

        lock.lock()
        let out = String(data: outData, encoding: .utf8) ?? ""
        var err = String(data: errData, encoding: .utf8) ?? ""
        lock.unlock()

        if timedOut {
            err = tr("Превышено время ожидания (\(Int(timeout)) с). ", "Timed out after \(Int(timeout))s. ", "Күтүү убактысы бүттү (\(Int(timeout)) с). ") + err
        }
        return ProcessResult(stdout: out, stderr: err, status: timedOut ? -2 : task.terminationStatus)
    }

    /// Непривилегированный вызов движка. Возвращает только stdout,
    /// stderr уходит в журнал приложения.
    private func runCommand(args: [String], timeout: TimeInterval = 120) -> String {
        let result = runProcess(launchPath: "/bin/bash",
                                arguments: [enginePath] + args,
                                timeout: timeout)
        let err = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty {
            appendLog("engine \(args.first ?? ""): \(err)", isError: !result.succeeded)
        }
        return result.stdout
    }

    /// Привилегированный вызов движка.
    ///
    /// Сначала пробуется беспарольный помощник, при неудаче — запрос пароля
    /// администратора через AppleScript. Текст ошибки теперь попадает в журнал,
    /// а отмена пользователем не выдаётся за системный сбой.
    private func runRootCommand(args: [String], timeout: TimeInterval = 180) -> Bool {
        // 1. Быстрый путь: беспарольный помощник.
        let sudo = runProcess(launchPath: "/usr/bin/sudo",
                              arguments: ["-n", Self.helperPath] + args,
                              timeout: timeout)
        if sudo.succeeded {
            DispatchQueue.main.async { self.isHelperInstalled = true }
            return true
        }

        // 2. Запасной путь: штатный запрос прав администратора.
        var commandStr = "/bin/bash '\(enginePath.replacingOccurrences(of: "'", with: "'\\''"))'"
        for arg in args {
            let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
            commandStr += " '\(escaped)'"
        }

        let escapedAppleScriptCmd = commandStr
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = "do shell script \"\(escapedAppleScriptCmd)\" with administrator privileges"

        var errorDict: NSDictionary?
        guard let scriptObject = NSAppleScript(source: scriptSource) else {
            appendLog(tr("Не удалось собрать AppleScript для запроса прав", "Could not build the AppleScript privilege request", "Укук суроо үчүн AppleScript түзүү мүмкүн болгон жок"), isError: true)
            return false
        }

        _ = scriptObject.executeAndReturnError(&errorDict)
        if let err = errorDict {
            let code = err[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -128 {
                // Пользователь нажал «Отмена» — это не ошибка, шуметь незачем.
                appendLog(tr("Запрос прав администратора отменён пользователем", "Administrator prompt cancelled by the user", "Администратор укуктарын суроону колдонуучу жокко чыгарды"))
            } else {
                let msg = err[NSAppleScript.errorMessage] as? String ?? tr("неизвестная ошибка", "unknown error", "белгисиз ката")
                appendLog(tr("Ошибка выполнения с правами администратора: \(msg)", "Privileged execution failed: \(msg)", "Администратор укуктары менен аткарууда ката: \(msg)"), isError: true)
            }
            return false
        }

        checkHelperStatus()
        return true
    }

    // MARK: - Pro Feature 1: Live Query Inspector & Analytics

    /// Идентификаторы уже учтённых запросов — чтобы повторное чтение хвоста
    /// журнала не накручивало статистику по второму разу.
    private var seenQueryIds = Set<String>()

    func startLiveQueryStream() {
        guard queryStreamTimer == nil else { return }
        refreshQueryStream()

        queryStreamTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isStreamFrozen else { return }
            self.refreshQueryStream()
        }
    }

    /// Реальные запросы, если работает локальный dnsmasq; иначе — демонстрация.
    private func refreshQueryStream() {
        guard isRunningService else {
            if !isQueryStreamSimulated {
                isQueryStreamSimulated = true
                appendLog(tr("Локальный dnsmasq остановлен — инспектор переключён в демо-режим", "Local dnsmasq is stopped — the inspector switched to demo mode", "Жергиликтүү dnsmasq токтотулду — инспектор демо режимине которулду"))
            }
            generateSimulatedLiveQuery()
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.runCommand(args: ["--query-log-json", "200"], timeout: 20)
            guard let data = out.data(using: .utf8), !data.isEmpty else { return }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            guard let items = try? decoder.decode([DNSQueryLogItem].self, from: data) else { return }

            DispatchQueue.main.async {
                if items.isEmpty {
                    // Журнал есть, но пуст — молчим, а не подсовываем выдумку.
                    self.isQueryStreamSimulated = false
                    return
                }
                if self.isQueryStreamSimulated {
                    self.isQueryStreamSimulated = false
                    self.queries.removeAll()
                    self.seenQueryIds.removeAll()
                    self.analytics = AnalyticsStats()
                    self.appendLog(tr("Инспектор переключён на журнал dnsmasq", "Inspector switched to the dnsmasq query log", "Инспектор dnsmasq журналына которулду"))
                }
                self.ingestRealQueries(items)
            }
        }
    }

    /// Добавляет только те записи, которых ещё не видели, и обновляет счётчики.
    private func ingestRealQueries(_ items: [DNSQueryLogItem]) {
        let fresh = items.filter { !seenQueryIds.contains($0.id) }
        guard !fresh.isEmpty else { return }

        for item in fresh { seenQueryIds.insert(item.id) }
        queries.insert(contentsOf: fresh, at: 0)
        if queries.count > 400 { queries.removeLast(queries.count - 400) }
        if seenQueryIds.count > 4000 { seenQueryIds = Set(queries.map { $0.id }) }

        // Счётчики меняются в локальной копии и публикуются один раз.
        // Прямые изменения @Published в цикле давали публикацию на каждый шаг,
        // и каждая перерисовывала всё дерево представлений.
        var stats = analytics
        for item in fresh {
            stats.totalQueries += 1
            guard item.isBlocked else { continue }
            stats.blockedQueries += 1
            // Оценка: средний перехваченный рекламный ответ тянет за собой
            // порядка четверти мегабайта загрузки.
            stats.dataSavedMB += 0.25
            stats.timeSavedSec += 0.12
            bumpTopTracker(in: &stats, domain: item.domain, category: item.category.title)

            if item.category == .malware {
                sendThreatNotification(domain: item.domain, category: item.category.title)
            }
        }
        analytics = stats
    }

    /// Работает по месту в переданной структуре, а не по опубликованному
    /// свойству: иначе каждый шаг был бы отдельной публикацией.
    private func bumpTopTracker(in stats: inout AnalyticsStats, domain: String, category: String) {
        if let idx = stats.topTrackers.firstIndex(where: { $0.domain == domain }) {
            let old = stats.topTrackers[idx]
            stats.topTrackers[idx] = TopTrackerItem(domain: old.domain, count: old.count + 1, category: old.category)
        } else {
            stats.topTrackers.append(TopTrackerItem(domain: domain, count: 1, category: category))
        }
        stats.topTrackers.sort { $0.count > $1.count }
        if stats.topTrackers.count > 10 {
            stats.topTrackers.removeLast(stats.topTrackers.count - 10)
        }
    }

    private func generateSimulatedLiveQuery() {
        let candidateQueries: [(String, ThreatCategory, Bool)] = [
            ("ad.adriver.ru", .ad, true),
            ("telemetry.dropbox.com", .telemetry, true),
            ("news.yandex.ru", .safe, false),
            ("api.github.com", .safe, false),
            ("pixel.facebook.com", .tracker, true),
            ("safebrowsing.googleapis.com", .safe, false),
            ("adservice.google.ru", .ad, true),
            ("cdn.apple-cloudkit.com", .safe, false),
            ("stat.online.sberbank.ru", .telemetry, true),
            ("gateway.icloud.com", .safe, false),
            ("taboola.com", .ad, true),
            ("segment.io", .tracker, true)
        ]
        
        guard let item = candidateQueries.randomElement() else { return }
        let isProtectedNow = isProtected && !isPaused && !dnsOverridden
        let isBlocked = item.2 && isProtectedNow
        let status: QueryStatus = isBlocked ? .blocked : .allowed
        let cat: ThreatCategory = isBlocked ? item.1 : (item.2 ? item.1 : .safe)
        
        let newQuery = DNSQueryLogItem(
            id: UUID().uuidString,
            domain: item.0,
            clientIp: "127.0.0.1",
            queryType: "A",
            status: status,
            category: cat,
            latencyMs: isBlocked ? 1 : Int.random(in: 8...36),
            timestamp: Date()
        )
        
        queries.insert(newQuery, at: 0)
        if queries.count > 250 {
            queries.removeLast()
        }
        
        var stats = analytics
        stats.totalQueries += 1
        if isBlocked {
            stats.blockedQueries += 1
            stats.dataSavedMB += Double.random(in: 0.15...0.40)
            stats.timeSavedSec += Double.random(in: 0.08...0.20)
            bumpTopTracker(in: &stats, domain: item.0, category: cat.title)
        }
        analytics = stats
    }
    
    func clearQueryLog() {
        queries.removeAll()
        showBanner(tr("Журнал запросов очищен", "Query log cleared", "Сурамдар журналы тазаланды"))
        SoundSystem.shared.playAction()
    }
    
    func toggleStreamFreeze() {
        isStreamFrozen.toggle()
        showBanner(isStreamFrozen ? tr("Поток запросов приостановлен", "Query stream paused", "Сурамдар агымы тындырылды") : tr("Поток запросов возобновлён", "Query stream resumed", "Сурамдар агымы кайра улантылды"))
        SoundSystem.shared.playAction()
    }
    
    func addDomainToBlacklistFromInspector(_ domain: String) {
        addBlacklistDomain(domain)
        showBanner(tr("Домен \(domain) заблокирован", "\(domain) is now blocked", "\(domain) домени бөгөттөлдү"))
        SoundSystem.shared.playAction()
    }
    
    func addDomainToWhitelistFromInspector(_ domain: String) {
        addWhitelistDomain(domain)
        showBanner(tr("Домен \(domain) добавлен в белый список", "\(domain) added to the whitelist", "\(domain) домени ак тизмеге кошулду"))
        SoundSystem.shared.playAction()
    }
    
    func exportQueriesJSON() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            // Раньше время выгружалось как «сколько-то секунд от 2001 года» —
            // ни человеку, ни другому инструменту это ни о чём не говорило.
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(queries)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    // MARK: - Pro Feature 2: Protection Pause Timer
    func pauseProtection(for duration: PauseDuration) {
        pauseProtection(seconds: duration.rawValue)
    }
    
    func pauseProtection(seconds: Int) {
        isPaused = true
        pauseRemainingSeconds = seconds
        let expiry = Date().addingTimeInterval(TimeInterval(seconds))
        self.pauseExpiryDate = expiry
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: "pause_expiry_timestamp")

        if isProtected {
            // Профиль надо запомнить ДО выключения: `turnOff()` дёргает
            // `refreshStatus()`, и `currentProfileId` перетирается состоянием
            // выключенного движка. Из-за этого пауза всегда возобновлялась
            // на AdGuard, чем бы пользователь ни пользовался до неё.
            UserDefaults.standard.set(currentProfileId, forKey: "paused_profile_id")
            turnOff()
        }
        showBanner(tr("Пауза защиты на \(seconds / 60) мин", "Protection paused for \(seconds / 60) min", "Коргоо \(seconds / 60) мүнөткө тындырылды"))
        SoundSystem.shared.playAction()

        startPauseCountdown()
    }
    
    func resumeProtection() {
        isPaused = false
        pauseRemainingSeconds = 0
        pauseExpiryDate = nil
        UserDefaults.standard.removeObject(forKey: "pause_expiry_timestamp")
        pauseTimer?.invalidate()
        pauseTimer = nil

        let restoreId = UserDefaults.standard.string(forKey: "paused_profile_id") ?? lastActiveProfileId
        UserDefaults.standard.removeObject(forKey: "paused_profile_id")

        if !isProtected {
            enableProtection(profileId: restoreId)
        }
        showBanner(tr("Защита возобновлена", "Protection resumed", "Коргоо кайра улантылды"))
        SoundSystem.shared.playSuccess()
    }
    
    func checkPendingPause() {
        guard let timestamp = UserDefaults.standard.object(forKey: "pause_expiry_timestamp") as? Double else { return }
        let expiry = Date(timeIntervalSince1970: timestamp)
        let remaining = Int(expiry.timeIntervalSince(Date()))
        
        if remaining > 0 {
            self.isPaused = true
            self.pauseRemainingSeconds = remaining
            self.pauseExpiryDate = expiry
            startPauseCountdown()
        } else {
            UserDefaults.standard.removeObject(forKey: "pause_expiry_timestamp")
        }
    }
    
    private func startPauseCountdown() {
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let expiry = self.pauseExpiryDate else { return }
            let remaining = Int(expiry.timeIntervalSince(Date()))
            if remaining > 0 {
                self.pauseRemainingSeconds = remaining
            } else {
                self.resumeProtection()
            }
        }
    }
    
    var formattedPauseRemaining: String {
        let mins = pauseRemainingSeconds / 60
        let secs = pauseRemainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Pro Feature 3: Launch at Login
    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                appendLog("LaunchAtLogin SMAppService: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Pro Feature 4: macOS Notifications
    /// Центр уведомлений доступен только внутри полноценного бандла:
    /// при запуске бинарника напрямую обращение к нему приводит к падению.
    private var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestNotificationPermissions() {
        guard notificationsAvailable else {
            appendLog(tr("Уведомления недоступны: приложение запущено не из бандла .app", "Notifications unavailable: the app is not running from an .app bundle", "Билдирмелер жеткиликсиз: колдонмо .app бандлынан ишке киргизилген эмес"))
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationsAuthorized = granted
                if let error = error {
                    self?.appendLog(tr("Уведомления: \(error.localizedDescription)", "Notifications: \(error.localizedDescription)", "Билдирмелер: \(error.localizedDescription)"), isError: true)
                } else if !granted {
                    self?.appendLog(tr("Уведомления запрещены в системных настройках macOS", "Notifications are disabled in macOS system settings", "Билдирмелерге macOS системалык жөндөөлөрүндө тыюу салынган"))
                }
            }
        }
    }
    
    func sendThreatNotification(domain: String, category: String) {
        guard notificationsEnabled, notificationsAuthorized, notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("🛡 Cerberus DNS: угроза заблокирована", "🛡 Cerberus DNS: threat blocked", "🛡 Cerberus DNS: коркунуч бөгөттөлдү")
        content.body = tr("Перехвачен опасный запрос к \(domain) (\(category)).", "Blocked a dangerous request to \(domain) (\(category)).", "\(domain) (\(category)) дарегине кооптуу сурам кармалды.")
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
