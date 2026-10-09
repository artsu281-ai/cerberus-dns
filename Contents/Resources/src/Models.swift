import Foundation
import SwiftUI

// MARK: - Navigation Tab
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case inspector = "inspector"
    case profiles = "profiles"
    case vpn = "vpn"
    case diagnostics = "diagnostics"
    case rules = "rules"
    case tools = "tools"
    case faq = "faq"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var localizedTitle: String {
        return L("tab.\(rawValue)")
    }
    
    var iconName: String {
        switch self {
        case .dashboard: return "shield.lefthalf.filled"
        case .inspector: return "dot.radiowaves.left.and.right"
        case .profiles: return "server.rack"
        case .vpn: return "network.badge.shield.half.filled"
        case .diagnostics: return "waveform.path.ecg"
        case .rules: return "checklist"
        case .tools: return "wrench.and.screwdriver"
        case .faq: return "questionmark.circle.fill"
        case .settings: return "gearshape"
        }
    }
    
    var shortcutNumber: String {
        switch self {
        case .dashboard: return "1"
        case .inspector: return "2"
        case .profiles: return "3"
        case .vpn: return "4"
        case .diagnostics: return "5"
        case .rules: return "6"
        case .tools: return "7"
        case .faq: return "8"
        case .settings: return ","
        }
    }
}

// MARK: - Modern Proxy Protocols
enum ProxyProtocol: String, CaseIterable, Codable, Identifiable {
    case vless = "vless"
    case shadowsocks = "shadowsocks"
    case trojan = "trojan"
    case hysteria2 = "hysteria2"
    case socks5 = "socks5"
    case http = "http"
    case warp = "warp"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .vless: return "VLESS (REALITY)"
        case .shadowsocks: return "Shadowsocks 2022"
        case .trojan: return "Trojan"
        case .hysteria2: return "Hysteria 2 / TUIC"
        case .socks5: return "SOCKS5"
        case .http: return "HTTP(S)"
        case .warp: return "Cloudflare WARP"
        }
    }
    
    var shortBadge: String {
        switch self {
        case .vless: return "VLESS"
        case .shadowsocks: return "SS-2022"
        case .trojan: return "Trojan"
        case .hysteria2: return "HY2"
        case .socks5: return "SOCKS5"
        case .http: return "HTTP"
        case .warp: return "WARP"
        }
    }
}

// MARK: - Traffic Routing Mode
enum TrafficRoutingMode: String, CaseIterable, Codable, Identifiable {
    case ruleBased = "rule_based"
    case global = "global"
    case bypassBlocked = "bypass_blocked"
    case direct = "direct"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .ruleBased:     return tr("По правилам (Smart Routing)", "Rule-based (smart routing)", "Эрежелер боюнча (Smart Routing)")
        case .global:        return tr("Глобальный туннель (Global)", "Global tunnel", "Глобалдык туннель (Global)")
        case .bypassBlocked: return tr("Только недоступные сайты", "Unreachable sites only", "Жеткиликсиз сайттар гана")
        case .direct:        return tr("Прямой (Direct Only)", "Direct only", "Түз (Direct Only)")
        }
    }
    
    var description: String {
        switch self {
        case .ruleBased:
            return tr("Реклама блокируется, банки и RU-сайты идут напрямую, заблокированные ресурсы — через прокси.",
                      "Ads are blocked, banking and local sites go direct, blocked resources go through the proxy.", "Жарнама бөгөттөлөт, банктар жана RU-сайттар түз ачылат, бөгөттөлгөн ресурстар — прокси аркылуу.")
        case .global:
            return tr("Весь сетевой трафик системы перенаправляется через выбранный узел VLESS / Proxy.",
                      "All system network traffic is routed through the selected VLESS / proxy node.", "Системанын бардык тармак трафиги тандалган VLESS / Proxy түйүнү аркылуу багытталат.")
        case .bypassBlocked:
            return tr("Трафик к заблокированным за рубежом сетям туннелируется, остальные сайты — напрямую.",
                      "Traffic to blocked networks is tunnelled; everything else connects directly.", "Чет өлкөдө бөгөттөлгөн тармактарга трафик туннель аркылуу өтөт, калган сайттар — түз.")
        case .direct:
            return tr("Прямое подключение к интернету с активным DNS-фильтром рекламы.",
                      "Direct internet connection with DNS ad filtering active.", "Жарнаманын DNS-чыпкасы иштеп турган түз интернет туташуусу.")
        }
    }
    
    var iconName: String {
        switch self {
        case .ruleBased: return "arrow.triangle.branch"
        case .global: return "globe.europe.africa.fill"
        case .bypassBlocked: return "lock.open.trianglebadge.exclamationmark.fill"
        case .direct: return "bolt.horizontal.fill"
        }
    }
}

// MARK: - Node Kind
/// Чем узел является на самом деле.
///
/// Встроенные «узлы» вроде 94.140.14.14:53 — это публичные DNS-резолверы,
/// а не SOCKS-прокси. Подключение к ним как к прокси настраивало бы системный
/// SOCKS на DNS-порт и обрывало весь сетевой доступ.
enum VPNNodeKind: String, Codable {
    case dns
    case proxy
}

// MARK: - Advanced VPN / Proxy Node
struct VPNNode: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var country: String
    var flag: String
    var host: String
    var port: String
    var protocolType: String // vless, shadowsocks, trojan, hysteria2, socks5, http, warp
    var isRecommended: Bool
    var latencyMs: Int
    var isOnline: Bool
    
    // VLESS / REALITY / Vision / Shadowsocks / Trojan Parameters
    var uuid: String?
    var password: String?
    var security: String? // reality, tls, none
    var sni: String?      // e.g. yahoo.com, apple.com
    var publicKey: String? // for REALITY (pbk)
    var shortId: String?   // for REALITY (sid)
    var flow: String?      // xtls-rprx-vision
    var transport: String? // tcp, grpc, ws
    var isCustom: Bool = false

    init(id: String, name: String, country: String, flag: String, host: String, port: String,
         protocolType: String, isRecommended: Bool, latencyMs: Int, isOnline: Bool,
         uuid: String? = nil, password: String? = nil, security: String? = nil, sni: String? = nil,
         publicKey: String? = nil, shortId: String? = nil, flow: String? = nil,
         transport: String? = nil, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.country = VPNNode.normalizedCountry(country)
        self.flag = flag
        self.host = host
        self.port = port
        self.protocolType = VPNNode.normalizedProtocol(protocolType)
        self.isRecommended = isRecommended
        self.latencyMs = latencyMs
        self.isOnline = isOnline
        self.uuid = uuid
        self.password = password
        self.security = security
        self.sni = sni
        self.publicKey = publicKey
        self.shortId = shortId
        self.flow = flow
        self.transport = transport
        self.isCustom = isCustom
    }

    /// Снисходительный декодер.
    ///
    /// Синтезированный `init(from:)` игнорирует значения по умолчанию и требует
    /// все ключи. Движок не отдаёт `isCustom`, поэтому разбор всего списка узлов
    /// падал с `keyNotFound`, ошибка глоталась, и интерфейс всегда показывал
    /// зашитые в код задержки вместо реально измеренных.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        country = VPNNode.normalizedCountry(try c.decodeIfPresent(String.self, forKey: .country) ?? "")
        flag = try c.decodeIfPresent(String.self, forKey: .flag) ?? "🌐"
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try c.decodeIfPresent(String.self, forKey: .port) ?? ""
        protocolType = VPNNode.normalizedProtocol(try c.decodeIfPresent(String.self, forKey: .protocolType) ?? "")
        isRecommended = try c.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        latencyMs = try c.decodeIfPresent(Int.self, forKey: .latencyMs) ?? -1
        isOnline = try c.decodeIfPresent(Bool.self, forKey: .isOnline) ?? (latencyMs >= 0)
        uuid = try c.decodeIfPresent(String.self, forKey: .uuid)
        password = try c.decodeIfPresent(String.self, forKey: .password)
        security = try c.decodeIfPresent(String.self, forKey: .security)
        sni = try c.decodeIfPresent(String.self, forKey: .sni)
        publicKey = try c.decodeIfPresent(String.self, forKey: .publicKey)
        shortId = try c.decodeIfPresent(String.self, forKey: .shortId)
        flow = try c.decodeIfPresent(String.self, forKey: .flow)
        transport = try c.decodeIfPresent(String.self, forKey: .transport)
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    /// Приводит «SOCKS5 / Anycast», «DoH / Tunnel» и подобное к одному словарю,
    /// на который опирается логика подключения.
    static func normalizedProtocol(_ raw: String) -> String {
        let v = raw.lowercased()
        // Порядок проверок важен. Конкретные протоколы идут раньше общих
        // признаков: строка «SOCKS5 / Anycast» содержит и «socks», и «anycast»,
        // и при обратном порядке превращалась в «warp». На порту 53 это ничем
        // не грозило, но настоящий SOCKS5-прокси с таким описанием считался бы
        // DNS-узлом и применялся как DNS-профиль вместо туннеля.
        if v.contains("vless") { return "vless" }
        if v.contains("shadowsocks") || v.hasPrefix("ss:") || v == "ss" { return "shadowsocks" }
        if v.contains("trojan") { return "trojan" }
        if v.contains("hysteria") || v.contains("tuic") || v.contains("hy2") { return "hysteria2" }
        if v.contains("socks") { return "socks5" }
        if v.contains("http") { return "http" }
        if v.contains("warp") { return "warp" }
        if v.contains("anycast") || v.contains("doh") || v.contains("dns") { return "dns" }
        return v.isEmpty ? "socks5" : v
    }

    /// Двухбуквенный код страны — его ждут флаговые бейджи в палитре команд.
    static func normalizedCountry(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count == 2 { return trimmed.uppercased() }
        let map: [String: String] = [
            "нидерланды": "NL", "netherlands": "NL",
            "германия": "DE", "germany": "DE",
            "финляндия": "FI", "finland": "FI",
            "швеция": "SE", "sweden": "SE",
            "сша": "US", "usa": "US", "united states": "US",
            "россия": "RU", "russia": "RU",
            "локальный mac": "RU", "локальный": "RU", "local": "RU",
            "глобальный anycast": "WW", "anycast": "WW", "global": "WW"
        ]
        return map[trimmed.lowercased()] ?? (trimmed.isEmpty ? "WW" : trimmed)
    }

    /// DNS-резолвер или настоящий прокси-туннель.
    var kind: VPNNodeKind {
        // Порт 53 — это DNS, чем бы ни назывался протокол в описании узла.
        if port == "53" { return .dns }
        if protocolType == "warp" || protocolType == "dns" { return .dns }
        return .proxy
    }

    /// Подпись для бейджа, честно отражающая природу узла.
    var kindBadge: String {
        switch kind {
        case .dns: return protocolType == "warp" ? "ANYCAST DNS" : "DNS"
        case .proxy: return protocolType.uppercased()
        }
    }
}

