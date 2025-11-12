#!/bin/sh

quick_cleanup() {
    printf "\033[32;1mQuick AmneziaWG configuration cleanup...\033[0m\n"
    
    # Удаляем конфигурацию интерфейса
    uci delete network.awg1 2>/dev/null && echo "Removed network.awg1"
    uci delete network.amneziawg_awg1 2>/dev/null && echo "Removed network.amneziawg_awg1"
    
    # Удаляем firewall zone
    ZONE_ID=$(uci show firewall | grep "@zone\[.*\].name='awg1'" | cut -d'[' -f2 | cut -d']' -f1)
    if [ -n "$ZONE_ID" ]; then
        uci delete firewall.@zone[$ZONE_ID] 2>/dev/null && echo "Removed firewall zone awg1"
    fi
    
    # Удаляем forwarding правила
    FORWARDING_IDS=$(uci show firewall | grep -E "@forwarding\[.*\]\.(dest|src)='awg1'" | cut -d'[' -f2 | cut -d']' -f1 | sort -r | uniq)
    for ID in $FORWARDING_IDS; do
        uci delete firewall.@forwarding[$ID] 2>/dev/null && echo "Removed firewall forwarding rule $ID"
    done
    
    # Коммитим изменения
    uci commit network
    uci commit firewall
    
    # Останавливаем интерфейс
    ifdown awg1 2>/dev/null
    ip link delete dev awg1 2>/dev/null 2>/dev/null
    
    # Перезапускаем службы
    /etc/init.d/network restart
    /etc/init.d/firewall restart
    
    printf "\033[32;1mQuick cleanup completed\033[0m\n"
}

quick_cleanup