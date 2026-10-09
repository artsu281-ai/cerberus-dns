import Foundation
import AppKit

// Проверки чистой логики — тех мест, где нет побочных эффектов, но есть
// правила, которые легко сломать незаметной правкой.

var failures = 0
var checks = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    checks += 1
    if condition() {
        print("  ✔ \(name)")
    } else {
        print("  ✘ \(name)")
        failures += 1
    }
}

func group(_ title: String) { print("\n\(title)") }

// ─────────────────────────────────────────── DomainValidator

group("DomainValidator — нормализация")
check("схема отбрасывается",      DomainValidator.normalize("https://example.com") == "example.com")
check("путь отбрасывается",       DomainValidator.normalize("http://example.com/ads?x=1") == "example.com")
check("порт отбрасывается",       DomainValidator.normalize("example.com:8080") == "example.com")
check("регистр приводится",       DomainValidator.normalize("EXAMPLE.COM") == "example.com")
check("точки по краям срезаются", DomainValidator.normalize(".example.com.") == "example.com")
check("пробелы срезаются",        DomainValidator.normalize("  example.com  ") == "example.com")
check("логин отбрасывается",      DomainValidator.normalize("user@example.com") == "example.com")

group("DomainValidator — валидация")
check("обычный домен",            DomainValidator.isValid("example.com"))
check("многоуровневый",           DomainValidator.isValid("a.b.example.co.uk"))
check("дефис внутри метки",       DomainValidator.isValid("ad-service.example.com"))
check("без точки отвергается",    !DomainValidator.isValid("localhost"))
check("пустая метка отвергается", !DomainValidator.isValid("a..b.com"))
check("дефис в начале метки",     !DomainValidator.isValid("-bad.com"))
check("дефис в конце метки",      !DomainValidator.isValid("bad-.com"))
check("недопустимые символы",     !DomainValidator.isValid("exa mple.com"))
check("пусто отвергается",        !DomainValidator.isValid(""))
check("метка длиннее 63",         !DomainValidator.isValid(String(repeating: "a", count: 64) + ".com"))

group("DomainValidator — sanitized")
check("грязный ввод чистится",    DomainValidator.sanitized("HTTPS://Example.COM/path") == "example.com")
check("мусор отвергается",        DomainValidator.sanitized("не домен") == nil)
check("голый хост отвергается",   DomainValidator.sanitized("localhost") == nil)

group("DomainValidator — isValidIP")
check("IPv4 Cloudflare",          DomainValidator.isValidIP("1.1.1.1"))
check("IPv4 AdGuard",             DomainValidator.isValidIP("94.140.14.14"))
check("IPv4 локальный хост",      DomainValidator.isValidIP("127.0.0.1"))
check("IPv6 Cloudflare",          DomainValidator.isValidIP("2606:4700:4700::1111"))
check("IPv6 loopback",            DomainValidator.isValidIP("::1"))
check("октеты вне диапазона",     !DomainValidator.isValidIP("999.999.999.999"))
check("неполный IP",              !DomainValidator.isValidIP("1.1.1"))
check("домен вместо IP",          !DomainValidator.isValidIP("example.com"))
check("пустая строка",            !DomainValidator.isValidIP(""))
check("IP с пробелами",           DomainValidator.isValidIP("  1.1.1.1  "))

// ─────────────────────────────────────────── VPNNode

group("VPNNode — снисходительный декодер")
let minimal = #"{"id":"n1"}"#.data(using: .utf8)!
if let node = try? JSONDecoder().decode(VPNNode.self, from: minimal) {
    // Ровно этот случай ронял разбор всего списка узлов: синтезированный
    // init(from:) требовал ключ isCustom, которого движок не присылает.
    check("узел без необязательных полей разбирается", true)
    check("latencyMs по умолчанию -1", node.latencyMs == -1)
    check("isCustom по умолчанию false", node.isCustom == false)
    check("имя подставляется из id", node.name == "n1")
} else {
    check("узел без необязательных полей разбирается", false)
}