// MARK: - FAQ Item
struct FAQItem: Identifiable, Equatable {
    let id: String
    /// Ключ категории, не зависящий от языка: фильтр в интерфейсе раньше
    /// сравнивал переведённые подписи и ломался при переключении RU/EN.
    let categoryKey: String
    let category: String
    let question: String
    let answer: String
    let icon: String
    let actionTitle: String?
    let actionTab: AppTab?
    
    init(id: String? = nil, categoryKey: String, category: String, question: String, answer: String, icon: String, actionTitle: String? = nil, actionTab: AppTab? = nil) {
        self.id = id ?? "\(categoryKey)_\(icon)"
        self.categoryKey = categoryKey
        self.category = category
        self.question = question
        self.answer = answer
        self.icon = icon
        self.actionTitle = actionTitle
        self.actionTab = actionTab
    }
    
    static func == (lhs: FAQItem, rhs: FAQItem) -> Bool {
        lhs.id == rhs.id
    }
    
    private static let faqLock = NSLock()
    private static var faqCache: (lang: AppLanguage, items: [FAQItem])?

    /// Список статей, собранный один раз на язык.
    ///
    /// Было вычисляемым свойством — ради переключения RU/EN, которое `static let`
    /// ломал бы, запомнив язык первого обращения. Но у `FAQItem` идентификатор
    /// это `UUID()`, и пересборка на каждое обращение выдавала новые id: SwiftUI
    /// терял тождество строк, а раскрытая статья, которая хранится по id,
    /// схлопывалась при первой же перерисовке — раздел нельзя было прочитать.
    ///
    /// Запоминание по языку решает и это, и стоимость: 63 вызова `tr()` и 16
    /// объектов пересобирались на каждый кадр.
    static var allFAQs: [FAQItem] {
        faqLock.lock(); defer { faqLock.unlock() }
        let lang = LocalizationManager.shared.currentLanguage
        if let cached = faqCache, cached.lang == lang { return cached.items }
        let items = buildFAQs()
        faqCache = (lang, items)
        return items
    }

