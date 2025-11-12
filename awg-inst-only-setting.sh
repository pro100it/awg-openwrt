#!/bin/sh

#set -x

check_repo() {
    printf "\033[32;1mChecking OpenWrt repo availability...\033[0m\n"
    apk update | grep -q "Failed to download" && printf "\033[32;1mapk failed. Check internet or date. Command for force ntp sync: ntpd -p ptbtime1.ptb.de\033[0m\n" && exit 1
}

add_mark() {
    grep -q "99 vpn" /etc/iproute2/rt_tables || echo '99 vpn' >> /etc/iproute2/rt_tables
    
    if ! uci show network | grep -q mark0x1; then
        printf "\033[32;1mConfigure mark rule\033[0m\n"
        uci add network rule
        uci set network.@rule[-1].name='mark0x1'
        uci set network.@rule[-1].mark='0x1'
        uci set network.@rule[-1].priority='100'
        uci set network.@rule[-1].lookup='vpn'
        uci commit
    fi
}

add_tunnel() {
    echo "Select a tunnel:"
    echo "1) Amnezia WireGuard"
    echo "2) Skip this step"

    while true; do
    read -r -p '' TUNNEL
        case $TUNNEL in 
        1) 
            TUNNEL=awg
            break
            ;;
        2)
            echo "Skip"
            TUNNEL=0
            break
            ;;
        *)
            echo "Choose from the following options"
            ;;
        esac
    done

    if [ "$TUNNEL" == 'awg' ]; then
        printf "\033[32;1mConfigure Amnezia WireGuard\033[0m\n"

        # Проверяем установлены ли пакеты AmneziaWG
        if apk info | grep -q amneziawg-tools && apk info | grep -q kmod-amneziawg; then
            echo "AmneziaWG already installed"
        else
            echo "Please install AmneziaWG packages manually first:"
            echo "amneziawg-tools, kmod-amneziawg, luci-proto-amneziawg"
            exit 1
        fi

        read -r -p "Enter the private key (from [Interface]):"$'\n' AWG_PRIVATE_KEY

        while true; do
            read -r -p "Enter internal IP address with subnet, example 192.168.100.5/24 (Address from [Interface]):"$'\n' AWG_IP
            if echo "$AWG_IP" | egrep -oq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; then
                break
            else
                echo "This IP is not valid. Please repeat"
            fi
        done

        read -r -p "Enter Jc value (from [Interface]):"$'\n' AWG_JC
        read -r -p "Enter Jmin value (from [Interface]):"$'\n' AWG_JMIN
        read -r -p "Enter Jmax value (from [Interface]):"$'\n' AWG_JMAX
        read -r -p "Enter S1 value (from [Interface]):"$'\n' AWG_S1
        read -r -p "Enter S2 value (from [Interface]):"$'\n' AWG_S2
        read -r -p "Enter H1 value (from [Interface]):"$'\n' AWG_H1
        read -r -p "Enter H2 value (from [Interface]):"$'\n' AWG_H2
        read -r -p "Enter H3 value (from [Interface]):"$'\n' AWG_H3
        read -r -p "Enter H4 value (from [Interface]):"$'\n' AWG_H4
    
        read -r -p "Enter the public key (from [Peer]):"$'\n' AWG_PUBLIC_KEY
        read -r -p "If use PresharedKey, Enter this (from [Peer]). If your don't use leave blank:"$'\n' AWG_PRESHARED_KEY
        read -r -p "Enter Endpoint host without port (Domain or IP) (from [Peer]):"$'\n' AWG_ENDPOINT

        read -r -p "Enter Endpoint host port (from [Peer]) [51820]:"$'\n' AWG_ENDPOINT_PORT
        AWG_ENDPOINT_PORT=${AWG_ENDPOINT_PORT:-51820}
        
        uci set network.awg0=interface
        uci set network.awg0.proto='amneziawg'
        uci set network.awg0.private_key=$AWG_PRIVATE_KEY
        uci set network.awg0.listen_port='51820'
        uci set network.awg0.addresses=$AWG_IP

        uci set network.awg0.awg_jc=$AWG_JC
        uci set network.awg0.awg_jmin=$AWG_JMIN
        uci set network.awg0.awg_jmax=$AWG_JMAX
        uci set network.awg0.awg_s1=$AWG_S1
        uci set network.awg0.awg_s2=$AWG_S2
        uci set network.awg0.awg_h1=$AWG_H1
        uci set network.awg0.awg_h2=$AWG_H2
        uci set network.awg0.awg_h3=$AWG_H3
        uci set network.awg0.awg_h4=$AWG_H4

        if ! uci show network | grep -q amneziawg_awg0; then
            uci add network amneziawg_awg0
        fi

        uci set network.@amneziawg_awg0[0]=amneziawg_awg0
        uci set network.@amneziawg_awg0[0].name='awg0_client'
        uci set network.@amneziawg_awg0[0].public_key=$AWG_PUBLIC_KEY
        uci set network.@amneziawg_awg0[0].preshared_key=$AWG_PRESHARED_KEY
        uci set network.@amneziawg_awg0[0].route_allowed_ips='0'
        uci set network.@amneziawg_awg0[0].persistent_keepalive='25'
        uci set network.@amneziawg_awg0[0].endpoint_host=$AWG_ENDPOINT
        uci set network.@amneziawg_awg0[0].allowed_ips='0.0.0.0/0'
        uci set network.@amneziawg_awg0[0].endpoint_port=$AWG_ENDPOINT_PORT
        uci commit
    fi
}

