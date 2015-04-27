#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

prefix ?= /usr

all:

clean:

install:
	@cd files; \
	 find * -type f | grep -v '\/\.svn\/' | grep -v '\/\.git' | \
	 while read L; do \
	   d=/`dirname $$L`; \
	   mkdir -p $(DESTDIR)/$$d; \
	   cp -v $$L $(DESTDIR)/$$d/; \
	 done;

uninstall:
	@rm -vf $(DESTDIR)/etc/rc?.d/*ipset.sh
	@rm -rvf $(DESTDIR)/etc/ipset $(DESTDIR)/etc/gfwlist $(DESTDIR)/etc/init.d/ipset.sh