    private static func buildFAQs() -> [FAQItem] {
        [
        FAQItem(
            categoryKey: "basics",
            category: tr("Основы", "Basics", "Негиздер"),
            question: tr("В чём разница между DNS-блокировкой и традиционным VPN?",
                         "What is the difference between DNS blocking and a traditional VPN?", "DNS-бөгөттөө менен кадимки VPNдин айырмасы эмнеде?"),
            answer: tr("DNS-блокировщик фильтрует запросы на уровне доменных имен (DNS) прямо перед загрузкой сайта: реклама, баннеры и шпионские трекеры блокируются до того, как они скачаются. Это не снижает скорость интернета и не расходует батарею MacBook.\n\nVPN, напротив, шифрует весь интернет-трафик и перенаправляет его через удаленный сервер, меняя ваш внешний IP-адрес для обхода региональных блокировок.",
                       "A DNS blocker filters requests at the domain-name level, before a page loads: ads, banners and tracking scripts are dropped before they are ever downloaded. It does not slow the connection down or drain the battery.\n\nA VPN instead encrypts all traffic and routes it through a remote server, changing your public IP address to get around regional restrictions.", "DNS-бөгөттөгүч сурамдарды домендик аттардын (DNS) деңгээлинде, сайт жүктөлөрдөн мурун эле чыпкалайт: жарнама, баннерлер жана тыңчы трекерлер жүктөлүп алынганга чейин бөгөттөлөт. Бул интернеттин ылдамдыгын төмөндөтпөйт жана MacBook батареясын коротпойт.\n\nVPN болсо, тескерисинче, бардык интернет трафигин шифрлеп, алыскы сервер аркылуу багыттайт жана аймактык бөгөттөрдү айланып өтүү үчүн тышкы IP-дарегиңизди өзгөртөт."),
            icon: "shield.lefthalf.filled",
            actionTitle: tr("Проверить профили DNS", "Open DNS profiles", "DNS профилдерин текшерүү"),
            actionTab: .profiles
        ),
        FAQItem(
            categoryKey: "vpn",
            category: tr("VPN и Туннели", "VPN & tunnels", "VPN жана туннелдер"),
            question: tr("Как работает автоматический фоллбек (Auto-Failover)?",
                         "How does automatic failover work?", "Автоматтык алмаштыруу (Auto-Failover) кантип иштейт?"),
            answer: tr("Функция Auto-Failover постоянно следит за откликом активного узла VPN/прокси в фоне. Если выбранный сервер перестает отвечать, блокируется провайдером или задержка превышает 1.5 секунды, система автоматически и бесшовно переключает сетевые настройки macOS на следующий самый быстрый резервный узел из пула.",
                       "Auto-failover watches the response time of the active node in the background. If the selected server stops answering, gets blocked by your ISP, or its latency exceeds 1.5 seconds, the app switches macOS over to the fastest healthy node in the pool.", "Auto-Failover функциясы активдүү VPN/прокси түйүнүнүн жооп берүүсүн фондо дайыма көзөмөлдөйт. Тандалган сервер жооп бербей калса, провайдер тарабынан бөгөттөлсө же кечигүү 1.5 секунддан ашса, система macOS тармак жөндөөлөрүн пулдагы эң ылдам кийинки камдык түйүнгө автоматтык түрдө жана байкалбай которот."),
            icon: "bolt.shield.fill",
            actionTitle: tr("Открыть настройки VPN", "Open VPN settings", "VPN жөндөөлөрүн ачуу"),
            actionTab: .vpn
        ),
        FAQItem(
            categoryKey: "security",
            category: tr("Безопасность", "Security", "Коопсуздук"),
            question: tr("Будут ли работать банки, госуслуги и локальные сервисы?",
                         "Will banking, government and local services keep working?", "Банктар, мамлекеттик кызматтар жана жергиликтүү сервистер иштейби?"),
            answer: tr("Да. При включенном DNS-блокировщике локальные сервисы и банки работают на полной скорости. При использовании раздела «VPN и Прокси» включите «Раздельное туннелирование (Split Tunneling)»: оно отправляет заблокированные ресурсы через туннель, а банки и локальные сайты — напрямую через вашего провайдера.",
                       "Yes. With DNS filtering on, local services and banks work at full speed. In the VPN & Proxy section, enable split tunnelling: blocked resources go through the tunnel while banking and local sites connect directly through your ISP.", "Ооба. DNS-бөгөттөгүч күйгүзүлгөндө жергиликтүү сервистер жана банктар толук ылдамдыкта иштейт. «VPN жана Прокси» бөлүмүн колдонсоңуз, «Бөлүнгөн туннелдөө (Split Tunneling)» функциясын күйгүзүңүз: ал бөгөттөлгөн ресурстарды туннель аркылуу, ал эми банктарды жана жергиликтүү сайттарды провайдериңиз аркылуу түз жөнөтөт."),
            icon: "creditcard.fill",
            actionTitle: tr("Настроить Split Tunneling", "Configure split tunnelling", "Split Tunneling жөндөө"),
            actionTab: .vpn
        ),
        FAQItem(
            categoryKey: "basics",
            category: tr("Основы", "Basics", "Негиздер"),
            question: tr("Что такое Cloudflare WARP и DNS-over-HTTPS (DoH)?",
                         "What are Cloudflare WARP and DNS-over-HTTPS (DoH)?", "Cloudflare WARP жана DNS-over-HTTPS (DoH) деген эмне?"),
            answer: tr("Cloudflare WARP и протокол DoH (DNS-over-HTTPS) шифруют запросы к сайтам с использованием TLS 1.3 через стандартный порт 443. Это скрывает названия посещаемых вами сайтов от интернет-провайдера и затрудняет их перехват системами DPI.",
                       "Cloudflare WARP and DoH encrypt name lookups with TLS 1.3 over the standard HTTPS port 443. That hides the names of the sites you visit from your ISP and makes them much harder for DPI systems to intercept.", "Cloudflare WARP жана DoH (DNS-over-HTTPS) протоколу сайттарга сурамдарды стандарттык 443 порту аркылуу TLS 1.3 менен шифрлейт. Бул сиз кирген сайттардын аттарын интернет-провайдерден жашырат жана аларды DPI системаларынын кармап калуусун кыйындатат."),
            icon: "lock.shield.fill",
            actionTitle: tr("Тест эффективности DoH", "Test DoH effectiveness", "DoH натыйжалуулугунун тести"),
            actionTab: .diagnostics
        ),
        FAQItem(
            categoryKey: "troubleshooting",
            category: tr("Устранение неполадок", "Troubleshooting", "Көйгөйлөрдү оңдоо"),
            question: tr("Зачем и когда нужно очищать DNS-кэш macOS?",
                         "Why and when should I flush the macOS DNS cache?", "macOS DNS-кэшин эмне үчүн жана качан тазалоо керек?"),
            answer: tr("macOS кэширует IP-адреса посещенных сайтов в системном сервисе mDNSResponder на срок до 5–15 минут. После переключения профиля или изменения белого списка сброс кэша заставляет систему сразу применить новые настройки во всех браузерах и приложениях.",
                       "macOS caches resolved addresses in mDNSResponder for five to fifteen minutes. After switching profiles or editing the whitelist, flushing the cache makes every browser and app pick up the new settings immediately.", "macOS кирген сайттардын IP-даректерин mDNSResponder системалык кызматында 5–15 мүнөткө чейин кэштейт. Профилди которгондон же ак тизмени өзгөрткөндөн кийин кэшти тазалоо системаны жаңы жөндөөлөрдү бардык браузерлерде жана колдонмолордо дароо колдонууга мажбурлайт."),
            icon: "trash.circle.fill",
            actionTitle: tr("Сбросить кэш DNS сейчас", "Flush the DNS cache now", "DNS кэшин азыр тазалоо"),
            actionTab: .tools
        ),
        FAQItem(
            categoryKey: "performance",
            category: tr("Производительность", "Performance", "Өндүрүмдүүлүк"),
            question: tr("Влияет ли приложение на расход аккумулятора MacBook?",
                         "Does the app affect MacBook battery life?", "Колдонмо MacBook батареясынын сарпталышына таасир этеби?"),
            answer: tr("Нет. В отличие от VPN-приложений, постоянно нагружающих процессор шифрованием трафика, блокировщик работает на системном резолвере и сетевых правилах macOS. Нагрузка на процессор Apple Silicon минимальна.",
                       "No. Unlike VPN clients that constantly encrypt traffic, the blocker relies on the system resolver and macOS network rules. CPU usage on Apple Silicon is negligible.", "Жок. Трафикти шифрлөө менен процессорду дайыма жүктөгөн VPN-колдонмолордон айырмаланып, бөгөттөгүч системалык резолвердин жана macOS тармак эрежелеринин негизинде иштейт. Apple Silicon процессоруна жүк өтө аз."),
            icon: "battery.100.bolt",
            actionTitle: nil,
            actionTab: nil
        ),
        FAQItem(
            categoryKey: "security",
            category: tr("Безопасность", "Security", "Коопсуздук"),
            question: tr("Сохраняются ли мои персональные данные или история сайтов?",
                         "Is my browsing history or personal data stored anywhere?", "Жеке маалыматтарым же сайттардын тарыхы сакталабы?"),
            answer: tr("Нет. Приложение не ведёт логи посещений и не передаёт DNS-запросы третьим лицам. В локальном режиме dnsmasq вся обработка выполняется прямо внутри вашего Mac.",
                       "No. The app keeps no browsing logs and sends no query data to third parties. In local dnsmasq mode everything is processed on your Mac.", "Жок. Колдонмо кирүүлөрдүн логдорун жүргүзбөйт жана DNS-сурамдарды үчүнчү жактарга бербейт. Жергиликтүү dnsmasq режиминде бардык иштетүү түздөн-түз сиздин Mac'тин ичинде аткарылат."),
            icon: "eye.slash.fill",
            actionTitle: tr("Проверить статус", "Check the status", "Абалды текшерүү"),
            actionTab: .dashboard
        ),
        FAQItem(
            categoryKey: "rules",
            category: tr("Списки и Правила", "Rules & lists", "Тизмелер жана Эрежелер"),
            question: tr("Что делать, если нужный сайт ошибочно блокируется?",
                         "What if a site I need is blocked by mistake?", "Керектүү сайт жаңылыштык менен бөгөттөлсө эмне кылуу керек?"),
            answer: tr("Добавьте домен в «Белый список» в разделе «Списки и правила». Правило применится сразу, и сайт перестанет блокироваться независимо от используемого списка.",
                       "Add the domain to the whitelist under Rules & Lists. The rule takes effect immediately and the site stops being blocked regardless of which blocklist flagged it.", "Доменди «Тизмелер жана эрежелер» бөлүмүндөгү «Ак тизмеге» кошуңуз. Эреже дароо колдонулат жана сайт кайсы тизме колдонулганына карабастан бөгөттөлбөй калат."),
            icon: "checklist",
            actionTitle: tr("Открыть Белый список", "Open the whitelist", "Ак тизмени ачуу"),
            actionTab: .rules
        ),
        FAQItem(
            categoryKey: "vpn",
            category: tr("VPN и Туннели", "VPN & tunnels", "VPN жана туннелдер"),
            question: tr("Как подключить собственный V2Ray, Shadowsocks, Sing-box или Clash?",
                         "How do I connect my own V2Ray, Shadowsocks, sing-box or Clash?", "Өзүмдүн V2Ray, Shadowsocks, Sing-box же Clash клиентимди кантип туташтырам?"),
            answer: tr("Если на вашем Mac запущен клиент V2Ray, Sing-box, Xray или Clash, укажите его локальный порт (например, 10808 для SOCKS5 или 7890 для Clash) во вкладке «VPN и Прокси» и нажмите «Применить SOCKS5». Приложение настроит системные сетевые адаптеры macOS.",
                       "If a V2Ray, sing-box, Xray or Clash client is already running on your Mac, enter its local port (10808 for SOCKS5 or 7890 for Clash, typically) on the VPN & Proxy tab and press Apply SOCKS5. The app then configures the macOS network services.", "Эгер Mac'иңизде V2Ray, Sing-box, Xray же Clash клиенти иштеп жатса, анын жергиликтүү портун (мисалы, SOCKS5 үчүн 10808 же Clash үчүн 7890) «VPN жана Прокси» өтмөгүндө көрсөтүп, «SOCKS5 колдонуу» баскычын басыңыз. Колдонмо macOS системалык тармак адаптерлерин өзү жөндөйт."),
            icon: "arrow.triangle.2.circlepath.circle.fill",
            actionTitle: tr("Настроить порт прокси", "Configure the proxy port", "Прокси портун жөндөө"),
            actionTab: .vpn
        ),

        // ── Вопросы, которые порождает само приложение. Без них раздел
        // отвечал на общие темы, но молчал ровно там, где человек упирается
        // в конкретный экран и не понимает, что происходит.

        FAQItem(
            categoryKey: "troubleshooting",
            category: tr("Устранение неполадок", "Troubleshooting", "Көйгөйлөрдү оңдоо"),
            question: tr("Написано «защита настроена, но не действует» — что это значит?",
                         "It says “configured but not in effect” — what does that mean?", "«Коргоо жөндөлгөн, бирок иштебейт» деп жазылып турат — бул эмнени билдирет?"),
            answer: tr("Профиль применён верно, но система спрашивает не тот резолвер. macOS выбирает его по приоритету, и программа, которая прописалась через API сетевых расширений — VPN-клиент, Tailscale, корпоративный профиль, — оказывается выше нас. Пока это так, фильтрация не применяется ни к чему.\n\nНа «Обзоре» указано, кто именно перехватил и на какой адрес уходят запросы. Дальше либо отключить этот источник, либо настроить фильтрацию в нём, либо — если это Tailscale — развести зоны одной кнопкой.",
                       "The profile is applied correctly, but the system is asking a different resolver. macOS picks by priority, and anything registered through the network extension API — a VPN client, Tailscale, a corporate profile — outranks us. While that holds, nothing is filtered at all.\n\nThe overview names the culprit and the address queries actually go to. From there: disable that source, configure filtering inside it, or — if it is Tailscale — split the zones with one button.", "Профиль туура колдонулган, бирок система башка резолверден сурап жатат. macOS аны артыкчылык боюнча тандайт, жана тармактык кеңейтүүлөрдүн API аркылуу катталган программа — VPN-клиент, Tailscale, корпоративдик профиль — бизден жогору турат. Ушундай болуп турганда чыпкалоо эч нерсеге колдонулбайт.\n\n«Серепте» ким кармап алганы жана сурамдар кайсы дарекке кетип жатканы көрсөтүлгөн. Андан ары же ошол булакты өчүрүү, же анын ичинде чыпкалоону жөндөө, же — эгер бул Tailscale болсо — зоналарды бир баскыч менен бөлүү керек."),
            icon: "exclamationmark.triangle.fill",
            actionTitle: tr("Проверить сейчас", "Check now", "Азыр текшерүү"),
            actionTab: .diagnostics
        ),
        FAQItem(
            categoryKey: "vpn",
            category: tr("VPN и Туннели", "VPN & tunnels", "VPN жана туннелдер"),
            question: tr("У меня Tailscale. Как совместить его с фильтром?",
                         "I use Tailscale. How do I combine it with the filter?", "Менде Tailscale бар. Аны чыпка менен кантип бирге колдонсо болот?"),
            answer: tr("Соперничать с ним бесполезно: он прописывается через API сетевых расширений и всегда выигрывает по приоритету. Вместо этого зоны разделяются — имена вашего tailnet уходят в Tailscale, все остальные запросы идут через фильтр.\n\nКнопка «Настроить» на «Обзоре» делает это сама: создаёт правило для зоны ts.net, отключает у Tailscale захват всего DNS, затем проверяет, что имена ваших машин по-прежнему резолвятся, и откатывается, если нет. Отменить можно в настройках, а при удалении приложения настройки Tailscale возвращаются сами.",
                       "Competing with it is pointless: it registers through the network extension API and always wins on priority. Split the zones instead — your tailnet names go to Tailscale, everything else goes through the filter.\n\nThe Fix it button on the overview does this for you: it adds a rule for the ts.net zone, stops Tailscale claiming all DNS, then checks that your machines still resolve and rolls back if they do not. It can be undone in settings, and removing the app restores Tailscale on its own.", "Аны менен атаандашуунун пайдасы жок: ал тармактык кеңейтүүлөрдүн API аркылуу катталат жана артыкчылык боюнча дайыма утат. Анын ордуна зоналар бөлүнөт — tailnet аттарыңыз Tailscale'ге кетет, калган бардык сурамдар чыпка аркылуу өтөт.\n\n«Серептеги» «Жөндөө» баскычы муну өзү жасайт: ts.net зонасы үчүн эреже түзөт, Tailscale'дин бардык DNSти кармап алуусун өчүрөт, андан кийин машиналарыңыздын аттары мурдагыдай эле резолвденип жатканын текшерет, андай болбосо, артка кайтарат. Муну жөндөөлөрдөн жокко чыгарса болот, ал эми колдонмо жок кылынганда Tailscale жөндөөлөрү өзү эле калыбына келет."),
            icon: "arrow.triangle.branch",
            actionTitle: tr("Открыть настройки", "Open settings", "Жөндөөлөрдү ачуу"),
            actionTab: .settings
        ),
        FAQItem(
            categoryKey: "troubleshooting",
            category: tr("Устранение неполадок", "Troubleshooting", "Көйгөйлөрдү оңдоо"),
            question: tr("Реклама исчезла везде, кроме браузера. Почему?",
                         "Ads are gone everywhere except in the browser. Why?", "Жарнама браузерден башка бардык жерде жоголду. Эмне үчүн?"),
            answer: tr("Скорее всего, браузер резолвит домены сам, по DNS-over-HTTPS. Такие запросы уходят зашифрованными на 443 порт и системного резолвера не видят вовсе — помешать этому снаружи нельзя.\n\nВ разделе «Диагностика» показано, что именно настроен делать каждый найденный браузер. Отключается там же, где включалось: в Chrome — «Настройки → Конфиденциальность → Использовать защищённый DNS», в Firefox — «Настройки → Приватность → Защита DNS через HTTPS».\n\nОтдельный случай: у Chrome режим «автоматически» безопасен — он повышает соединение до защищённого адреса того же провайдера, и фильтрация продолжает работать.",
                       "Most likely the browser resolves names itself over DNS-over-HTTPS. Those queries leave encrypted on port 443 and never reach the system resolver, and nothing outside the browser can intercept them.\n\nDiagnostics shows what each installed browser is configured to do. Turn it off where it was turned on: Chrome under Privacy and security → Use secure DNS, Firefox under Privacy → DNS over HTTPS.\n\nOne exception: Chrome's automatic mode is safe — it upgrades to the same provider's secure endpoint, so filtering keeps working.", "Кыязы, браузер домендерди DNS-over-HTTPS аркылуу өзү резолвдейт. Мындай сурамдар шифрленип 443 портуна кетет жана системалык резолверге такыр жетпейт — буга сырттан тоскоол болуу мүмкүн эмес.\n\n«Диагностика» бөлүмүндө табылган ар бир браузер эмне кылууга жөндөлгөнү көрсөтүлгөн. Кайсы жерден күйгүзүлсө, ошол жерден өчүрүлөт: Chrome'до — «Настройки → Конфиденциальность → Использовать защищённый DNS», Firefox'то — «Настройки → Приватность → Защита DNS через HTTPS».\n\nӨзгөчө учур: Chrome'догу «автоматтык» режим коопсуз — ал туташууну ошол эле провайдердин корголгон дарегине которот, жана чыпкалоо иштей берет."),
            icon: "globe.badge.chevron.backward",
            actionTitle: tr("Посмотреть браузеры", "Check the browsers", "Браузерлерди кароо"),
            actionTab: .diagnostics
        ),
        FAQItem(
            categoryKey: "security",
            category: tr("Безопасность", "Security", "Коопсуздук"),
            question: tr("Зачем приложение просит пароль администратора?",
                         "Why does the app ask for an administrator password?", "Колдонмо эмне үчүн администратордун сырсөзүн сурайт?"),
            answer: tr("Настройки DNS принадлежат системе, и менять их без прав администратора нельзя. Это единственное, для чего нужен пароль: переключить резолвер, сбросить кэш, запустить локальную службу.\n\nЧтобы не спрашивать каждый раз, можно один раз установить привилегированный помощник. Он кладёт копию движка в системный каталог, принадлежащую root, и разрешает запускать её без пароля — только вам и только её. Копия сверяется по контрольной сумме: если движок в приложении обновится, программа заметит расхождение и предложит переустановить помощника.\n\nУдалить его: в Терминале выполнить «sudo /usr/local/bin/dnsblock-engine --remove-helper». После этого приложение снова будет спрашивать пароль.",
                       "DNS settings belong to the system and cannot be changed without administrator rights. That is the only thing the password is for: switching the resolver, flushing the cache, starting the local service.\n\nTo avoid being asked every time, you can install the privileged helper once. It places a root-owned copy of the engine in a system directory and allows running just that one file without a password, for your account only. The copy is verified by checksum: if the engine in the app changes, the mismatch is noticed and a reinstall is offered.\n\nTo remove it, run “sudo /usr/local/bin/dnsblock-engine --remove-helper” in Terminal. The app then goes back to asking for the password.", "DNS жөндөөлөрү системага таандык жана аларды администратор укуктарысыз өзгөртүүгө болбойт. Сырсөз ушул үчүн гана керек: резолверди которуу, кэшти тазалоо, жергиликтүү кызматты ишке киргизүү.\n\nАр дайым сурабашы үчүн артыкчылыктуу жардамчыны бир жолу орнотсо болот. Ал кыймылдаткычтын root'ко таандык көчүрмөсүн системалык каталогго коёт жана аны сырсөзсүз ишке киргизүүгө уруксат берет — сизге гана жана ошол көчүрмөнү гана. Көчүрмө контролдук сумма боюнча текшерилет: эгер колдонмодогу кыймылдаткыч жаңыртылса, программа айырманы байкап, жардамчыны кайра орнотууну сунуштайт.\n\nАны жок кылуу үчүн Терминалда «sudo /usr/local/bin/dnsblock-engine --remove-helper» буйругун аткарыңыз. Андан кийин колдонмо кайрадан сырсөз сурай баштайт."),
            icon: "lock.shield.fill",
            actionTitle: tr("Открыть настройки", "Open settings", "Жөндөөлөрдү ачуу"),
            actionTab: .settings
        ),
        FAQItem(
            categoryKey: "basics",
            category: tr("Основы", "Basics", "Негиздер"),
            question: tr("Инспектор трафика помечен «ДЕМО». Где настоящие запросы?",
                         "The traffic inspector says “DEMO”. Where are the real queries?", "Трафик инспектору «ДЕМО» деп белгиленген. Чыныгы сурамдар кайда?"),
            answer: tr("Журнал запросов ведёт только резолвер, работающий на вашем Mac. Облачные профили — AdGuard, Cloudflare, Quad9 — обрабатывают запросы у себя и никакого журнала здесь не оставляют, поэтому показывать было бы нечего.\n\nПометка «ДЕМО» означает ровно это: поток сгенерирован для примера. Как только включится профиль «Локальный dnsmasq», инспектор переключится на настоящий журнал сам и метка сменится на «LIVE».",
                       "Only a resolver running on your Mac keeps a query log. Cloud profiles — AdGuard, Cloudflare, Quad9 — process queries on their side and leave no log here, so there would be nothing to show.\n\nThe DEMO badge means exactly that: the stream is generated as an illustration. As soon as the Local dnsmasq profile is active, the inspector switches to the real log by itself and the badge becomes LIVE.", "Сурамдар журналын сиздин Mac'те иштеген резолвер гана жүргүзөт. Булут профилдери — AdGuard, Cloudflare, Quad9 — сурамдарды өздөрүндө иштетет жана бул жерде эч кандай журнал калтырбайт, ошондуктан көрсөтө турган эч нерсе жок.\n\n«ДЕМО» белгиси так ушуну билдирет: агым мисал катары түзүлгөн. «Жергиликтүү dnsmasq» профили күйгүзүлөр замат инспектор өзү чыныгы журналга которулат жана белги «LIVE» болуп өзгөрөт."),
            icon: "dot.radiowaves.left.and.right",
            actionTitle: tr("Открыть профили", "Open profiles", "Профилдерди ачуу"),
            actionTab: .profiles
        ),
        FAQItem(
            categoryKey: "basics",
            category: tr("Основы", "Basics", "Негиздер"),
            question: tr("Чем облачный профиль отличается от локального?",
                         "What is the difference between a cloud and a local profile?", "Булут профили жергиликтүү профилден эмнеси менен айырмаланат?"),
            answer: tr("Облачный профиль просто указывает системе на чужой фильтрующий резолвер. Включается мгновенно, ничего ставить не нужно, но список правил не ваш, журнала запросов нет и сами запросы видит провайдер этого резолвера.\n\nЛокальный режим поднимает резолвер на вашей машине: база из сотен тысяч доменов лежит здесь, задержка близка к нулю, работают собственные списки, ведётся журнал запросов. Цена — нужен установленный dnsmasq, а значит Homebrew.\n\nПрактическое правило: для «просто чтобы не было рекламы» хватает облачного; локальный нужен тем, кто хочет видеть и решать сам.",
                       "A cloud profile simply points the system at someone else's filtering resolver. It works instantly and needs nothing installed, but the rule list is not yours, there is no query log, and that provider sees your queries.\n\nLocal mode runs a resolver on your machine: a database of hundreds of thousands of domains lives here, latency is near zero, your own lists apply and a query log is kept. The cost is that dnsmasq has to be installed, which means Homebrew.\n\nRule of thumb: cloud is enough to simply not see ads; local is for people who want to look and decide for themselves.", "Булут профили системага башка бирөөнүн чыпкалоочу резолверин гана көрсөтөт. Заматта күйөт, эч нерсе орнотуунун кереги жок, бирок эрежелер тизмеси сиздики эмес, сурамдар журналы жок жана сурамдардын өзүн ошол резолвердин провайдери көрөт.\n\nЖергиликтүү режим резолверди сиздин машинаңызда иштетет: жүздөгөн миң домендин базасы ушул жерде, кечигүү нөлгө жакын, өзүңүздүн тизмелериңиз иштейт, сурамдар журналы жүргүзүлөт. Анын баасы — орнотулган dnsmasq керек, демек Homebrew да.\n\nПрактикалык эреже: «жөн гана жарнама болбосун» десеңиз, булут профили жетиштүү; жергиликтүүсү өзү көрүп, өзү чечкиси келгендерге керек."),
            icon: "cpu",
            actionTitle: tr("Сравнить профили", "Compare profiles", "Профилдерди салыштыруу"),
            actionTab: .profiles
        ),
        FAQItem(
            categoryKey: "troubleshooting",
            category: tr("Устранение неполадок", "Troubleshooting", "Көйгөйлөрдү оңдоо"),
            question: tr("Как удалить всё и вернуть сеть в исходное состояние?",
                         "How do I remove everything and restore the original network setup?", "Баарын кантип жок кылып, тармакты баштапкы абалына кайтарам?"),
            answer: tr("В разделе «Инструменты» есть «Удалить всё». Оно останавливает локальную службу, снимает автозапуск обновления списков, удаляет привилегированный помощник и его root-копию, возвращает Tailscale управление DNS, если зоны были разведены, и восстанавливает DNS на всех сетевых интерфейсах из резервной копии, снятой при первом включении.\n\nПосле этого приложение можно просто перетащить в Корзину: в системе от него ничего не остаётся.",
                       "Tools has a Remove everything action. It stops the local service, unloads the scheduled list update, deletes the privileged helper and its root copy, hands DNS back to Tailscale if the zones were split, and restores DNS on every network interface from the backup taken when it was first enabled.\n\nAfter that the app can simply be dragged to the Trash: nothing of it is left in the system.", "«Куралдар» бөлүмүндө «Баарын жок кылуу» бар. Ал жергиликтүү кызматты токтотот, тизмелерди жаңыртуунун автоматтык ишке киришин алып салат, артыкчылыктуу жардамчыны жана анын root-көчүрмөсүн жок кылат, зоналар бөлүнгөн болсо, DNS башкарууну Tailscale'ге кайтарат жана биринчи жолу күйгүзүлгөндө алынган камдык көчүрмөдөн бардык тармак интерфейстеринде DNSти калыбына келтирет.\n\nАндан кийин колдонмону жөн гана Корзинага сүйрөп салса болот: системада андан эч нерсе калбайт."),
            icon: "trash.circle.fill",
            actionTitle: tr("Открыть инструменты", "Open tools", "Куралдарды ачуу"),
            actionTab: .tools
        )
        ]
    }
}