dnsmasqfull() {
    if apk info | grep -q dnsmasq-full; then
        printf "\033[32;1mdnsmasq-full already installed\033[0m\n"
    else
        printf "\033[32;1mInstalling dnsmasq-full\033[0m\n"
        apk add dnsmasq-full
    fi
}

dnsmasqconfdir() {
    VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d '"' -f 2 | cut -d '.' -f 1)
    if [ "$VERSION_ID" -ge 24 ]; then
        if uci get dhcp.@dnsmasq[0].confdir | grep -q /tmp/dnsmasq.d; then
            printf "\033[32;1mconfdir already set\033[0m\n"
        else
            printf "\033[32;1mSetting confdir\033[0m\n"
            uci set dhcp.@dnsmasq[0].confdir='/tmp/dnsmasq.d'
            uci commit dhcp
        fi
    fi
}

add_zone() {
    if  [ "$TUNNEL" == 0 ]; then
        printf "\033[32;1mZone setting skipped\033[0m\n"
    elif uci show firewall | grep -q "@zone.*name='$TUNNEL'"; then
        printf "\033[32;1mZone already exist\033[0m\n"
    else
        printf "\033[32;1mCreate zone\033[0m\n"

        uci add firewall zone
        uci set firewall.@zone[-1].name="$TUNNEL"
        uci set firewall.@zone[-1].network='awg0'
        uci set firewall.@zone[-1].forward='REJECT'
        uci set firewall.@zone[-1].output='ACCEPT'
        uci set firewall.@zone[-1].input='REJECT'
        uci set firewall.@zone[-1].masq='1'
        uci set firewall.@zone[-1].mtu_fix='1'
        uci set firewall.@zone[-1].family='ipv4'
        uci commit firewall
        
        printf "\033[32;1mConfigured forwarding\033[0m\n"
        uci add firewall forwarding
        uci set firewall.@forwarding[-1]=forwarding
        uci set firewall.@forwarding[-1].name="$TUNNEL-lan"
        uci set firewall.@forwarding[-1].dest="$TUNNEL"
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].family='ipv4'
        uci commit firewall
    fi
}

add_set() {
    if uci show firewall | grep -q "@ipset.*name='vpn_domains'"; then
        printf "\033[32;1mSet already exist\033[0m\n"
    else
        printf "\033[32;1mCreate set\033[0m\n"
        uci add firewall ipset
        uci set firewall.@ipset[-1].name='vpn_domains'
        uci set firewall.@ipset[-1].match='dst_net'
        uci commit
    fi
    if uci show firewall | grep -q "@rule.*name='mark_domains'"; then
        printf "\033[32;1mRule for set already exist\033[0m\n"
    else
        printf "\033[32;1mCreate rule set\033[0m\n"
        uci add firewall rule
        uci set firewall.@rule[-1]=rule
        uci set firewall.@rule[-1].name='mark_domains'
        uci set firewall.@rule[-1].src='lan'
        uci set firewall.@rule[-1].dest='*'
        uci set firewall.@rule[-1].proto='all'
        uci set firewall.@rule[-1].ipset='vpn_domains'
        uci set firewall.@rule[-1].set_mark='0x1'
        uci set firewall.@rule[-1].target='MARK'
        uci set firewall.@rule[-1].family='ipv4'
        uci commit
    fi
}

add_dns_resolver() {
    echo "Configure Stubby for secure DNS?"
    echo "Select:"
    echo "1) No [Default]"
    echo "2) Stubby"

    while true; do
    read -r -p '' DNS_RESOLVER
        case $DNS_RESOLVER in 
        1) 
            echo "Skipped"
            break
            ;;
        2) 
            DNS_RESOLVER=STUBBY
            break
            ;;
        *)
            echo "Choose from the following options"
            ;;
        esac
    done

    if [ "$DNS_RESOLVER" == 'STUBBY' ]; then
        printf "\033[32;1mConfigure Stubby\033[0m\n"

        if apk info | grep -q stubby; then
            printf "\033[32;1mStubby already installed\033[0m\n"
        else
            printf "\033[32;1mInstalling stubby\033[0m\n"
            apk add stubby

            printf "\033[32;1mConfigure Dnsmasq for Stubby\033[0m\n"
            uci set dhcp.@dnsmasq[0].noresolv="1"
            uci -q delete dhcp.@dnsmasq[0].server
            uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5453"
            uci add_list dhcp.@dnsmasq[0].server='/use-application-dns.net/'
            uci commit dhcp

            printf "\033[32;1mDnsmasq restart\033[0m\n"
            /etc/init.d/dnsmasq restart
        fi
    fi
}

