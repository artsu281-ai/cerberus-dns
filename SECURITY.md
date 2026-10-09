# Безопасность / Security

Cerberus DNS меняет системные настройки DNS и может поставить
привилегированного помощника: копию `engine.sh` в
`/usr/local/libexec/adblock-dns-engine.sh`, обёртку `/usr/local/bin/dnsblock-engine` и правило
в `/etc/sudoers.d/dnsblocker_helper`, которое разрешает текущему пользователю
запускать без пароля **только этот файл**. Поэтому ошибки в `engine.sh`
потенциально дают повышение прав.

Если нашли уязвимость, не публикуйте её в открытых issues. Откройте приватный
отчёт через вкладку **Security → Report a vulnerability** этого репозитория на
GitHub.

Please report vulnerabilities privately via **Security → Report a
vulnerability** on GitHub rather than in public issues.

Удалить помощника / remove the helper:

```bash
sudo /usr/local/bin/dnsblock-engine --remove-helper
```
