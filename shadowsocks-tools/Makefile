#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

prefix ?= /usr

all:

clean:

install: all
	@cd files; \
	 find * -type f | grep -v '\/\.svn\/' | grep -v '\/\.git' | \
	 while read L; do \
	   d=`dirname $$L`; \
	   mkdir -p $(DESTDIR)/$$d; \
	   cp -v $$L $(DESTDIR)/$$d/; \
	 done;

uninstall:
	/etc/init.d/ss-redir.sh stop || :
	@rm -vf $(DESTDIR)/etc/rc?.d/*ss-redir.sh
	@rm -vf $(DESTDIR)/etc/init.d/ss-redir.sh
	@rm -vf $(DESTDIR)$(prefix)/sbin/ss-redir

