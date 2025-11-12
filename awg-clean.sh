#!/bin/sh

remove_amneziawg_config() {
    printf "\033[32;1mRemoving AmneziaWG configuration...\033[0m\n"
    
    # Удаляем конфигурацию интерфейса
    uci delete network.awg1 2>/dev/null
    uci delete network.amneziawg_awg1 2>/dev/null
    
    # Удаляем firewall zone (ищем по имени)
    ZONE_ID=$(uci show firewall | grep "@zone\[.*\].name='awg1'" | cut -d'[' -f2 | cut -d']' -f1)
    if [ -n "$ZONE_ID" ]; then
        uci delete firewall.@zone[$ZONE_ID] 2>/dev/null
    fi
    
    # Удаляем forwarding правила (ищем по dest или src awg1)
    FORWARDING_IDS=$(uci show firewall | grep -E "@forwarding\[.*\]\.(dest|src)='awg1'" | cut -d'[' -f2 | cut -d']' -f1 | sort -r | uniq)
    for ID in $FORWARDING_IDS; do
        uci delete firewall.@forwarding[$ID] 2>/dev/null
    done
    
    # Коммитим изменения
    uci commit network
    uci commit firewall
    
    # Останавливаем и удаляем интерфейс
    ifdown awg1 2>/dev/null
    ip link delete dev awg1 2>/dev/null
    
    printf "\033[32;1mAmneziaWG configuration removed successfully\033[0m\n"
}

remove_amneziawg_packages() {
    printf "\033[32;1mRemoving AmneziaWG packages...\033[0m\n"
    
    # Удаляем пакеты в правильном порядке (зависимости)
    opkg remove --autoremove luci-i18n-amneziawg-ru 2>/dev/null
    opkg remove --autoremove luci-proto-amneziawg 2>/dev/null
    opkg remove --autoremove luci-app-amneziawg 2>/dev/null
    opkg remove --autoremove amneziawg-tools 2>/dev/null
    opkg remove --autoremove kmod-amneziawg 2>/dev/null
    
    printf "\033[32;1mAmneziaWG packages removed successfully\033[0m\n"
}

clean_temp_files() {
    printf "\033[32;1mCleaning temporary files...\033[0m\n"
    
    # Удаляем временные файлы
    rm -rf /tmp/amneziawg 2>/dev/null
    
    # Очищаем кеш opkg
    rm -f /tmp/opkg-lists/* 2>/dev/null
    
    printf "\033[32;1mTemporary files cleaned\033[0m\n"
}

show_remaining_config() {
    printf "\033[33;1mChecking for remaining AmneziaWG configurations...\033[0m\n"
    
    # Проверяем оставшиеся конфигурации в uci
    REMAINING_NETWORK=$(uci show network | grep -E "(awg|amneziawg)")
    REMAINING_FIREWALL=$(uci show firewall | grep -E "(awg|amneziawg)")
    
    if [ -n "$REMAINING_NETWORK" ]; then
        printf "\033[31;1mRemaining network configurations:\033[0m\n"
        echo "$REMAINING_NETWORK"
    fi
    
    if [ -n "$REMAINING_FIREWALL" ]; then
        printf "\033[31;1mRemaining firewall configurations:\033[0m\n"
        echo "$REMAINING_FIREWALL"
    fi
    
    # Проверяем запущенные процессы
    RUNNING_PROCESSES=$(ps | grep -E "(amneziawg|awg)" | grep -v grep)
    if [ -n "$RUNNING_PROCESSES" ]; then
        printf "\033[31;1mRunning AmneziaWG processes:\033[0m\n"
        echo "$RUNNING_PROCESSES"
    fi
    
    # Проверяем существующие интерфейсы
    EXISTING_INTERFACES=$(ip link show | grep awg)
    if [ -n "$EXISTING_INTERFACES" ]; then
        printf "\033[31;1mExisting AWG interfaces:\033[0m\n"
        echo "$EXISTING_INTERFACES"
    fi
}

main_cleanup() {
    printf "\033[32;1m=== AmneziaWG Complete Cleanup ===\033[0m\n"
    
    # Останавливаем сетевые службы перед очисткой
    printf "\033[32;1mStopping network services...\033[0m\n"
    /etc/init.d/network stop 2>/dev/null
    /etc/init.d/firewall stop 2>/dev/null
    
    # 1. Удаляем конфигурацию
    remove_amneziawg_config
    
    # 2. Удаляем пакеты (раскомментируйте если нужно удалить и пакеты)
    printf "\033[33;1mDo you want to remove AmneziaWG packages as well? (y/n) [n]: \033[0m"
    read REMOVE_PACKAGES
    REMOVE_PACKAGES=${REMOVE_PACKAGES:-n}
    
    if [ "$REMOVE_PACKAGES" = "y" ] || [ "$REMOVE_PACKAGES" = "Y" ]; then
        remove_amneziawg_packages
    else
        printf "\033[32;1mSkipping package removal\033[0m\n"
    fi
    
    # 3. Очищаем временные файлы
    clean_temp_files
    
    # 4. Перезапускаем службы
    printf "\033[32;1mRestarting network services...\033[0m\n"
    /etc/init.d/firewall start 2>/dev/null
    /etc/init.d/network start 2>/dev/null
    /etc/init.d/firewall restart 2>/dev/null
    /etc/init.d/network restart 2>/dev/null
    
    # 5. Показываем оставшиеся конфигурации
    show_remaining_config
    
    printf "\033[32;1m=== Cleanup completed ===\033[0m\n"
}

# Запуск очистки
main_cleanup