// MARK: - Latency History Sparkline Point
struct LatencyPoint: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let latencyMs: Int
}

// MARK: - Command Palette Item
struct CommandPaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let icon: String
    let iconColor: Color
    var countryCode: String? = nil
    let shortcut: String?
    let action: () -> Void
}

// MARK: - Full Network Speedtest Model
struct NetworkSpeedtestResult: Codable, Identifiable {
    var id: String = UUID().uuidString
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Int
    let jitterMs: Double
    let packetLossPct: Double
    let serverName: String
    let serverCountry: String
    let ispName: String
    let qualityGrade: String
    var timestamp: Date = Date()
    /// Замер не состоялся. Движок сообщает об этом вместо того, чтобы
    /// подставить правдоподобные числа, как делал раньше.
    var failed: Bool? = nil
    var reason: String? = nil

    var didFail: Bool { failed ?? false }
    /// Отдачу измерить не всегда удаётся; -1 значит «не измерено».
    var hasUpload: Bool { uploadMbps >= 0 }

    enum CodingKeys: String, CodingKey {
        case downloadMbps, uploadMbps, pingMs, jitterMs, packetLossPct
        case serverName, serverCountry, ispName, qualityGrade, failed, reason
    }
}

// MARK: - DNS Profile
struct DNSProfile: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let servers: String
    let icon: String
    let badge: String
    let color: Color
    let isLocal: Bool
    let description: String
    let features: [String]
    
    private static let profileLock = NSLock()
    private static var profileCache: (lang: AppLanguage, items: [DNSProfile])?

    /// Профили, собранные один раз на язык.
    ///
    /// Идентификаторы здесь строковые, поэтому тождество не ломалось, но
    /// пересборка стоила 64 вызова `tr()` и восемь объектов `Color` на каждое
    /// обращение — а обращаются к списку из тела `currentProfile`, из боковой
    /// панели и из попапа строки состояния, то есть на каждый кадр.
    static var allProfiles: [DNSProfile] {
        profileLock.lock(); defer { profileLock.unlock() }
        let lang = LocalizationManager.shared.currentLanguage
        if let cached = profileCache, cached.lang == lang { return cached.items }
        let items = buildProfiles()
        profileCache = (lang, items)
        return items
    }

    private static func buildProfiles() -> [DNSProfile] {
        [
        DNSProfile(
            id: "adguard",
            title: "AdGuard DNS",
            subtitle: tr("Облачный блокировщик", "Cloud ad blocker", "Булут бөгөттөгүчү"),
            servers: "94.140.14.14, 94.140.15.15",
            icon: "shield.checkerboard",
            badge: tr("Рекомендуемый", "Recommended", "Сунушталат"),
            color: Color(red: 0.18, green: 0.78, blue: 0.44),
            isLocal: false,
            description: tr("Блокирует рекламу, баннеры, счетчики аналитики и фишинговые сайты без необходимости установки локальных служб.",
                            "Blocks ads, banners, analytics counters and phishing sites without installing anything locally.", "Жергиликтүү кызматтарды орнотпостон жарнаманы, баннерлерди, аналитика эсептегичтерин жана фишинг сайттарын бөгөттөйт."),
            features: [
                tr("Блокировка баннеров и всплывающих окон", "Blocks banners and pop-ups", "Баннерлерди жана калкып чыкма терезелерди бөгөттөө"),
                tr("Защита от веб-трекеров", "Protection from web trackers", "Веб-трекерлерден коргоо"),
                tr("Защита от фишинга", "Phishing protection", "Фишингден коргоо"),
                tr("Мгновенное подключение", "Works instantly", "Заматта туташуу")
            ]
        ),
        DNSProfile(
            id: "local_dnsmasq",
            title: tr("Локальный dnsmasq", "Local dnsmasq", "Жергиликтүү dnsmasq"),
            subtitle: tr("Собственный DNS на Mac", "Your own resolver on this Mac", "Mac'те өзүңүздүн DNS"),
            servers: "127.0.0.1",
            icon: "cpu",
            badge: tr("Макс. мощь", "Most powerful", "Макс. күч"),
            color: Color(red: 0.35, green: 0.52, blue: 0.95),
            isLocal: true,
            description: tr("Фильтрация прямо на вашем Mac с базой из 340 000+ доменов (OISD, StevenBlack, AdAway). Минимальный пинг (0 мс) и полная приватность.",
                            "Filtering runs on your Mac against 340,000+ domains (OISD, StevenBlack, AdAway). Near-zero latency and full privacy.", "Чыпкалоо түздөн-түз сиздин Mac'те, 340 000+ домендик база менен (OISD, StevenBlack, AdAway). Минималдуу пинг (0 мс) жана толук купуялык."),
            features: [
                tr("340 000+ правил блокировки", "340,000+ blocking rules", "340 000+ бөгөттөө эрежеси"),
                tr("Минимальная задержка (0 мс)", "Minimal latency (0 ms)", "Минималдуу кечигүү (0 мс)"),
                tr("Поддержка своих списков и правил", "Supports your own lists and rules", "Өз тизмелериңизди жана эрежелериңизди колдоо"),
                tr("Абсолютная приватность", "Complete privacy", "Абсолюттук купуялык")
            ]
        ),
        DNSProfile(
            id: "adguard_family",
            title: tr("AdGuard Семейный", "AdGuard Family", "AdGuard Үй-бүлөлүк"),
            subtitle: tr("Антиреклама + 18+ защита", "Ad blocking plus adult filtering", "Антижарнама + 18+ коргоо"),
            servers: "94.140.14.15, 94.140.15.16",
            icon: "person.2.circle.fill",
            badge: tr("Семейный", "Family", "Үй-бүлөлүк"),
            color: Color(red: 0.96, green: 0.58, blue: 0.18),
            isLocal: false,
            description: tr("Блокирует рекламу и трекеры, а также включает безопасный поиск и блокирует доступ к сайтам для взрослых.",
                            "Blocks ads and trackers, enforces safe search and blocks adult websites.", "Жарнаманы жана трекерлерди бөгөттөйт, ошондой эле коопсуз издөөнү күйгүзөт жана чоңдор үчүн сайттарга кирүүнү бөгөттөйт."),
            features: [
                tr("Блокировка рекламы", "Ad blocking", "Жарнаманы бөгөттөө"),
                tr("Защита от сайтов 18+", "Adult site filtering", "18+ сайттардан коргоо"),
                tr("Принудительный безопасный поиск", "Enforced safe search", "Милдеттүү коопсуз издөө"),
                tr("Защита детей в сети", "Child protection online", "Тармакта балдарды коргоо")
            ]
        ),
        DNSProfile(
            id: "cloudflare_security",
            title: "Cloudflare Security",
            subtitle: tr("1.1.1.2 — Защита от угроз", "1.1.1.2 — threat protection", "1.1.1.2 — Коркунучтардан коргоо"),
            servers: "1.1.1.2, 1.0.0.2",
            icon: "bolt.shield.fill",
            badge: tr("Быстрый", "Fastest", "Ылдам"),
            color: Color(red: 0.95, green: 0.45, blue: 0.10),
            isLocal: false,
            description: tr("Сверхбыстрый DNS от Cloudflare со встроенной блокировкой вредоносных программ, ботнетов и фишинга.",
                            "Very fast Cloudflare resolver with built-in malware, botnet and phishing blocking.", "Зыяндуу программаларды, ботнеттерди жана фишингди бөгөттөөсү камтылган Cloudflare'дин өтө ылдам DNSи."),
            features: [
                tr("Сверхнизкая задержка", "Very low latency", "Өтө төмөн кечигүү"),
                tr("Блокировка вредоносного ПО", "Malware blocking", "Зыяндуу программаларды бөгөттөө"),
                tr("Защита от фишинга", "Phishing protection", "Фишингден коргоо"),
                tr("Глобальная сеть Cloudflare Anycast", "Global Cloudflare anycast network", "Cloudflare Anycast глобалдык тармагы")
            ]
        ),
        DNSProfile(
            id: "cloudflare_family",
            title: "Cloudflare Family",
            subtitle: tr("1.1.1.3 — Угрозы + 18+", "1.1.1.3 — threats and adult content", "1.1.1.3 — Коркунучтар + 18+"),
            servers: "1.1.1.3, 1.0.0.3",
            icon: "figure.2.and.child.holdinghands",
            badge: tr("Безопасность", "Safety", "Коопсуздук"),
            color: Color(red: 0.92, green: 0.35, blue: 0.30),
            isLocal: false,
            description: tr("DNS от Cloudflare с автоматической блокировкой вредоносных доменов и контента для взрослых.",
                            "Cloudflare resolver that automatically blocks malicious domains and adult content.", "Зыяндуу домендерди жана чоңдор үчүн контентти автоматтык түрдө бөгөттөгөн Cloudflare'дин DNSи."),
            features: [
                tr("Блокировка вирусов и малвари", "Blocks malware", "Вирустарды жана зыяндуу программаларды бөгөттөө"),
                tr("Родительский контроль 18+", "Parental controls", "18+ ата-эне көзөмөлү"),
                tr("Высокая скорость", "High speed", "Жогорку ылдамдык"),
                tr("Конфиденциальность", "Privacy", "Купуялык")
            ]
        ),
        DNSProfile(
            id: "quad9",
            title: "Quad9 Security",
            subtitle: tr("9.9.9.9 — Швейцарская защита", "9.9.9.9 — Swiss protection", "9.9.9.9 — Швейцариялык коргоо"),
            servers: "9.9.9.9, 149.112.112.112",
            icon: "lock.shield.fill",
            badge: tr("Приватный", "Private", "Купуя"),
            color: Color(red: 0.55, green: 0.35, blue: 0.90),
            isLocal: false,
            description: tr("Некоммерческий сервис Quad9 (Швейцария), блокирующий фишинг и шпионские домены на основе данных 20+ компаний кибербезопасности.",
                            "Non-profit Swiss resolver blocking phishing and spyware domains using feeds from 20+ security vendors.", "20дан ашык киберкоопсуздук компаниясынын маалыматтарынын негизинде фишингди жана тыңчы домендерди бөгөттөгөн Quad9 коммерциялык эмес кызматы (Швейцария)."),
            features: [
                tr("Швейцарская юрисдикция", "Swiss jurisdiction", "Швейцариянын юрисдикциясы"),
                tr("Защита от киберугроз", "Cyber threat protection", "Киберкоркунучтардан коргоо"),
                tr("Не сохраняет IP пользователей", "Does not log user IP addresses", "Колдонуучулардын IP даректерин сактабайт"),
                tr("DNSSEC валидация", "DNSSEC validation", "DNSSEC текшерүүсү")
            ]
        ),
        DNSProfile(
            id: "mullvad",
            title: "Mullvad AdBlock",
            subtitle: tr("194.242.2.3 — Антитрекер", "194.242.2.3 — anti-tracking", "194.242.2.3 — Антитрекер"),
            servers: "194.242.2.3",
            icon: "eye.slash.fill",
            badge: tr("Анонимный", "Anonymous", "Анонимдүү"),
            color: Color(red: 0.12, green: 0.72, blue: 0.72),
            isLocal: false,
            description: tr("Конфиденциальный DNS-сервер от провайдера Mullvad VPN с защитой от рекламы, трекеров и вредоносных адресов.",
                            "Privacy-focused resolver from Mullvad VPN with ad, tracker and malware filtering.", "Mullvad VPN провайдеринин жарнамадан, трекерлерден жана зыяндуу даректерден коргоочу купуя DNS-сервери."),
            features: [
                tr("Блокировка трекеров", "Tracker blocking", "Трекерлерди бөгөттөө"),
                tr("Блокировка рекламы", "Ad blocking", "Жарнаманы бөгөттөө"),
                tr("Без логов активности", "No activity logs", "Аракеттердин логдору жок"),
                tr("Высокая надежность", "High reliability", "Жогорку ишенимдүүлүк")
            ]
        ),
        DNSProfile(
            id: "custom",
            title: tr("Пользовательский DNS", "Custom DNS", "Колдонуучунун DNSи"),
            subtitle: tr("Свои DNS серверы", "Your own DNS servers", "Өз DNS серверлериңиз"),
            servers: tr("По выбору", "Your choice", "Тандоо боюнча"),
            icon: "slider.horizontal.3",
            badge: tr("Настраиваемый", "Configurable", "Жөндөлмө"),
            color: Color(red: 0.65, green: 0.40, blue: 0.85),
            isLocal: false,
            description: tr("Позволяет задать произвольные DNS-серверы (например, корпоративные, AdGuard Home, Pi-hole или NextDNS).",
                            "Lets you point at any resolver — corporate DNS, AdGuard Home, Pi-hole or NextDNS.", "Каалаган DNS-серверлерди көрсөтүүгө мүмкүндүк берет (мисалы, корпоративдик, AdGuard Home, Pi-hole же NextDNS)."),
            features: [
                tr("Любые IPv4/IPv6 адреса", "Any IPv4 / IPv6 address", "Каалаган IPv4/IPv6 даректер"),
                tr("Поддержка кастомных портов", "Custom ports supported", "Өз портторуңузду колдоо"),
                tr("Гибкая настройка", "Flexible configuration", "Ийкемдүү жөндөө")
            ]
        )
        ]
    }
}

