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

do_start()
{
	local vt_enabled=`uci get minivtun.@minivtun[0].enabled 2>/dev/null`
	local vt_server_addr=`uci get minivtun.@minivtun[0].server`
	local vt_server_port=`uci get minivtun.@minivtun[0].server_port`

	if [ "$vt_enabled" = 0 ]; then
		echo "WARNING: Mini Virtual Tunneller is disabled."
		return 1
	fi
	if [ -z "$vt_server_addr" -o -z "$vt_server_port" ]; then
		echo "WARNING: No server address configured, not starting."
		return 1
	fi

	killall -9 invoke.sh 2>/dev/null && sleep 1
	# The startup script might wait for DNS resolution to be
	# ready, so execute in background.
	start-stop-daemon -S -b -x /usr/lib/minivtun/invoke.sh -- -s
}

do_stop()
{
	/usr/lib/minivtun/invoke.sh -k
	killall -9 invoke.sh 2>/dev/null && sleep 1 || :
}

restart()
{
	export KEEP_GFWLIST=Y
	stop
	start
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

