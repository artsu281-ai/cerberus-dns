import Foundation
import AppKit

/// Единая точка разрешения путей к ресурсам приложения.
///
/// Раньше пути к `engine.sh` и `AppIcon.png` были прописаны абсолютно
/// («/Users/…/Downloads/DNS-блокировщик.app/…»), из-за чего на любой другой
/// машине не грузилась иконка, а движок находился только по случайности.
/// Здесь каталог ресурсов вычисляется во время выполнения.
enum AppPaths {

    /// Каталог `Contents/Resources` работающего приложения.
    ///
    /// Порядок поиска:
    /// 1. `Bundle.main.resourceURL` — обычный запуск из `.app`;
    /// 2. `<каталог исполняемого файла>/../Resources` — запуск из папки
    ///    репозитория, которая не называется `.app` (Bundle тогда врёт);
    /// 3. `./Contents/Resources` относительно рабочего каталога — запуск
    ///    бинарника вручную из корня проекта.
    static let resourcesURL: URL = {
        let fm = FileManager.default

        if let url = Bundle.main.resourceURL,
           fm.fileExists(atPath: url.appendingPathComponent("engine.sh").path) {
            return url
        }

        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        let siblingResources = exeDir.deletingLastPathComponent()
            .appendingPathComponent("Resources")
        if fm.fileExists(atPath: siblingResources.appendingPathComponent("engine.sh").path) {
            return siblingResources
        }

        let cwdResources = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("Contents/Resources")
        if fm.fileExists(atPath: cwdResources.appendingPathComponent("engine.sh").path) {
            return cwdResources
        }

        // Ничего не нашли — возвращаем предполагаемое место рядом с бинарником,
        // чтобы вызывающий код получил внятный путь в сообщении об ошибке.
        return siblingResources
    }()

    /// Полный путь к файлу в каталоге ресурсов (существование не проверяется).
    static func resource(_ name: String) -> String {
        resourcesURL.appendingPathComponent(name).path
    }

    /// Путь к файлу ресурса, если он действительно существует.
    static func existingResource(_ name: String) -> String? {
        let path = resource(name)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Путь к bash-движку `engine.sh`.
    static var enginePath: String { resource("engine.sh") }

    /// Иконка приложения для боковой панели и окна «О программе».
    ///
    /// Сначала `.icns`: он содержит все представления от 16 до 1024 pt, поэтому
    /// в мелких размерах выглядит резче одиночного PNG. Загружается один раз —
    /// `NSImage(contentsOfFile:)` на каждый кадр перерисовки означал бы
    /// обращение к диску прямо в теле `body`.
    static let appIcon: NSImage? = {
        for name in ["AppIcon.icns", "AppIcon.png"] {
            if let path = existingResource(name), let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return NSApp?.applicationIconImage
    }()
}


/// Нормализация и проверка доменных имён для белого и чёрного списков.
///
/// Пользовательские правила попадают напрямую в конфигурацию dnsmasq,
/// поэтому мусорная строка ломала конфиг целиком. Раньше поле принимало
/// что угодно, включая «https://example.com/path».
enum DomainValidator {

    /// Приводит ввод к голому имени хоста: убирает схему, путь, порт,
    /// пробелы, регистр и завершающую точку.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let range = value.range(of: "://") {
            value = String(value[range.upperBound...])
        }
        if let slash = value.firstIndex(of: "/") {
            value = String(value[..<slash])
        }
        if let at = value.lastIndex(of: "@") {
            value = String(value[value.index(after: at)...])
        }
        // Порт отрезаем только у имён, а не у IPv6-литералов.
        if let colon = value.firstIndex(of: ":"), !value.contains("[") {
            value = String(value[..<colon])
        }
        while value.hasSuffix(".") { value.removeLast() }
        while value.hasPrefix(".") { value.removeFirst() }
        return value
    }

    static func isValid(_ domain: String) -> Bool {
        guard !domain.isEmpty, domain.count <= 253, domain.contains(".") else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
            guard CharacterSet(charactersIn: String(label)).isSubset(of: allowed) else { return false }
        }
        return true
    }

    /// Готовое к отправке имя, либо `nil`, если ввод не является доменом.
    static func sanitized(_ raw: String) -> String? {
        let value = normalize(raw)
        return isValid(value) ? value : nil
    }

    /// Проверяет, является ли строка корректным IPv4 или IPv6 адресом.
    static func isValidIP(_ raw: String) -> Bool {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        if inet_pton(AF_INET, clean, &sin.sin_addr) == 1 { return true }
        if inet_pton(AF_INET6, clean, &sin6.sin6_addr) == 1 { return true }
        return false
    }
}
