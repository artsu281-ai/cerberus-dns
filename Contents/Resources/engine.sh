#!/bin/bash
#
#  adblock-dns — расширенный движок DNS-блокировщика рекламы для macOS.
#  Используется приложением Cerberus DNS и командной строкой.
#

set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

VERSION="3.0.0"

# ─────────── НАСТРОЙКИ СЕРВЕРОВ ───────────

UPSTREAM_1="1.1.1.1"
UPSTREAM_2="1.0.0.1"

ADGUARD_DNS="94.140.14.14 94.140.15.15"
ADGUARD_FAMILY_DNS="94.140.14.15 94.140.15.16"
CLOUDFLARE_SEC_DNS="1.1.1.2 1.0.0.2"
CLOUDFLARE_FAM_DNS="1.1.1.3 1.0.0.3"
QUAD9_DNS="9.9.9.9 149.112.112.112"
MULLVAD_DNS="194.242.2.3"

BLOCKLIST_URLS=(
  "https://big.oisd.nl/dnsmasq2"
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://adaway.org/hosts.txt"
)

# ─────────── ПУТИ ───────────

# Пути можно переопределить окружением. Нужно ровно для проверок: без этого
# сгенерированный конфиг dnsmasq нельзя протестировать, не записав его в
# настоящий системный каталог.
STATE_DIR="${CERBERUS_STATE_DIR:-/usr/local/share/adblock-dns}"
DNS_BACKUP="$STATE_DIR/dns-backup.txt"
MODE_FILE="$STATE_DIR/mode"
PROFILE_FILE="$STATE_DIR/profile"
CUSTOM_DNS_FILE="$STATE_DIR/custom_dns"
WHITELIST_FILE="$STATE_DIR/whitelist.txt"
BLACKLIST_FILE="$STATE_DIR/blacklist.txt"
QUERY_LOG="/var/log/adblock-dns-queries.log"
RESOLVER_DIR="/etc/resolver"
TS_MARK="$STATE_DIR/tailscale_split"
TS_RESOLVER="$RESOLVER_DIR/ts.net"
TS_DNS="100.100.100.100"
DOH_MARK="$STATE_DIR/block_doh"
LIBEXEC="/usr/local/libexec/adblock-dns-engine.sh"
# dnsmasq работает от root, поэтому запускается root-копия, а не файл из
# Homebrew: каталог Homebrew принадлежит пользователю, и любой его процесс мог
# подменить бинарник или конфиг, которые затем исполнялись бы от root.
# Имя файла — именно dnsmasq: по нему `pgrep -x dnsmasq` узнаёт, что служба работает.
DNSMASQ_RUN="/usr/local/libexec/adblock-dns/dnsmasq"
HELPER_BIN="/usr/local/bin/dnsblock-engine"
HELPER_SUDOERS="/etc/sudoers.d/dnsblocker_helper"
DNS_PLIST="/Library/LaunchDaemons/com.adblockdns.dnsmasq.plist"
DNS_LABEL="com.adblockdns.dnsmasq"
UPD_PLIST="/Library/LaunchDaemons/com.adblockdns.update.plist"
UPD_LABEL="com.adblockdns.update"

BREW=""; BREW_PREFIX=""; DNSMASQ_BIN=""

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

if [ -t 1 ]; then
  R=$'\033[0m'; B=$'\033[1m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; CYA=$'\033[36m'; DIM=$'\033[2m'
else
  R=""; B=""; GRN=""; YLW=""; RED=""; CYA=""; DIM=""
fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s▸ %s%s\n' "$CYA$B" "$*" "$R"; }
ok()   { printf '%s  ✔ %s%s\n' "$GRN" "$*" "$R"; }
warn() { printf '%s  ! %s%s\n' "$YLW" "$*" "$R"; }
fail() { printf '%s  ✘ %s%s\n' "$RED" "$*" "$R"; }

# ─────────── HOMEBREW ───────────

find_brew() {
  local p
  BREW=""; BREW_PREFIX=""; DNSMASQ_BIN=""
  # HOME у фонового обновления из launchd не задан, а `set -u` прервал бы скрипт.
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew "${HOME:-/var/empty}/.homebrew/bin/brew" "${HOME:-/var/empty}/homebrew/bin/brew"; do
    if [ -x "$p" ]; then BREW="$p"; break; fi
  done
  [ -z "$BREW" ] && BREW="$(command -v brew 2>/dev/null || true)"
  [ -z "$BREW" ] && return 1
  # Префикс выводится из пути, а не из `brew --prefix`: brew — скрипт в
  # каталоге пользователя, и от root его исполнять нельзя.
  BREW_PREFIX="$(dirname "$(dirname "$BREW")")"
  [ -z "$BREW_PREFIX" ] && return 1
  DNSMASQ_BIN="$BREW_PREFIX/sbin/dnsmasq"
  return 0
}

# Префикс Homebrew нельзя принимать из аргументов. Помощник вызывается через
# sudo без пароля, и `--apply-full /tmp/x` ставил LaunchDaemon, который
# запускал от root `/tmp/x/sbin/dnsmasq`.

# Конфиг и база лежат в каталоге состояния, принадлежащем root, а не в
# $BREW_PREFIX/etc: dnsmasq исполняет директивы конфига от root
# (dhcp-script=…), и правка файла пользователем давала root.
conf_path()      { printf '%s/dnsmasq.conf' "$STATE_DIR"; }
blocklist_path() { printf '%s/blocklist.conf' "$STATE_DIR"; }

# Копирует dnsmasq из Homebrew в root-каталог. Вызывается только по явному
# действию — включению локального режима — или однократно для перехода со
# старой установки, а не при каждом запуске.
install_root_dnsmasq() {
  if [ "${1:-}" != "refresh" ] && [ -x "$DNSMASQ_RUN" ]; then return 0; fi
  [ -n "$DNSMASQ_BIN" ] || find_brew || return 1
  [ -x "$DNSMASQ_BIN" ] || return 1
  $SUDO mkdir -p "$(dirname "$DNSMASQ_RUN")" 2>/dev/null
  $SUDO install -o root -g wheel -m 0755 "$DNSMASQ_BIN" "$DNSMASQ_RUN"
}

# Каталог состояния: root:wheel 0755. Если его создал кто-то другой, правила
# и конфиг в нём мог бы переписать непривилегированный процесс.
make_state_dir() {
  $SUDO mkdir -p "$STATE_DIR" 2>/dev/null
  $SUDO chown root:wheel "$STATE_DIR" 2>/dev/null
  $SUDO chmod 0755 "$STATE_DIR" 2>/dev/null
  return 0
}

# Пользователь, которому выдаётся право на помощник. Под `do shell script …
# with administrator privileges` SUDO_USER не задан, и раньше право уходило
# всей группе admin.
helper_user() {
  local u="${SUDO_USER:-}"
  if [ -z "$u" ] || [ "$u" = "root" ]; then
    u="$(stat -f %Su /dev/console 2>/dev/null)"
  fi
  case "$u" in ""|root|loginwindow) return 1 ;; esac
  printf '%s' "$u"
}

# Без аргумента только обновляет уже установленный помощник. Раньше любой
# вызов от root — смена профиля, сброс кэша — ставил его заново, даже если
# человек его удалил.
ensure_privileged_helper() {
  [ "$(id -u)" -eq 0 ] || return 0
  [ "${1:-}" = "install" ] || [ -f "$HELPER_BIN" ] || return 0

  local helper_bin="$HELPER_BIN"
  local sudoers_file="$HELPER_SUDOERS"
  local self_path target_user

  # Путь к самому себе, а не заранее вписанный путь к папке разработчика.
  self_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  mkdir -p /usr/local/bin /usr/local/libexec /etc/sudoers.d 2>/dev/null || true

  # Root-копия движка. Прежняя обёртка исполняла скрипт прямо из бандла
  # приложения — то есть из каталога, доступного пользователю на запись,
  # с правом NOPASSWD для всей группы admin. Это позволяло любому процессу
  # пользователя переписать файл и выполнить произвольный код от root.
  if [ "$self_path" != "$LIBEXEC" ] && [ -f "$self_path" ]; then
    install -o root -g wheel -m 0755 "$self_path" "$LIBEXEC" 2>/dev/null || return 1
  fi

  cat > "$helper_bin" <<HEOF
#!/bin/bash
exec /bin/bash $LIBEXEC "\$@"
HEOF
  chown root:wheel "$helper_bin" 2>/dev/null || true
  chmod 0755 "$helper_bin" 2>/dev/null || true

  # Право выдаётся конкретному пользователю и никогда — всей группе admin.
  # Если пользователя не определить, прежнее правило остаётся как есть.
  if ! target_user="$(helper_user)"; then
    [ "${1:-}" = "install" ] && return 1
    return 0
  fi

  # Файл собирается рядом и проверяется до замены: битый файл в sudoers.d
  # ломает sudo для всей системы.
  local tmp_sudoers="$sudoers_file.new"
  printf '%s ALL=(ALL) NOPASSWD: %s\n' "$target_user" "$helper_bin" > "$tmp_sudoers"
  chown root:wheel "$tmp_sudoers" 2>/dev/null || true
  chmod 0440 "$tmp_sudoers" 2>/dev/null || true
  if ! visudo -cf "$tmp_sudoers" >/dev/null 2>&1; then
    rm -f "$tmp_sudoers"
    return 1
  fi
  mv -f "$tmp_sudoers" "$sudoers_file"
  return 0
}

# Удаляет помощник целиком: обёртку, root-копию движка и правило sudoers.
remove_privileged_helper() {
  $SUDO rm -f "$HELPER_BIN" "$HELPER_SUDOERS" "$HELPER_SUDOERS.new" "$LIBEXEC"
}

# ─────────── СЕТЕВЫЕ СЕРВИСЫ ───────────

active_services() {
  networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | grep -v '^\*'
}

backup_dns() {
  $SUDO mkdir -p "$STATE_DIR" 2>/dev/null
  [ -s "$DNS_BACKUP" ] && return 0
  local svc cur tmp
  tmp="$(mktemp)"
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    cur="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    case "$cur" in
      ""|*"aren't any DNS Servers"*|*"not a recognized"*) cur="empty" ;;
    esac
    printf '%s\t%s\n' "$svc" "$cur" >> "$tmp"
  done < <(active_services)
  $SUDO cp "$tmp" "$DNS_BACKUP"; rm -f "$tmp"
}

apply_dns() {
  local raw_servers="$1" svc n=0
  local servers
  servers="$(printf '%s' "$raw_servers" | tr ',' ' ' | tr ';' ' ' | xargs)"
  [ -z "$servers" ] && return 1
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    # shellcheck disable=SC2086
    if $SUDO networksetup -setdnsservers "$svc" $servers >/dev/null 2>&1; then n=$((n + 1)); fi
  done < <(active_services)
  [ "$n" -gt 0 ]
}

restore_dns() {
  local svc cur
  if [ ! -s "$DNS_BACKUP" ]; then
    while IFS= read -r svc; do
      [ -z "$svc" ] && continue
      $SUDO networksetup -setdnsservers "$svc" empty >/dev/null 2>&1
    done < <(active_services)
    return 0
  fi
  while IFS=$'\t' read -r svc cur; do
    [ -z "$svc" ] && continue
    # shellcheck disable=SC2086
    $SUDO networksetup -setdnsservers "$svc" $cur >/dev/null 2>&1
  done < "$DNS_BACKUP"
}

flush_dns() {
  ensure_privileged_helper
  $SUDO dscacheutil -flushcache 2>/dev/null
  $SUDO killall -HUP mDNSResponder 2>/dev/null
  return 0
}

set_mode() {
  ensure_privileged_helper
  $SUDO mkdir -p "$STATE_DIR" 2>/dev/null
  printf '%s\n' "$1" | $SUDO tee "$MODE_FILE" >/dev/null
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | $SUDO tee "$PROFILE_FILE" >/dev/null
  fi
}

get_mode() {
  if [ -r "$MODE_FILE" ]; then cat "$MODE_FILE"; else printf 'off'; fi
}

get_profile() {
  if [ -r "$PROFILE_FILE" ]; then cat "$PROFILE_FILE"; else get_mode; fi
}

# ─────────── ПРОВЕРКА РЕЗОЛВА И ПИНГА ───────────

