#
# Copyright (c) 2015 Justin Liu
# Author: Justin Liu <rssnsj@gmail.com>
#

prefix ?= /usr

all: shadowsocks-libev/src/ss-redir

shadowsocks-libev/src/ss-redir: shadowsocks-libev
	cd shadowsocks-libev; ./configure --prefix=/usr
	make -C shadowsocks-libev

shadowsocks-libev:
	svn co https://github.com/shadowsocks/shadowsocks-libev/tags/v2.2.3 shadowsocks-libev

clean:
	rm -rf shadowsocks-libev

install: all
	@mkdir -p $(DESTDIR)$(prefix)/bin
	@$(foreach p,ss-redir ss-local ss-server,cp -v shadowsocks-libev/src/$(p) $(DESTDIR)$(prefix)/bin/;)
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
	@rm -vf $(DESTDIR)$(prefix)/bin/ss-redir
