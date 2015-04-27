#!/bin/sh
#
# Copyright (C) 2014 Justin Liu <rssnsj@gmail.com>
#

### BEGIN INIT INFO
# Provides: shadowsocks-tools
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:
# Short-Description: Non-standard VPN that helps you to get through firewalls
### END INIT INFO

START=96

#
# Data source of /etc/gfwlist/china-banned:
#  https://github.com/zhiyi7/ddwrt/blob/master/jffs/vpn/dnsmasq-gfw.txt
#  http://code.google.com/p/autoproxy-gfwlist/
#

SS_REDIR_PORT=7070
SS_REDIR_PIDFILE=/var/run/ss-redir-go.pid 
DNSMASQ_PORT=53
DNSMASQ_PIDFILE=/var/run/dnsmasq-go.pid
PDNSD_LOCAL_PORT=7453

[ -f /etc/default/shadowsocks ] && . /etc/default/shadowsocks
if [ -z "$vt_enabled" -o "$vt_enabled" = 0 ]; then
	echo "WARNING: Shadowsocks transparent proxy service is disabled."
	exit 1
fi


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

# New implementation:
# Attach rules to main 'dnsmasq' service and restart it.

do_start()
{
	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		echo "WARNING: Shadowsocks not fully configured, not starting."
		return 1
	fi
	[ -z "$vt_proxy_mode" ] && vt_proxy_mode=S
	[ -z "$vt_method" ] && vt_method=table
	[ -z "$vt_timeout" ] && vt_timeout=60
	[ -z "$vt_safe_dns_port" ] && vt_safe_dns_port=53
	# Get LAN settings as default parameters
	[ -z "$covered_subnets" ] && covered_subnets="192.168.10.0/24"
	[ -z "$local_addresses" ] && local_addresses="192.168.10.1"
	local vt_gfwlist="china-banned"
	vt_np_ipset="china"  # Must be global variable

	# -----------------------------------------------------------------
	###### shadowsocks ######
	/usr/bin/ss-redir -b0.0.0.0 -l$SS_REDIR_PORT -s$vt_server_addr -p$vt_server_port \
		-k"$vt_password" -m$vt_method -t$vt_timeout -f $SS_REDIR_PIDFILE || return 1

	# IPv4 firewall rules
	iptables -t nat -N shadowsocks_pre
	iptables -t nat -F shadowsocks_pre
	iptables -t nat -A shadowsocks_pre -m set --match-set local dst -j RETURN || {
		iptables -t nat -A shadowsocks_pre -d 10.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocks_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocks_pre -d 172.16.0.0/12 -j RETURN
		iptables -t nat -A shadowsocks_pre -d 192.168.0.0/16 -j RETURN
		iptables -t nat -A shadowsocks_pre -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A shadowsocks_pre -d 224.0.0.0/3 -j RETURN
	}
	iptables -t nat -A shadowsocks_pre -d $vt_server_addr -j RETURN
	case "$vt_proxy_mode" in
		G) : ;;
		S)
			iptables -t nat -A shadowsocks_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		M)
			ipset create gfwlist hash:ip maxelem 65536
			iptables -t nat -A shadowsocks_pre -m set ! --match-set gfwlist dst -j RETURN
			iptables -t nat -A shadowsocks_pre -m set --match-set $vt_np_ipset dst -j RETURN
			;;
		V)
			vt_np_ipset=""
			vt_gfwlist="unblock-youku"
			ipset create gfwlist hash:ip maxelem 65536
			iptables -t nat -A shadowsocks_pre -m set ! --match-set gfwlist dst -j RETURN
			;;
	esac
	iptables -t nat -A shadowsocks_pre -p tcp -j REDIRECT --to $SS_REDIR_PORT
	iptables -t nat -I PREROUTING -p tcp -j shadowsocks_pre
	iptables -t nat -I OUTPUT -p tcp -j shadowsocks_pre

	# -----------------------------------------------------------------
	mkdir -p /tmp/etc/dnsmasq-go.d
	###### Anti-pollution configuration ######
	if [ -n "$vt_safe_dns" ]; then
		if [ "$vt_safe_dns_tcp" = 1 ]; then
			start_pdnsd "$vt_safe_dns"
			awk -vs="127.0.0.1#$PDNSD_LOCAL_PORT" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/$vt_gfwlist > /tmp/etc/dnsmasq-go.d/01-pollution.conf
		else
			awk -vs="$vt_safe_dns#$vt_safe_dns_port" '!/^$/&&!/^#/{printf("server=/%s/%s\n",$0,s)}' \
				/etc/gfwlist/$vt_gfwlist > /tmp/etc/dnsmasq-go.d/01-pollution.conf
		fi
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
		# IMPORTANT: Must make sure 'dnsmasq' is not running as a system service
		[ -x /etc/init.d/dnsmasq ] && /etc/init.d/dnsmasq stop >/dev/null 2>/dev/null

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

	stop_pdnsd

	# -----------------------------------------------------------------
	if iptables -t nat -F shadowsocks_pre 2>/dev/null; then
		while iptables -t nat -D OUTPUT -p tcp -j shadowsocks_pre 2>/dev/null; do :; done
		while iptables -t nat -D PREROUTING -p tcp -j shadowsocks_pre 2>/dev/null; do :; done
		iptables -t nat -X shadowsocks_pre 2>/dev/null
	fi

	# -----------------------------------------------------------------
	ipset destroy gfwlist 2>/dev/null

	# -----------------------------------------------------------------
	if [ -f $SS_REDIR_PIDFILE ]; then
		kill -9 `cat $SS_REDIR_PIDFILE`
		rm -f $SS_REDIR_PIDFILE
	fi

}

