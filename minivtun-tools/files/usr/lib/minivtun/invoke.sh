#!/bin/sh
#
# Copyright (C) 2014 Justin Liu <rssnsj@gmail.com>
# https://github.com/rssnsj/network-feeds
#

MAX_DNS_WAIT_DEFAULT=120
VPN_ROUTE_FWMARK=199
VPN_IPROUTE_TABLE=virtual

[ -f /etc/default/minivtun ] && . /etc/default/minivtun
if [ -z "$vt_enabled" -o "$vt_enabled" = 0 ]; then
	echo "WARNING: Mini Virtual Tunneller is disabled."
	exit 1
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

# $1: hostname to resolve
# $1: maximum seconds to wait until successful
wait_dns_ready()
{
	local host="$1"
	local timeo="$2"

	# Wait for domain name to be ready
	if expr "$host" : '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$' >/dev/null; then
		return 0
	else
		local dns_ok=N
		local ts_start=`date +%s`
		while :; do
			if nslookup "$host" >/dev/null 2>&1; then
				dns_ok=Y
				return 0
			fi

			sleep 5

			local ts_tick=`date +%s`
			local ts_diff=`expr $ts_tick - $ts_start`
			if [ "$timeo" = 0 ]; then
				continue
			elif [ "$ts_diff" -gt 10000 ]; then
				# Eliminate time jumps on boot
				ts_start=$ts_tick
				continue
			elif ! [ "$ts_diff" -lt "$timeo" ]; then
				# Timed out
				return 1
			fi
		done

		# Never reaches here
		return 1
	fi
}

logger_warn()
{
	logger -s -t minivtun -p daemon.warn "$1"
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

__gfwlist_by_mode()
{
	case "$1" in
		V) echo unblock-youku;;
		*) echo china-banned;;
	esac
}

# New implementation:
# Attach rules to main 'dnsmasq' service and restart it.