resolve_a() {
  local name="$1" srv="${2:-}"
  if command -v dig >/dev/null 2>&1; then
    if [ -n "$srv" ]; then
      dig +short +time=2 +tries=1 "@$srv" "$name" A 2>/dev/null | grep -E '^[0-9.]+$' | head -1
    else
      dig +short +time=2 +tries=1 "$name" A 2>/dev/null | grep -E '^[0-9.]+$' | head -1
    fi
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$name" "$srv" 2>/dev/null <<'PYDNS'
import socket, struct, random, sys
name = sys.argv[1]
srv = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    if not srv:
        print(socket.gethostbyname(name)); sys.exit(0)
    tid = random.randint(0, 65535)
    q = b"".join(bytes([len(x)]) + x.encode() for x in name.split(".")) + b"\x00"
    pkt = struct.pack(">HHHHHH", tid, 0x0100, 1, 0, 0, 0) + q + struct.pack(">HH", 1, 1)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(2.0)
    s.sendto(pkt, (srv, 53)); data, _ = s.recvfrom(4096); s.close()
    an = struct.unpack(">H", data[6:8])[0]
    i = 12
    while data[i]: i += data[i] + 1
    i += 5
    for _ in range(an):
        while True:
            l = data[i]
            if l & 0xC0 == 0xC0: i += 2; break
            if l == 0: i += 1; break
            i += l + 1
        t, _c, _t, rdl = struct.unpack(">HHIH", data[i:i + 10]); i += 10
        rd = data[i:i + rdl]; i += rdl
        if t == 1:
            print(socket.inet_ntop(socket.AF_INET, rd)); break
except Exception:
    pass
PYDNS
    return
  fi
  if command -v nslookup >/dev/null 2>&1; then
    if [ -n "$srv" ]; then
      nslookup -timeout=2 "$name" "$srv" 2>/dev/null | awk '/^Address: /{print $2; exit}'
    else
      nslookup -timeout=2 "$name" 2>/dev/null | awk '/^Address: /{print $2; exit}'
    fi
  fi
}

measure_dns_ping() {
  local srv="${1:-127.0.0.1}"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$srv" 2>/dev/null <<'PYPING'
import time, socket, struct, random, sys
srv = sys.argv[1]
try:
    tid = random.randint(0, 65535)
    sub = f"p{random.randint(1000,9999)}"
    q = b"".join(bytes([len(p)]) + p.encode() for p in [sub, "cloudflare", "com"]) + b"\x00\x00\x01\x00\x01"
    pkt = struct.pack(">HHHHHH", tid, 0x0100, 1, 0, 0, 0) + q
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(1.5)
    t0 = time.perf_counter()
    s.sendto(pkt, (srv, 53))
    data, _ = s.recvfrom(512)
    t1 = time.perf_counter()
    s.close()
    ms = int(round((t1 - t0) * 1000))
    if ms == 0:
        ms = 1
    print(ms)
except Exception:
    print("-1")
PYPING
    return
  fi
  local p
  p="$(ping -c 1 -W 1000 "$srv" 2>/dev/null | awk -F'/' 'END{if (NF>4) print int($5); else print "-1"}')"
  printf '%s\n' "${p:--1}"
}

# ─────────── СПИСОК БЛОКИРОВКИ ───────────

convert_list() {
  local src="$1" dst="$2"
  if grep -qE '^[[:space:]]*(address|local|server)=' "$src" 2>/dev/null; then
    # Из чужого списка берутся только строки, которые блокируют домен.
    # Прежде строки server=/домен/IP и address=/домен/IP проходили как есть,
    # и подменённый список мог увести любой сайт, хоть банк, на свой адрес.
    # Список скачивается и применяется от root без участия человека.
    LC_ALL=C tr -d '\r' < "$src" | LC_ALL=C awk '
      { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); $0 = tolower($0) }
      /^(address|local)=\/[a-z0-9_-]+(\.[a-z0-9_-]+)+\/(#|0\.0\.0\.0|::)?$/ {
        if (!seen[$0]++) print
      }' > "$dst"
  else
    LC_ALL=C awk '
      { sub(/\r$/, "") }
      /^[[:space:]]*#/ { next }
      ($1 == "0.0.0.0" || $1 == "127.0.0.1") && NF >= 2 {
        d = tolower($2)
        if (d == "" || d == "localhost" || d == "localhost.localdomain" ||
            d == "broadcasthost" || d == "local" || d == "0.0.0.0" ||
            d == "ip6-localhost" || d == "ip6-loopback") next
        if (d !~ /^[a-z0-9_.-]+$/) next
        if (d !~ /\./) next
        if (seen[d]++) next
        print "address=/" d "/#"
      }' "$src" > "$dst"
  fi
  [ -s "$dst" ] || return 1
  [ "$(wc -l < "$dst" | tr -d ' ')" -gt 1000 ]
}

build_blocklist() {
  local out="$1" tmp url n
  tmp="$(mktemp -d)" || return 1
  for url in "${BLOCKLIST_URLS[@]}"; do
    say "    источник: $url"
    if curl -fsSL --max-time 180 "$url" -o "$tmp/raw" 2>/dev/null && [ -s "$tmp/raw" ]; then
      if convert_list "$tmp/raw" "$tmp/list.conf"; then
        if "$DNSMASQ_RUN" --test --conf-file="$tmp/list.conf" >/dev/null 2>&1; then
          n="$(wc -l < "$tmp/list.conf" | tr -d ' ')"
          $SUDO mkdir -p "$(dirname "$out")" 2>/dev/null
          # Через временный файл рядом: работающий dnsmasq не должен увидеть
          # недописанную базу.
          $SUDO cp "$tmp/list.conf" "$out.new" && $SUDO chmod 0644 "$out.new" && $SUDO mv -f "$out.new" "$out"
          rm -rf "$tmp"; ok "список готов: $n доменов"; return 0
        fi
      fi
    fi
    warn "не подошёл, пробую следующий"
  done
  rm -rf "$tmp"; return 1
}

# ─────────── КОНФИГ И СЛУЖБЫ ───────────

# Конфиг собирается во временном файле и заменяет рабочий только после
# `dnsmasq --test`. Раньше он перезаписывался на месте, и при неудачной
# проверке битый файл оставался: следующий перезапуск службы оставлял систему
# с DNS 127.0.0.1, на котором никто не отвечает.
write_conf() {
  local conf blocklist effective_blocklist out wdom bdom
  conf="$(conf_path)"; blocklist="$(blocklist_path)"
  # На установке прежней версии root-копии ещё нет, а проверять конфиг
  # нечем — без этого правка правил там просто не применялась бы.
  install_root_dnsmasq || return 1
  out="$(mktemp)" || return 1

  local u1="$UPSTREAM_1" u2="$UPSTREAM_2"
  if [ -s "$STATE_DIR/upstreams" ]; then
    local line1 line2
    line1="$(sed -n '1p' "$STATE_DIR/upstreams" 2>/dev/null | tr -d '[:space:]')"
    line2="$(sed -n '2p' "$STATE_DIR/upstreams" 2>/dev/null | tr -d '[:space:]')"
    valid_upstream "$line1" && u1="$line1"
    valid_upstream "$line2" && u2="$line2"
  fi

  # Создаем файл журнала с правами 0644 для доступа GUI без root
  $SUDO touch "$QUERY_LOG" 2>/dev/null || touch "$QUERY_LOG" 2>/dev/null || true
  $SUDO chmod 0644 "$QUERY_LOG" 2>/dev/null || chmod 0644 "$QUERY_LOG" 2>/dev/null || true

  cat > "$out" <<EOF
# adblock-dns v$VERSION — $(date '+%Y-%m-%d %H:%M')
# Конфигурация локального DNS-фильтра dnsmasq

port=53
listen-address=127.0.0.1
bind-interfaces
no-resolv
no-poll

domain-needed
bogus-priv

cache-size=10000

# Журнал запросов — источник данных для «Инспектора трафика».
log-queries
log-async=25
log-facility=$QUERY_LOG

server=$u1
server=$u2

EOF

  # Добавляем белый список (перенаправление на апстрим без блокировки)
  if [ -s "$WHITELIST_FILE" ]; then
    printf '\n# Пользовательский белый список\n' >> "$out"
    # Строки проверяются и здесь: файл мог остаться от версии без проверки
    # ввода, и одна мусорная строка валила бы весь конфиг.
    while IFS= read -r wdom; do
      wdom="$(echo "$wdom" | tr -d '[:space:]')"
      valid_domain "$wdom" || continue
      printf 'server=/%s/%s\n' "$wdom" "$u1" >> "$out"
    done < "$WHITELIST_FILE"
  fi

  # Добавляем черный список
  if [ -s "$BLACKLIST_FILE" ]; then
    printf '\n# Пользовательский черный список\n' >> "$out"
    while IFS= read -r bdom; do
      bdom="$(echo "$bdom" | tr -d '[:space:]')"
      valid_domain "$bdom" || continue
      printf 'address=/%s/#\n' "$bdom" >> "$out"
    done < "$BLACKLIST_FILE"
  fi

  # Блокировка браузерного DoH.
  #
  # Ключевая строка — первая: домен-канарейка. Firefox проверяет его перед
  # включением своего DoH и выключает DoH сам, если тот не резолвится.
  # Нужен именно NXDOMAIN, поэтому форма `address=/домен/` без адреса:
  # `address=/домен/0.0.0.0` даёт NOERROR, и канарейка не срабатывает.
  #
  # Адрес текущего провайдера сюда намеренно не входит: режим «автоматически»
  # у Chromium повышает соединение до DoH того же провайдера, фильтрация при
  # этом сохраняется, и мешать этому смысла нет.
  if [ -f "$DOH_MARK" ]; then
    printf '\n# Блокировка стороннего DNS-over-HTTPS\n' >> "$out"
    local d
    for d in use-application-dns.net \
             mozilla.cloudflare-dns.com chrome.cloudflare-dns.com \
             cloudflare-dns.com one.one.one.one \
             dns.google dns64.dns.google \
             doh.opendns.com doh.familyshield.opendns.com \
             dns.quad9.net dns9.quad9.net dns11.quad9.net \
             dns.nextdns.io doh.cleanbrowsing.org \
             doh.dns.sb dns.alidns.com doh.360.cn; do
      printf 'address=/%s/\n' "$d" >> "$out"
    done
  fi

  # Если включено разделение зон с Tailscale, локальный резолвер тоже должен
  # уметь отдать tailnet-имена: /etc/resolver перехватывает не все обращения,
  # программа может спросить 127.0.0.1 напрямую.
  if [ -f "$TS_MARK" ]; then
    printf '\n# Зона Tailscale\nserver=/ts.net/%s\n' "$TS_DNS" >> "$out"
  fi

  effective_blocklist="$blocklist"
  if [ -f "$blocklist" ]; then
    if [ -s "$WHITELIST_FILE" ]; then
      effective_blocklist="${blocklist%.conf}.active.conf"
      # Исключаем домены из белого списка из активной базы правил dnsmasq
      awk 'NR==FNR { sub(/[[:space:]]+$/, "", $1); if ($1 != "") w[$1]=1; next } {
        n = split($0, a, "/")
        if (n >= 2 && a[2] in w) next
        print
      }' "$WHITELIST_FILE" "$blocklist" > "$effective_blocklist" 2>/dev/null || effective_blocklist="$blocklist"
    fi
    printf '\nconf-file=%s\n' "$effective_blocklist" >> "$out"
  fi

  if ! "$DNSMASQ_RUN" --test --conf-file="$out" >/dev/null 2>&1; then
    rm -f "$out"
    return 1
  fi
  $SUDO mkdir -p "$(dirname "$conf")" 2>/dev/null
  $SUDO cp "$out" "$conf.new" && $SUDO chmod 0644 "$conf.new" && $SUDO mv -f "$conf.new" "$conf"
  local rc=$?
  rm -f "$out"
  return $rc
}

# Применяет новый конфиг. Служба, поставленная прежней версией, запускает
# dnsmasq и конфиг из каталога Homebrew — её переставляем целиком, иначе она
# так и осталась бы на файлах, доступных пользователю на запись.
reload_service() {
  if [ -f "$DNS_PLIST" ] && ! grep -qF "$DNSMASQ_RUN" "$DNS_PLIST"; then
    install_root_dnsmasq || return 1
    migrate_legacy_blocklist && write_conf
    start_service
    return
  fi
  $SUDO launchctl kickstart -k "system/$DNS_LABEL" >/dev/null 2>&1
}

# Перенос базы из каталога Homebrew, где её держали прежние версии. Файл там
# доступен пользователю на запись, поэтому он проходит тот же фильтр, что и
# скачанный список: в root-конфиг попадают только блокирующие строки.
migrate_legacy_blocklist() {
  [ -s "$(blocklist_path)" ] && return 0
  [ -n "$BREW_PREFIX" ] || find_brew || return 1
  local legacy="$BREW_PREFIX/etc/adblock-dns/blocklist.conf" tmp
  [ -s "$legacy" ] || return 1
  tmp="$(mktemp)" || return 1
  if convert_list "$legacy" "$tmp"; then
    $SUDO cp "$tmp" "$(blocklist_path)" && $SUDO chmod 0644 "$(blocklist_path)"
  fi
  rm -f "$tmp"
  [ -s "$(blocklist_path)" ]
}