// MARK: - Браузерный DoH
/// Состояние DNS-over-HTTPS в установленных браузерах.
///
/// Браузер со своим DoH не виден никакому системному резолверу: запросы идут
/// по HTTPS на 443 порт. Помешать этому изнутри приложения нельзя, но можно
/// не делать вид, что фильтр их покрывает.
struct BrowserDoHInfo: Codable, Identifiable {
    var id: String { browser }
    let browser: String
    let installed: Bool
    /// off · automatic · secure — для Chromium; off · doh-first · doh-only — для Firefox.
    let mode: String
    let endpoint: String
    /// Запросы уходят мимо системного резолвера.
    let bypasses: Bool

    var modeTitle: String {
        switch mode {
        case "off", "unset":  return tr("выключен", "off", "өчүк")
        case "automatic":     return tr("автоматически", "automatic", "автоматтык")
        case "secure":        return tr("свой адрес", "custom endpoint", "өз дарегиңиз")
        case "doh-first":     return tr("DoH с откатом", "DoH with fallback", "DoH, артка кайтуу менен")
        case "doh-only":      return tr("только DoH", "DoH only", "DoH гана")
        default:              return mode
        }
    }
}

// MARK: - Tailscale
/// Состояние совместной работы с Tailscale.
///
/// Соперничать с ним за системный резолвер бесполезно — он прописывается через
/// API сетевых расширений и всегда выигрывает по приоритету. Вместо этого
/// зоны разделяются: имена tailnet идут в Tailscale, остальное фильтруется.
struct TailscaleInfo: Codable {
    let installed: Bool
    let running: Bool
    let suffix: String
    let selfName: String
    let acceptDNS: Bool
    let splitEnabled: Bool

