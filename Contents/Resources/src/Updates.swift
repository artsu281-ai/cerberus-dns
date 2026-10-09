import Foundation
import AppKit

/// Проверка обновлений: есть ли на GitHub релиз новее этой сборки.
///
/// Единственный сетевой запрос, который приложение делает само, без действия
/// пользователя: анонимный GET открытого адреса GitHub, без идентификаторов и
/// тела запроса. Не чаще раза в сутки; выключается в настройках.
/// Устанавливает найденное `Updater`. Устройство то же, что у Double Bubble.
@MainActor
final class UpdateChecker: ObservableObject {

    struct Release: Equatable {
        let version: String
        /// Страница релиза — «Что нового».
        let url: URL
        /// Архив для установки; `nil`, если релиз опубликован без него.
        let downloadURL: URL?
    }

    static let shared = UpdateChecker()

    static let repository = "artsu281-ai/cerberus-dns"
    static let enabledKey = "check_updates_automatically"
    private static let lastCheckKey = "last_update_check_at"
    private static let skippedKey = "skipped_update_version"
    private static let interval: TimeInterval = 60 * 60 * 24

    @Published private(set) var available: Release?
    /// Итог последней ручной проверки — для строки в настройках.
    @Published private(set) var lastResult: String?
    @Published private(set) var isChecking = false

    private let endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    private let defaults = UserDefaults.standard

    private init() {}

    var isEnabled: Bool {
        defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// При запуске: учитывает и выключатель, и «не чаще раза в сутки».
    func checkIfDue() async {
        guard isEnabled, !isChecking else { return }
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < Self.interval { return }
        await check(manual: false)
    }

    /// «Проверить сейчас»: без ограничения по времени и с показом пропущенной версии.
    func check(manual: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let latest = await fetchLatest() else {
            if manual {
                lastResult = tr("Не удалось связаться с GitHub", "Couldn’t reach GitHub", "GitHub менен байланышуу мүмкүн болгон жок")
            }
            return
        }
        defaults.set(Date(), forKey: Self.lastCheckKey)

        let newer = Self.isNewer(latest.version, than: Self.currentVersion)
        let skipped = !manual && defaults.string(forKey: Self.skippedKey) == latest.version
        available = (newer && !skipped) ? latest : nil
        if manual {
            lastResult = newer
                ? tr("Доступна версия \(latest.version)", "Version \(latest.version) is available", "\(latest.version) версиясы жеткиликтүү")
                : tr("Установлена последняя версия", "You have the latest version", "Акыркы версия орнотулган")
        }
    }

    /// Скрыть эту версию; следующая всё равно появится.
    func skip(_ release: Release) {
        defaults.set(release.version, forKey: Self.skippedKey)
        available = nil
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey)
        objectWillChange.send()
        if !enabled { available = nil }
    }

    private func fetchLatest() async -> Release? {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CerberusDNS/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return Self.parseRelease(json)
    }

    /// Разбор ответа GitHub; вынесен отдельно, чтобы проверять без сети.
    nonisolated static func parseRelease(_ json: [String: Any]) -> Release? {
        guard let tag = json["tag_name"] as? String,
              let page = json["html_url"] as? String,
              let url = URL(string: page) else { return nil }
        let asset = (json["assets"] as? [[String: Any]])?
            .compactMap { $0["browser_download_url"] as? String }
            .first { $0.hasSuffix(".zip") }
            .flatMap(URL.init(string:))
        // Теги вида «v3.0.1» — сравниваем только число.
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard !version.isEmpty else { return nil }
        return Release(version: version, url: url, downloadURL: asset)
    }

    /// Сравнение версий по числам: 3.0.10 новее 3.0.9 (строковое сравнение
    /// дало бы обратное). Нечисловая часть считается нулём.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

/// Скачивает релиз и ставит его на место работающей копии.
///
/// Gatekeeper проверяет только файлы с флагом `com.apple.quarantine`; после
/// распаковки флаг снимается, поэтому новая копия открывается сразу. Подпись
/// у сборки ad hoc: она не доказывает авторство, только то, что архив пришёл по
/// TLS из релиза, названного API GitHub, что это наш бандл нужной версии и что
/// его подпись цела. Ровно то же даёт и ручная загрузка.
///
/// Подмену нельзя сделать изнутри работающего процесса, поэтому её выполняет
/// короткий скрипт: дождаться выхода, отодвинуть старый бандл, распаковать
/// новый, а при ошибке вернуть старый на место. Момента «без приложения» нет.
@MainActor
final class Updater: ObservableObject {