stop_service() {
  $SUDO launchctl bootout "system/$DNS_LABEL" >/dev/null 2>&1
  $SUDO launchctl unload -w "$DNS_PLIST" >/dev/null 2>&1
  return 0
}

# Служба dnsmasq из `brew services` останавливается через launchctl, а не
# вызовом brew: brew — скрипт в каталоге пользователя, и запуск его от root
# исполнял бы файл, который может переписать любой процесс пользователя.
stop_brew_service() {
  $SUDO launchctl bootout system/homebrew.mxcl.dnsmasq >/dev/null 2>&1
  return 0
}

start_service() {
  stop_brew_service
  stop_service
  $SUDO tee "$DNS_PLIST" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$DNS_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$DNSMASQ_RUN</string>
    <string>--keep-in-foreground</string>
    <string>--conf-file=$(conf_path)</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>/var/log/adblock-dns.log</string>
</dict>
</plist>
EOF
  $SUDO chown root:wheel "$DNS_PLIST" 2>/dev/null
  $SUDO chmod 644 "$DNS_PLIST"
  $SUDO launchctl bootstrap system "$DNS_PLIST" >/dev/null 2>&1 || \
  $SUDO launchctl load -w "$DNS_PLIST" >/dev/null 2>&1 || return 1
  sleep 2
  pgrep -x dnsmasq >/dev/null 2>&1
}

install_updater() {
  $SUDO mkdir -p "$(dirname "$LIBEXEC")" 2>/dev/null
  # Через помощника скрипт и так запущен из $LIBEXEC. Копирование файла в
  # самого себя завершалось ошибкой, и фоновое обновление не ставилось вовсе.
  if [ "$SELF" != "$LIBEXEC" ]; then
    $SUDO install -o root -g wheel -m 0755 "$SELF" "$LIBEXEC" 2>/dev/null || return 1
  fi
  $SUDO tee "$UPD_PLIST" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$UPD_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$LIBEXEC</string>
    <string>--update</string>
  </array>
  <key>StartInterval</key><integer>604800</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>/var/log/adblock-dns-update.log</string>
  <key>StandardErrorPath</key><string>/var/log/adblock-dns-update.log</string>
</dict>
</plist>
EOF
  $SUDO chown root:wheel "$UPD_PLIST" 2>/dev/null
  $SUDO chmod 644 "$UPD_PLIST"
  $SUDO launchctl bootout "system/$UPD_LABEL" >/dev/null 2>&1
  $SUDO launchctl bootstrap system "$UPD_PLIST" >/dev/null 2>&1 || \
  $SUDO launchctl load -w "$UPD_PLIST" >/dev/null 2>&1 || return 1
  return 0
}

# ─────────── КОМАНДЫ УПРАВЛЕНИЯ ───────────

# Фактический резолвер, который система реально использует для обычных запросов
# (resolver #1 из scutil). Именно он решает, работает фильтрация или нет —
# networksetup может быть настроен как угодно, но VPN-клиент или утилита с
# собственным резолвером перебивает его по приоритету.
effective_resolver() {
  scutil --dns 2>/dev/null | awk '
    /^resolver #1$/ { inres = 1; next }
    inres && /^resolver #/ { exit }
    inres && /nameserver\[0\]/ && ns == "" { ns = $3 }
    inres && /if_index/ { iface = $NF; gsub(/[()]/, "", iface) }
    END { printf "%s|%s", ns, iface }
  '
}

# Кто именно перехватил резолвер — по адресу и интерфейсу.
override_source() {
  local ns="$1" iface="$2"
  case "$ns" in
    100.100.100.100) printf 'Tailscale MagicDNS'; return ;;
    127.0.0.1|::1)   printf 'локальный резолвер на этом Mac'; return ;;
  esac
  case "$iface" in
    utun*|ipsec*|ppp*) printf 'VPN-туннель (%s)' "$iface"; return ;;
    "")                printf 'неизвестный источник'; return ;;
  esac
  printf 'интерфейс %s' "$iface"
}

# Профиль по фактически прописанным DNS-серверам, а не по файлу состояния.
# Файл в /usr/local/share мог остаться от прошлой настройки, и приложение
# показывало «Пользовательский DNS», когда в системе стоял AdGuard.
detect_profile_from_dns() {
  case " $1 " in
    *" 94.140.14.14 "*|*" 94.140.15.15 "*)   printf 'adguard' ;;
    *" 94.140.14.15 "*|*" 94.140.15.16 "*)   printf 'adguard_family' ;;
    *" 1.1.1.2 "*|*" 1.0.0.2 "*)             printf 'cloudflare_security' ;;
    *" 1.1.1.3 "*|*" 1.0.0.3 "*)             printf 'cloudflare_family' ;;
    *" 9.9.9.9 "*|*" 149.112.112.112 "*)     printf 'quad9' ;;
    *" 194.242.2.3 "*)                       printf 'mullvad' ;;
    *" 127.0.0.1 "*)                         printf 'local_dnsmasq' ;;
    *)                                       printf '' ;;
  esac
}

# ─────────── DoH В БРАУЗЕРАХ ───────────
#
# Браузер со своим DNS-over-HTTPS не виден никакому системному резолверу:
# запросы уходят по HTTPS на 443 порт. Ни разделение зон, ни NEDNSSettingsManager
# тут не помогают — перехватывать нечего. Единственное, что можно честно
# сделать без вмешательства в чужие настройки, — заметить это и сказать.
cmd_doh_status_json() {
  command -v python3 >/dev/null 2>&1 || { printf '[]\n'; return 0; }
  python3 - "$HOME" <<'PYDOH'
import json, os, re, sys, glob

home = sys.argv[1]
out = []

# Chromium-семейство хранит настройку в Local State.
# mode: "off" | "automatic" | "secure".
#   automatic — повышение до DoH ТОГО ЖЕ провайдера, фильтрация выживает;
#   secure    — жёстко заданный адрес, мимо системного резолвера.
CHROMIUM = [
    ("Google Chrome", "Google/Chrome/Local State"),
    ("Chrome Beta",   "Google/Chrome Beta/Local State"),
    ("Microsoft Edge","Microsoft Edge/Local State"),
    ("Brave",         "BraveSoftware/Brave-Browser/Local State"),
    ("Yandex",        "Yandex/YandexBrowser/Local State"),
    ("Vivaldi",       "Vivaldi/Local State"),
]

for name, rel in CHROMIUM:
    path = os.path.join(home, "Library/Application Support", rel)
    if not os.path.exists(path):
        continue
    mode, template = "unset", ""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
        doh = data.get("dns_over_https", {}) or {}
        mode = doh.get("mode") or "unset"
        template = doh.get("templates") or ""
    except Exception:
        pass
    bypasses = (mode == "secure")
    out.append({"browser": name, "installed": True, "mode": mode,
                "endpoint": template, "bypasses": bypasses})

# Firefox: network.trr.mode в prefs.js каждого профиля.
#   0 — по умолчанию (выкл), 2 — DoH с откатом, 3 — только DoH, 5 — выключено явно.
ff_modes = []
for prefs in glob.glob(os.path.join(home, "Library/Application Support/Firefox/Profiles/*/prefs.js")):
    try:
        text = open(prefs, "r", encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    m = re.search(r'user_pref\("network\.trr\.mode",\s*(\d+)\)', text)
    ff_modes.append(int(m.group(1)) if m else 0)

if os.path.exists(os.path.join(home, "Library/Application Support/Firefox")):
    worst = max(ff_modes) if ff_modes else 0
    label = {0: "off", 2: "doh-first", 3: "doh-only", 5: "off"}.get(worst, "mode-%d" % worst)
    out.append({"browser": "Firefox", "installed": True, "mode": label,
                "endpoint": "", "bypasses": worst in (2, 3)})

print(json.dumps(out, ensure_ascii=False))
PYDOH
}

doh_block_apply() {
  # Правила живут в конфиге dnsmasq, поэтому нужен локальный режим.
  if [ "$(get_mode)" = "full" ] && install_root_dnsmasq; then
    write_conf && reload_service
    flush_dns
    return 0
  fi
  return 1
}

cmd_doh_block_on() {
  [ "$(id -u)" -eq 0 ] || { fail "Требуются права администратора"; return 1; }
  mkdir -p "$STATE_DIR" 2>/dev/null
  : > "$DOH_MARK"
  if doh_block_apply; then
    ok "Сторонний DoH заблокирован"
  else
    warn "Отметка сохранена, но правила применятся только в локальном режиме"
  fi
  return 0
}

cmd_doh_block_off() {
  [ "$(id -u)" -eq 0 ] || { fail "Требуются права администратора"; return 1; }
  rm -f "$DOH_MARK"
  doh_block_apply >/dev/null 2>&1
  ok "Блокировка стороннего DoH выключена"
  return 0
}

# ─────────── СОВМЕСТНАЯ РАБОТА С TAILSCALE ───────────
#
# Tailscale прописывает свой резолвер через API сетевых расширений и получает
# в scutil приоритет выше, чем даёт networksetup. Соперничать с ним бесполезно:
# два перехватчика DNS всегда дерутся. Вместо этого разделяем зоны —
# имена tailnet уходят в Tailscale, всё остальное фильтруется нами.
#
# Делается это средствами самой macOS: файл в /etc/resolver/<домен> задаёт
# резолвер для конкретной зоны. Локальный dnsmasq для этого не нужен —
# схема работает и на облачном профиле.

TS_BIN=""
find_tailscale() {
  local p
  for p in /Applications/Tailscale.app/Contents/MacOS/Tailscale \
           /usr/local/bin/tailscale /opt/homebrew/bin/tailscale; do
    [ -x "$p" ] && TS_BIN="$p" && return 0
  done
  TS_BIN="$(command -v tailscale 2>/dev/null || true)"
  [ -n "$TS_BIN" ]
}

# Резолв через системный стек, а не через dig.
# dig читает /etc/resolv.conf напрямую и правила из /etc/resolver игнорирует —
# проверять им результат было бы бессмысленно.
resolve_system() {
  dscacheutil -q host -a name "$1" 2>/dev/null | awk '/^ip_address: /{print $2; exit}'
}

ts_self_name() {
  [ -n "$TS_BIN" ] || return 1
  "$TS_BIN" status --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))
except Exception:
    pass
' 2>/dev/null
}

cmd_tailscale_status_json() {
  local installed=false running=false suffix="" self_name="" accept=false split=false
  if find_tailscale; then
    installed=true
    self_name="$(ts_self_name)"
    [ -n "$self_name" ] && running=true
    suffix="$(printf '%s' "$self_name" | cut -d. -f2-)"
    if "$TS_BIN" debug prefs 2>/dev/null | grep -q '"CorpDNS": *true'; then accept=true; fi
  fi
  [ -f "$TS_MARK" ] && [ -f "$TS_RESOLVER" ] && split=true

  cat <<EOF
{
  "installed": $installed,
  "running": $running,
  "suffix": "$suffix",
  "selfName": "$self_name",
  "acceptDNS": $accept,
  "splitEnabled": $split
}
EOF
}

ts_split_teardown() {
  rm -f "$TS_RESOLVER" "$TS_MARK" 2>/dev/null
  [ -n "$TS_BIN" ] && "$TS_BIN" set --accept-dns=true >/dev/null 2>&1
  flush_dns
}

cmd_tailscale_split_on() {
  [ "$(id -u)" -eq 0 ] || { fail "Требуются права администратора"; return 1; }
  find_tailscale || { fail "Tailscale не установлен"; return 1; }

  local self_name
  self_name="$(ts_self_name)"
  [ -n "$self_name" ] || { fail "Tailscale не запущен"; return 1; }

  mkdir -p "$RESOLVER_DIR" "$STATE_DIR" 2>/dev/null
  printf 'nameserver %s\n' "$TS_DNS" > "$TS_RESOLVER"
  chmod 644 "$TS_RESOLVER"
  printf '%s\n' "$self_name" > "$TS_MARK"

  "$TS_BIN" set --accept-dns=false >/dev/null 2>&1
  flush_dns
  sleep 2

  # Проверяем результат, а не рапортуем об успехе по факту записи файла.
  # Если имена tailnet перестали резолвиться — откатываемся сами, чтобы не
  # оставить человека без доступа к своим машинам.
  local ip
  ip="$(resolve_system "$self_name")"
  case "$ip" in
    100.*)
      ok "Разделение зон включено: $self_name → $ip"
      return 0
      ;;
  esac

  ts_split_teardown
  fail "Имена tailnet перестали резолвиться — настройки возвращены как были"
  return 1
}

cmd_tailscale_split_off() {
  [ "$(id -u)" -eq 0 ] || { fail "Требуются права администратора"; return 1; }
  find_tailscale
  ts_split_teardown
  ok "Разделение зон выключено, Tailscale снова управляет DNS"
  return 0
}

