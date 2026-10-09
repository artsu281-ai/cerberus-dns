import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru = "ru"
    case ky = "ky"
    case en = "en"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .ru: return "Русский"
        case .ky: return "Кыргызча"
        case .en: return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .ru: return "🇷🇺"
        case .ky: return "🇰🇬"
        case .en: return "🇺🇸"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = LocalizationManager.systemLanguage()
        }
    }
    
    /// Первый запуск: язык системы, если он один из наших; иначе русский.
    static func systemLanguage() -> AppLanguage {
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2)).lowercased()
            if let lang = AppLanguage(rawValue: code) { return lang }
        }
        return .ru
    }

    func tr(_ key: String) -> String {
        switch currentLanguage {
        case .en: return LocalizationManager.enDict[key] ?? LocalizationManager.ruDict[key] ?? key
        case .ky: return LocalizationManager.kyDict[key] ?? LocalizationManager.ruDict[key] ?? key
        case .ru: return LocalizationManager.ruDict[key] ?? key
        }
    }
    
    // MARK: - Localization Dictionaries
    static let ruDict: [String: String] = [
        // Tabs
        "tab.dashboard": "Обзор",
        "tab.inspector": "Инспектор трафика",
        "tab.profiles": "Профили DNS",
        "tab.vpn": "VPN и Прокси",
        "tab.diagnostics": "Диагностика",
        "tab.rules": "Списки и правила",
        "tab.tools": "Инструменты",
        "tab.faq": "FAQ и Помощь",
        "tab.settings": "Настройки",
        
        // Pro Features
        "inspector.title": "Инспектор DNS-запросов",
        "inspector.subtitle": "Мониторинг сетевых запросов в реальном времени с мгновенной блокировкой трекеров",
        "inspector.search": "Поиск по домену...",
        "inspector.clear": "Очистить",
        "inspector.freeze": "Пауза стрима",
        "inspector.resume": "Продолжить",
        "inspector.export": "Экспорт JSON",
        "pause.title": "Временная пауза",
        "pause.remaining": "Пауза защиты: %@",
        "pause.resume_now": "Включить сейчас",
        "analytics.total_queries": "Всего запросов",
        "analytics.blocked_queries": "Заблокировано",
        "analytics.data_saved": "Сэкономлено трафика",
        "analytics.time_saved": "Сэкономлено времени",
        "settings.autostart": "Запуск при входе в систему",
        "settings.autostart.sub": "Автоматически запускать Cerberus DNS в фоновом режиме при старте macOS",
        "settings.notifications": "Уведомления macOS",
        "settings.notifications.sub": "Оповещать при перехвате опасных доменов и авто-переключении узлов",
        "settings.theme_accent": "Акцентный цвет интерфейса",
        "settings.theme_bg": "Стиль фона",
        
        // General
        "app.title": "Cerberus DNS",
        "app.version": "v3.0 Pro",
        "status.protected": "Защита включена",
        "status.unprotected": "Защита выключена",
        "status.active": "Защита активна",
        "btn.enable": "Включить защиту",
        "btn.disable": "Отключить",
        "btn.refresh": "Обновить статус",
        "btn.flush": "Сбросить кэш",
        "btn.palette": "Палитра команд",
        "btn.settings": "Настройки",
        "btn.language": "Язык",
        
        // Dashboard
        "dashboard.hero.active_sub": "Профиль: %@ • %@",
        "dashboard.hero.inactive_sub": "Нажмите на щит для мгновенной активации фильтрации рекламы",
        "dashboard.traffic": "Трафик:",
        "metric.adblock": "Блокировка рекламы",
        "metric.adblock.active": "100% Активна",
        "metric.adblock.inactive": "Отключена",
        "metric.adblock.active_sub": "Трекеры и баннеры фильтруются",
        "metric.adblock.inactive_sub": "Прямой доступ без фильтра",
        "metric.ping": "Задержка DNS (Ping)",
        "metric.rules": "База правил",
        "metric.rules.domains": "%d доменов",
        "metric.rules.cloud": "Облачный фильтр",
        "metric.current_dns": "Текущий DNS",
        "ping.perfect": "Идеально",
        "ping.fast": "Быстро",
        "ping.normal": "Норма",
        "ping.slow": "Задержка",
        "ping.testing": "Замер...",
        
        // VPN
        "vpn.title": "VPN, Прокси и Защищенные туннели",
        "vpn.subtitle": "Бесплатные проверенные узлы, зашифрованные Anycast туннели и автоматический фоллбек при сбоях и блокировках.",
        "vpn.active": "Туннель активен",
        "vpn.inactive": "Туннели отключены",
        "vpn.failover.title": "Авто-фоллбек (Auto-Failover при сбоях)",
        "vpn.failover.on": "Фоновый мониторинг: при сбое узла система мгновенно переключит трафик на резервный сервер.",
        "vpn.failover.off": "Авто-переключение отключено. Переключение узлов выполняется вручную.",
        "vpn.pool.title": "Пул проверенных бесплатных узлов",
        "vpn.pool.sub": "Все узлы протестированы, зашифрованы и поддерживают авто-переключение при недоступности.",
        "vpn.btn.check_ping": "Проверить пинг",
        "vpn.ip.title": "Текущий сетевой адрес и локация",
        "vpn.ip.refresh": "Обновить IP",
        "vpn.custom.title": "Собственные локальные клиенты (V2Ray / Shadowsocks / Clash)",
        "vpn.security.title": "Параметры безопасности",
        "vpn.split_tunneling": "Раздельное туннелирование (Split Tunneling)",
        "vpn.split_tunneling_sub": "Локальные сервисы и банковские сайты открываются напрямую на полной скорости, а заблокированные — через туннель.",
        
        // Diagnostics
        "diag.title": "Диагностика и Аналитика",
        "diag.subtitle": "Комплексная проверка устойчивости к рекламным сетям, аналитическим трекерам и замер задержки DNS-провайдеров.",
        "diag.tab.adblock": "Проверка трекеров и рекламы",
        "diag.tab.speed": "Бенчмарк скорости DNS",
        "diag.btn.run": "Запустить тест",
        "diag.btn.copy": "Копировать отчёт",
        
        // Rules
        "rules.title": "Списки фильтрации и исключения",
        "rules.subtitle": "Управление источниками правил блокировки, белым списком исключений и собственными черными списками.",
        "rules.tab.whitelist": "Белый список (Разрешить)",
        "rules.tab.blacklist": "Чёрный список (Блокировать)",
        "rules.btn.add": "Добавить правило",
        "rules.search": "Поиск по доменам...",
        
        // FAQ
        "faq.title": "База знаний и FAQ",
        "faq.subtitle": "Ответы на часто задаваемые вопросы, руководства по безопасности и настройке туннелей.",
        "faq.search": "Поиск по вопросам, терминам или проблемам...",
        
        // Settings
        "settings.title": "Настройки",
        "settings.tab.general": "Основные",
        "settings.tab.network": "DNS и Сеть",
        "settings.tab.about": "О программе",
        "settings.appearance": "Оформление (Тема)",
        "settings.sidebar_size": "Размер бокового меню",
        "settings.autoupdate": "Фоновое обновление списков блокировки",
        "settings.sounds": "Звуковые эффекты интерфейса",
        "settings.language": "Язык интерфейса (Interface Language)",
        
        // Theme & Sidebar
        "theme.system": "Системная",
        "theme.light": "Светлая",
        "theme.dark": "Тёмная",
        "sidebar.small": "Компактный",
        "sidebar.medium": "Стандартный",
        "sidebar.large": "Крупный"
    ]
    
    static let enDict: [String: String] = [
        // Tabs
        "tab.dashboard": "Overview",
        "tab.inspector": "Traffic Inspector",
        "tab.profiles": "DNS Profiles",
        "tab.vpn": "VPN & Proxy",
        "tab.diagnostics": "Diagnostics",
        "tab.rules": "Rules & Lists",
        "tab.tools": "Tools",
        "tab.faq": "FAQ & Help",
        "tab.settings": "Settings",
        
        // Pro Features
        "inspector.title": "Live DNS Query Inspector",
        "inspector.subtitle": "Real-time network query monitoring with instant tracker blocking",
        "inspector.search": "Search domain...",
        "inspector.clear": "Clear",
        "inspector.freeze": "Freeze Stream",
        "inspector.resume": "Resume",
        "inspector.export": "Export JSON",
        "pause.title": "Pause Protection",
        "pause.remaining": "Paused: %@ remaining",
        "pause.resume_now": "Resume Now",
        "analytics.total_queries": "Total Queries",
        "analytics.blocked_queries": "Blocked",
        "analytics.data_saved": "Data Saved",
        "analytics.time_saved": "Time Saved",
        "settings.autostart": "Launch at Login",
        "settings.autostart.sub": "Automatically launch Cerberus DNS in background when macOS starts",
        "settings.notifications": "macOS Notifications",
        "settings.notifications.sub": "Alert when threats are blocked or failover switches node",
        "settings.theme_accent": "Interface Accent Color",
        "settings.theme_bg": "Background Style",
        
        // General
        "app.title": "Cerberus DNS",
        "app.version": "v3.0 Pro",
        "status.protected": "Protection Enabled",
        "status.unprotected": "Protection Disabled",
        "status.active": "Protection Active",
        "btn.enable": "Enable Protection",
        "btn.disable": "Disable",
        "btn.refresh": "Refresh Status",
        "btn.flush": "Flush DNS Cache",
        "btn.palette": "Command Palette",
        "btn.settings": "Settings",
        "btn.language": "Language",
        
        // Dashboard
        "dashboard.hero.active_sub": "Profile: %@ • %@",
        "dashboard.hero.inactive_sub": "Click the shield to instantly activate ad & tracker blocking",
        "dashboard.traffic": "Traffic:",
        "metric.adblock": "Ad & Tracker Blocking",
        "metric.adblock.active": "100% Active",
        "metric.adblock.inactive": "Disabled",
        "metric.adblock.active_sub": "Trackers and ads are filtered",
        "metric.adblock.inactive_sub": "Direct unfiltered access",
        "metric.ping": "DNS Latency (Ping)",
        "metric.rules": "Rule Database",
        "metric.rules.domains": "%d domains",
        "metric.rules.cloud": "Cloud Filter",
        "metric.current_dns": "Current DNS",
        "ping.perfect": "Perfect",
        "ping.fast": "Fast",
        "ping.normal": "Good",
        "ping.slow": "High Latency",
        "ping.testing": "Testing...",
        
        // VPN
        "vpn.title": "VPN, Proxy & Secure Tunnels",
        "vpn.subtitle": "Free verified nodes, encrypted Anycast tunnels, and auto-failover on connection drop or blocking.",
        "vpn.active": "Tunnel Active",
        "vpn.inactive": "Tunnels Inactive",
        "vpn.failover.title": "Auto-Failover on Connection Failure",
        "vpn.failover.on": "Background monitoring: if a node fails, traffic automatically switches to the fastest backup server.",
        "vpn.failover.off": "Auto-failover disabled. Node switching is manual.",
        "vpn.pool.title": "Verified Free Nodes Pool",
        "vpn.pool.sub": "All nodes are tested, encrypted, and support seamless auto-failover upon outage.",
        "vpn.btn.check_ping": "Check Ping",
        "vpn.ip.title": "Current Network IP & Location",
        "vpn.ip.refresh": "Refresh IP",
        "vpn.custom.title": "Custom Local Clients (V2Ray / Shadowsocks / Clash)",
        "vpn.security.title": "Security Options",
        "vpn.split_tunneling": "Split Tunneling",
        "vpn.split_tunneling_sub": "Local services and banking websites open directly at full speed, while blocked services route through the tunnel.",
        
        // Diagnostics
        "diag.title": "Diagnostics & Analytics",
        "diag.subtitle": "Comprehensive testing against ad networks, tracking telemetry, and DNS response time benchmark.",
        "diag.tab.adblock": "Ad & Tracker Test",
        "diag.tab.speed": "DNS Speed Benchmark",
        "diag.btn.run": "Run Test",
        "diag.btn.copy": "Copy Report",
        
        // Rules
        "rules.title": "Filtering Rules & Exceptions",
        "rules.subtitle": "Manage blocklist sources, whitelist exceptions, and custom blacklists.",
        "rules.tab.whitelist": "Whitelist (Allow)",
        "rules.tab.blacklist": "Blacklist (Block)",
        "rules.btn.add": "Add Rule",
        "rules.search": "Search domains...",
        
        // FAQ
        "faq.title": "Knowledge Base & FAQ",
        "faq.subtitle": "Frequently asked questions, security guides and tunnel configurations.",
        "faq.search": "Search questions, keywords or topics...",
        
        // Settings
        "settings.title": "Settings",
        "settings.tab.general": "General",
        "settings.tab.network": "DNS & Network",
        "settings.tab.about": "About",
        "settings.appearance": "Appearance & Theme",
        "settings.sidebar_size": "Sidebar Size",
        "settings.autoupdate": "Background weekly rule updates",
        "settings.sounds": "Interface sound effects",
        "settings.language": "Interface Language",
        
        // Theme & Sidebar
        "theme.system": "System",
        "theme.light": "Light",
        "theme.dark": "Dark",
        "sidebar.small": "Small",
        "sidebar.medium": "Medium",
        "sidebar.large": "Large"
    ]

    static let kyDict: [String: String] = [
        "tab.dashboard": "Сереп",
        "tab.inspector": "Трафик инспектору",
        "tab.profiles": "DNS профилдери",
        "tab.vpn": "VPN жана прокси",
        "tab.diagnostics": "Диагностика",
        "tab.rules": "Тизмелер жана эрежелер",
        "tab.tools": "Куралдар",
        "tab.faq": "FAQ жана жардам",
        "tab.settings": "Жөндөөлөр",
        "inspector.title": "DNS-сурамдардын инспектору",
        "inspector.subtitle": "Тармак сурамдарын реалдуу убакытта көзөмөлдөө жана трекерлерди заматта бөгөттөө",
        "inspector.search": "Домен боюнча издөө...",
        "inspector.clear": "Тазалоо",
        "inspector.freeze": "Агымды тындыруу",
        "inspector.resume": "Улантуу",
        "inspector.export": "JSON экспорттоо",
        "pause.title": "Убактылуу тыным",
        "pause.remaining": "Коргоонун тынымы: %@",
        "pause.resume_now": "Азыр күйгүзүү",
        "analytics.total_queries": "Бардык сурамдар",
        "analytics.blocked_queries": "Бөгөттөлдү",
        "analytics.data_saved": "Үнөмдөлгөн трафик",
        "analytics.time_saved": "Үнөмдөлгөн убакыт",
        "settings.autostart": "Системага киргенде ишке киргизүү",
        "settings.autostart.sub": "macOS иштей баштаганда Cerberus DNS'ти фондо автоматтык түрдө ишке киргизүү",
        "settings.notifications": "macOS билдирмелери",
        "settings.notifications.sub": "Коркунучтуу домендер кармалганда жана түйүндөр автоматтык түрдө которулганда билдирүү",
        "settings.theme_accent": "Интерфейстин акцент түсү",
        "settings.theme_bg": "Фондун стили",
        "app.title": "Cerberus DNS",
        "app.version": "v3.0 Pro",
        "status.protected": "Коргоо күйгүзүлгөн",
        "status.unprotected": "Коргоо өчүрүлгөн",
        "status.active": "Коргоо активдүү",
        "btn.enable": "Коргоону күйгүзүү",
        "btn.disable": "Өчүрүү",
        "btn.refresh": "Абалды жаңыртуу",
        "btn.flush": "Кэшти тазалоо",
        "btn.palette": "Буйруктар палитрасы",
        "btn.settings": "Жөндөөлөр",
        "btn.language": "Тил",
        "dashboard.hero.active_sub": "Профиль: %@ • %@",
        "dashboard.hero.inactive_sub": "Жарнаманы чыпкалоону заматта иштетүү үчүн калканчты басыңыз",
        "dashboard.traffic": "Трафик:",
        "metric.adblock": "Жарнаманы бөгөттөө",
        "metric.adblock.active": "100% активдүү",
        "metric.adblock.inactive": "Өчүрүлгөн",
        "metric.adblock.active_sub": "Трекерлер жана баннерлер чыпкаланууда",
        "metric.adblock.inactive_sub": "Чыпкасыз түз кирүү",
        "metric.ping": "DNS кечигүүсү (Ping)",
        "metric.rules": "Эрежелер базасы",
        "metric.rules.domains": "%d домен",
        "metric.rules.cloud": "Булуттагы чыпка",
        "metric.current_dns": "Учурдагы DNS",
        "ping.perfect": "Мыкты",
        "ping.fast": "Ылдам",
        "ping.normal": "Кадимки",
        "ping.slow": "Кечигүү",
        "ping.testing": "Өлчөө...",
        "vpn.title": "VPN, прокси жана корголгон туннелдер",
        "vpn.subtitle": "Акысыз текшерилген түйүндөр, шифрленген Anycast туннелдер жана үзгүлтүк же бөгөттөө болгондо автоматтык алмаштыруу.",
        "vpn.active": "Туннель активдүү",
        "vpn.inactive": "Туннелдер өчүрүлгөн",
        "vpn.failover.title": "Авто-алмаштыруу (үзгүлтүктө Auto-Failover)",
        "vpn.failover.on": "Фондук көзөмөл: түйүн иштебей калса, система трафикти заматта камдык серверге которот.",
        "vpn.failover.off": "Авто-которуу өчүрүлгөн. Түйүндөр кол менен которулат.",
        "vpn.pool.title": "Текшерилген акысыз түйүндөрдүн пулу",
        "vpn.pool.sub": "Бардык түйүндөр тестирленген, шифрленген жана жеткиликсиз болгондо авто-которууну колдойт.",
        "vpn.btn.check_ping": "Пингди текшерүү",
        "vpn.ip.title": "Учурдагы тармак дареги жана жайгашкан жери",
        "vpn.ip.refresh": "IP жаңыртуу",
        "vpn.custom.title": "Өз локалдык клиенттериңиз (V2Ray / Shadowsocks / Clash)",
        "vpn.security.title": "Коопсуздук параметрлери",
        "vpn.split_tunneling": "Бөлүнгөн туннелдөө (Split Tunneling)",
        "vpn.split_tunneling_sub": "Локалдык кызматтар жана банк сайттары түз, толук ылдамдыкта ачылат, ал эми бөгөттөлгөндөрү — туннель аркылуу.",
        "diag.title": "Диагностика жана аналитика",
        "diag.subtitle": "Жарнама тармактарына жана аналитикалык трекерлерге туруктуулукту комплекстүү текшерүү жана DNS провайдерлеринин кечигүүсүн өлчөө.",
        "diag.tab.adblock": "Трекерлерди жана жарнаманы текшерүү",
        "diag.tab.speed": "DNS ылдамдыгынын бенчмарки",
        "diag.btn.run": "Тестти баштоо",
        "diag.btn.copy": "Отчетту көчүрүү",
        "rules.title": "Чыпкалоо тизмелери жана өзгөчөлүктөр",
        "rules.subtitle": "Бөгөттөө эрежелеринин булактарын, өзгөчөлүктөрдүн ак тизмесин жана өз кара тизмелериңизди башкаруу.",
        "rules.tab.whitelist": "Ак тизме (Уруксат берүү)",
        "rules.tab.blacklist": "Кара тизме (Бөгөттөө)",
        "rules.btn.add": "Эреже кошуу",
        "rules.search": "Домендер боюнча издөө...",
        "faq.title": "Билим базасы жана FAQ",
        "faq.subtitle": "Көп берилүүчү суроолорго жооптор, коопсуздук жана туннелдерди жөндөө боюнча колдонмолор.",
        "faq.search": "Суроолор, терминдер же көйгөйлөр боюнча издөө...",
        "settings.title": "Жөндөөлөр",
        "settings.tab.general": "Негизги",
        "settings.tab.network": "DNS жана тармак",
        "settings.tab.about": "Программа жөнүндө",
        "settings.appearance": "Көрүнүш (Тема)",
        "settings.sidebar_size": "Каптал менюнун өлчөмү",
        "settings.autoupdate": "Бөгөттөө тизмелерин фондо жаңыртуу",
        "settings.sounds": "Интерфейстин үн эффекттери",
        "settings.language": "Интерфейстин тили (Interface Language)",
        "theme.system": "Системалык",
        "theme.light": "Жарык",
        "theme.dark": "Караңгы",
        "sidebar.small": "Компакттуу",
        "sidebar.medium": "Стандарттык",
        "sidebar.large": "Ири"
    ]
}

// Global convenience translation function
func L(_ key: String) -> String {
    LocalizationManager.shared.tr(key)
}


/// Выбор строки по текущему языку интерфейса: русский, английский, кыргызский.
///
/// Тексты баннеров формируются в `DNSManager`, а не в представлениях,
/// и до сих пор оставались русскими независимо от выбранного языка.
/// Функция объявлена на уровне файла, чтобы её можно было вызывать
/// из ускользающих замыканий без `self.`.
func tr(_ ru: String, _ en: String, _ ky: String) -> String {
    switch LocalizationManager.shared.currentLanguage {
    case .ru: return ru
    case .en: return en
    case .ky: return ky
    }
}
