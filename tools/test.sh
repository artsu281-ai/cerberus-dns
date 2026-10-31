#!/bin/bash
#
#  Прогон проверок. Ни одна из них не трогает систему: только чистая логика.
#
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/Contents/Resources/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0

echo "── Swift: чистая логика ──"
# Собираем только те файлы, от которых зависят проверяемые типы.
if swiftc -O -o "$TMP/logictests" \
    "$SRC/AppPaths.swift" \
    "$SRC/Localization.swift" \
    "$SRC/EngineText.swift" \
    "$SRC/Updates.swift" \
    "$SRC/Theme.swift" \
    "$SRC/Models.swift" \
    "$HERE/tests/main.swift" 2>"$TMP/build.log"; then
  "$TMP/logictests" || fails=$((fails + 1))
else
  echo "  ✘ не скомпилировалось:"
  sed 's/^/    /' "$TMP/build.log" | head -20
  fails=$((fails + 1))
fi

echo
echo "── engine.sh: валидатор доменов ──"
sed -n '/^valid_domain()/,/^}/p' "$ROOT/Contents/Resources/engine.sh" > "$TMP/vd.sh"
cat >> "$TMP/vd.sh" <<'EOF'
bad=0
ok()  { if valid_domain "$1"; then echo "  ✔ $1 — принят"; else echo "  ✘ $1 — должен приниматься"; bad=$((bad+1)); fi; }
no()  { if valid_domain "$1"; then echo "  ✘ $1 — не должен приниматься"; bad=$((bad+1)); else echo "  ✔ $1 — отвергнут"; fi; }
ok "example.com"
ok "sub.example.co.uk"
ok "ad-1.example.com"
no "http://evil.com/x"
no "no-dot"
no "-bad.com"
no "a..b.com"
no "space here.com"
no "example.com."
no "0.0.0.0/#"
exit $bad
EOF
bash "$TMP/vd.sh" || fails=$((fails + 1))

echo
echo "── engine.sh: ссылка подписки встроенного VPN ──"
# Ссылка уходит в аргументы curl и в файл: всё, что не «схема://хост[:порт]/путь»,
# обязано отвергаться, включая подстановки оболочки и собственную строку запроса.
sed -n '/^valid_sub_url()/,/^}/p' "$ROOT/Contents/Resources/engine.sh" > "$TMP/su.sh"
cat >> "$TMP/su.sh" <<'EOF'
bad=0
ok()  { if valid_sub_url "$1"; then echo "  ✔ принят: $1"; else echo "  ✘ должен приниматься: $1"; bad=$((bad+1)); fi; }
no()  { if valid_sub_url "$1"; then echo "  ✘ не должен приниматься: $1"; bad=$((bad+1)); else echo "  ✔ отвергнут: $1"; fi; }
ok "http://203.0.113.10:5005/sub/0123456789abcdef"
ok "https://sub.example.com/sub/abc"
no "ftp://example.com/sub/abc"
no 'http://example.com/$(id)'
no "http://example.com/sub/a;rm -rf /"
no "http://example.com/sub/a?format=singbox"
no "http://exa mple.com/sub/a"
no ""
exit $bad
EOF
bash "$TMP/su.sh" || fails=$((fails + 1))

echo
echo "── engine.sh: приём профиля встроенного VPN ──"
# Заглушка оператора приходит с кодом 200; телефонный профиль с TUN не стартует
# без root. Ни то ни другое не должно заменить рабочий профиль на диске.
{ echo 'VPN_PORT=10808'; sed -n '/^vpn_profile_acceptable()/,/^}/p' "$ROOT/Contents/Resources/engine.sh"; } > "$TMP/pa.sh"
cat >> "$TMP/pa.sh" <<EOF
bad=0
T="$TMP"
EOF
cat >> "$TMP/pa.sh" <<'EOF'
good='{"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":10808}],"outbounds":[{"type":"urltest","tag":"a","outbounds":["x"]}]}'
tun='{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"urltest","tag":"a","outbounds":["x"]}]}'
lan='{"inbounds":[{"type":"mixed","listen":"0.0.0.0","listen_port":10808}],"outbounds":[{"type":"urltest","tag":"a","outbounds":["x"]}]}'
port='{"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":1080}],"outbounds":[{"type":"urltest","tag":"a","outbounds":["x"]}]}'
chk() { printf '%s' "$2" > "$T/p.json"; if vpn_profile_acceptable "$T/p.json"; then r=yes; else r=no; fi
        if [ "$r" = "$3" ]; then echo "  ✔ $1"; else echo "  ✘ $1 (получено $r, ожидалось $3)"; bad=$((bad+1)); fi; }
