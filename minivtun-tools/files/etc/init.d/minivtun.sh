#!/bin/sh
#
# Copyright (C) 2014 Justin Liu <rssnsj@gmail.com>
#

### BEGIN INIT INFO
# Provides: minivtun-tools
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:
# Short-Description: Non-standard VPN that helps you to get through firewalls
### END INIT INFO

START=93

VPN_ROUTE_FWMARK=199
VPN_IPROUTE_TABLE=virtual
DNSMASQ_PORT=53
DNSMASQ_PIDFILE=/var/run/dnsmasq-go.pid

[ -f /etc/default/minivtun ] && . /etc/default/minivtun
if [ -z "$vt_enabled" -o "$vt_enabled" = 0 ]; then
	echo "WARNING: Mini Virtual Tunneller is disabled."
	return 1
fi

__netmask_to_bits()
{
	local netmask="$1"
	local __masklen=0
	local __byte

	for __byte in `echo "$netmask" | sed 's/\./ /g'`; do
		case "$__byte" in
			255) __masklen=`expr $__masklen + 8`;;
			254) __masklen=`expr $__masklen + 7`;;
			252) __masklen=`expr $__masklen + 6`;;
			248) __masklen=`expr $__masklen + 5`;;
			240) __masklen=`expr $__masklen + 4`;;
			224) __masklen=`expr $__masklen + 3`;;
			192) __masklen=`expr $__masklen + 2`;;
			128) __masklen=`expr $__masklen + 1`;;
			0) break;;
		esac
	done

	echo "$__masklen"
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

# New implementation:
# Attach rules to main 'dnsmasq' service and restart it.