# Реальные DNS-запросы из журнала dnsmasq.
# Работает только в локальном режиме (профиль «Локальный dnsmasq»): облачные
# резолверы журнал на этой машине не ведут.
# Перезапуск локального резолвера.
# В интерфейсе кнопка «Перезапустить службу» была подписана верно,
# но выполняла лишь обновление статуса.
cmd_restart_service() {
  if ! install_root_dnsmasq; then
    fail "dnsmasq не установлен (brew install dnsmasq)"
    return 1
  fi
  if [ "$(get_mode)" != "full" ]; then
    warn "Локальный режим не активен — перезапускать нечего"
    return 1
  fi
  stop_service
  if start_service; then
    flush_dns
    ok "Локальный резолвер dnsmasq перезапущен"
    return 0
  fi
  fail "Не удалось перезапустить dnsmasq"
  return 1
}

cmd_query_log_json() {
  local limit="${1:-200}"
  # Только число и до проверки журнала. Значение подставлялось в $(( )), а
  # bash вычисляет строку в арифметике как выражение: `a[$(команда)]`
  # выполнял команду от root через беспарольный помощник.
  case "$limit" in
    ""|*[!0-9]*) printf '[]\n'; return 2 ;;
  esac
  limit=$((10#$limit))
  [ "$limit" -ge 1 ] && [ "$limit" -le 2000 ] || { printf '[]\n'; return 2; }
  if [ ! -r "$QUERY_LOG" ]; then
    printf '[]\n'
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf '[]\n'
    return 0
  fi

  tail -n $(( limit * 6 )) "$QUERY_LOG" 2>/dev/null | python3 -c '
import sys, re, json, time, calendar

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 200

AD_HINTS      = ("ads", "adservice", "doubleclick", "adsystem", "adnxs", "pagead",
                 "googlesyndication", "adriver", "criteo", "taboola", "outbrain")
TRACK_HINTS   = ("analytics", "metrika", "metrics", "pixel", "track", "stat",
                 "segment", "mixpanel", "hotjar", "matomo", "mc.yandex",
                 "counter", "collect", "an.yandex")
TELEM_HINTS   = ("telemetry", "app-measurement", "crashlytics", "sentry",
                 "diagnostic", "beacon")

def category(domain, blocked):
    d = domain.lower()
    if any(h in d for h in AD_HINTS):    return "ad"
    if any(h in d for h in TRACK_HINTS): return "tracker"
    if any(h in d for h in TELEM_HINTS): return "telemetry"
    return "ad" if blocked else "safe"

MONTHS = {m: i + 1 for i, m in enumerate(
    ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"])}

def parse_ts(mon, day, clock):
    try:
        h, mi, sec = (int(x) for x in clock.split(":"))
        now = time.localtime()
        year = now.tm_year
        t = calendar.timegm((year, MONTHS[mon], int(day), h, mi, sec, 0, 0, 0))
        t -= time.timezone if not time.localtime().tm_isdst else time.altzone
        # Запись из будущего означает, что журнал перешагнул новый год.
        if t > time.time() + 86400:
            t -= 365 * 86400
        return t
    except Exception:
        return time.time()

LINE = re.compile(
    r"^(?P<mon>[A-Z][a-z]{2})\s+(?P<day>\d+)\s+(?P<clock>\d{2}:\d{2}:\d{2}).*?"
    r"dnsmasq\[\d+\]:\s+(?P<rest>.*)$")

pending = {}   # domain -> query record awaiting its answer
done = []

for raw in sys.stdin:
    m = LINE.match(raw.rstrip())
    if not m:
        continue
    rest = m.group("rest")
    ts = parse_ts(m.group("mon"), m.group("day"), m.group("clock"))

    q = re.match(r"query\[(?P<qt>[A-Z0-9]+)\]\s+(?P<dom>\S+)\s+from\s+(?P<cli>\S+)", rest)
    if q:
        pending[q.group("dom")] = {
            "domain": q.group("dom"),
            "clientIp": q.group("cli"),
            "queryType": q.group("qt"),
            "t0": ts,
        }
        continue

    a = re.match(r"(?P<verb>config|cached|forwarded|reply)\s+(?P<dom>\S+)\s+(?:is|to)\s+(?P<val>\S+)", rest)
    if not a:
        continue
    verb, dom, val = a.group("verb"), a.group("dom"), a.group("val")
    rec = pending.pop(dom, None)
    if rec is None:
        continue
    if verb == "forwarded":
        pending[dom] = rec          # ответ ещё впереди
        continue

    blocked = verb == "config" and val in ("0.0.0.0", "<CNAME>", "NXDOMAIN", "::")
    status = "blocked" if blocked else ("cached" if verb == "cached" else "allowed")
    latency = max(0, int(round((ts - rec["t0"]) * 1000)))
    done.append({
        "id": "%s-%d-%d" % (dom, int(rec["t0"]), len(done)),
        "domain": dom,
        "clientIp": rec["clientIp"],
        "queryType": rec["queryType"],
        "status": status,
        "category": category(dom, blocked),
        "latencyMs": latency,
        "timestamp": rec["t0"],
    })

done.reverse()
print(json.dumps(done[:LIMIT], ensure_ascii=False))
' "$limit"
}

# `--brief` опрашивает одну службу вместо всех и не отдаёт их список.
#
# Опрос одиннадцати служб стоит около 210 мс из 340, а вызывается статус раз
# в восемь секунд. Для определения профиля и перехвата хватает любой службы —
# приложение прописывает один и тот же DNS на все, — а полный список нужен
# только вкладке «Инструменты» и обновляется по требованию.
# Профиль по фактически прописанным DNS, с откатом на файл состояния.
effective_profile() {
  local all detected svc srvs
  all=""
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    srvs="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ')"
    case "$srvs" in
      *"aren't any DNS Servers"*|*"not a recognized"*) : ;;
      *) all="$all $srvs" ;;
    esac
  done < <(active_services)
  [ -z "$all" ] && { printf 'off'; return; }
  detected="$(detect_profile_from_dns "$all")"
  [ -n "$detected" ] && printf '%s' "$detected" || get_profile
}

cmd_status_json() {
  local brief=""
  [ "${1:-}" = "--brief" ] && brief="1"
  local mode prof running domains updated blocked probe ping_ms dns_list wcount bcount
  local all_servers eff eff_ns eff_iface overridden override_from detected
  mode="$(get_mode)"
  prof="$(get_profile)"
  
  running="false"
  pgrep -x dnsmasq >/dev/null 2>&1 && running="true"
  
  domains=0; updated=""
  if [ -f "$(blocklist_path)" ]; then
    domains="$(wc -l < "$(blocklist_path)" | tr -d ' ')"
    updated="$(date -r "$(blocklist_path)" '+%d.%m.%Y %H:%M' 2>/dev/null)"
  fi

  # Проба идёт через системный резолвер — то есть проверяет ровно тот путь,
  # которым ходят браузер и приложения.
  probe="$(resolve_a doubleclick.net)"
  if [ -z "$probe" ] || [ "$probe" = "0.0.0.0" ]; then blocked="true"; else blocked="false"; fi

  # DNS по сервисам
  all_servers=""
  if [ -n "$brief" ]; then
    # Опрашиваем службы по порядку и останавливаемся на первой, где DNS задан.
    # Брать буквально первую нельзя: список начинается не с используемого
    # интерфейса, и служба на DHCP заставила бы сообщить «защита выключена»,
    # когда она включена на остальных. В обычном случае это один вызов.
    dns_list="null"
    local svc srvs
    while IFS= read -r svc; do
      [ -z "$svc" ] && continue
      srvs="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
      case "$srvs" in
        ""|*"aren't any DNS Servers"*|*"not a recognized"*) continue ;;
        *) all_servers=" $srvs"; break ;;
      esac
    done < <(active_services)
  else
    dns_list="["
    local first=1
    while IFS= read -r svc; do
      [ -z "$svc" ] && continue
      local srvs
      srvs="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
      case "$srvs" in
        ""|*"aren't any DNS Servers"*|*"not a recognized"*) srvs="DHCP (авто)" ;;
        *) all_servers="$all_servers $srvs" ;;
      esac
      [ "$first" -eq 0 ] && dns_list="$dns_list,"
      dns_list="$dns_list{\"service\":\"$svc\",\"servers\":\"$srvs\"}"
      first=0
    done < <(active_services)
    dns_list="$dns_list]"
  fi

  # Профиль: сначала по факту, файл состояния — только как запасной вариант.
  detected="$(detect_profile_from_dns "$all_servers")"
  [ -n "$detected" ] && prof="$detected"
  if [ -z "$all_servers" ]; then
    mode="off"
    prof="off"
  fi

  # Перехват резолвера
  eff="$(effective_resolver)"
  eff_ns="${eff%%|*}"
  eff_iface="${eff##*|}"
  overridden="false"
  override_from=""
  if [ -n "$eff_ns" ] && [ -n "$all_servers" ]; then
    case " $all_servers " in
      *" $eff_ns "*) overridden="false" ;;
      *) overridden="true"; override_from="$(override_source "$eff_ns" "$eff_iface")" ;;
    esac
  fi

  # Пинг измеряем по фактическому резолверу, а не по предполагаемому.
  local test_ip="$eff_ns"
  if [ -z "$test_ip" ]; then
    test_ip="1.1.1.1"
    if [ "$mode" = "full" ]; then test_ip="127.0.0.1"
    elif [ "$mode" = "quick" ]; then test_ip="94.140.14.14"
    fi
  fi
  ping_ms="$(measure_dns_ping "$test_ip")"

  wcount=0; [ -s "$WHITELIST_FILE" ] && wcount="$(wc -l < "$WHITELIST_FILE" | tr -d ' ')"
  bcount=0; [ -s "$BLACKLIST_FILE" ] && bcount="$(wc -l < "$BLACKLIST_FILE" | tr -d ' ')"

  cat <<EOF
{
  "version": "$VERSION",
  "mode": "$mode",
  "profile": "$prof",
  "running": $running,
  "domains": $domains,
  "updated": "$updated",
  "blocked": $blocked,
  "probe": "${probe:-none}",
  "pingMs": ${ping_ms:--1},
  "whitelistCount": $wcount,
  "blacklistCount": $bcount,
  "effectiveResolver": "$eff_ns",
  "effectiveInterface": "$eff_iface",
  "dnsOverridden": $overridden,
  "dohBlocking": $([ -f "$DOH_MARK" ] && printf 'true' || printf 'false'),
  "overrideSource": "$override_from",
  "services": $dns_list
}
EOF
}

cmd_status() {
  local mode dns running domains updated blocked probe
  mode="$(get_mode)"
  dns=""
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    dns="$dns$svc: $(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ' | sed 's/There aren.t any DNS Servers set on.*/авто (от роутера)/')|"
  done < <(active_services)
  running=no; pgrep -x dnsmasq >/dev/null 2>&1 && running=yes
  domains=0; updated=""
  if [ -f "$(blocklist_path)" ]; then
    domains="$(wc -l < "$(blocklist_path)" | tr -d ' ')"
    updated="$(date -r "$(blocklist_path)" '+%d.%m.%Y %H:%M' 2>/dev/null)"
  fi
  probe="$(resolve_a doubleclick.net)"
  if [ -z "$probe" ] || [ "$probe" = "0.0.0.0" ]; then blocked=yes; else blocked=no; fi
  printf 'mode=%s\n' "$mode"
  # По факту, а не по файлу состояния: он мог остаться от прошлой настройки,
  # и текстовый вывод показывал «Пользовательский DNS», когда в системе стоял
  # AdGuard. JSON это уже умел — теперь и текст.
  printf 'profile=%s\n' "$(effective_profile)"
  printf 'dns=%s\n' "$dns"
  printf 'running=%s\n' "$running"
  printf 'domains=%s\n' "$domains"
  printf 'updated=%s\n' "$updated"
  printf 'blocked=%s\n' "$blocked"
  if [ -f "$DNS_PLIST" ]; then printf 'installed=yes\n'; else printf 'installed=no\n'; fi
  printf 'probe=%s\n' "${probe:-нет ответа}"
}

