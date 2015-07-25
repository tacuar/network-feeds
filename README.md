# network-feeds
Linux下的网络加速扩展应用（欢迎提交有价值优化的 Pull Requests）

### 包含的组件
* ipset-lists: 包含所有中国IP地址段的ipset列表（数据来自 apnic.net）
* shadowsocks-libev: Shadowsocks服务程序（来自: https://github.com/shadowsocks/shadowsocks-libev ）
* shadowsocks-tools: OpenWrt下的Shadowsocks配置、启动脚本以及luci界面
* minivtun-tools: 一种安全、快速、部署便捷的非标准协议VPN，可用于防火墙穿越（服务器配置方法请见: https://github.com/rssnsj/minivtun ）

### 下载代码

    git clone https://github.com/rssnsj/network-feeds.git -b linux-dist linux-dist

### 如何编译以及生成.deb安装包

    apt-get update
    apt-get install fakeroot debhelper build-essential libssl-dev autotools-dev mime-support gawk -y
     
    cd ipset-lists; dpkg-buildpackage -b
    cd minivtun-tools; dpkg-buildpackage -b
    cd shadowsocks-libev; dpkg-buildpackage -b
    cd shadowsocks-tools; dpkg-buildpackage -b

### 如何安装（仅Ubuntu）

##### Ubuntu 12.04 - 64位

    apt-get update
    apt-get install ipset iptables dnsmasq-base pdnsd -y
     
    # 若是你自己编译的.deb包则跳过下载步骤
    wget http://rssn.cn/linux-dist/amd64/ipset-lists_0.1.0_all.deb
    wget http://rssn.cn/linux-dist/amd64/minivtun-tools_0.9.1_amd64.deb
    wget http://rssn.cn/linux-dist/amd64/shadowsocks-libev_2.1.4-1_amd64.deb
    wget http://rssn.cn/linux-dist/amd64/shadowsocks-tools_0.9.1_amd64.deb
     
    dpkg -i ipset-lists_*.deb minivtun-tools_*.deb shadowsocks-libev_*.deb shadowsocks-tools_*.deb

##### Ubuntu 12.04 - 32位

    apt-get update
    apt-get install ipset iptables dnsmasq-base pdnsd -y
     
    wget http://rssn.cn/linux-dist/i386/ipset-lists_0.1.0_all.deb
    wget http://rssn.cn/linux-dist/i386/minivtun-tools_0.9.1_i386.deb
    wget http://rssn.cn/linux-dist/i386/shadowsocks-libev_2.1.4-1_i386.deb
    wget http://rssn.cn/linux-dist/i386/shadowsocks-tools_0.9.1_i386.deb
     
    dpkg -i ipset-lists_*.deb minivtun-tools_*.deb shadowsocks-libev_*.deb shadowsocks-tools_*.deb

### 如何配置
* 编辑 /etc/default/shadowsocks ，修改`enabled=1`，并根据服务器`ss-server`的配置对其他参数做相应修改；
* 启动服务：`/etc/init.d/ss-redir restart`