do_start()
{
#	local vt_enabled=`uci get minivtun.@minivtun[0].enabled 2>/dev/null`
#	local vt_network=`uci get minivtun.@minivtun[0].network 2>/dev/null`
#	local vt_server_addr=`uci get minivtun.@minivtun[0].server`
#	local vt_server_port=`uci get minivtun.@minivtun[0].server_port`
#	local vt_password=`uci get minivtun.@minivtun[0].password 2>/dev/null`
#	local vt_local_ipaddr=`uci get minivtun.@minivtun[0].local_ipaddr 2>/dev/null`
#	local vt_local_netmask=`uci get minivtun.@minivtun[0].local_netmask 2>/dev/null`
#	local vt_local_ip6pair=`uci get minivtun.@minivtun[0].local_ip6pair 2>/dev/null`
#	local vt_safe_dns=`uci get minivtun.@minivtun[0].safe_dns 2>/dev/null`
#	local vt_safe_dns_port=`uci get minivtun.@minivtun[0].safe_dns_port 2>/dev/null`
#	local vt_proxy_mode=`uci get minivtun.@minivtun[0].proxy_mode`
#	#local vt_protocols=`uci get minivtun.@minivtun[0].protocols 2>/dev/null`
#	# $covered_subnets, $local_addresses are not required
#	local covered_subnets=`uci get minivtun.@minivtun[0].covered_subnets 2>/dev/null`
#	local local_addresses=`uci get minivtun.@minivtun[0].local_addresses 2>/dev/null`

	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		echo "WARNING: No server address configured, not starting."
		return 1
	fi
	[ -z "$vt_network" ] && vt_network="vt0"
	[ -z "$vt_local_netmask" ] && vt_local_netmask="255.255.255.0"
	[ -z "$vt_proxy_mode" ] && vt_proxy_mode=S
	[ -z "$vt_safe_dns_port" ] && vt_safe_dns_port=53
	# Get LAN settings as default parameters
	[ -z "$covered_subnets" ] && covered_subnets="192.168.10.0/24"
	[ -z "$local_addresses" ] && local_addresses="192.168.10.1"
	local vt_ifname="minivtun-$vt_network"
	local vt_local_prefix=`__netmask_to_bits "$vt_local_netmask"`
	local vt_gfwlist="china-banned"
	local vt_np_ipset="china"

	# -----------------------------------------------------------------
	/usr/sbin/minivtun -r $vt_server_addr:$vt_server_port \
		-a $vt_local_ipaddr/$vt_local_prefix -n $vt_ifname -e "$vt_password" \
		-d -p /var/run/$vt_ifname.pid || return 1

	# IMPORTANT: 'rp_filter=1' will cause returned packets from
	# virtual interface being dropped, so we have to fix it.
	echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
	echo 0 > /proc/sys/net/ipv4/conf/$vt_ifname/rp_filter

	# -----------------------------------------------------------------
	###### IPv4 firewall rules and policy routing ######
	if ! grep '^175' /etc/iproute2/rt_tables >/dev/null; then
		( echo ""; echo "175   $VPN_IPROUTE_TABLE" ) >> /etc/iproute2/rt_tables
	fi

	if ! ip route add default dev $vt_ifname table $VPN_IPROUTE_TABLE; then
		echo "*** Unexpected error while setting default route for table 'virtual'."
		return 1
	fi
	ip rule add fwmark $VPN_ROUTE_FWMARK table $VPN_IPROUTE_TABLE

	iptables -t mangle -N minivtun_$vt_network
	iptables -t mangle -F minivtun_$vt_network
	iptables -t mangle -A minivtun_$vt_network -m set --match-set local dst -j RETURN || {
		iptables -t mangle -A minivtun_$vt_network -d 10.0.0.0/8 -j RETURN
		iptables -t mangle -A minivtun_$vt_network -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A minivtun_$vt_network -d 172.16.0.0/12 -j RETURN
		iptables -t mangle -A minivtun_$vt_network -d 192.168.0.0/16 -j RETURN
		iptables -t mangle -A minivtun_$vt_network -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A minivtun_$vt_network -d 224.0.0.0/3 -j RETURN
	}
	iptables -t mangle -A minivtun_$vt_network -d $vt_server_addr -j RETURN
	case "$vt_proxy_mode" in
		G) : ;;
		S)
			iptables -t mangle -A minivtun_$vt_network -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		M)
			ipset create gfwlist hash:ip maxelem 65536
			[ -n "$vt_safe_dns" ] && ipset add gfwlist $vt_safe_dns
			iptables -t mangle -A minivtun_$vt_network -m set ! --match-set gfwlist dst -j RETURN
			iptables -t mangle -A minivtun_$vt_network -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		V)
			vt_np_ipset=""
			vt_gfwlist="unblock-youku"
			ipset create gfwlist hash:ip maxelem 65536
			[ -n "$vt_safe_dns" ] && ipset add gfwlist $vt_safe_dns
			iptables -t mangle -A minivtun_$vt_network -m set ! --match-set gfwlist dst -j RETURN
			;;
	esac
	iptables -t mangle -A minivtun_$vt_network -j MARK --set-mark $VPN_ROUTE_FWMARK

	iptables -t mangle -I PREROUTING -j minivtun_$vt_network
	iptables -t mangle -I OUTPUT -j minivtun_$vt_network

	# -----------------------------------------------------------------
	mkdir -p /tmp/etc/dnsmasq-go.d
	###### Anti-pollution configuration ######
	if [ -n "$vt_safe_dns" ]; then
		awk -vs="$vt_safe_dns#$vt_safe_dns_port" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
			/etc/gfwlist/$vt_gfwlist > /tmp/etc/dnsmasq-go.d/01-pollution.conf
	else
		echo "WARNING: Not using secure DNS, DNS resolution might be polluted if you are in China."
	fi

	###### dnsmasq-to-ipset configuration ######
	case "$vt_proxy_mode" in
		M|V)
			awk '!/^$/&&!/^#/{printf("ipset=/%s/gfwlist\n",$0)}' \
				/etc/gfwlist/$vt_gfwlist > /tmp/etc/dnsmasq-go.d/02-ipset.conf
			;;
	esac

	# -----------------------------------------------------------------
	###### Restart main 'dnsmasq' service if needed ######
	if ls /tmp/etc/dnsmasq-go.d/* >/dev/null 2>&1; then
		cat > /tmp/etc/dnsmasq-go.conf <<EOF
conf-dir=/tmp/etc/dnsmasq-go.d
resolv-file=/tmp/etc/resolv.conf.auto
EOF
		if ! grep 'nameserver[ \t]\+127\.0\.0\.1' /etc/resolv.conf >/dev/null; then
			cat /etc/resolv.conf > /tmp/etc/resolv.conf.auto
		fi
		if dnsmasq -C /tmp/etc/dnsmasq-go.conf -p $DNSMASQ_PORT -x $DNSMASQ_PIDFILE; then
			echo "nameserver 127.0.0.1" > /etc/resolv.conf
		else
			echo "*** WARNING: 'dnsmasq' service was not started successfully."
		fi
	fi

}

do_stop()
{
#	local vt_network=`uci get minivtun.@minivtun[0].network 2>/dev/null`

	[ -z "$vt_network" ] && vt_network="vt0"
	local vt_ifname="minivtun-$vt_network"

	# -----------------------------------------------------------------
	# Stop 'dnsmasq' service and delete configuration files
	if [ -f $DNSMASQ_PIDFILE ]; then
		kill -9 `cat $DNSMASQ_PIDFILE`
		rm -f $DNSMASQ_PIDFILE
	fi
	rm -rf /tmp/etc/dnsmasq-go.d
	rm -f /tmp/etc/dnsmasq-go.conf
	# Restore /etc/resolv.conf
	if grep 'nameserver[ \t]\+127\.0\.0\.1' /etc/resolv.conf >/dev/null; then
		[ -f /tmp/etc/resolv.conf.auto ] && cat /tmp/etc/resolv.conf.auto > /etc/resolv.conf
	fi

	# -----------------------------------------------------------------
	if iptables -t mangle -F minivtun_$vt_network 2>/dev/null; then
		while iptables -t mangle -D OUTPUT -j minivtun_$vt_network 2>/dev/null; do :; done
		while iptables -t mangle -D PREROUTING -j minivtun_$vt_network 2>/dev/null; do :; done
		iptables -t mangle -X minivtun_$vt_network 2>/dev/null
	fi

	# -----------------------------------------------------------------
	ipset destroy gfwlist 2>/dev/null

	# -----------------------------------------------------------------
	# We don't have to delete the default route in 'virtual', since
	# it will be brought down along with the interface.
	while ip rule del fwmark $VPN_ROUTE_FWMARK table $VPN_IPROUTE_TABLE 2>/dev/null; do :; done

	if [ -f /var/run/$vt_ifname.pid ]; then
		kill -9 `cat /var/run/$vt_ifname.pid`
		rm -f /var/run/$vt_ifname.pid
	fi

}

case "$1" in
	start)
		do_start
		;;
	stop)
		do_stop
		;;
	restart)
		do_stop
		do_start
		;;
	*)
		echo "Usage: $0 {start|stop|restart}"
		exit 1
		;;
esac