let engineShaped = #"""
{"id":"nl","name":"AdGuard DNS","country":"Нидерланды","flag":"🛡","host":"94.140.14.14",
 "port":"53","protocolType":"SOCKS5 / Anycast","isRecommended":true,"latencyMs":91,"isOnline":true}
"""#.data(using: .utf8)!
if let node = try? JSONDecoder().decode(VPNNode.self, from: engineShaped) {
    check("протокол нормализуется",  node.protocolType == "socks5")
    check("страна → код",            node.country == "NL")
    check("порт 53 значит DNS",      node.kind == .dns)
    check("бейдж честный",           node.kindBadge == "DNS")
} else {
    check("узел в формате движка разбирается", false)
}

group("VPNNode — нормализация протоколов")
check("VLESS",        VPNNode.normalizedProtocol("VLESS (REALITY)") == "vless")
check("Shadowsocks",  VPNNode.normalizedProtocol("Shadowsocks 2022") == "shadowsocks")
check("Hysteria",     VPNNode.normalizedProtocol("Hysteria 2 / TUIC") == "hysteria2")
check("DoH → dns",    VPNNode.normalizedProtocol("DoH / Tunnel") == "dns")
check("WARP → warp",  VPNNode.normalizedProtocol("WARP / Anycast") == "warp")
check("SOCKS раньше anycast", VPNNode.normalizedProtocol("SOCKS5 / Anycast") == "socks5")
check("пусто → socks5", VPNNode.normalizedProtocol("") == "socks5")

group("VPNNode — прокси на нестандартном порту остаётся прокси")
let proxy = VPNNode(id: "p", name: "Local", country: "RU", flag: "💻",
                    host: "127.0.0.1", port: "10808", protocolType: "socks5",
                    isRecommended: false, latencyMs: 5, isOnline: true)
check("порт 10808 значит прокси", proxy.kind == .proxy)
check("бейдж прокси", proxy.kindBadge == "SOCKS5")

// ─────────────────────────────────────────── DiagnosticItem

group("DiagnosticItem — группировка для фильтра")
func item(_ key: String) -> DiagnosticItem {
    let json = #"{"domain":"d","category":"c","categoryKey":"\#(key)","blocked":false,"ip":"1.2.3.4","isControl":false}"#
    return try! JSONDecoder().decode(DiagnosticItem.self, from: json.data(using: .utf8)!)
}
check("Google Ads → реклама",      item("google_ads").group == "ads")
check("Метрика → аналитика",       item("yandex_metrica").group == "analytics")
check("Facebook Pixel → трекеры",  item("facebook_pixel").group == "trackers")
check("Microsoft → телеметрия",    item("microsoft_telemetry").group == "telemetry")
check("контрольный сайт вне групп", item("control_site").group == "other")

group("DiagnosticItem — отсутствующие поля")
let legacy = #"{"domain":"d","category":"c","blocked":true,"ip":"0.0.0.0","isControl":false}"#
if let it = try? JSONDecoder().decode(DiagnosticItem.self, from: legacy.data(using: .utf8)!) {
    check("старый формат без categoryKey разбирается", true)
    check("didFail по умолчанию false", it.didFail == false)
} else {
    check("старый формат без categoryKey разбирается", false)
}

// ─────────────────────────────────────────── FAQ

group("FAQ — целостность")
let faqs = FAQItem.allFAQs
// Категории, которые предлагает фильтр в интерфейсе. Статья с ключом вне
// этого списка попадает только в «Все» и иначе недостижима.
let knownCategories: Set<String> = ["basics", "vpn", "security", "rules", "troubleshooting", "performance"]

check("статей достаточно", faqs.count >= 12)
check("нет пустых вопросов", faqs.allSatisfy { !$0.question.trimmingCharacters(in: .whitespaces).isEmpty })
check("нет пустых ответов",  faqs.allSatisfy { $0.answer.count > 80 })
check("все ключи категорий известны фильтру",
      faqs.allSatisfy { knownCategories.contains($0.categoryKey) })
// Ровно эта рассинхронизация и была заглушкой: подпись у кнопки есть,
// а вести ей некуда.
check("у каждой кнопки есть назначение",
      faqs.allSatisfy { ($0.actionTitle == nil) == ($0.actionTab == nil) })
check("вопросы не повторяются",
      Set(faqs.map { $0.question }).count == faqs.count)
check("покрыты темы, которые порождает само приложение",
      faqs.contains { $0.answer.contains("приоритет") } &&
      faqs.contains { $0.answer.lowercased().contains("tailscale") } &&
      faqs.contains { $0.answer.contains("DNS-over-HTTPS") })

group("Тождество списков — регрессия раскрытия FAQ")
// Пересборка списка на каждое обращение выдавала новые UUID: SwiftUI терял
// тождество строк, а раскрытая статья схлопывалась при первой перерисовке.
check("id статей стабильны между обращениями",
      FAQItem.allFAQs.map { $0.id } == FAQItem.allFAQs.map { $0.id })
check("id профилей стабильны между обращениями",
      DNSProfile.allProfiles.map { $0.id } == DNSProfile.allProfiles.map { $0.id })

do {
    // Раскрытие хранится по стабильному строковому id:
    var expanded = Set<String>()
    expanded.insert(FAQItem.allFAQs[2].id)
    check("раскрытая статья переживает перерисовку",
          expanded.contains(FAQItem.allFAQs[2].id))
}

do {
    // Запоминание не должно мешать переключению языка.
    let before = LocalizationManager.shared.currentLanguage
    LocalizationManager.shared.currentLanguage = .ru
    let ru = DNSProfile.allProfiles.first { $0.id == "local_dnsmasq" }?.title ?? ""
    LocalizationManager.shared.currentLanguage = .en
    let en = DNSProfile.allProfiles.first { $0.id == "local_dnsmasq" }?.title ?? ""
    LocalizationManager.shared.currentLanguage = before
    check("смена языка пересобирает список", ru != en && !ru.isEmpty && !en.isEmpty)
}

group("Фоновые темы оформления")
check("присутствуют стили для светлой темы",
      AppBackgroundMode.allCases.contains(.ceramic) && AppBackgroundMode.allCases.contains(.pureWhite))
check("у всех стилей непустые заголовки",
      AppBackgroundMode.allCases.allSatisfy { !$0.title.isEmpty })

group("Оформление и цветовая схема (Theme & ColorScheme)")
check("AppAppearance.light задаёт ColorScheme.light", AppAppearance.light.colorScheme == .light)
check("AppAppearance.dark задаёт ColorScheme.dark", AppAppearance.dark.colorScheme == .dark)
check("AppAppearance.system разрешается в актуальную системную тему",
      AppAppearance.system.colorScheme == (Theme.isSystemInDarkMode ? .dark : .light))

ThemeManager.shared.appearance = .light
check("isDarkAppearance синхронно false при светлой теме", !Theme.isDarkAppearance)
ThemeManager.shared.appearance = .dark
check("isDarkAppearance синхронно true при тёмной теме", Theme.isDarkAppearance)
ThemeManager.shared.appearance = .system
check("isDarkAppearance совпадает с isSystemInDarkMode при системной теме",
      Theme.isDarkAppearance == Theme.isSystemInDarkMode)

group("Контраст: текст поверх заливок (WCAG AA, 4.5:1)")
// Все пять акцентов служат подложкой под текст. С белым не проходил ни один:
// emerald 2.11, amber 2.21, crimson 3.41, sapphire 3.62, purple 4.17.
func contrast(_ a: NSColor, _ b: NSColor) -> Double {
    func lum(_ c: NSColor) -> Double {
        guard let s = c.usingColorSpace(.sRGB) else { return 0 }
        func ch(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(s.redComponent) + 0.7152 * ch(s.greenComponent) + 0.0722 * ch(s.blueComponent)
    }
    let (x, y) = (lum(a), lum(b))
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

for palette in AccentPalette.allCases {
    let r = contrast(NSColor(palette.color), NSColor(palette.onColor))
    check("акцент \(palette.rawValue): \(String(format: "%.2f", r)):1", r >= 4.5)
}

for (name, color) in [("statusRed", Theme.statusRed), ("statusGreen", Theme.statusGreen),
                      ("statusOrange", Theme.statusOrange), ("statusBlue", Theme.statusBlue),
                      ("statusPurple", Theme.statusPurple), ("statusCyan", Theme.statusCyan)] {
    let fg = Theme.readableForeground(on: color)
    let r = contrast(NSColor(color), NSColor(fg))
    check("\(name): \(String(format: "%.2f", r)):1", r >= 4.5)
}

// ─────────────────────────────────────────── языки

group("Локализация — словари")
let ruKeys = Set(LocalizationManager.ruDict.keys)
check("у английского те же ключи, что у русского", Set(LocalizationManager.enDict.keys) == ruKeys)
check("у кыргызского те же ключи, что у русского", Set(LocalizationManager.kyDict.keys) == ruKeys)
check("кыргызские значения не пустые", LocalizationManager.kyDict.values.allSatisfy { !$0.isEmpty })
check("в выборе языка три языка", AppLanguage.allCases.map(\.rawValue) == ["ru", "ky", "en"])

group("Локализация — сообщения движка")
let wl = "Домен ads.example.com добавлен в белый список"
check("русский остаётся как есть", EngineText.localize(wl, to: .ru) == wl)
check("английский с доменом",      EngineText.localize(wl, to: .en) == "Domain ads.example.com added to the whitelist")
check("кыргызский с доменом",      EngineText.localize(wl, to: .ky) == "ads.example.com домени ак тизмеге кошулду")
check("без переменных",            EngineText.localize("DNS кэш успешно очищен", to: .ky) == "DNS кэши тазаланды")
check("незнакомое не трогается",   EngineText.localize("что-то новое", to: .ky) == "что-то новое")
check("две похожие фразы не путаются",
      EngineText.localize("Homebrew не найден", to: .en) == "Homebrew not found")

// ─────────────────────────────────────────── обновления

group("Обновления — сравнение версий")
check("3.0.1 новее 3.0.0",       UpdateChecker.isNewer("3.0.1", than: "3.0.0"))
check("3.0.10 новее 3.0.9",      UpdateChecker.isNewer("3.0.10", than: "3.0.9"))
check("3.0 не новее 3.0.0",      !UpdateChecker.isNewer("3.0", than: "3.0.0"))
check("та же версия не новее",   !UpdateChecker.isNewer("3.0.0", than: "3.0.0"))
check("старая не новее",         !UpdateChecker.isNewer("2.9.9", than: "3.0.0"))

group("Обновления — ответ GitHub")
let rel = UpdateChecker.parseRelease([
    "tag_name": "v3.1.0",
    "html_url": "https://github.com/artsu281-ai/cerberus-dns/releases/tag/v3.1.0",
    "assets": [["browser_download_url": "https://example.com/notes.txt"],
               ["browser_download_url": "https://example.com/CerberusDNS-3.1.0-macOS.zip"]]])
check("версия без «v»",          rel?.version == "3.1.0")
check("берётся архив .zip",      rel?.downloadURL?.lastPathComponent == "CerberusDNS-3.1.0-macOS.zip")
check("релиз без архива читается",
      UpdateChecker.parseRelease(["tag_name": "v3.1.0", "html_url": "https://github.com/x"])?.downloadURL == nil)
check("без тега — нет релиза",   UpdateChecker.parseRelease(["html_url": "https://github.com/x"]) == nil)
check("кавычка в пути экранируется", Updater.quoted("/Applications/It's.app") == "'/Applications/It'\\''s.app'")

// ─────────────────────────────────────────── итог

print("\n\(checks - failures) из \(checks) проверок пройдено")
exit(failures == 0 ? 0 : 1)
