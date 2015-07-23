#!/bin/sh
#
# Copyright (C) 2014 Justin Liu <rssnsj@gmail.com>
#

### BEGIN INIT INFO
# Provides:     ipset-lists
# Required-Start:
# Required-Stop:
# Default-Start:    2 3 4 5
# Default-Stop:
# Short-Description:    ipset tables and gfwlist
### END INIT INFO

do_start()
{
	local file
	for file in /etc/ipset/*; do
		[ -f $file ] || continue
		ipset restore < $file
	done
}

do_stop()
{
	local file
	for file in /etc/ipset/*; do
		[ -f $file ] || continue
		ipset destroy `basename $file`
	done
}

restart()
{
	stop >/dev/null 2>&1
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

