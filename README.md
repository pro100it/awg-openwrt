# AmneziaWG for OpenWrt 25.12.x (SNR AX2)

![OpenWrt](https://img.shields.io/badge/OpenWrt-25.12.x-blue)
![Platform](https://img.shields.io/badge/Platform-mediatek%2Ffilogic-orange)
![Manager](https://img.shields.io/badge/Packages-apk-green)
![Status](https://img.shields.io/badge/Status-Release--grade-success)

---

## 🇷🇺 Описание

**AmneziaWG** — это сборка WireGuard‑совместимого VPN (AWG 2.0) для **OpenWrt 25.12.x**, ориентированная на конкретную модель роутера **SNR AX2**.

⚠️ Это **форк оригинального репозитория**:
[https://github.com/Slava-Shchipunov/awg-openwrt](https://github.com/Slava-Shchipunov/awg-openwrt)

Проект использует **универсальный install‑скрипт**, который автоматически определяет версию OpenWrt и устанавливает подходящие `.apk`‑пакеты из GitHub Releases.

---

## 🇬🇧 Description

**AmneziaWG** is a WireGuard‑compatible VPN build (AWG 2.0) for **OpenWrt 25.12.x**, specifically targeting the **SNR AX2** router.

⚠️ This is a **fork of the original repository**:
[https://github.com/Slava-Shchipunov/awg-openwrt](https://github.com/Slava-Shchipunov/awg-openwrt)

The project uses a **single universal install script** that automatically detects the OpenWrt version and installs the correct `.apk` packages from GitHub Releases.

---

## 📌 Поддержка / Support

### ✅ Поддерживается / Supported

* **OpenWrt:** `25.12.0-rc1`, `25.12.0-rc2`, `25.12.0-rc3`, `25.12.0-rc4`
* **Device / Устройство:** SNR AX2
* **Target:** `mediatek / filogic`
* **AmneziaWG:** 2.0
* **Package format:** `.apk`
* **Package manager:** `apk`

### ❌ Не поддерживается / Not supported

* Другие устройства OpenWrt
* Другие версии OpenWrt

Использование на других платформах возможно **на ваш страх и риск**.

Using this build on other devices or OpenWrt versions is **at your own risk**.

---

## 📦 Установка / Installation

### 🔹 Вариант 1 — вручную / Manual

1. Перейдите в раздел **GitHub Releases**
2. Скачайте все `.apk` файлы, соответствующие вашей версии OpenWrt
3. Установите их на роутере:

```sh
apk add --allow-untrusted *.apk
```

---

### 🔹 Вариант 2 — универсальный скрипт (рекомендуется) / Universal script (recommended)

Скрипт автоматически:

* определяет версию OpenWrt
* определяет target устройства
* загружает нужные пакеты из Releases

The script automatically:

* detects OpenWrt version
* detects device target
* downloads the correct packages from Releases

```sh
sh <(wget -O - https://raw.githubusercontent.com/pro100it/awg-openwrt/master/amneziawg-install.sh)
```

Поддерживаемые версии / Supported versions:

* `25.12.0-rc1`
* `25.12.0-rc2`
* `25.12.0-rc3`
* `25.12.0-rc4`

---

## ⚙️ Настройка / Configuration

После установки настройка выполняется через **LuCI**:

```
Network → Interfaces → AmneziaWG
```

After installation, configure via **LuCI**:

```
Network → Interfaces → AmneziaWG
```

---

## ℹ️ Примечания / Notes

* Используется **один универсальный install‑скрипт**
* При выходе новых `rc`‑версий OpenWrt обновление скрипта **не требуется**
* Пакеты загружаются напрямую из **GitHub Releases**

---

## ⚠️ Disclaimer

Этот проект предоставляется **как есть**, без каких‑либо гарантий.

This project is provided **as is**, without any warranty.

---

## ❤️ Credits

* Original project: **Slava‑Shchipunov**
* Fork & automation: **pro100it**
