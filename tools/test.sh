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
  mkdir -p "$SB/state" "$SB/prefix/etc/adblock-dns"
  printf 'good.example
allow.example
' > "$SB/state/whitelist.txt"
  printf 'bad.example
block.example
'  > "$SB/state/blacklist.txt"
  printf 'address=/tracker.example/#
address=/good.example/#
'   > "$SB/prefix/etc/adblock-dns/blocklist.conf"
  : > "$SB/state/block_doh"       # правила блокировки DoH
  : > "$SB/state/tailscale_split" # зона Tailscale
  CERBERUS_SOURCE_ONLY=1 CERBERUS_STATE_DIR="$SB/state" \
  bash -c '
    source "'"$ROOT"'/Contents/Resources/engine.sh"
    BREW_PREFIX="'"$SB"'/prefix"
    DNSMASQ_BIN="'"$DNSMASQ_TEST_BIN"'"
    SUDO=""
    write_conf
  ' >"$TMP/wc.log" 2>&1
  rc=$?
  conf="$SB/prefix/etc/dnsmasq.conf"
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
  if [ -f "$SB/prefix/etc/adblock-dns/blocklist.active.conf" ]; then
    grep -q 'good.example' "$SB/prefix/etc/adblock-dns/blocklist.active.conf" && { echo "  ✘ домен белого списка остался в базе блокировки"; bad=1; } || echo "  ✔ домен белого списка исключён из базы блокировки"
  fi
  [ "$bad" -eq 0 ] || fails=$((fails + 1))
fi

echo
echo "── engine.sh: безопасность use_prefix (LPE защита) ──"
if bash -c 'CERBERUS_SOURCE_ONLY=1 source "'"$ROOT"'/Contents/Resources/engine.sh" >/dev/null 2>&1; CERBERUS_SOURCE_ONLY="" use_prefix "/tmp/evil" >/dev/null 2>&1'; then
  echo "  ✘ префикс /tmp/evil был принят!"
  fails=$((fails + 1))
else
  echo "  ✔ префикс /tmp/evil отвергнут"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "✔ все наборы пройдены"
else
  echo "✘ наборов с ошибками: $fails"
fi
exit "$fails"