# $1: upstream DNS server
start_pdnsd()
{
	local safe_dns="$1"

	local tcp_dns_list="8.8.8.8,8.8.4.4"
	[ -n "$safe_dns" ] && tcp_dns_list="$safe_dns,$tcp_dns_list"

	killall -9 pdnsd 2>/dev/null && sleep 1
	mkdir -p /tmp/etc /tmp/pdnsd
	cat > /tmp/etc/pdnsd.conf <<EOF
global {
	perm_cache=256;
	cache_dir="/tmp/pdnsd";
	pid_file = /tmp/run/pdnsd.pid;
	run_as="nobody";
	server_ip = 127.0.0.1;
	server_port = $PDNSD_LOCAL_PORT;
	status_ctl = on;
	query_method = tcp_only;
	min_ttl=15m;
	max_ttl=1w;
	timeout=10;
	neg_domain_pol=on;
	proc_limit=2;
	procq_limit=8;
}
server {
	label= "fwxxx";
	ip = $tcp_dns_list;
	timeout=6;
	uptest=none;
	interval=10m;
	purge_cache=off;
}
EOF

	start-stop-daemon -S -b -x /usr/sbin/pdnsd -- -c /tmp/etc/pdnsd.conf --nostatus

	# Access TCP DNS server through Shadowsocks tunnel
	if iptables -t nat -N pdnsd_output; then
		iptables -t nat -A pdnsd_output -m set --match-set $vt_np_ipset dst -j RETURN
		iptables -t nat -A pdnsd_output -p tcp -j REDIRECT --to $SS_REDIR_PORT
	fi
	iptables -t nat -I OUTPUT -p tcp --dport 53 -j pdnsd_output
}

stop_pdnsd()
{
	if iptables -t nat -F pdnsd_output 2>/dev/null; then
		while iptables -t nat -D OUTPUT -p tcp --dport 53 -j pdnsd_output 2>/dev/null; do :; done
		iptables -t nat -X pdnsd_output
	fi
	killall -9 pdnsd 2>/dev/null
	rm -rf /tmp/pdnsd
	rm -f /tmp/etc/pdnsd.conf
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

