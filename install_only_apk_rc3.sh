#!/bin/sh

set -e

BASE_URL="https://github.com/pro100it/awg-openwrt/releases/download/v25.12.0-rc3"
POSTFIX="_v25.12.0-rc3__mediatek_filogic.apk"

echo "Установка amneziawg пакетов..."

# Устанавливаем каждый пакет
curl -L -o /tmp/kmod.apk "$BASE_URL/kmod-amneziawg$POSTFIX"
apk add --allow-untrusted /tmp/kmod.apk
echo "kmod-amneziawg установлен"

curl -L -o /tmp/tools.apk "$BASE_URL/amneziawg-tools$POSTFIX"
apk add --allow-untrusted /tmp/tools.apk
echo "amneziawg-tools установлен"

curl -L -o /tmp/luci.apk "$BASE_URL/luci-proto-amneziawg$POSTFIX"
apk add --allow-untrusted /tmp/luci.apk
echo "luci-proto-amneziawg установлен"

curl -L -o /tmp/ru.apk "$BASE_URL/luci-i18n-amneziawg-ru$POSTFIX"
apk add --allow-untrusted /tmp/ru.apk
echo "luci-i18n-amneziawg-ru установлен"

# Очистка
rm -f /tmp/*.apk

echo "Все пакеты установлены успешно!"
