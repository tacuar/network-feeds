
ARCH := $(shell uname -m | grep '64$$' >/dev/null && echo amd64 || echo i386)

all:
	@cd ipset-lists; dpkg-buildpackage -b
	@cd minivtun-tools; dpkg-buildpackage -b
	@cd shadowsocks-libev; dpkg-buildpackage -b
	@cd shadowsocks-tools; dpkg-buildpackage -b

up:
	@rm -rf $(ARCH)
	mkdir -p $(ARCH)
	cp *.deb $(ARCH)/
	md5sum *.deb > $(ARCH)/MD5SUMS
	rsync -rLpt -v $(ARCH) root@jp.rssn.cn:/www/linux-dist/ --delete
	rsync -rLpt -v $(ARCH) root@sg.rssn.cn:/www/linux-dist/ --delete
	rsync -rLpt -v $(ARCH) root@w.rssn.cn:/www/linux-dist/ --delete

