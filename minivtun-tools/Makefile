#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

prefix ?= /usr

all: src/minivtun

src/minivtun: src
	make -C src

src:
	svn co https://github.com/rssnsj/minivtun/trunk/src

clean:
	rm -rf src

install: all
	@mkdir -p $(DESTDIR)$(prefix)/sbin
	@cp -vf src/minivtun $(DESTDIR)$(prefix)/sbin/
	@cd files; \
	 find * -type f | grep -v '\/\.svn\/' | grep -v '\/\.git' | \
	 while read L; do \
	   d=`dirname $$L`; \
	   mkdir -p $(DESTDIR)/$$d; \
	   cp -v $$L $(DESTDIR)/$$d/; \
	 done;

uninstall:
	/etc/init.d/minivtun.sh stop || :
	@rm -vf $(DESTDIR)/etc/rc?.d/*minivtun.sh
	@rm -vf $(DESTDIR)/etc/init.d/minivtun.sh
	@rm -vf $(DESTDIR)$(prefix)/sbin/minivtun

