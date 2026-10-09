# Сторонние компоненты и сервисы / Third-party components and services

Cerberus DNS распространяется по лицензии MIT (см. `LICENSE`). Ниже — то, что
приложение **не содержит в себе**, а скачивает или вызывает во время работы.
Права на эти компоненты принадлежат их авторам; их условия действуют отдельно.

Cerberus DNS is MIT-licensed. Nothing below is bundled in this repository: the
app downloads or contacts it at run time, under its own terms.

## Программы / Software

| Компонент | Как используется | Лицензия |
|---|---|---|
| [sing-box](https://github.com/SagerNet/sing-box) | Необязательное VPN-ядро. По кнопке скачивается официальная сборка с GitHub Releases (версия и SHA-256 зашиты в `engine.sh`) и запускается отдельным процессом. В репозиторий и сборку приложения не входит. | GPL-3.0-or-later с дополнительным условием автора: производным работам нельзя использовать название sing-box или намекать на связь с ним без согласия. Cerberus DNS не является производной работой sing-box и не связан с его авторами. |
| [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) | Локальный DNS-сервер, ставится через Homebrew. | GPL-2.0 / GPL-3.0 |

Если когда-нибудь класть бинарник sing-box в готовую сборку `.app`, нужно
приложить текст GPL-3.0 и ссылку на исходники той же версии.

## Списки блокировки / Blocklists

Скачиваются на машину пользователя напрямую из источника; приложение их не
распространяет.

| Список | Источник | Условия |
|---|---|---|
| OISD Big | `https://big.oisd.nl/dnsmasq2` | Лицензия на сайте oisd.nl не указана (проверено 09.10.2026) |
| StevenBlack hosts | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` | MIT |
| AdAway | `https://adaway.org/hosts.txt` | CC BY 3.0 |

## Сетевые сервисы / Network services

Приложение обращается к ним по действию пользователя, для проверки состояния
и раз в день за проверкой обновлений. Телеметрии и сбора данных разработчиком нет.

| Сервис | Зачем |
|---|---|
| ipinfo.io, api.ipify.org | Показать внешний IP и провайдера |
| speed.cloudflare.com, speedtest.selectel.ru | Тест скорости |
| github.com | Скачать ядро sing-box |
| api.github.com | Раз в день: есть ли новый релиз Cerberus DNS (анонимный запрос, выключается в настройках) |
| Публичные DNS (AdGuard, Cloudflare, Quad9, Mullvad, Google, Яндекс, NextDNS) | Вышестоящие резолверы и профили фильтрации |

## Товарные знаки / Trademarks

AdGuard, Cloudflare, Google, Quad9, Mullvad, NextDNS, Tailscale, Firefox,
Chrome, macOS и другие названия принадлежат их владельцам и упоминаются только
для описания совместимости. Cerberus DNS не связан с ними и не одобрен ими.
