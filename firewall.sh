#!/bin/sh

for arg in "$@"; do
    case $arg in
        proxy-type=*)
            PROXY_TYPE=`echo $arg | sed 's/proxy-type=//g'`
            ;;
        proxy-ip=*)
            PROXY_IP=`echo $arg | sed 's/proxy-ip=//g'`
            ;;
        proxy-port=*)
            PROXY_PORT=`echo $arg | sed 's/proxy-port=//g'`
            ;;
        mac=*)
            DEVICE_MAC=`echo $arg | sed -e 's/mac=//g' -e 's/%3A/:/g'`
            ;;
        *)
            echo "huh?"
            ;;
    esac
done

CGI_DIR=/www/cgi-bin
WAN_IFACE=eth0.2
OLD_PROXY_IP=`cat /www/cgi-bin/PROXY_IP`

# kind of a hack
iptables -F && iptables-restore < $CGI_DIR/default.rules

case $PROXY_TYPE in
full)
    # maybe not needed?
    #ip route flush $OLD_PROXY_IP
    #ip route del default via $OLD_PROXY_IP dev $WAN_IFACE table 2

    if [ ! -z $DEVICE_MAC ]; then
        iptables -t mangle -A PREROUTING -j ACCEPT -p tcp -m multiport --dports 80,443 -s $PROXY_IP -m mac --mac-source $DEVICE_MAC
        iptables -t mangle -A PREROUTING -j MARK --set-mark 3 -p tcp -m multiport --dports 80,443 -m mac --mac-source $DEVICE_MAC
    else
        iptables -t mangle -A PREROUTING -j ACCEPT -p tcp -m multiport --dports 80,443 -s $PROXY_IP
        iptables -t mangle -A PREROUTING -j MARK --set-mark 3 -p tcp -m multiport --dports 80,443
    fi

    ip rule add fwmark 3 table 2
    #ip route add default via $PROXY_IP dev $WAN_IFACE table 2
    #[ $? != 0 ] && 
    ip route replace default via $PROXY_IP dev $WAN_IFACE table 2
    ;;
partial)
    PROXY_PORT=8888
    #LAN_IP=`nvram get lan_ipaddr`
    LAN_IP=192.168.3.1
    LAN_NET=$LAN_IP/`nvram get lan_netmask`
    LAN_IFACE=br-lan

    if [ ! -z ${DEVICE_MAC} ]; then
        iptables -t nat -A PREROUTING -i $LAN_IFACE -s $LAN_NET -d $LAN_NET -p tcp --dport 80 -j ACCEPT -m mac --mac-source $DEVICE_MAC
        iptables -t nat -A PREROUTING -i $LAN_IFACE ! -s $PROXY_IP -p tcp --dport 80 -j DNAT --to $PROXY_IP:$PROXY_PORT -m mac --mac-source $DEVICE_MAC
        iptables -t nat -I POSTROUTING -o $LAN_IFACE -s $LAN_NET -d $PROXY_IP -p tcp -j SNAT --to $LAN_IP -m mac --mac-source $DEVICE_MAC
        iptables -I FORWARD -i $LAN_IFACE -o $LAN_IFACE -s $LAN_NET -d $PROXY_IP -p tcp --dport $PROXY_PORT -j ACCEPT -m mac --mac-source $DEVICE_MAC
    else
        iptables -t nat -A PREROUTING -i $LAN_IFACE -s $LAN_NET -d $LAN_NET -p tcp --dport 80 -j ACCEPT
        iptables -t nat -A PREROUTING -i $LAN_IFACE ! -s $PROXY_IP -p tcp --dport 80 -j DNAT --to $PROXY_IP:$PROXY_PORT
        iptables -t nat -I POSTROUTING -o $LAN_IFACE -s $LAN_NET -d $PROXY_IP -p tcp -j SNAT --to $LAN_IP
        iptables -I FORWARD -i $LAN_IFACE -o $LAN_IFACE -s $LAN_NET -d $PROXY_IP -p tcp --dport $PROXY_PORT -j ACCEPT
    fi
    ;;
*)
    echo "unreconized proxy type \"$PROXY_TYPE\""
    exit 1
esac

if [ $? = 0 ]; then
    echo $PROXY_TYPE > $CGI_DIR/PROXY_TYPE
    [ ! -z $PROXY_IP ] && echo $PROXY_IP > $CGI_DIR/PROXY_IP
    echo $DEVICE_MAC > $CGI_DIR/DEVICE_MAC
fi
