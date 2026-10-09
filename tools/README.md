# tools

Служебные скрипты. В бандл приложения не попадают: установка копирует
только каталог `Contents`.

## makeicon.swift — иконка приложения

Рисует знак «Триглав» (щит с тремя головами) и собирает из него полный
набор представлений для `iconutil`. Каждый размер отрисовывается из вектора
заново, а не уменьшается из одного большого PNG — на 16 и 32 px это заметно
чище.

```bash
swiftc -O -o /tmp/makeicon tools/makeicon.swift
mkdir -p /tmp/AppIcon.iconset
/tmp/makeicon /tmp/AppIcon.iconset
iconutil -c icns /tmp/AppIcon.iconset -o Contents/Resources/AppIcon.icns
cp /tmp/AppIcon.iconset/icon_512x512.png Contents/Resources/AppIcon.png
```
