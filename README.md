AmneziaWG — OpenWRT 25.12.0-rc1 (SNR AX2)

⚠️ Форк / Fork оригинального репозитория:
https://github.com/Slava-Shchipunov/awg-openwrt

Поддержка 
OpenWRT 25.12.0-rc1, 25.12.0-rc2, 25.12.0-rc3, 25.12.0-rc3• SNR AX2 • AWG 2.0
Пакеты  .apk • Менеджер / Manager: apk

❌ Другие устройства и версии OpenWRT не поддерживаются но попробовать на ваш страх и риск можно )


Установка / Install:
Скачайте пакеты из GitHub Releases

apk add --allow-untrusted *.apk

Либо можно все установить на роутер скриптом
```
sh <(wget -O - https://raw.githubusercontent.com/pro100it/awg-openwrt/refs/heads/master/amneziawg-install.sh)
```

Настройка вручную через LuCI 
(Network → Interfaces → AmneziaWG)