    /// Разделение зон можно предложить: Tailscale работает и ещё не настроен.
    var canEnableSplit: Bool { installed && running && !splitEnabled }
}

// MARK: - IP Geolocation Info
struct IPInfo: Codable {
    let ip: String
    let country: String
    let city: String
    let org: String
}

// MARK: - VPN Status Response
struct VPNStatusResponse: Codable {
    let vpnActive: Bool?
    let socksEnabled: Bool?
    let socksServer: String?
    let socksPort: String?
    let httpEnabled: Bool?
    let httpServer: String?
    let httpPort: String?
}

// MARK: - Network Service Info
struct NetworkServiceInfo: Identifiable, Codable, Hashable {
    var id: String { service }
    let service: String
    let servers: String
}

// MARK: - Engine Status
struct EngineStatusResponse: Codable {
    let version: String?
    let mode: String?
    let profile: String?
    let running: Bool?
    let domains: Int?
    let updated: String?
    let blocked: Bool?
    let probe: String?
    let pingMs: Int?
    let whitelistCount: Int?
    let blacklistCount: Int?
    /// Резолвер, который система реально опрашивает (resolver #1 из scutil).
    let effectiveResolver: String?
    let effectiveInterface: String?
    /// Настроенный нами DNS перебит другим резолвером — фильтрация не работает.
    let dnsOverridden: Bool?
    /// Включена блокировка стороннего DNS-over-HTTPS.
    let dohBlocking: Bool?
    let overrideSource: String?
    let services: [NetworkServiceInfo]?
}

