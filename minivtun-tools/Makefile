#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

all: src/minivtun

src/minivtun: src
	make -C src

src:
	svn co https://github.com/rssnsj/minivtun/trunk/src

install: all
	@cp -vf src/minivtun /usr/sbin/
	@[ -f /etc/default/minivtun ] && mv -f /etc/default/minivtun ./aaa || :
	@cd files; \
	 find * -type f | grep -v '\/\.svn\/' | grep -v '\/\.git' | \
	 while read L; do \
	   d=/`dirname $$L`; \
	   mkdir -p $$d; \
	   cp -v $$L $$d/; \
	 done;
	@[ -f ./aaa ] && mv ./aaa -f /etc/default/minivtun || :
	@ln -svf ../init.d/minivtun.sh /etc/rc2.d/S95minivtun.sh; \
	 ln -svf ../init.d/minivtun.sh /etc/rc3.d/S95minivtun.sh; \
	 ln -svf ../init.d/minivtun.sh /etc/rc4.d/S95minivtun.sh; \
	 ln -svf ../init.d/minivtun.sh /etc/rc5.d/S95minivtun.sh
	@if which ipset >/dev/null; then \
	   /etc/init.d/minivtun.sh restart; \
	 else \
	   echo "*** 'ipset' is not installed. Not starting 'minivtun' service."; \
	 fi

uninstall:
	/etc/init.d/minivtun.sh stop || :
	@rm -vf /etc/rc?.d/*minivtun.sh
	@rm -rvf /etc/minivtun /etc/gfwlist /etc/init.d/minivtun.sh
	@rm -vf /usr/sbin/minivtun