cmd_status_text() {
  local s mode blocked running domains updated prof
  s="$(cmd_status)"
  mode="$(printf '%s' "$s"  | sed -n 's/^mode=//p')"
  prof="$(printf '%s' "$s"  | sed -n 's/^profile=//p')"
  blocked="$(printf '%s' "$s" | sed -n 's/^blocked=//p')"
  running="$(printf '%s' "$s" | sed -n 's/^running=//p')"
  domains="$(printf '%s' "$s" | sed -n 's/^domains=//p')"
  updated="$(printf '%s' "$s" | sed -n 's/^updated=//p')"
  case "$prof" in
    adguard|quick)       printf 'Профиль: Облачный AdGuard DNS\n' ;;
    adguard_family)      printf 'Профиль: Облачный AdGuard Семейный\n' ;;
    cloudflare_security) printf 'Профиль: Cloudflare 1.1.1.2 (Security)\n' ;;
    cloudflare_family)   printf 'Профиль: Cloudflare 1.1.1.3 (Family)\n' ;;
    quad9)               printf 'Профиль: Quad9 Security (9.9.9.9)\n' ;;
    mullvad)             printf 'Профиль: Mullvad AdBlock DNS\n' ;;
    local_dnsmasq|full)  printf 'Профиль: Локальный dnsmasq (на этом Mac)\n' ;;
    custom)              printf 'Профиль: Пользовательский DNS\n' ;;
    *)                   printf 'Режим: Защита выключена\n' ;;
  esac
  if [ "$blocked" = yes ]; then printf 'Блокировка рекламы: активна ✓\n'; else printf 'Блокировка рекламы: НЕ активна ✗\n'; fi
  if [ "$mode" = full ] || [ "$prof" = local_dnsmasq ]; then
    if [ "$running" = yes ]; then printf 'Служба dnsmasq: работает\n'; else printf 'Служба dnsmasq: остановлена\n'; fi
    [ "$domains" != 0 ] && printf 'В базе: %s доменов (обновлено: %s)\n' "$domains" "$updated"
  fi
  printf '\nDNS по подключениям:\n'
  printf '%s' "$s" | sed -n 's/^dns=//p' | tr '|' '\n' | sed '/^$/d;s/^/  · /'
}

cmd_apply_profile() {
  local p="${1:-adguard}"
  local custom="${2:-}"
  backup_dns

  case "$p" in
    adguard|quick)
      apply_dns "$ADGUARD_DNS" || return 1
      set_mode quick adguard
      ;;
    adguard_family)
      apply_dns "$ADGUARD_FAMILY_DNS" || return 1
      set_mode quick adguard_family
      ;;
    cloudflare_security)
      apply_dns "$CLOUDFLARE_SEC_DNS" || return 1
      set_mode quick cloudflare_security
      ;;
    cloudflare_family)
      apply_dns "$CLOUDFLARE_FAM_DNS" || return 1
      set_mode quick cloudflare_family
      ;;
    quad9)
      apply_dns "$QUAD9_DNS" || return 1
      set_mode quick quad9
      ;;
    mullvad)
      apply_dns "$MULLVAD_DNS" || return 1
      set_mode quick mullvad
      ;;
    custom)
      if [ -n "$custom" ]; then
        apply_dns "$custom" || return 1
        $SUDO mkdir -p "$STATE_DIR"
        local clean_custom
        clean_custom="$(printf '%s' "$custom" | tr ',' ' ' | tr ';' ' ' | xargs)"
        printf '%s\n' "$clean_custom" | $SUDO tee "$CUSTOM_DNS_FILE" >/dev/null
      fi
      set_mode quick custom
      ;;
    local_dnsmasq|full)
      cmd_apply_full || return 1
      set_mode full local_dnsmasq
      ;;
    off)
      cmd_apply_off
      return 0
      ;;
    *)
      fail "Неизвестный профиль: $p"
      return 2
      ;;
  esac

  flush_dns
  ok "Применён профиль $p"
  return 0
}

cmd_prepare_full() {
  find_brew || { fail "Homebrew не найден"; return 3; }
  step "Проверяю dnsmasq"
  if [ -x "$DNSMASQ_BIN" ]; then ok "dnsmasq уже установлен"
  elif [ "$(id -u)" -eq 0 ]; then
    # brew от root не запускается, да и не должен: это скрипт, который может
    # переписать любой процесс пользователя.
    fail "dnsmasq не установлен — выполните без sudo: brew install dnsmasq"; return 1
  else
    "$BREW" install dnsmasq || { fail "не удалось установить dnsmasq"; return 1; }
    [ -x "$DNSMASQ_BIN" ] || { fail "dnsmasq не нашёлся после установки"; return 1; }
    ok "dnsmasq установлен"
  fi
  make_state_dir
  install_root_dnsmasq refresh || { fail "не удалось скопировать dnsmasq в $DNSMASQ_RUN"; return 1; }
  step "Скачиваю базу рекламных доменов"
  build_blocklist "$(blocklist_path)" || { fail "ни один список не скачался"; return 1; }
  step "Формирую конфигурацию"
  write_conf || { fail "конфиг не прошёл проверку"; return 1; }
  ok "конфиг записан и проверен"
  return 0
}

# Аргументов не принимает: путь к Homebrew из командной строки позволял
# запустить от root любой файл (см. conf_path).
cmd_apply_full() {
  find_brew || { fail "не нашёл Homebrew"; return 1; }
  [ -x "$DNSMASQ_BIN" ] || { fail "dnsmasq не установлен (brew install dnsmasq)"; return 1; }
  make_state_dir
  # Копия обновляется при каждом явном включении режима — так подхватывается
  # новая версия dnsmasq после `brew upgrade`.
  install_root_dnsmasq refresh || { fail "не удалось скопировать dnsmasq в $DNSMASQ_RUN"; return 1; }

  # Приложение включает режим одной этой командой и `--prepare-full` не
  # вызывает. Без этих шагов dnsmasq стартовал без базы и без конфига,
  # то есть ничего не блокировал.
  if [ ! -s "$(blocklist_path)" ]; then
    step "Скачиваю базу рекламных доменов"
    build_blocklist "$(blocklist_path)" || { fail "ни один список не скачался — настройки сети не изменены"; return 1; }
  fi
  write_conf || { fail "конфиг не прошёл проверку — настройки сети не изменены"; return 1; }

  step "Запускаю службу dnsmasq"
  start_service || { fail "служба не запустилась, лог: /var/log/adblock-dns.log"; return 1; }
  ok "dnsmasq запущен"

  step "Проверяю локальный резолвер"
  local good bad
  good="$(resolve_a apple.com 127.0.0.1)"
  bad="$(resolve_a doubleclick.net 127.0.0.1)"
  if [ -z "$good" ] || [ "$good" = "0.0.0.0" ]; then
    fail "локальный DNS не отвечает — настройки сети не изменены"
    stop_service; return 1
  fi
  ok "локальный резолвер отвечает штатно (apple.com → $good)"

  step "Переключаю системный DNS на 127.0.0.1"
  backup_dns
  apply_dns "127.0.0.1" || { fail "не удалось изменить DNS"; return 1; }
  flush_dns
  ok "DNS всех подключений переключен на 127.0.0.1"

  step "Настраиваю фоновое обновление базы"
  install_updater >/dev/null 2>&1

  set_mode full local_dnsmasq
  return 0
}

cmd_apply_quick() {
  cmd_apply_profile "adguard"
}

cmd_apply_off() {
  restore_dns
  stop_brew_service
  stop_service
  flush_dns
  $SUDO rm -f "$MODE_FILE" "$PROFILE_FILE"
  ok "прежний DNS возвращён, служба остановлена"
  return 0
}

cmd_apply_remove() {
  # Возвращаем Tailscale управление DNS до всего остального: иначе удаление
  # приложения оставило бы человека без MagicDNS и без объяснения, почему.
  if [ -f "$TS_MARK" ]; then
    find_tailscale
    ts_split_teardown
  fi
  rm -f "$DOH_MARK" 2>/dev/null
  restore_dns
  flush_dns
  $SUDO launchctl bootout "system/$UPD_LABEL" >/dev/null 2>&1
  $SUDO launchctl unload -w "$UPD_PLIST" >/dev/null 2>&1
  stop_service
  stop_brew_service
  $SUDO rm -f "$UPD_PLIST" "$DNS_PLIST" "$QUERY_LOG" /var/log/adblock-dns-update.log /var/log/adblock-dns.log
  $SUDO rm -rf "$(dirname "$DNSMASQ_RUN")"
  # Следы прежних версий, которые писали конфиг прямо в каталог Homebrew.
  if find_brew; then
    local legacy="$BREW_PREFIX/etc/dnsmasq.conf"
    [ -f "$legacy.adblock-backup" ] && mv -f "$legacy.adblock-backup" "$legacy" 2>/dev/null
    rm -rf "$BREW_PREFIX/etc/adblock-dns" 2>/dev/null || $SUDO rm -rf "$BREW_PREFIX/etc/adblock-dns"
  fi
  $SUDO rm -rf "$STATE_DIR"
  # Помощник удаляется вместе со всем остальным. Раньше обёртка и правило
  # sudoers оставались, хотя FAQ обещал полное удаление.
  remove_privileged_helper
  ok "DNS-блокировщик полностью удалён, настройки сети восстановлены"
  return 0
}

cmd_update() {
  install_root_dnsmasq || exit 1
  echo "[$(date '+%F %T')] Запуск обновления списка..."
  if build_blocklist "$(blocklist_path)"; then
    # Без проверенного конфига службу не трогаем: рабочий файл остался прежним.
    if ! write_conf; then
      echo "[$(date '+%F %T')] Конфиг не прошёл проверку, служба не перезапущена"; exit 1
    fi
    reload_service
    echo "[$(date '+%F %T')] Обновление успешно завершено"; exit 0
  fi
  echo "[$(date '+%F %T')] Ошибка обновления базы"; exit 1
}

# ─────────── ДИАГНОСТИКА И ТЕСТЫ ───────────

cmd_test_domains_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 <<'PYTEST'
import socket, json, concurrent.futures

# Ключ категории отдаётся отдельно от подписи, чтобы приложение могло
# перевести её. Раньше движок присылал только русский текст, и в английском
# режиме половина таблицы оставалась на русском.
DOMAINS = [
    ("doubleclick.net",               "google_ads"),
    ("pagead2.googlesyndication.com", "google_adsense"),
    ("an.yandex.ru",                  "yandex_direct"),
    ("mc.yandex.ru",                  "yandex_metrica"),
    ("ads.pubmatic.com",              "pubmatic"),
    ("connect.facebook.net",          "facebook_pixel"),
    ("analytics.tiktok.com",          "tiktok_analytics"),
    ("telemetry.microsoft.com",       "microsoft_telemetry"),
    ("scorecardresearch.com",         "comscore"),
    ("static.criteo.net",             "criteo"),
    ("adservice.google.com",          "google_adservice"),
    ("apple.com",                     "control_site")
]

RU_LABELS = {
    "google_ads": "Google Ads / Маркетинг",
    "google_adsense": "Google AdSense",
    "yandex_direct": "Яндекс Директ / РСЯ",
    "yandex_metrica": "Яндекс Метрика",
    "pubmatic": "Баннерная сеть PubMatic",
    "facebook_pixel": "Facebook Pixel / Трекер",
    "tiktok_analytics": "TikTok Аналитика",
    "microsoft_telemetry": "Телеметрия Microsoft",
    "comscore": "Comscore Трекинг",
    "criteo": "Criteo Ретаргетинг",
    "google_adservice": "Google Сервис рекламы",
    "control_site": "Контрольный обычный сайт",
}

def check(item):
    dom, key = item
    base = {
        "domain": dom,
        "category": RU_LABELS.get(key, key),
        "categoryKey": key,
        "isControl": dom == "apple.com",
        "failed": False,
    }
    try:
        ip = socket.gethostbyname(dom)
        blocked = ip in ("0.0.0.0", "127.0.0.1", "::", "")
        base.update({"blocked": blocked, "ip": ip if not blocked else "0.0.0.0"})
        return base
    except socket.gaierror as e:
        # Только «имя не найдено» означает блокировку. Таймаут, отсутствие
        # сети и прочие сбои раньше тоже засчитывались как блокировка, из-за
        # чего при выключенном интернете диагностика рапортовала 100 % защиты.
        name_not_found = e.errno in (socket.EAI_NONAME, socket.EAI_NODATA) if hasattr(socket, "EAI_NODATA") \
            else e.errno == socket.EAI_NONAME
        if name_not_found:
            base.update({"blocked": True, "ip": "NXDOMAIN"})
        else:
            base.update({"blocked": False, "failed": True, "ip": "ошибка сети"})
        return base
    except Exception:
        base.update({"blocked": False, "failed": True, "ip": "ошибка"})
        return base

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    results = list(ex.map(check, DOMAINS))

print(json.dumps(results, ensure_ascii=False))
PYTEST
    return
  fi
  echo "[]"
}

cmd_test_speed_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 <<'PYSPEED'
import time, socket, struct, random, json, concurrent.futures

PROVIDERS = [
    ("local", "Локальный dnsmasq", "127.0.0.1"),
    ("adguard", "AdGuard DNS", "94.140.14.14"),
    ("cloudflare", "Cloudflare 1.1.1.1", "1.1.1.1"),
    ("quad9", "Quad9 (9.9.9.9)", "9.9.9.9"),
    ("google", "Google DNS (8.8.8.8)", "8.8.8.8"),
    ("system", "Текущий системный DNS", "")
]

