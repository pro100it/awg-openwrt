AmneziaWG — OpenWRT 25.12.0-rc1 (SNR AX2)

⚠️ Форк / Fork оригинального репозитория:
https://github.com/Slava-Shchipunov/awg-openwrt

Поддержка / Supported:
OpenWRT 25.12.0-rc1, 25.12.0-rc2 • SNR AX2 • AWG 2.0
Пакеты / Packages: .apk • Менеджер / Manager: apk

❌ Другие устройства и версии OpenWRT не поддерживаются
❌ Other devices and OpenWRT versions are not supported

Установка / Install:
Скачайте пакеты из GitHub Releases
Download packages from GitHub Releases

apk add --allow-untrusted *.apk

Либо можно все установить на роутер скриптом 
```
sh <(wget -O - https://raw.githubusercontent.com/pro100it/awg-openwrt/refs/heads/master/install_only_apk.sh)
```

Настройка вручную через LuCI / Manual LuCI configuration
(Network → Interfaces → AmneziaWG)