chk "настольный профиль принят"            "$good" yes
chk "телефонный профиль с TUN отвергнут"   "$tun"  no
chk "вход, слушающий всю сеть, отвергнут"  "$lan"  no
chk "чужой порт отвергнут"                 "$port" no
chk "HTML-заглушка отвергнута"             "<html>blocked</html>" no
exit $bad
EOF
bash "$TMP/pa.sh" || fails=$((fails + 1))

echo
echo "── engine.sh: определение профиля по фактическому DNS ──"
sed -n '/^detect_profile_from_dns()/,/^}/p' "$ROOT/Contents/Resources/engine.sh" > "$TMP/dp.sh"
cat >> "$TMP/dp.sh" <<'EOF'
bad=0
eq() { got="$(detect_profile_from_dns "$1")"; if [ "$got" = "$2" ]; then echo "  ✔ $1 → $2"; else echo "  ✘ $1 → «$got», ожидалось «$2»"; bad=$((bad+1)); fi; }
eq " 94.140.14.14 "      "adguard"
eq " 94.140.14.15 "      "adguard_family"
eq " 1.1.1.2 1.0.0.2 "   "cloudflare_security"
eq " 9.9.9.9 "           "quad9"
eq " 194.242.2.3 "       "mullvad"
eq " 127.0.0.1 "         "local_dnsmasq"
eq " 8.8.8.8 "           ""
exit $bad
EOF
bash "$TMP/dp.sh" || fails=$((fails + 1))

echo
echo "── engine.sh: разбор журнала dnsmasq ──"
python3 - "$ROOT" <<'EOF' || fails=$((fails + 1))
import sys, re, json, subprocess, time, pathlib
root = pathlib.Path(sys.argv[1])
s = (root / "Contents/Resources/engine.sh").read_text()
start = s.index("tail -n $(( limit * 6 ))")
block = s[s.index("'", start) + 1 : s.index("' \"$limit\"", start)]

stamp = time.strftime("%b %e %H:%M:%S")
log = "\n".join([
    f"{stamp} Mac dnsmasq[1]: query[A] googleads.g.doubleclick.net from 127.0.0.1",
    f"{stamp} Mac dnsmasq[1]: config googleads.g.doubleclick.net is 0.0.0.0",
    f"{stamp} Mac dnsmasq[1]: query[A] github.com from 127.0.0.1",
    f"{stamp} Mac dnsmasq[1]: forwarded github.com to 1.1.1.1",
    f"{stamp} Mac dnsmasq[1]: reply github.com is 140.82.121.4",
    f"{stamp} Mac dnsmasq[1]: query[AAAA] mc.yandex.ru from 192.168.1.55",
    f"{stamp} Mac dnsmasq[1]: config mc.yandex.ru is 0.0.0.0",
    f"{stamp} Mac dnsmasq[1]: query[A] apple.com from 127.0.0.1",
    f"{stamp} Mac dnsmasq[1]: cached apple.com is 17.253.144.10",
]) + "\n"

r = subprocess.run(["python3", "-c", block, "50"], input=log.encode(), capture_output=True)
data = json.loads(r.stdout)
by = {d["domain"]: d for d in data}
bad = 0
def check(name, cond):
    global bad
    print(("  ✔ " if cond else "  ✘ ") + name)
    if not cond: bad += 1

check("разобраны все четыре записи", len(data) == 4)
check("рекламный домен помечен blocked", by["googleads.g.doubleclick.net"]["status"] == "blocked")
check("категория рекламы определена", by["googleads.g.doubleclick.net"]["category"] == "ad")
check("forwarded+reply даёт allowed", by["github.com"]["status"] == "allowed")
check("cached распознаётся отдельно", by["apple.com"]["status"] == "cached")
check("Метрика опознана как трекер", by["mc.yandex.ru"]["category"] == "tracker")
check("тип запроса сохранён", by["mc.yandex.ru"]["queryType"] == "AAAA")
check("клиент сохранён", by["mc.yandex.ru"]["clientIp"] == "192.168.1.55")
check("порядок: свежие первыми", data[0]["domain"] == "apple.com")
sys.exit(bad)
EOF