def ping_server(p):
    pid, name, srv = p
    times = []
    for _ in range(2):
        try:
            sub = f"p{random.randint(1000,9999)}"
            q = b"".join(bytes([len(part)]) + part.encode() for part in [sub, "cloudflare", "com"]) + b"\x00\x00\x01\x00\x01"
            if not srv:
                t0 = time.perf_counter()
                socket.gethostbyname(f"{sub}.apple.com")
                t1 = time.perf_counter()
                ms = int(round((t1 - t0) * 1000))
                times.append(max(1, ms))
            else:
                tid = random.randint(0, 65535)
                pkt = struct.pack(">HHHHHH", tid, 0x0100, 1, 0, 0, 0) + q
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.settimeout(1.5)
                t0 = time.perf_counter()
                s.sendto(pkt, (srv, 53))
                s.recvfrom(512)
                t1 = time.perf_counter()
                s.close()
                ms = int(round((t1 - t0) * 1000))
                times.append(max(1, ms))
        except Exception:
            pass
    ms = min(times) if times else -1
    return {"id": pid, "name": name, "server": srv or "Системный", "latencyMs": ms}

with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
    results = list(ex.map(ping_server, PROVIDERS))

print(json.dumps(results, ensure_ascii=False))
PYSPEED
    return
  fi
  echo "[]"
}

# ─────────── БЕЛЫЙ / ЧЕРНЫЙ СПИСКИ ───────────

# Проверка доменного имени.
# Пользовательские правила попадают прямо в dnsmasq.conf. Мусорная строка
# делала конфиг невалидным: `dnsmasq --test` падал, служба не перезапускалась,
# а при следующем старте локальный резолвер уже не поднимался.
# Вышестоящий DNS: IPv4 или IPv6, по желанию с портом через # (как пишет dnsmasq).
valid_upstream() {
  local a="${1:-}" host port="" o
  host="${a%%#*}"
  [ "$host" != "$a" ] && port="${a#*#}"
  if [ "$host" != "$a" ]; then
    case "$port" in ""|*[!0-9]*) return 1 ;; esac
    [ ${#port} -le 5 ] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || return 1
  fi
  case "$host" in
    *:*)
      case "$host" in *[!0-9a-fA-F:]*|*:::*) return 1 ;; esac
      [ ${#host} -le 39 ] || return 1
      return 0 ;;
    *[!0-9.]*|.*|*.|*..*) return 1 ;;
  esac
  local IFS=.
  # shellcheck disable=SC2086
  set -- $host
  [ $# -eq 4 ] || return 1
  for o in "$@"; do
    [ ${#o} -le 3 ] && [ "$o" -le 255 ] || return 1
  done
  return 0
}

valid_domain() {
  local d="$1"
  [ -n "$d" ] || return 1
  [ ${#d} -le 253 ] || return 1
  case "$d" in
    *[!a-zA-Z0-9.-]*) return 1 ;;   # только буквы, цифры, точка и дефис
    .*|*.|-*|*-)      return 1 ;;   # не начинается и не кончается точкой/дефисом
    *..*)             return 1 ;;   # без пустых меток
    *.*)              return 0 ;;   # минимум одна точка
    *)                return 1 ;;
  esac
}

# Удаление строки из списка без интерполяции в регулярное выражение sed:
# домен со слэшем ломал саму команду sed.
remove_domain_line() {
  local file="$1" dom="$2" tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp)"
  grep -vxF -- "$dom" "$file" > "$tmp" 2>/dev/null || true
  $SUDO cp "$tmp" "$file"
  rm -f "$tmp"
}

cmd_add_whitelist() {
  local dom="$1"
  dom="$(printf '%s' "$dom" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  if ! valid_domain "$dom"; then
    fail "Недопустимое доменное имя: «$1»"
    return 1
  fi
  $SUDO mkdir -p "$STATE_DIR"
  $SUDO touch "$WHITELIST_FILE"
  if ! grep -qxF -- "$dom" "$WHITELIST_FILE" 2>/dev/null; then
    printf '%s\n' "$dom" | $SUDO tee -a "$WHITELIST_FILE" >/dev/null
  fi
  if [ "$(get_mode)" = "full" ]; then
    write_conf && reload_service
  fi
  ok "Домен $dom добавлен в белый список"
}

cmd_remove_whitelist() {
  local dom="$1"
  [ -z "$dom" ] || [ ! -f "$WHITELIST_FILE" ] && return 0
  remove_domain_line "$WHITELIST_FILE" "$dom"
  if [ "$(get_mode)" = "full" ]; then
    write_conf && reload_service
  fi
  ok "Домен $dom удален из белого списка"
}

cmd_get_whitelist() {
  # Пустой список — это не ошибка. Прежняя форма возвращала код 1, когда файла
  # просто нет, и вызывающая сторона считала это сбоем чтения.
  [ -f "$WHITELIST_FILE" ] && cat "$WHITELIST_FILE"
  return 0
}

cmd_add_blacklist() {
  local dom="$1"
  dom="$(printf '%s' "$dom" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  if ! valid_domain "$dom"; then
    fail "Недопустимое доменное имя: «$1»"
    return 1
  fi
  $SUDO mkdir -p "$STATE_DIR"
  $SUDO touch "$BLACKLIST_FILE"
  if ! grep -qxF -- "$dom" "$BLACKLIST_FILE" 2>/dev/null; then
    printf '%s\n' "$dom" | $SUDO tee -a "$BLACKLIST_FILE" >/dev/null
  fi
  if [ "$(get_mode)" = "full" ]; then
    write_conf && reload_service
  fi
  ok "Домен $dom добавлен в черный список"
}

cmd_remove_blacklist() {
  local dom="$1"
  [ -z "$dom" ] || [ ! -f "$BLACKLIST_FILE" ] && return 0
  remove_domain_line "$BLACKLIST_FILE" "$dom"
  if [ "$(get_mode)" = "full" ]; then
    write_conf && reload_service
  fi
  ok "Домен $dom удален из черного списка"
}

cmd_get_blacklist() {
  # Пустой список — это не ошибка. Прежняя форма возвращала код 1, когда файла
  # просто нет, и вызывающая сторона считала это сбоем чтения.
  [ -f "$BLACKLIST_FILE" ] && cat "$BLACKLIST_FILE"
  return 0
}

# ─────────── ФУНКЦИОНАЛ VPN И ПРОКСИ ───────────

VPN_STATE_FILE="$STATE_DIR/vpn_state"

cmd_vpn_status_json() {
  local socks_enabled="false" http_enabled="false" socks_server="" socks_port="" http_server="" http_port=""
  local primary_svc
  primary_svc="$(active_services | head -1)"
  
  if [ -n "$primary_svc" ]; then
    local s_out h_out
    s_out="$(networksetup -getsocksfirewallproxy "$primary_svc" 2>/dev/null)"
    h_out="$(networksetup -getwebproxy "$primary_svc" 2>/dev/null)"
    
    if echo "$s_out" | grep -qi "Enabled: Yes"; then
      socks_enabled="true"
      socks_server="$(echo "$s_out" | awk '/Server:/ {print $2}')"
      socks_port="$(echo "$s_out" | awk '/Port:/ {print $2}')"
    fi
    
    if echo "$h_out" | grep -qi "Enabled: Yes"; then
      http_enabled="true"
      http_server="$(echo "$h_out" | awk '/Server:/ {print $2}')"
      http_port="$(echo "$h_out" | awk '/Port:/ {print $2}')"
    fi
  fi
  
  local vpn_active="false"
  if [ "$socks_enabled" = "true" ] || [ "$http_enabled" = "true" ]; then
    vpn_active="true"
  fi
  
  cat <<EOF
{
  "vpnActive": $vpn_active,
  "socksEnabled": $socks_enabled,
  "socksServer": "${socks_server:-}",
  "socksPort": "${socks_port:-}",
  "httpEnabled": $http_enabled,
  "httpServer": "${http_server:-}",
  "httpPort": "${http_port:-}"
}
EOF
}

cmd_apply_socks5_proxy() {
  local host="${1:-127.0.0.1}" port="${2:-10808}"
  local svc
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    $SUDO networksetup -setsocksfirewallproxy "$svc" "$host" "$port" >/dev/null 2>&1
    $SUDO networksetup -setsocksfirewallproxystate "$svc" on >/dev/null 2>&1
  done < <(active_services)
  ok "SOCKS5 прокси $host:$port включён"
}

cmd_apply_http_proxy() {
  local host="${1:-127.0.0.1}" port="${2:-8080}"
  local svc
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    $SUDO networksetup -setwebproxy "$svc" "$host" "$port" >/dev/null 2>&1
    $SUDO networksetup -setwebproxystate "$svc" on >/dev/null 2>&1
    $SUDO networksetup -setsecurewebproxy "$svc" "$host" "$port" >/dev/null 2>&1
    $SUDO networksetup -setsecurewebproxystate "$svc" on >/dev/null 2>&1
  done < <(active_services)
  ok "HTTP/HTTPS прокси $host:$port включён"
}

cmd_apply_proxy_off() {
  local svc
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    $SUDO networksetup -setsocksfirewallproxystate "$svc" off >/dev/null 2>&1
    $SUDO networksetup -setwebproxystate "$svc" off >/dev/null 2>&1
    $SUDO networksetup -setsecurewebproxystate "$svc" off >/dev/null 2>&1
  done < <(active_services)
  ok "Прокси и туннели отключены"
}

cmd_get_ip_info_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 <<'PYIP'
import urllib.request, json
try:
    req = urllib.request.Request(
        "https://ipinfo.io/json",
        headers={"User-Agent": "curl/7.64.1"}
    )
    with urllib.request.urlopen(req, timeout=3.0) as resp:
        data = json.loads(resp.read().decode())
        out = {
            "ip": data.get("ip", "Не определен"),
            "country": data.get("country", "??"),
            "city": data.get("city", "Не определен"),
            "org": data.get("org", "Провайдер")
        }
        print(json.dumps(out, ensure_ascii=False))
except Exception:
    try:
        req = urllib.request.Request("https://api.ipify.org?format=json")
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            data = json.loads(resp.read().decode())
            print(json.dumps({"ip": data.get("ip", "—"), "country": "WW", "city": "Онлайн", "org": "Интернет"}, ensure_ascii=False))
    except Exception:
        print(json.dumps({"ip": "—", "country": "??", "city": "Недоступно", "org": "Офлайн"}, ensure_ascii=False))
PYIP
    return
  fi
  echo '{"ip":"—","country":"??","city":"—","org":"—"}'
}

cmd_test_vpn_nodes_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 <<'PYNODES'
import socket, time, json, concurrent.futures

# Встроенные узлы — это публичные DNS-резолверы, а не VPN-выходы.
# 94.140.14.14 принадлежит AdGuard и отвечает из ближайшей точки anycast,
# а не «из Амстердама»; подключение к нему меняет DNS, а не маршрут трафика.
# Прежние подписи («Нидерланды (Амстердам)», бейдж SOCKS5) обещали туннель,
# которого нет. Единственный настоящий прокси здесь — локальный клиент.
NODES = [
    {"id": "warp_edge",    "name": "Cloudflare 1.1.1.1",     "country": "WW", "flag": "⚡️", "host": "1.1.1.1",      "port": "53",    "protocolType": "dns",    "isRecommended": True},
    {"id": "nl_amsterdam", "name": "AdGuard DNS",            "country": "WW", "flag": "🛡", "host": "94.140.14.14", "port": "53",    "protocolType": "dns",    "isRecommended": True},
    {"id": "de_frankfurt", "name": "Cloudflare 1.0.0.1",     "country": "WW", "flag": "⚡️", "host": "1.0.0.1",      "port": "53",    "protocolType": "dns",    "isRecommended": False},
    {"id": "fi_helsinki",  "name": "Mullvad DNS",            "country": "SE", "flag": "🇸🇪", "host": "194.242.2.3",  "port": "53",    "protocolType": "dns",    "isRecommended": False},
    {"id": "se_stockholm", "name": "Quad9",                  "country": "CH", "flag": "🇨🇭", "host": "9.9.9.9",      "port": "53",    "protocolType": "dns",    "isRecommended": False},
    {"id": "us_newyork",   "name": "Google Public DNS",      "country": "US", "flag": "🇺🇸", "host": "8.8.8.8",      "port": "53",    "protocolType": "dns",    "isRecommended": False},
    {"id": "local_v2ray",  "name": "Локальный клиент (Xray / sing-box / Clash)", "country": "RU", "flag": "💻", "host": "127.0.0.1", "port": "10808", "protocolType": "socks5", "isRecommended": False}
]