    enum Phase: Equatable {
        case idle, downloading, verifying, installing
        case failed(String)
    }

    static let shared = Updater()

    @Published private(set) var phase: Phase = .idle
    private var work: Task<Void, Never>?

    private init() {}

    var isBusy: Bool {
        switch phase {
        case .idle, .failed: return false
        case .downloading, .verifying, .installing: return true
        }
    }

    /// Можно ли заменить эту копию на месте: это `.app` и папку над ним можно
    /// писать (копия в /Applications, поставленная пользователем, — можно).
    static var canReplaceItself: Bool {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { return false }
        return FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    func install(_ release: UpdateChecker.Release) {
        guard !isBusy, let asset = release.downloadURL else { return }
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let zip = try await self.download(asset)
                guard !Task.isCancelled else { return }
                self.phase = .verifying
                let app = try await Self.unpackAndVerify(zip: zip, expecting: release.version)
                guard !Task.isCancelled else { return }
                self.phase = .installing
                try Self.swapAndRelaunch(with: app, staging: zip.deletingLastPathComponent())
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed((error as? Failure)?.message ?? error.localizedDescription)
            }
        }
    }

    func cancel() {
        work?.cancel()
        work = nil
        phase = .idle
    }

    private func download(_ url: URL) async throws -> URL {
        phase = .downloading
        var request = URLRequest(url: url)
        request.timeoutInterval = 180
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let (temporary, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            try? FileManager.default.removeItem(at: temporary)
            throw Failure(tr("Загрузка не началась", "The download didn’t start", "Жүктөө башталган жок"))
        }
        let staging = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CerberusDNSUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let zip = staging.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: temporary, to: zip)
        return zip
    }

    /// Отказывает всему, что не является обещанным релизом: наш идентификатор,
    /// объявленная версия и подпись, которая проверяется сама по себе.
    private static func unpackAndVerify(zip: URL, expecting version: String) async throws -> URL {
        let staging = zip.deletingLastPathComponent()
        try await run("/usr/bin/ditto", ["-x", "-k", zip.path, staging.path],
                      failure: tr("Архив не распаковался", "The download couldn’t be unpacked", "Архив ачылган жок"))

        let fm = FileManager.default
        guard let name = (try? fm.contentsOfDirectory(atPath: staging.path))?
                .first(where: { $0.hasSuffix(".app") }) else {
            throw Failure(tr("В архиве нет приложения", "The download didn’t contain an application", "Архивде программа жок"))
        }
        let app = staging.appendingPathComponent(name)

        guard let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let identifier = plist["CFBundleIdentifier"] as? String,
              identifier == Bundle.main.bundleIdentifier,
              let shipped = plist["CFBundleShortVersionString"] as? String,
              shipped == version else {
            throw Failure(tr("Загрузка не совпала с обещанным обновлением", "The download wasn’t the update it claimed to be", "Жүктөлгөн файл убадаланган жаңыртууга дал келген жок"))
        }

        try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path],
                      failure: tr("Обновление не прошло проверку подписи и не установлено", "The update failed its integrity check and was not installed", "Жаңыртуу кол текшерүүсүнөн өткөн жок жана орнотулган жок"))
        return app
    }

    private static func swapAndRelaunch(with newApp: URL, staging: URL) throws {
        let destination = Bundle.main.bundleURL
        let script = staging.appendingPathComponent("install.sh")
        let body = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        sleep 0.5
        DEST=\(quoted(destination.path))
        BACKUP="$DEST.replaced-$$"
        /bin/mv "$DEST" "$BACKUP" || exit 1
        if /usr/bin/ditto \(quoted(newApp.path)) "$DEST"; then
          /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
          /bin/rm -rf "$BACKUP"
        else
          /bin/rm -rf "$DEST"
          /bin/mv "$BACKUP" "$DEST"
        fi
        /usr/bin/open "$DEST"
        /bin/rm -rf \(quoted(staging.path))
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path]
        try process.run()
        NSApp.terminate(nil)
    }

    private struct Failure: Error { let message: String; init(_ m: String) { message = m } }

    nonisolated static func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func run(_ tool: String, _ arguments: [String], failure: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw Failure(failure) }
        }.value
    }
}