echo
echo "── engine.sh: краткий статус согласован с полным ──"
# Краткий режим опрашивает одну службу вместо всех. Если он выберет не ту,
# приложение сообщит «защита выключена» при включённой защите.
python3 - "$ROOT" <<'EOF' || fails=$((fails + 1))
import sys, json, subprocess, pathlib
root = pathlib.Path(sys.argv[1])
eng = str(root / "Contents/Resources/engine.sh")
def run(extra):
    out = subprocess.run(["bash", eng, "--status-json"] + extra, capture_output=True, text=True).stdout
    return json.loads(out)
full, brief = run([]), run(["--brief"])
bad = 0
def check(name, cond):
    global bad
    print(("  ✔ " if cond else "  ✘ ") + name)
    if not cond: bad += 1
check("режим совпадает",            full["mode"] == brief["mode"])
check("профиль совпадает",          full["profile"] == brief["profile"])
check("перехват определён одинаково", full["dnsOverridden"] == brief["dnsOverridden"])
check("краткий не отдаёт список служб", brief["services"] is None)
check("полный отдаёт список служб",  isinstance(full["services"], list) and len(full["services"]) > 0)
sys.exit(bad)
EOF

echo
echo "── engine.sh: конфигурация dnsmasq валидна ──"
# Самый опасный файл в проекте: битый конфиг кладёт DNS целиком. Проверяем
# настоящей функцией write_conf в песочнице, ничего системного не трогая.
DNSMASQ_TEST_BIN=""
for c in /opt/homebrew/sbin/dnsmasq /usr/local/sbin/dnsmasq; do
  [ -x "$c" ] && DNSMASQ_TEST_BIN="$c" && break
done
if [ -z "$DNSMASQ_TEST_BIN" ]; then
  echo "  ⚠ dnsmasq не установлен — проверка пропущена (brew install dnsmasq)"
else
  SB="$TMP/sandbox"
  mkdir -p "$SB/state"
  # Последняя строка — мусор, оставшийся от версии без проверки ввода.
  # Она должна быть пропущена, а не валить весь конфиг.
  printf 'good.example
allow.example
bad/entry
' > "$SB/state/whitelist.txt"
  printf 'bad.example
block.example
'  > "$SB/state/blacklist.txt"
  printf 'address=/tracker.example/#
