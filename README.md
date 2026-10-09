# Cerberus DNS

Бесплатный блокировщик рекламы, трекеров и фишинга на уровне DNS для macOS,
с открытым кодом. Работает через локальный `dnsmasq`: запросы к рекламным
доменам не уходят в сеть. Есть журнал запросов, профили DNS (AdGuard,
Cloudflare, Quad9 и др.), белый и чёрный списки, совместимость с Tailscale и
необязательный VPN-клиент на ядре sing-box для вашей собственной подписки.

Free, open-source DNS-level ad, tracker and phishing blocker for macOS, built on
a local `dnsmasq`.

**Кыргызча.** Cerberus DNS — macOS үчүн акысыз, ачык коддуу программа: жарнаманы,
трекерлерди жана фишингди DNS деңгээлинде бөгөттөйт. Интерфейс кыргыз, орус жана
англис тилдеринде.

Разработано [Constanta.kg](https://constanta.kg), сделано в Кыргызстане.
Интерфейс на трёх языках: русском, кыргызском и английском.
Made in Kyrgyzstan by [Constanta.kg](https://constanta.kg).

## Установка / Install

1. Скачайте `CerberusDNS-<версия>-macOS.zip` со страницы
   [Releases](https://github.com/artsu281-ai/cerberus-dns/releases/latest) или с
   [constanta.kg/cerberus-dns.html](https://constanta.kg/cerberus-dns.html).
2. Распакуйте и перетащите `Cerberus DNS.app` в «Программы».
3. Сборка подписана ad hoc, без заверения Apple: при первом запуске
   правый клик → «Открыть».

Обновления: раз в день приложение проверяет новый релиз на GitHub и
предлагает «Обновить и перезапустить». Проверку можно выключить в
«Настройки → О программе».

## Требования / Requirements

- macOS 12 или новее, Apple Silicon или Intel
- [Homebrew](https://brew.sh) и `dnsmasq` (`brew install dnsmasq`)
- Xcode Command Line Tools (`xcode-select --install`) для сборки
- Права администратора: приложение меняет системные настройки DNS

## Сборка из исходников / Build from source

```bash
bash Contents/Resources/build.sh
```

Приложение — это каталог `Contents`. Установка:

```bash
mkdir -p "/Applications/Cerberus DNS.app" && cp -R Contents "/Applications/Cerberus DNS.app/"
```

Архив релиза (универсальный, Apple Silicon + Intel, подпись ad hoc):
`bash tools/release.sh` → `dist/`. Проверки (систему не трогают):

```bash
bash tools/test.sh
```

## Что приложение делает с системой / What it changes on your Mac

- Меняет DNS-серверы сетевых служб и сохраняет прежние в резервную копию.
- Ставит службу `dnsmasq` (`/Library/LaunchDaemons/com.adblockdns.dnsmasq.plist`).
- По желанию ставит привилегированного помощника с правилом в
  `/etc/sudoers.d/` — подробности и удаление в [SECURITY.md](SECURITY.md).
- Скачивает списки блокировки и, по кнопке, ядро sing-box — см.
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Телеметрии нет. Журнал запросов и статистика хранятся только на вашем Mac.

## Ответственность / Disclaimer

Программа распространяется «как есть», без каких-либо гарантий (см. `LICENSE`).
Она меняет системные сетевые настройки: перед установкой убедитесь, что знаете,
как вернуть DNS вручную (Системные настройки → Сеть → DNS).

VPN-функция — это клиент для подписки, которую пользователь указывает сам.
Проект не предоставляет VPN-серверов. Пользователь сам отвечает за соблюдение
законов своей страны при использовании VPN и прокси.

The software is provided "as is", without warranty. The VPN feature is only a
client for a subscription you supply; the project operates no servers. You are
responsible for complying with the laws of your country.

## Лицензия / License

[MIT](LICENSE). Сторонние компоненты — в [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Названия сторонних сервисов принадлежат их владельцам; проект с ними не связан.
