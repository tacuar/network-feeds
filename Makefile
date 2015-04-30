
all:
	@cd ipset-lists; dpkg-buildpackage -b
	@cd minivtun-tools; dpkg-buildpackage -b
	@cd shadowsocks-libev; dpkg-buildpackage -b
	@cd shadowsocks-tools; dpkg-buildpackage -b

up:
	@rm -rf amd64
	mkdir -p amd64
	cp *.deb amd64/
	md5sum *.deb > amd64/MD5SUMS
	rsync -rLpt -v amd64 root@jp.rssn.cn:/www/linux-dist/ --delete
	rsync -rLpt -v amd64 root@sg.rssn.cn:/www/linux-dist/ --delete
	rsync -rLpt -v amd64 root@w.rssn.cn:/www/linux-dist/ --delete