add_packages() {
    for package in curl nano; do
        if apk info | grep -q "^$package"; then
            printf "\033[32;1m$package already installed\033[0m\n"
        else
            printf "\033[32;1mInstalling $package...\033[0m\n"
            apk add "$package"
        fi
    done
}

add_getdomains() {
    echo "Choose you country"
    echo "Select:"
    echo "1) Russia inside. You are inside Russia"
    echo "2) Russia outside. You are outside of Russia, but you need access to Russian resources"
    echo "3) Ukraine. uablacklist.net list"
    echo "4) Skip script creation"

    while true; do
    read -r -p '' COUNTRY
        case $COUNTRY in 

        1) 
            COUNTRY=russia_inside
            break
            ;;

        2)
            COUNTRY=russia_outside
            break
            ;;

        3) 
            COUNTRY=ukraine
            break
            ;;

        4) 
            echo "Skiped"
            COUNTRY=0
            break
            ;;

        *)
            echo "Choose from the following options"
            ;;
        esac
    done

    if [ "$COUNTRY" == 'russia_inside' ]; then
        DOMAINS_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-dnsmasq-nfset.lst"
    elif [ "$COUNTRY" == 'russia_outside' ]; then
        DOMAINS_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/outside-dnsmasq-nfset.lst"
    elif [ "$COUNTRY" == 'ukraine' ]; then
        DOMAINS_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Ukraine/inside-dnsmasq-nfset.lst"
    fi

    if [ "$COUNTRY" != '0' ]; then
        printf "\033[32;1mCreate script /etc/init.d/getdomains\033[0m\n"

        # Создаем директорию если не существует
        mkdir -p /tmp/dnsmasq.d

cat << EOF > /etc/init.d/getdomains
#!/bin/sh /etc/rc.common

START=99

start() {
    count=0
    while [ \$count -lt 3 ]; do
        echo "Trying to download domains list... attempt \$((count+1))"
        if curl -m 15 -k -f "$DOMAINS_URL" -o /tmp/dnsmasq.d/domains.lst; then
            echo "Domains list downloaded successfully"
            if [ -s /tmp/dnsmasq.d/domains.lst ]; then
                echo "File size: \$(wc -l < /tmp/dnsmasq.d/domains.lst) lines"
                if dnsmasq --conf-file=/tmp/dnsmasq.d/domains.lst --test 2>&1 | grep -q "syntax check OK"; then
                    echo "Syntax check passed, restarting dnsmasq"
                    /etc/init.d/dnsmasq restart
                    break
                else
                    echo "Syntax check failed. File content:"
                    head -5 /tmp/dnsmasq.d/domains.lst
                    echo "..."
                fi
            else
                echo "Downloaded file is empty"
            fi
        else
            echo "Failed to download domains list (attempt \$((count+1)))"
            count=\$((count+1))
            sleep 5
        fi
    done
}

stop() {
    return 0
}
EOF

        chmod +x /etc/init.d/getdomains
        /etc/init.d/getdomains enable

        # Исправляем добавление в crontab
        printf "\033[32;1mAdding cron job...\033[0m\n"
        (crontab -l 2>/dev/null || true; echo "0 */8 * * * /etc/init.d/getdomains start") | crontab -

        printf "\033[32;1mStart script\033[0m\n"
        /etc/init.d/getdomains start
    fi
}

# System Details
MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || echo "Unknown")
if [ -f /etc/os-release ]; then
    source /etc/os-release
    printf "\033[34;1mModel: $MODEL\033[0m\n"
    printf "\033[34;1mVersion: ${OPENWRT_RELEASE:-Unknown}\033[0m\n"
else
    printf "\033[34;1mModel: $MODEL\033[0m\n"
    printf "\033[34;1mVersion: Unknown\033[0m\n"
fi

printf "\033[31;1mAll actions performed here cannot be rolled back automatically.\033[0m\n"

check_repo
add_packages
add_tunnel
add_mark
dnsmasqfull
dnsmasqconfdir
add_zone
add_set
add_dns_resolver
add_getdomains

printf "\033[32;1mRestart network\033[0m\n"
/etc/init.d/network restart

printf "\033[32;1mDone\033[0m\n"