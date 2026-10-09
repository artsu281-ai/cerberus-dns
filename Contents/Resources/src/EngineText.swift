import Foundation

/// Перевод сообщений движка (`engine.sh`) на язык интерфейса.
///
/// Движок пишет по-русски, а баннеры и журнал показывают его последнюю строку
/// как есть, поэтому в английском и кыргызском режиме там оставался русский.
/// Здесь каждое известное сообщение сопоставляется по шаблону: `%@` — переменная
/// часть (домен, адрес, версия), она переносится в перевод без изменений.
/// Незнакомая строка возвращается нетронутой.
enum EngineText {

    private struct Entry {
        let regex: NSRegularExpression
        let en: String
        let ky: String
    }

    // (русский шаблон, английский, кыргызский)
    private static let table: [(String, String, String)] = [
        ("Homebrew не найден — локальный dnsmasq не установлен", "Homebrew not found — local dnsmasq is not installed", "Homebrew табылган жок — жергиликтүү dnsmasq орнотулган эмес"),
        ("Homebrew не найден", "Homebrew not found", "Homebrew табылган жок"),
        ("не нашёл Homebrew", "Homebrew not found", "Homebrew табылган жок"),
        ("Tailscale не запущен", "Tailscale is not running", "Tailscale иштеп жаткан жок"),
        ("Tailscale не установлен", "Tailscale is not installed", "Tailscale орнотулган эмес"),
        ("dnsmasq не нашёлся после установки", "dnsmasq not found after installation", "Орнотуудан кийин dnsmasq табылган жок"),
        ("dnsmasq не установлен (%@)", "dnsmasq is not installed (%@)", "dnsmasq орнотулган эмес (%@)"),
        ("dnsmasq не установлен", "dnsmasq is not installed", "dnsmasq орнотулган эмес"),
        ("launchd не принял агент ядра", "launchd rejected the core agent", "launchd ядронун агентин кабыл алган жок"),
        ("Архив ядра повреждён", "The core archive is corrupted", "Ядронун архиви бузулган"),
        ("Имена tailnet перестали резолвиться — настройки возвращены как были", "Tailnet names stopped resolving — settings were restored", "Tailnet аттары чечилбей калды — жөндөөлөр мурунку абалга кайтарылды"),
        ("Команды VPN-ядра выполняются от пользователя, не от root", "VPN core commands run as the user, not as root", "VPN ядросунун буйруктары root эмес, колдонуучунун атынан аткарылат"),
        ("Контрольная сумма ядра не совпала - файл отброшен", "Core checksum mismatch — file discarded", "Ядронун текшерүү суммасы дал келген жок — файл четке кагылды"),
        ("Не удалось перезапустить dnsmasq", "Could not restart dnsmasq", "dnsmasq кайра иштетилген жок"),
        ("Не удалось скачать ядро с github.com", "Could not download the core from github.com", "Ядрону github.com сайтынан жүктөп алуу мүмкүн болгон жок"),
        ("Недопустимое доменное имя: «%@»", "Invalid domain name: “%@”", "Жараксыз домен аты: «%@»"),
        ("Недопустимый путь Homebrew: %@", "Invalid Homebrew path: %@", "Homebrew жолу жараксыз: %@"),
        ("Неизвестная архитектура: %@", "Unknown architecture: %@", "Белгисиз архитектура: %@"),
        ("Неизвестный параметр: %@", "Unknown option: %@", "Белгисиз параметр: %@"),
        ("Неизвестный профиль: %@", "Unknown profile: %@", "Белгисиз профиль: %@"),
        ("Нет профиля - сначала обновите подписку", "No profile — update the subscription first", "Профиль жок — адегенде жазылууну жаңыртыңыз"),
        ("Подписка недоступна, а сохранённого профиля ещё нет", "Subscription unavailable and no saved profile yet", "Жазылуу жеткиликсиз, сакталган профиль азырынча жок"),
        ("Профиль не проходит проверку ядра", "The profile fails the core check", "Профиль ядронун текшерүүсүнөн өткөн жок"),
        ("Режим DNS: tunnel или system", "DNS mode: tunnel or system", "DNS режими: tunnel же system"),
        ("Ссылка подписки не задана", "No subscription link set", "Жазылуу шилтемеси көрсөтүлгөн эмес"),
        ("Требуются права администратора", "Administrator rights required", "Администратордун укуктары керек"),
        ("Это не похоже на ссылку подписки (нужен адрес вида http://хост:порт/sub/ключ)", "This does not look like a subscription link (expected http://host:port/sub/key)", "Бул жазылуу шилтемесине окшобойт (http://хост:порт/sub/ачкыч түрүндөгү дарек керек)"),
        ("Ядро sing-box не установлено", "The sing-box core is not installed", "sing-box ядросу орнотулган эмес"),
        ("Ядро не поднялось: %@", "The core did not start: %@", "Ядро иштеген жок: %@"),
        ("Ядро установлено, но не запускается", "The core is installed but does not start", "Ядро орнотулду, бирок иштебей жатат"),
        ("конфиг не прошёл проверку", "configuration check failed", "конфигурация текшерүүдөн өткөн жок"),
        ("локальный DNS не отвечает — настройки сети не изменены", "local DNS is not responding — network settings left unchanged", "жергиликтүү DNS жооп бербей жатат — тармак жөндөөлөрү өзгөртүлгөн жок"),
        ("не удалось изменить DNS", "could not change DNS", "DNS өзгөртүлгөн жок"),
        ("не удалось установить dnsmasq", "could not install dnsmasq", "dnsmasq орнотулган жок"),
        ("ни один список не скачался", "no blocklist could be downloaded", "бир да тизме жүктөлгөн жок"),
        ("служба не запустилась, лог: %@", "the service did not start, log: %@", "кызмат иштеген жок, журнал: %@"),
        ("DNS всех подключений переключен на 127.0.0.1", "DNS of all connections switched to 127.0.0.1", "Бардык туташуулардын DNS'и 127.0.0.1 дарегине которулду"),
        ("DNS кэш успешно очищен", "DNS cache flushed", "DNS кэши тазаланды"),
        ("DNS-блокировщик полностью удалён, настройки сети восстановлены", "The DNS blocker is fully removed, network settings restored", "DNS бөгөттөгүч толук жок кылынды, тармак жөндөөлөрү калыбына келтирилди"),
        ("HTTP/HTTPS прокси %@ включён", "HTTP/HTTPS proxy %@ enabled", "HTTP/HTTPS прокси %@ күйгүзүлдү"),
        ("SOCKS5 прокси %@ включён", "SOCKS5 proxy %@ enabled", "SOCKS5 прокси %@ күйгүзүлдү"),
        ("dnsmasq запущен", "dnsmasq started", "dnsmasq иштеп баштады"),
        ("dnsmasq уже установлен", "dnsmasq is already installed", "dnsmasq мурунтан эле орнотулган"),
        ("dnsmasq установлен", "dnsmasq installed", "dnsmasq орнотулду"),
        ("Автообновление правил включено", "Automatic rule updates enabled", "Эрежелерди автоматтык жаңыртуу күйгүзүлдү"),
        ("Автообновление правил отключено", "Automatic rule updates disabled", "Эрежелерди автоматтык жаңыртуу өчүрүлдү"),
        ("Блокировка стороннего DoH выключена", "Third-party DoH blocking disabled", "Бөтөн DoH бөгөттөөсү өчүрүлдү"),
        ("Вышестоящие DNS обновлены: %@", "Upstream DNS updated: %@", "Жогорку DNS серверлери жаңыртылды: %@"),
        ("Домен %@ добавлен в белый список", "Domain %@ added to the whitelist", "%@ домени ак тизмеге кошулду"),
        ("Домен %@ добавлен в черный список", "Domain %@ added to the blacklist", "%@ домени кара тизмеге кошулду"),
        ("Домен %@ удален из белого списка", "Domain %@ removed from the whitelist", "%@ домени ак тизмеден алынды"),
        ("Домен %@ удален из черного списка", "Domain %@ removed from the blacklist", "%@ домени кара тизмеден алынды"),
        ("Локальный резолвер dnsmasq перезапущен", "Local dnsmasq resolver restarted", "Жергиликтүү dnsmasq резолвери кайра иштетилди"),
        ("Помощник удален", "Helper removed", "Жардамчы жок кылынды"),
        ("Привилегированный помощник установлен", "Privileged helper installed", "Артыкчылыктуу жардамчы орнотулду"),
        ("Применён профиль %@", "Profile %@ applied", "%@ профили колдонулду"),
        ("Прокси и туннели отключены", "Proxies and tunnels disabled", "Прокси жана туннелдер өчүрүлдү"),
        ("Профиль обновлён", "Profile updated", "Профиль жаңыртылды"),
        ("Разделение зон включено: %@", "Zone split enabled: %@", "Зоналарды бөлүү күйгүзүлдү: %@"),
        ("Разделение зон выключено, Tailscale снова управляет DNS", "Zone split disabled, Tailscale manages DNS again", "Зоналарды бөлүү өчүрүлдү, DNS'ти кайра Tailscale башкарат"),
        ("Режим DNS внутри VPN: %@", "DNS mode inside VPN: %@", "VPN ичиндеги DNS режими: %@"),
        ("Ссылка подписки сохранена", "Subscription link saved", "Жазылуу шилтемеси сакталды"),
        ("Сторонний DoH заблокирован", "Third-party DoH blocked", "Бөтөн DoH бөгөттөлдү"),
        ("Ядро sing-box %@ установлено", "sing-box core %@ installed", "sing-box %@ ядросу орнотулду"),
        ("Ядро запущено, слушает %@", "Core started, listening on %@", "Ядро иштеп жатат, угуп турат: %@"),
        ("Ядро остановлено", "Core stopped", "Ядро токтотулду"),
        ("конфиг записан и проверен", "configuration written and verified", "конфигурация жазылды жана текшерилди"),
        ("локальный резолвер отвечает штатно (%@)", "local resolver responds normally (%@)", "жергиликтүү резолвер кадимкидей жооп берип жатат (%@)"),
        ("прежний DNS возвращён, служба остановлена", "previous DNS restored, service stopped", "мурунку DNS кайтарылды, кызмат токтотулду"),
        ("список готов: %@ доменов", "list ready: %@ domains", "тизме даяр: %@ домен"),
        ("источник: %@", "source: %@", "булак: %@"),
        ("Локальный режим не активен — перезапускать нечего", "Local mode is not active — nothing to restart", "Жергиликтүү режим активдүү эмес — кайра иштетчү эч нерсе жок"),
        ("Отметка сохранена, но правила применятся только в локальном режиме", "Saved, but the rules apply only in local mode", "Белги сакталды, бирок эрежелер жергиликтүү режимде гана иштейт"),
        ("Подписка недоступна - остаюсь на сохранённом профиле", "Subscription unavailable — staying on the saved profile", "Жазылуу жеткиликсиз — сакталган профиль колдонулууда"),
        ("не подошёл, пробую следующий", "did not work, trying the next one", "ылайык келген жок, кийинкиси текшерилүүдө"),
    ]

    private static let entries: [Entry] = table.compactMap { ru, en, ky in
        let pattern = "^" + NSRegularExpression.escapedPattern(for: ru)
            .replacingOccurrences(of: "%@", with: "(.+?)") + "$"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        return Entry(regex: re, en: en, ky: ky)
    }

    /// Сообщение движка на языке интерфейса.
    static func localize(_ message: String) -> String {
        localize(message, to: LocalizationManager.shared.currentLanguage)
    }

    static func localize(_ message: String, to lang: AppLanguage) -> String {
        guard lang != .ru else { return message }
        let range = NSRange(message.startIndex..., in: message)
        for e in entries {
            guard let m = e.regex.firstMatch(in: message, range: range) else { continue }
            var out = lang == .ky ? e.ky : e.en
            for i in 1..<m.numberOfRanges {
                guard let r = Range(m.range(at: i), in: message),
                      let slot = out.range(of: "%@") else { break }
                out.replaceSubrange(slot, with: message[r])
            }
            return out
        }
        return message
    }
}
