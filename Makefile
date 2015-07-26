all:
	@cd ipset-lists; dpkg-buildpackage -b
	@cd minivtun-tools; dpkg-buildpackage -b
	@cd shadowsocks-tools; dpkg-buildpackage -b