// MARK: - Diagnostic Item
struct DiagnosticItem: Identifiable, Codable {
    var id: String { domain }
    let domain: String
    let category: String
    /// Устойчивый ключ категории для перевода подписи в интерфейсе.
    let categoryKey: String?
    let blocked: Bool
    let ip: String
    let isControl: Bool
    /// Проверку не удалось выполнить (нет сети, таймаут).
    /// Отличать это от блокировки обязательно: иначе оборванный интернет
    /// выглядит как стопроцентно работающий фильтр.
    let failed: Bool?

    var didFail: Bool { failed ?? false }

    /// Группа для фильтра на вкладке «Диагностика».
    ///
    /// Фильтр сравнивал переведённую подпись категории с подписью кнопки
    /// («Реклама» против «Google Ads / Маркетинг»), поэтому не совпадал
    /// никогда — списки «Реклама», «Аналитика», «Трекеры» и «Телеметрия»
    /// всегда оказывались пустыми, на любом языке.
    var group: String {
        switch categoryKey ?? "" {
        case "google_ads", "google_adsense", "yandex_direct",
             "pubmatic", "criteo", "google_adservice":   return "ads"
        case "yandex_metrica", "tiktok_analytics":       return "analytics"
        case "facebook_pixel", "comscore":               return "trackers"
        case "microsoft_telemetry":                      return "telemetry"
        default:                                         return "other"
        }
    }

