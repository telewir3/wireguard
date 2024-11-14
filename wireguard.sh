sudo apk add wireguard-tools wireguard-rpi libqrencode

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.proxy_arp" >> /etc/sysctl.conf
sed -i 's/IPFORWARD="no"/IPFORWARD="yes"/g' /etc/conf.d/iptables

cd /etc/wireguard
umask 077
wg genkey | tee peer1_privatekey | wg pubkey > peer1_publickey
wg genkey | tee server_privatekey | wg pubkey > server_publickey

cat << END > /etc/wireguard/wg0.conf
[Interface]
Address = 192.168.2.1/24
SaveConfig = true
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_privatekey)

PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE

[Peer]
PublicKey = $(cat /etc/wireguard/peer1_publickey)
AllowedIPs = 192.168.2.2/32
END

cat << END > /etc/wireguard/peer1.conf
[Interface]
Address = 192.168.2.2/32
PrivateKey = $(cat /etc/wireguard/peer1_privatekey)

[Peer]
PublicKey = $(cat /etc/wireguard/server_publickey)
Endpoint = home.knoopx.net:51820
AllowedIPs = 0.0.0.0/0, ::/0
END

cat << END > /etc/init.d/wg-quick
#!/sbin/openrc-run
# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

name="WireGuard"
description="WireGuard via wg-quick(8)"

depend() {
	need net
	use dns
}

CONF="${SVCNAME#*.}"

checkconfig() {
	if [ "$CONF" = "$SVCNAME" ]; then
		eerror "You cannot call this init script directly. You must create a symbolic link to it with the configuration name:"
		eerror "    ln -s /etc/init.d/wg-quick /etc/init.d/wg-quick.vpn0"
		eerror "And then call it instead:"
		eerror "    /etc/init.d/wg-quick.vpn0 start"
		return 1
	fi
}

start() {
	ebegin "Starting $description for $CONF"
	wg-quick up "$CONF"
	eend $? "Failed to start $description for $CONF"
}

stop() {
	ebegin "Stopping $description for $CONF"
	wg-quick down "$CONF"
	eend $? "Failed to stop $description for $CONF"
}
END

ln -s /etc/init.d/wg-quick /etc/init.d/wg-quick.wg0
rc-update add wg-quick.wg0

qrencode -t ansiutf8 < /etc/wireguard/peer1.conf