address=/good.example/#
'   > "$SB/state/blocklist.conf"
  : > "$SB/state/block_doh"       # правила блокировки DoH
  : > "$SB/state/tailscale_split" # зона Tailscale
  CERBERUS_SOURCE_ONLY=1 CERBERUS_STATE_DIR="$SB/state" \
  bash -c '
    source "'"$ROOT"'/Contents/Resources/engine.sh"
    DNSMASQ_RUN="'"$DNSMASQ_TEST_BIN"'"
    SUDO=""
    write_conf
  ' >"$TMP/wc.log" 2>&1
  rc=$?
  conf="$SB/state/dnsmasq.conf"
  bad=0
  if [ "$rc" -ne 0 ]; then
    echo "  ✘ write_conf вернул $rc"; sed 's/^/    /' "$TMP/wc.log" | head -5; bad=1
  else
    echo "  ✔ write_conf отработал (dnsmasq --test прошёл внутри)"
  fi
  grep -q '^server=/good.example/'      "$conf" && echo "  ✔ белый список попал в конфиг"  || { echo "  ✘ белый список потерян"; bad=1; }
  grep -q '^address=/bad.example/'      "$conf" && echo "  ✔ чёрный список попал в конфиг" || { echo "  ✘ чёрный список потерян"; bad=1; }
  grep -q '^address=/use-application-dns.net/$' "$conf" && echo "  ✔ канарейка Firefox без адреса (даёт NXDOMAIN)" || { echo "  ✘ канарейка отсутствует или с адресом"; bad=1; }
  grep -q '^server=/ts.net/100.100.100.100' "$conf" && echo "  ✔ зона Tailscale в конфиге" || { echo "  ✘ зона Tailscale потеряна"; bad=1; }
  grep -q '^log-queries'                "$conf" && echo "  ✔ журнал запросов включён"      || { echo "  ✘ журнал запросов выключен"; bad=1; }
  "$DNSMASQ_TEST_BIN" --test -C "$conf" >/dev/null 2>&1 && echo "  ✔ конфиг принят настоящим dnsmasq" || { echo "  ✘ dnsmasq отверг конфиг"; bad=1; }
  # Проверка, что домен из белого списка исключён из активной базы правил
  if [ -f "$SB/state/blocklist.active.conf" ]; then
    grep -q 'good.example' "$SB/state/blocklist.active.conf" && { echo "  ✘ домен белого списка остался в базе блокировки"; bad=1; } || echo "  ✔ домен белого списка исключён из базы блокировки"
  else
    echo "  ✘ активная база без белого списка не создана"; bad=1
  fi
  grep -q 'bad/entry' "$conf" && { echo "  ✘ мусорная строка правил попала в конфиг"; bad=1; } || echo "  ✔ мусорная строка правил пропущена"

  # Если новая сборка не прошла проверку, рабочий конфиг должен остаться прежним.
  cp "$conf" "$TMP/conf.before"
  printf 'dhcp-range=не-адрес\n' > "$SB/state/blocklist.conf"
  CERBERUS_SOURCE_ONLY=1 CERBERUS_STATE_DIR="$SB/state" \
  bash -c '
    source "'"$ROOT"'/Contents/Resources/engine.sh"
    DNSMASQ_RUN="'"$DNSMASQ_TEST_BIN"'"
    SUDO=""
    write_conf
  ' >/dev/null 2>&1
  rc2=$?
  if [ "$rc2" -ne 0 ] && cmp -s "$conf" "$TMP/conf.before"; then
    echo "  ✔ конфиг, не прошедший проверку, рабочий не заменил"
  else
    echo "  ✘ битый конфиг заменил рабочий (код $rc2)"; bad=1
  fi
  [ "$bad" -eq 0 ] || fails=$((fails + 1))
fi

echo
echo "── engine.sh: помощник не исполняет ввод ──"
# Помощник вызывается через sudo без пароля, поэтому любой аргумент — это
# ввод от непривилегированного процесса.
bad=0
canary="$TMP/pwned"
# Журнал подставляется настоящий: без него функция выходила бы раньше
# арифметики, и проверка проходила бы и на уязвимом коде. Имя переменной —
# существующее (PATH): с несуществующим `set -u` обрывал разбор раньше
# подстановки, и проверка тоже ничего бы не ловила.
: > "$TMP/query.log"
out="$(CERBERUS_SOURCE_ONLY=1 bash -c 'source "$1"; QUERY_LOG="$2"; cmd_query_log_json "$3"' _ \
  "$ROOT/Contents/Resources/engine.sh" "$TMP/query.log" 'PATH[$(touch '"$canary"')]' 2>/dev/null)"
if [ -e "$canary" ]; then
  echo "  ✘ --query-log-json выполнил подставленную команду"; bad=1
else
  echo "  ✔ --query-log-json не выполняет подставленную команду"
fi
[ "$out" = "[]" ] && echo "  ✔ на неверный лимит отвечает пустым списком" || { echo "  ✘ ответ на неверный лимит: $out"; bad=1; }
# Путь к Homebrew из аргумента давал LaunchDaemon, запускающий чужой файл от root.
if grep -nE 'cmd_apply_full "|cmd_apply_remove "|BREW_PREFIX="\$1"|PREFIX_FILE' "$ROOT/Contents/Resources/engine.sh"; then
  echo "  ✘ путь к Homebrew снова берётся из аргументов или файла"; bad=1
else
  echo "  ✔ путь к Homebrew из аргументов не принимается"
fi
if grep -nE '\$SUDO "\$BREW"|"\$BREW" --prefix' "$ROOT/Contents/Resources/engine.sh"; then
  echo "  ✘ brew запускается от root"; bad=1
else
  echo "  ✔ brew от root не запускается"
fi
if grep -nE '^[^#]*%admin' "$ROOT/Contents/Resources/engine.sh"; then
  echo "  ✘ право на помощник снова выдаётся всей группе admin"; bad=1