    /// Подпись категории на языке интерфейса.
    var localizedCategory: String {
        guard let key = categoryKey,
              let label = DiagnosticItem.categoryLabels[key] else { return category }
        return tr(label.0, label.1, label.2)
    }

    private static let categoryLabels: [String: (String, String, String)] = [
        "google_ads":          ("Google Ads / Маркетинг", "Google Ads / Marketing", "Google Ads / Маркетинг"),
        "google_adsense":      ("Google AdSense", "Google AdSense", "Google AdSense"),
        "yandex_direct":       ("Яндекс Директ / РСЯ", "Yandex Direct / Ad Network", "Яндекс Директ / РСЯ"),
        "yandex_metrica":      ("Яндекс Метрика", "Yandex Metrica", "Яндекс Метрика"),
        "pubmatic":            ("Баннерная сеть PubMatic", "PubMatic ad exchange", "PubMatic баннер тармагы"),
        "facebook_pixel":      ("Facebook Pixel / Трекер", "Facebook Pixel / tracker", "Facebook Pixel / Трекер"),
        "tiktok_analytics":    ("TikTok Аналитика", "TikTok analytics", "TikTok аналитикасы"),
        "microsoft_telemetry": ("Телеметрия Microsoft", "Microsoft telemetry", "Microsoft телеметриясы"),
        "comscore":            ("Comscore Трекинг", "Comscore tracking", "Comscore трекинги"),
        "criteo":              ("Criteo Ретаргетинг", "Criteo retargeting", "Criteo ретаргетинги"),
        "google_adservice":    ("Google Сервис рекламы", "Google ad service", "Google жарнама кызматы"),
        "control_site":        ("Контрольный обычный сайт", "Control site (should resolve)", "Текшерүү үчүн кадимки сайт")
    ]
}

// MARK: - Speed Benchmark Item
struct SpeedTestItem: Identifiable, Codable {
    let id: String
    let name: String
    let server: String
    let latencyMs: Int
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let isError: Bool
}

// MARK: - Query Inspector Models
enum QueryStatus: String, CaseIterable, Codable {
    case blocked = "blocked"
    case allowed = "allowed"
    case cached = "cached"
    
    var title: String {
        switch self {
        case .blocked: return tr("Заблокировано", "Blocked", "Бөгөттөлдү")
        case .allowed: return tr("Разрешено", "Allowed", "Уруксат берилди")
        case .cached:  return tr("Из кэша", "Cached", "Кэштен")
        }
    }
}

enum ThreatCategory: String, CaseIterable, Codable {
    case ad = "ad"
    case tracker = "tracker"
    case telemetry = "telemetry"
    case malware = "malware"
    case safe = "safe"
    
    var title: String {
        switch self {
        case .ad:        return tr("Реклама", "Ad", "Жарнама")
        case .tracker:   return tr("Трекер", "Tracker", "Трекер")
        case .telemetry: return tr("Телеметрия", "Telemetry", "Телеметрия")
        case .malware:   return tr("Фишинг/Угроза", "Phishing / threat", "Фишинг/Коркунуч")
        case .safe:      return tr("Безопасно", "Safe", "Коопсуз")
        }
    }
    
    var color: Color {
        switch self {
        case .ad: return Theme.statusRed
        case .tracker: return Theme.statusOrange
        case .telemetry: return Theme.statusPurple
        case .malware: return Color(red: 0.9, green: 0.1, blue: 0.3)
        case .safe: return Theme.statusGreen
        }
    }
}

struct DNSQueryLogItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    let domain: String
    let clientIp: String
    let queryType: String
    let status: QueryStatus
    let category: ThreatCategory
    let latencyMs: Int
    let timestamp: Date
    
    var isBlocked: Bool {
        return status == .blocked
    }
}

enum QueryFilterTab: String, CaseIterable, Identifiable {
    case all = "all"
    case blocked = "blocked"
    case allowed = "allowed"
    case ads = "ads"
    case trackers = "trackers"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all:      return tr("Все запросы", "All queries", "Бардык сурамдар")
        case .blocked:  return tr("Заблокировано", "Blocked", "Бөгөттөлдү")
        case .allowed:  return tr("Разрешено", "Allowed", "Уруксат берилди")
        case .ads:      return tr("Реклама", "Ads", "Жарнама")
        case .trackers: return tr("Трекеры", "Trackers", "Трекерлер")
        }
    }
}

// MARK: - Analytics & Savings Snapshot
struct TopTrackerItem: Identifiable, Codable {
    var id: String { domain }
    let domain: String
    let count: Int
    let category: String
}

struct AnalyticsStats: Codable {
    var totalQueries: Int = 0
    var blockedQueries: Int = 0
    var dataSavedMB: Double = 0.0
    var timeSavedSec: Double = 0.0
    var topTrackers: [TopTrackerItem] = []
    
    var blockRatioPct: Double {
        guard totalQueries > 0 else { return 0.0 }
        return Double(blockedQueries) / Double(totalQueries) * 100.0
    }
}

// MARK: - Pause Duration Presets
enum PauseDuration: Int, CaseIterable, Identifiable {
    case min5 = 300
    case min15 = 900
    case min30 = 1800
    case hour1 = 3600
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .min5:  return tr("5 мин", "5 min", "5 мүн")
        case .min15: return tr("15 мин", "15 min", "15 мүн")
        case .min30: return tr("30 мин", "30 min", "30 мүн")
        case .hour1: return tr("1 час", "1 hour", "1 саат")
        }
    }
}


// MARK: - Встроенное VPN-ядро
/// Ответ `engine.sh --vpn-core-status-json`. Все поля необязательные: старый
/// движок в бандле не должен ронять разбор в новом приложении.
struct VPNCoreStatus: Codable, Equatable {
    var coreInstalled: Bool? = false
    var coreVersion: String? = ""
    var running: Bool? = false
    var listening: Bool? = false
    var port: Int? = 10808
    var subscriptionHost: String? = ""
    var profileAgeSec: Int? = -1
    var nodes: [String]? = []
    var activeNode: String? = ""
    var activeDelayMs: Int? = -1
    var proxyOrphaned: Bool? = false
    var dnsMode: String? = "tunnel"

    var isInstalled: Bool { coreInstalled ?? false }
    var isUp: Bool { (running ?? false) && (listening ?? false) }
    var hasSubscription: Bool { !(subscriptionHost ?? "").isEmpty }
    var hasProfile: Bool { (profileAgeSec ?? -1) >= 0 }
}