def ping_node(node):
    host = node["host"]
    try:
        port = int(node["port"])
        t0 = time.perf_counter()
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM if port != 53 else socket.SOCK_DGRAM)
        s.settimeout(1.2)
        if port == 53:
            s.sendto(b"\x00\x01\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x05apple\x03com\x00\x00\x01\x00\x01", (host, 53))
            s.recvfrom(512)
        else:
            s.connect((host, port))
        t1 = time.perf_counter()
        s.close()
        ms = int(round((t1 - t0) * 1000))
        return {**node, "latencyMs": ms, "isOnline": True}
    except Exception:
        # Check if local node or host
        if host == "127.0.0.1":
            return {**node, "latencyMs": -1, "isOnline": False}
        return {**node, "latencyMs": -1, "isOnline": False}

with concurrent.futures.ThreadPoolExecutor(max_workers=7) as ex:
    results = list(ex.map(ping_node, NODES))

print(json.dumps(results, ensure_ascii=False))
PYNODES
    return
  fi
  echo "[]"
}

cmd_run_full_speedtest() {
  # Замер пропускной способности.
  #
  # Прежняя версия при любом сбое подставляла правдоподобные числа: 68.4 Мбит/с
  # при провале обеих попыток скачивания, 48 % от загрузки вместо неизмеренной
  # отдачи, 22 мс вместо неизмеренного пинга и 75/35/18 целиком, если не нашёлся
  # python3. Потери пакетов всегда были нулевыми, потому что их никто не считал.
  # Без интернета приложение показывало бодрый результат замера.
  if ! command -v python3 >/dev/null 2>&1; then
    printf '{"downloadMbps":0.0,"uploadMbps":-1.0,"pingMs":-1,"jitterMs":0.0,"packetLossPct":0.0,"serverName":"","serverCountry":"","ispName":"","qualityGrade":"","failed":true,"reason":"python3 не найден"}\n'
    return 1
  fi
  python3 <<'PYSPEEDTEST'
import time, socket, urllib.request, json, ssl, statistics

def fail(reason):
    # Форма ответа одинакова при успехе и при отказе: приложение разбирает
    # её одним типом, и урезанный JSON ломал бы разбор целиком.
    print(json.dumps({
        "downloadMbps": 0.0, "uploadMbps": -1.0, "pingMs": -1,
        "jitterMs": 0.0, "packetLossPct": 0.0,
        "serverName": "", "serverCountry": "", "ispName": "",
        "qualityGrade": "", "failed": True, "reason": reason
    }, ensure_ascii=False))
    raise SystemExit(0)

# 1. Задержка, джиттер и потери — по одной серии проб.
attempts = 8
latencies = []
for _ in range(attempts):
    try:
        t0 = time.perf_counter()
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect(("1.1.1.1", 443))
        latencies.append((time.perf_counter() - t0) * 1000.0)
        s.close()
    except Exception:
        pass
    time.sleep(0.04)

if not latencies:
    fail("нет соединения с сетью")

ping_ms = int(round(min(latencies)))
jitter_ms = round(statistics.stdev(latencies), 1) if len(latencies) > 1 else 0.0
# Реальная доля неудавшихся проб, а не константа 0.0.
loss_pct = round((attempts - len(latencies)) * 100.0 / attempts, 1)

ctx = ssl.create_default_context()

def measure_download(url, label, budget=5.0):
    req = urllib.request.Request(url, headers={"User-Agent": "CerberusDNS/3.0"})
    t0 = time.perf_counter()
    total = 0
    with urllib.request.urlopen(req, context=ctx, timeout=8.0) as resp:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            total += len(chunk)
            if time.perf_counter() - t0 > budget:
                break
    elapsed = time.perf_counter() - t0
    if elapsed < 0.05 or total < 200000:
        raise RuntimeError("слишком мало данных")
    return round((total * 8.0) / (elapsed * 1_000_000.0), 1), label

download_mbps, server_name = None, None
for url, label in (
    ("https://speed.cloudflare.com/__down?bytes=25000000", "Cloudflare Speed Test"),
    ("https://speedtest.selectel.ru/10MB", "Selectel Speedtest"),
):
    try:
        download_mbps, server_name = measure_download(url, label)
        break
    except Exception:
        continue

if download_mbps is None:
    fail("не удалось измерить скорость загрузки")

# 2. Отдача. Если не измерилась — так и сообщаем, а не выводим долю от загрузки.
upload_mbps = None
try:
    payload = b"0" * 5_000_000
    req = urllib.request.Request("https://speed.cloudflare.com/__up", data=payload,
                                 headers={"User-Agent": "CerberusDNS/3.0"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, context=ctx, timeout=10.0) as resp:
        resp.read()
    elapsed = time.perf_counter() - t0
    if elapsed >= 0.05:
        upload_mbps = round((len(payload) * 8.0) / (elapsed * 1_000_000.0), 1)
except Exception:
    upload_mbps = None

if download_mbps >= 100:
    quality = "Сверхскоростное подключение"
elif ping_ms > 70 or download_mbps < 25:
    quality = "Хватает для веба и HD-видео"
else:
    quality = "Хватает для 4K, стриминга и игр"

print(json.dumps({
    "downloadMbps": download_mbps,
    # -1 означает «не измерено»; интерфейс показывает прочерк, а не число.
    "uploadMbps": upload_mbps if upload_mbps is not None else -1.0,
    "pingMs": ping_ms,
    "jitterMs": jitter_ms,
    "packetLossPct": loss_pct,
    "serverName": server_name,
    "serverCountry": "",
    "ispName": "",
    "qualityGrade": quality,
    "failed": False
}, ensure_ascii=False))
PYSPEEDTEST
}

# ─────────── ДИСПЕТЧЕР ───────────

SELF="$0"
# Позволяет подключить файл как библиотеку функций (`source`) без выполнения
# команды. Используется набором проверок.
cmd_set_upstreams() {
  local u1="${1:-1.1.1.1}" u2="${2:-1.0.0.1}"
  # Значения попадают в конфиг dnsmasq, который работает от root.
  if ! valid_upstream "$u1" || ! valid_upstream "$u2"; then
    fail "Вышестоящий DNS должен быть IP-адресом (можно с #порт): «$u1», «$u2»"
    return 2
  fi
  $SUDO mkdir -p "$STATE_DIR"
  printf '%s\n%s\n' "$u1" "$u2" | $SUDO tee "$STATE_DIR/upstreams" >/dev/null
  if [ "$(get_mode)" = "full" ]; then
    write_conf && reload_service
  fi
  ok "Вышестоящие DNS обновлены: $u1, $u2"
}

cmd_enable_autoupdate() {
  install_updater
  ok "Автообновление правил включено"
}

cmd_disable_autoupdate() {
  $SUDO launchctl bootout "system/$UPD_LABEL" >/dev/null 2>&1
  $SUDO launchctl unload -w "$UPD_PLIST" >/dev/null 2>&1
  $SUDO rm -f "$UPD_PLIST"
  ok "Автообновление правил отключено"
}

# ─────────── ВСТРОЕННОЕ VPN-ЯДРО (sing-box) ───────────
#
# Вкладка «VPN» раньше умела только включить системный прокси на ЧУЖОЙ локальный
# клиент: человек должен был сам поставить Xray или sing-box и сам его запустить.
# Здесь ядро своё. Оно работает ОТ ПОЛЬЗОВАТЕЛЯ (слушает 127.0.0.1, root не нужен),
# живёт под launchd (переживает перезагрузку и падения), а конфиг берёт по ссылке
# подписки: каналы, автовыбор и порядок приезжают с сервера и обновляются сами.
# Root нужен только на одно действие - включить системный прокси, и оно уже есть
# выше (--apply-socks5-proxy), поэтому помощника переустанавливать не приходится.

VPN_DIR="${CERBERUS_VPN_DIR:-$HOME/Library/Application Support/CerberusDNS/vpn}"
VPN_BIN_DIR="${CERBERUS_VPN_BIN_DIR:-$HOME/Library/Application Support/CerberusDNS/bin}"
VPN_SUB_FILE="$VPN_DIR/subscription"
VPN_MIRRORS_FILE="$VPN_DIR/mirrors"
VPN_PROFILE="$VPN_DIR/profile.json"
VPN_DNS_MODE_FILE="$VPN_DIR/dns_mode"
VPN_LOG="$VPN_DIR/core.log"
VPN_PORT="${CERBERUS_VPN_PORT:-10808}"
VPN_API="127.0.0.1:19090"
VPN_AGENT_LABEL="com.cerberusdns.vpncore"
VPN_AGENT_PLIST="$HOME/Library/LaunchAgents/$VPN_AGENT_LABEL.plist"

# Версия и суммы закреплены: ядро получает весь трафик человека, поэтому «скачать
# последнюю» без проверки - это доверить его любому, кто подменит ответ по пути.
SB_VERSION="1.14.1"
SB_SHA256_ARM64="b9024642ef7b4848252df5469b7f60ef3c18bb5e217a16a0934f0174f8ad11b4"
SB_SHA256_AMD64="b34381b047106fe84895df14f7aaae06f3182130b728006944deb0d59d8590c3"

vpn_require_user() {
  # От root $HOME другой: ядро завелось бы с чужим каталогом и от чужого имени.
  if [ "$(id -u)" -eq 0 ]; then
    fail "Команды VPN-ядра выполняются от пользователя, не от root"
    return 1
  fi
  mkdir -p "$VPN_DIR" "$VPN_BIN_DIR" 2>/dev/null
  chmod 700 "$VPN_DIR" 2>/dev/null
  return 0
}

find_singbox() {
  local here cand
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for cand in "$here/bin/sing-box" "$VPN_BIN_DIR/sing-box" \
              "/opt/homebrew/bin/sing-box" "/usr/local/bin/sing-box"; do
    if [ -x "$cand" ]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}

# Ссылка подписки попадает в аргументы curl и в файл. Разрешаем только схему,
# хост с портом и путь; строку запроса дописываем сами, поэтому своя запрещена.
valid_sub_url() {
  printf '%s' "${1:-}" | grep -Eq '^https?://[A-Za-z0-9._-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~/-]*)?$'
}

vpn_dns_mode() {
  local m=""
  [ -f "$VPN_DNS_MODE_FILE" ] && m="$(head -1 "$VPN_DNS_MODE_FILE" 2>/dev/null)"
  [ "$m" = "system" ] && printf 'system' || printf 'tunnel'
}

cmd_vpn_dns_mode() {
  vpn_require_user || return 1
  case "${1:-}" in
    tunnel|system) printf '%s\n' "$1" > "$VPN_DNS_MODE_FILE"; ok "Режим DNS внутри VPN: $1" ;;
    *) fail "Режим DNS: tunnel или system"; return 2 ;;
  esac
}

cmd_vpn_sub_set() {
  vpn_require_user || return 1
  local url="${1:-}"
  url="${url%%\?*}"            # человек мог вставить ссылку с ?format=…
  if ! valid_sub_url "$url"; then
    fail "Это не похоже на ссылку подписки (нужен адрес вида http://хост:порт/sub/ключ)"
    return 2
  fi
  ( umask 077; printf '%s\n' "$url" > "$VPN_SUB_FILE" )
  rm -f "$VPN_MIRRORS_FILE"
  ok "Ссылка подписки сохранена"
}

# Профиль принимаем, только если это действительно наш настольный конфиг: вход
# слушает localhost и нет TUN. Иначе битый или чужой ответ (страница заглушки
# оператора приходит с кодом 200) заменил бы рабочий профиль.
vpn_profile_acceptable() {
  python3 - "$1" "$VPN_PORT" <<'PYCHK' 2>/dev/null
import json, sys
try:
    cfg = json.load(open(sys.argv[1], encoding="utf-8"))
    inb = cfg.get("inbounds") or []
    ok = (len(inb) == 1 and inb[0].get("type") == "mixed"
          and inb[0].get("listen") == "127.0.0.1"
          and int(inb[0].get("listen_port")) == int(sys.argv[2])
          and any(o.get("type") == "urltest" for o in cfg.get("outbounds") or []))
except Exception:
    ok = False
sys.exit(0 if ok else 1)
PYCHK
}