do_start_wait()
{
	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		logger_warn "WARNING: No server address configured, not starting."
		return 1
	fi

	[ -z "$vt_network" ] && vt_network="vt0"
	[ -z "$vt_algorithm" ] && vt_algorithm="aes-128"
	[ -z "$vt_local_netmask" ] && vt_local_netmask="255.255.255.0"
	[ -z "$vt_proxy_mode" ] && vt_proxy_mode=S
	[ -z "$vt_safe_dns_port" ] && vt_safe_dns_port=53
	[ -z "$vt_max_dns_wait" ] && vt_max_dns_wait=$MAX_DNS_WAIT_DEFAULT
	# Get LAN settings as default parameters
	[ -f /lib/functions/network.sh ] && . /lib/functions/network.sh
	[ -z "$covered_subnets" ] && covered_subnets="192.168.10.0/24"
	[ -z "$local_addresses" ] && local_addresses="192.168.10.1"
	local vt_ifname="minivtun-$vt_network"
	local vt_local_prefix=`__netmask_to_bits "$vt_local_netmask"`
	local vt_gfwlist=`__gfwlist_by_mode $vt_proxy_mode`
	local vt_np_ipset="china"
	local cmdline_opts=""
	[ -n "$vt_mtu" ] && cmdline_opts="-m$vt_mtu"

	# -----------------------------------------------------------------
	if ! wait_dns_ready "$vt_server_addr" "$vt_max_dns_wait"; then
		logger_warn "*** Failed to resolve '$vt_server_addr', quitted."
		return 1
	fi

	/usr/sbin/minivtun -r $vt_server_addr:$vt_server_port \
		-a $vt_local_ipaddr/$vt_local_prefix -n $vt_ifname \
		-e "$vt_password" -t "$vt_algorithm" $cmdline_opts -d \
		-p /var/run/$vt_ifname.pid || return 1

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
		logger_warn "Unexpected error while setting default route for table 'virtual'."
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
			ipset create $vt_gfwlist hash:ip maxelem 65536 2>/dev/null
			[ -n "$vt_safe_dns" ] && ipset add $vt_gfwlist $vt_safe_dns 2>/dev/null
			iptables -t mangle -A minivtun_$vt_network -m set ! --match-set $vt_gfwlist dst -j RETURN
			iptables -t mangle -A minivtun_$vt_network -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		V)
			vt_np_ipset=""
			ipset create $vt_gfwlist hash:ip maxelem 65536 2>/dev/null
			[ -n "$vt_safe_dns" ] && ipset add $vt_gfwlist $vt_safe_dns 2>/dev/null
			iptables -t mangle -A minivtun_$vt_network -m set ! --match-set $vt_gfwlist dst -j RETURN
			;;
	esac
	local subnet
	for subnet in $covered_subnets; do
		iptables -t mangle -A minivtun_$vt_network -s $subnet -j MARK --set-mark $VPN_ROUTE_FWMARK
	done
	[ -n "$vt_safe_dns" ] && \
		iptables -t mangle -A minivtun_$vt_network -d $vt_safe_dns -p udp --dport $vt_safe_dns_port -j MARK --set-mark $VPN_ROUTE_FWMARK
	iptables -t mangle -I PREROUTING -j minivtun_$vt_network
	iptables -t mangle -I OUTPUT -p udp --dport 53 -j minivtun_$vt_network  # DNS queries over tunnel

	# -----------------------------------------------------------------
	mkdir -p /var/etc/dnsmasq-go.d
	###### Anti-pollution configuration ######
	if [ -n "$vt_safe_dns" ]; then
		awk -vs="$vt_safe_dns#$vt_safe_dns_port" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
			/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/01-pollution.conf
	else
		logger_warn "WARNING: Not using secure DNS, DNS resolution might be polluted if you are in China."
	fi

	###### dnsmasq-to-ipset configuration ######
	case "$vt_proxy_mode" in
		M|V)
			awk '!/^$/&&!/^#/{printf("ipset=/%s/'"$vt_gfwlist"'\n",$0)}' \
				/etc/gfwlist/$vt_gfwlist > /var/etc/dnsmasq-go.d/02-ipset.conf
			;;
	esac

	# -----------------------------------------------------------------
	###### Restart main 'dnsmasq' service if needed ######
	if ls /var/etc/dnsmasq-go.d/* >/dev/null 2>&1; then
		# IMPORTANT: Must make sure 'dnsmasq' is not running as a system service
		[ -x /etc/init.d/dnsmasq ] && /etc/init.d/dnsmasq stop >/dev/null 2>/dev/null

		mkdir -p /tmp/dnsmasq.d
		cat > /tmp/dnsmasq.d/dnsmasq-go.conf <<EOF
conf-dir=/var/etc/dnsmasq-go.d
EOF

		if dnsmasq -C /tmp/dnsmasq.d/dnsmasq-go.conf -p $DNSMASQ_PORT -x $DNSMASQ_PIDFILE; then
			echo "nameserver 127.0.0.1" > /etc/resolv.conf
		else
			echo "*** WARNING: 'dnsmasq' service was not started successfully."
		fi
	fi

}

do_stop()
{
	[ -z "$vt_network" ] && vt_network="vt0"
	local vt_ifname="minivtun-$vt_network"
	local vt_gfwlist=`__gfwlist_by_mode $vt_proxy_mode`

	# -----------------------------------------------------------------
	rm -rf /var/etc/dnsmasq-go.d
	if [ -f /tmp/dnsmasq.d/dnsmasq-go.conf ]; then
		rm -f /tmp/dnsmasq.d/dnsmasq-go.conf
		killall -9 dnsmasq
	fi

	# -----------------------------------------------------------------
	if iptables -t mangle -F minivtun_$vt_network 2>/dev/null; then
		while iptables -t mangle -D OUTPUT -p udp --dport 53 -j minivtun_$vt_network 2>/dev/null; do :; done
		while iptables -t mangle -D PREROUTING -j minivtun_$vt_network 2>/dev/null; do :; done
		iptables -t mangle -X minivtun_$vt_network 2>/dev/null
	fi

	# -----------------------------------------------------------------
	[ "$KEEP_GFWLIST" = Y ] || ipset destroy "$vt_gfwlist" 2>/dev/null

	# -----------------------------------------------------------------
	# We don't have to delete the default route in 'virtual', since
	# it will be brought down along with the interface.
	while ip rule del fwmark $VPN_ROUTE_FWMARK table $VPN_IPROUTE_TABLE 2>/dev/null; do :; done

	if [ -f /var/run/$vt_ifname.pid ]; then
		kill -9 `cat /var/run/$vt_ifname.pid`
		rm -f /var/run/$vt_ifname.pid
	fi

}

#
case "$1" in
	-s) do_start_wait;;
	-k) do_stop;;
	*) echo "Usage: $0 -s|-k";;
esac

