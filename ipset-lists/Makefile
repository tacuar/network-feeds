#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

all:

install:
	@cd files; \
	 find * -type f | grep -v '\/\.svn\/' | grep -v '\/\.git' | \
	 while read L; do \
	   d=/`dirname $$L`; \
	   mkdir -p $$d; \
	   cp -v $$L $$d/; \
	 done;
	@ln -svf ../init.d/ipset.sh /etc/rc2.d/S37ipset.sh; \
	 ln -svf ../init.d/ipset.sh /etc/rc3.d/S37ipset.sh; \
	 ln -svf ../init.d/ipset.sh /etc/rc4.d/S37ipset.sh; \
	 ln -svf ../init.d/ipset.sh /etc/rc5.d/S37ipset.sh
	@if which ipset >/dev/null; then \
	   /etc/init.d/ipset.sh restart; \
	   echo "Predefined lists were imported."; \
	 else \
	   echo "*** 'ipset' is not installed. Not importing the predefined lists."; \
	 fi

uninstall:
	/etc/init.d/ipset.sh stop || :
	@rm -vf /etc/rc?.d/*ipset.sh
	@rm -rvf /etc/ipset /etc/gfwlist /etc/init.d/ipset.sh