cmd_vpn_sub_update() {
  vpn_require_user || return 1
  if [ ! -s "$VPN_SUB_FILE" ]; then fail "Ссылка подписки не задана"; return 2; fi
  local primary url tmp hdr sb got=""
  primary="$(head -1 "$VPN_SUB_FILE")"
  tmp="$(mktemp "$VPN_DIR/profile.XXXXXX")"; hdr="$(mktemp "$VPN_DIR/hdr.XXXXXX")"
  sb="$(find_singbox || true)"

  # Основной адрес, затем зеркала, которые сервер сам сообщил в прошлый раз:
  # адрес подписки - первое, что блокируют, а без обновления клиент остаётся
  # со старым списком каналов навсегда.
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    valid_sub_url "$url" || continue
    if curl -fsS -m 20 -A "CerberusDNS/$VERSION sing-box" -D "$hdr" -o "$tmp" \
         "$url?format=singbox&inbound=mixed&port=$VPN_PORT&dns=$(vpn_dns_mode)" 2>/dev/null \
       && vpn_profile_acceptable "$tmp" \
       && { [ -z "$sb" ] || "$sb" check -c "$tmp" >/dev/null 2>&1; }; then
      got="$url"; break
    fi
  done < <( { printf '%s\n' "$primary"; [ -f "$VPN_MIRRORS_FILE" ] && cat "$VPN_MIRRORS_FILE"; } | awk '!seen[$0]++' )

  if [ -z "$got" ]; then
    rm -f "$tmp" "$hdr"
    if [ -s "$VPN_PROFILE" ]; then
      warn "Подписка недоступна - остаюсь на сохранённом профиле"
      return 0
    fi
    fail "Подписка недоступна, а сохранённого профиля ещё нет"
    return 1
  fi

  chmod 600 "$tmp"; mv -f "$tmp" "$VPN_PROFILE"
  # Зеркала из заголовка ответа; путь подписки у них тот же, меняется только хост.
  tr -d '\r' < "$hdr" | awk 'tolower($1)=="subscription-mirrors:"{ $1=""; print }' \
    | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | while IFS= read -r m; do valid_sub_url "$m" && printf '%s\n' "$m"; done > "$VPN_MIRRORS_FILE.new" 2>/dev/null
  [ -s "$VPN_MIRRORS_FILE.new" ] && mv -f "$VPN_MIRRORS_FILE.new" "$VPN_MIRRORS_FILE" || rm -f "$VPN_MIRRORS_FILE.new"
  rm -f "$hdr"
  ok "Профиль обновлён"
}

cmd_vpn_core_install() {
  vpn_require_user || return 1
  local arch sum name url tmp
  case "$(uname -m)" in
    arm64)  arch="arm64"; sum="$SB_SHA256_ARM64" ;;
    x86_64) arch="amd64"; sum="$SB_SHA256_AMD64" ;;
    *) fail "Неизвестная архитектура: $(uname -m)"; return 1 ;;
  esac
  name="sing-box-$SB_VERSION-darwin-$arch"
  url="https://github.com/SagerNet/sing-box/releases/download/v$SB_VERSION/$name.tar.gz"
  tmp="$(mktemp -d)"
  if ! curl -fsSL -m 180 -o "$tmp/sb.tgz" "$url"; then
    rm -rf "$tmp"; fail "Не удалось скачать ядро с github.com"; return 1
  fi
  if [ "$(shasum -a 256 "$tmp/sb.tgz" | cut -d' ' -f1)" != "$sum" ]; then
    rm -rf "$tmp"; fail "Контрольная сумма ядра не совпала - файл отброшен"; return 1
  fi
  tar -xzf "$tmp/sb.tgz" -C "$tmp" "$name/sing-box" || { rm -rf "$tmp"; fail "Архив ядра повреждён"; return 1; }
  install -m 0755 "$tmp/$name/sing-box" "$VPN_BIN_DIR/sing-box"
  rm -rf "$tmp"
  "$VPN_BIN_DIR/sing-box" version >/dev/null 2>&1 || { fail "Ядро установлено, но не запускается"; return 1; }
  ok "Ядро sing-box $SB_VERSION установлено"
}

vpn_port_listening() { nc -z -G 1 127.0.0.1 "$VPN_PORT" >/dev/null 2>&1; }

cmd_vpn_core_start() {
  vpn_require_user || return 1
  local sb; sb="$(find_singbox || true)"
  if [ -z "$sb" ]; then fail "Ядро sing-box не установлено"; return 1; fi
  if [ ! -s "$VPN_PROFILE" ]; then fail "Нет профиля - сначала обновите подписку"; return 1; fi
  "$sb" check -c "$VPN_PROFILE" >/dev/null 2>&1 || { fail "Профиль не проходит проверку ядра"; return 1; }

  # Журнал не ротируется launchd; обрезаем сами, иначе за месяцы вырастет без предела.
  [ -f "$VPN_LOG" ] && [ "$(wc -c < "$VPN_LOG")" -gt 1048576 ] && : > "$VPN_LOG"

  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$VPN_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$VPN_AGENT_LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$sb</string><string>run</string>
    <string>-c</string><string>$VPN_PROFILE</string>
    <string>-D</string><string>$VPN_DIR</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardOutPath</key><string>$VPN_LOG</string>
  <key>StandardErrorPath</key><string>$VPN_LOG</string>
</dict></plist>
PLIST
  # KeepAlive здесь не удобство, а страховка: системный прокси остаётся включённым
  # и после падения ядра, и после перезагрузки. Без живого ядра на этом порту
  # у человека пропадает интернет целиком, и причину он не найдёт.
  launchctl bootout "gui/$(id -u)/$VPN_AGENT_LABEL" >/dev/null 2>&1
  if ! launchctl bootstrap "gui/$(id -u)" "$VPN_AGENT_PLIST" 2>/dev/null; then
    fail "launchd не принял агент ядра"; return 1
  fi
  local i=0
  while [ $i -lt 40 ]; do
    vpn_port_listening && { ok "Ядро запущено, слушает 127.0.0.1:$VPN_PORT"; return 0; }
    sleep 0.25; i=$((i+1))
  done
  launchctl bootout "gui/$(id -u)/$VPN_AGENT_LABEL" >/dev/null 2>&1
  rm -f "$VPN_AGENT_PLIST"
  fail "Ядро не поднялось: $(tail -3 "$VPN_LOG" 2>/dev/null | tr '\n' ' ')"
  return 1
}

cmd_vpn_core_stop() {
  vpn_require_user || return 1
  launchctl bootout "gui/$(id -u)/$VPN_AGENT_LABEL" >/dev/null 2>&1
  rm -f "$VPN_AGENT_PLIST"
  ok "Ядро остановлено"
}

cmd_vpn_core_status_json() {
  local sb ver="" running="false" listening="false" sub_host="" age="-1" orphan="false" svc s_out
  # Статус запускает найденный sing-box, а среди мест поиска есть каталоги
  # пользователя (/opt/homebrew/bin). Через беспарольный помощник это root:
  # положи туда файл — и он исполнится от root. Приложение спрашивает статус
  # от пользователя, как и все остальные команды ядра.
  if [ "$(id -u)" -eq 0 ]; then
    fail "Команды VPN-ядра выполняются от пользователя, не от root"
    return 1
  fi
  sb="$(find_singbox || true)"
  [ -n "$sb" ] && ver="$("$sb" version 2>/dev/null | awk 'NR==1{print $3}')"
  launchctl print "gui/$(id -u)/$VPN_AGENT_LABEL" >/dev/null 2>&1 && running="true"
  vpn_port_listening && listening="true"
  [ -s "$VPN_SUB_FILE" ] && sub_host="$(head -1 "$VPN_SUB_FILE" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ -s "$VPN_PROFILE" ] && age="$(( $(date +%s) - $(stat -f %m "$VPN_PROFILE") ))"
  # Осиротевший прокси: система шлёт трафик на наш порт, а там никого.
  svc="$(active_services | head -1)"
  if [ -n "$svc" ] && [ "$listening" = "false" ]; then
    s_out="$(networksetup -getsocksfirewallproxy "$svc" 2>/dev/null)"
    if printf '%s' "$s_out" | grep -qi "Enabled: Yes" \
       && printf '%s' "$s_out" | grep -q "Server: 127.0.0.1" \
       && printf '%s' "$s_out" | grep -q "Port: $VPN_PORT"; then orphan="true"; fi
  fi
  SB_PATH="$sb" SB_VER="$ver" RUNNING="$running" LISTENING="$listening" SUB_HOST="$sub_host" \
  AGE="$age" ORPHAN="$orphan" DNS_MODE="$(vpn_dns_mode)" PROFILE="$VPN_PROFILE" API="$VPN_API" \
  PORT="$VPN_PORT" python3 <<'PYSTAT'
import json, os, urllib.request, urllib.parse
e = os.environ
nodes, active, delay = [], "", -1
try:
    cfg = json.load(open(e["PROFILE"], encoding="utf-8"))
    auto = next(o for o in cfg["outbounds"] if o.get("type") == "urltest")
    nodes = list(auto.get("outbounds") or [])
    if e["LISTENING"] == "true":
        url = "http://%s/proxies/%s" % (e["API"], urllib.parse.quote(auto["tag"]))
        with urllib.request.urlopen(url, timeout=1.5) as r:
            data = json.load(r)
        active = data.get("now") or ""
        hist = data.get("history") or []
        if hist: delay = int(hist[-1].get("delay") or -1)
except Exception:
    pass
print(json.dumps({
    "coreInstalled": bool(e["SB_PATH"]), "coreVersion": e["SB_VER"],
    "running": e["RUNNING"] == "true", "listening": e["LISTENING"] == "true",
    "port": int(e["PORT"]), "subscriptionHost": e["SUB_HOST"],
    "profileAgeSec": int(e["AGE"]), "nodes": nodes, "activeNode": active,
    "activeDelayMs": delay, "proxyOrphaned": e["ORPHAN"] == "true",
    "dnsMode": e["DNS_MODE"],
}, ensure_ascii=False))
PYSTAT
}

if [ "${CERBERUS_SOURCE_ONLY:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

case "${1:-}" in
  --status)              cmd_status ;;
  --status-json)         cmd_status_json "${2:-}" ;;
  --status-text)         cmd_status_text ;;
  --brew-prefix)         find_brew && printf '%s\n' "$BREW_PREFIX" ;;
  --prepare-full)        cmd_prepare_full ;;
  --apply-full)          cmd_apply_full ;;
  --apply-quick)         cmd_apply_quick ;;
  --apply-profile)       cmd_apply_profile "${2:-adguard}" "${3:-}" ;;
  --apply-off)           cmd_apply_off ;;
  --apply-remove)        cmd_apply_remove ;;
  --flush-dns)           flush_dns; ok "DNS кэш успешно очищен" ;;
  --install-helper)      if ensure_privileged_helper install; then ok "Привилегированный помощник установлен"; else fail "Не удалось установить помощник"; exit 1; fi ;;
  --remove-helper)       remove_privileged_helper; ok "Помощник удален" ;;
  --full)                cmd_prepare_full && cmd_apply_full ;;
  --update)              cmd_update ;;
  --test-domains-json)   cmd_test_domains_json ;;
  --test-speed-json)     cmd_test_speed_json ;;
  --test-vpn-nodes-json) cmd_test_vpn_nodes_json ;;
  --run-full-speedtest)  cmd_run_full_speedtest ;;
  --add-whitelist)       cmd_add_whitelist "${2:-}" ;;
  --remove-whitelist)    cmd_remove_whitelist "${2:-}" ;;
  --get-whitelist)       cmd_get_whitelist ;;
  --add-blacklist)       cmd_add_blacklist "${2:-}" ;;
  --remove-blacklist)    cmd_remove_blacklist "${2:-}" ;;
  --get-blacklist)       cmd_get_blacklist ;;
  --vpn-status-json)     cmd_vpn_status_json ;;
  --apply-socks5-proxy)  cmd_apply_socks5_proxy "${2:-127.0.0.1}" "${3:-10808}" ;;
  --apply-http-proxy)    cmd_apply_http_proxy "${2:-127.0.0.1}" "${3:-8080}" ;;
  --apply-proxy-off)     cmd_apply_proxy_off ;;
  --get-ip-info-json)    cmd_get_ip_info_json ;;
  --vpn-core-status-json) cmd_vpn_core_status_json ;;
  --vpn-core-install)    cmd_vpn_core_install ;;
  --vpn-core-start)      cmd_vpn_core_start ;;
  --vpn-core-stop)       cmd_vpn_core_stop ;;
  --vpn-sub-set)         cmd_vpn_sub_set "${2:-}" ;;
  --vpn-sub-update)      cmd_vpn_sub_update ;;
  --vpn-dns-mode)        cmd_vpn_dns_mode "${2:-}" ;;
  --query-log-json)      cmd_query_log_json "${2:-200}" ;;
  --restart-service)     cmd_restart_service ;;
  --doh-status-json)       cmd_doh_status_json ;;
  --doh-block-on)          cmd_doh_block_on ;;
  --doh-block-off)         cmd_doh_block_off ;;
  --tailscale-status-json) cmd_tailscale_status_json ;;
  --tailscale-split-on)    cmd_tailscale_split_on ;;
  --tailscale-split-off)   cmd_tailscale_split_off ;;
  --set-upstreams)         cmd_set_upstreams "${2:-1.1.1.1}" "${3:-1.0.0.1}" ;;
  --enable-autoupdate)     cmd_enable_autoupdate ;;
  --disable-autoupdate)    cmd_disable_autoupdate ;;
  --version)             printf '%s\n' "$VERSION" ;;
  --self-hash)           shasum -a 256 "${BASH_SOURCE[0]}" 2>/dev/null | cut -d' ' -f1 ;;
  "")                    cmd_status_text ;;
  *)                     fail "Неизвестный параметр: $1"; exit 2 ;;
esac