else
  echo "  ✔ право на помощник — только одному пользователю"
fi
[ "$bad" -eq 0 ] || fails=$((fails + 1))

echo
echo "── engine.sh: из списков блокировки берутся только блокирующие строки ──"
bad=0
{
  i=0; while [ $i -lt 1005 ]; do printf 'local=/ad%d.example.com/\n' "$i"; i=$((i + 1)); done
  printf 'address=/tracker.example/#\naddress=/pixel.example/0.0.0.0\nADDRESS=/Upper.Example/\n'
  printf 'server=/bank.example/6.6.6.6\naddress=/bank.example/6.6.6.6\n'
  printf 'local=/evil.example/\ndhcp-script=/tmp/x\n'
  printf 'address=/a.example/b.example/#\naddress=/x.example/#  # хвост\n'
} > "$TMP/list.raw"
CERBERUS_SOURCE_ONLY=1 bash -c 'source "$1"; convert_list "$2" "$3"' _ \
  "$ROOT/Contents/Resources/engine.sh" "$TMP/list.raw" "$TMP/list.conf"
has()  { grep -qxF "$1" "$TMP/list.conf" && echo "  ✔ оставлена: $1" || { echo "  ✘ потеряна: $1"; bad=1; }; }
hasnt(){ grep -qF  "$1" "$TMP/list.conf" && { echo "  ✘ пропущена: $1"; bad=1; } || echo "  ✔ отброшена: $1"; }
has   'local=/ad1.example.com/'
has   'address=/tracker.example/#'
has   'address=/pixel.example/0.0.0.0'
has   'address=/upper.example/'
has   'local=/evil.example/'
hasnt '6.6.6.6'
hasnt 'server='
hasnt 'dhcp-script'
hasnt 'b.example'
hasnt 'x.example'
[ "$bad" -eq 0 ] || fails=$((fails + 1))

echo
echo "── engine.sh: вышестоящие DNS — только IP-адреса ──"
bad=0
mkdir -p "$TMP/ups"
for v in "/bank.example/6.6.6.6" "dhcp-script=/tmp/x" "1.1.1" "1.1.1.1 2.2.2.2"; do
  CERBERUS_SOURCE_ONLY=1 CERBERUS_STATE_DIR="$TMP/ups" bash -c 'source "$1"; SUDO=""; cmd_set_upstreams "1.1.1.1" "$2"' _ \
    "$ROOT/Contents/Resources/engine.sh" "$v" >/dev/null 2>&1
  if [ -e "$TMP/ups/upstreams" ]; then echo "  ✘ принят: $v"; bad=1; rm -f "$TMP/ups/upstreams"; else echo "  ✔ отвергнут: $v"; fi
done
CERBERUS_SOURCE_ONLY=1 CERBERUS_STATE_DIR="$TMP/ups" bash -c 'source "$1"; SUDO=""; cmd_set_upstreams "9.9.9.9" "2606:4700:4700::1111#53"' _ \
  "$ROOT/Contents/Resources/engine.sh" >/dev/null 2>&1
[ "$(cat "$TMP/ups/upstreams" 2>/dev/null)" = "9.9.9.9
2606:4700:4700::1111#53" ] && echo "  ✔ IPv4 и IPv6 с портом приняты" || { echo "  ✘ корректные адреса не сохранились"; bad=1; }
# Статус VPN-ядра запускает найденный sing-box, в том числе из /opt/homebrew/bin,
# который принадлежит пользователю. От root (через помощник) он запускаться не должен.
if sed -n '/^cmd_vpn_core_status_json() {/,/^}/p' "$ROOT/Contents/Resources/engine.sh" \
     | awk '/id -u/ && !guard {guard=NR} /find_singbox/ && !found {found=NR} END {exit !(guard && found && guard < found)}'; then
  echo "  ✔ статус VPN-ядра не запускает sing-box от root"
else
  echo "  ✘ статус VPN-ядра может запустить sing-box от root"; bad=1
fi
[ "$bad" -eq 0 ] || fails=$((fails + 1))

echo
if [ "$fails" -eq 0 ]; then
  echo "✔ все наборы пройдены"
else
  echo "✘ наборов с ошибками: $fails"
fi
exit "$fails"
