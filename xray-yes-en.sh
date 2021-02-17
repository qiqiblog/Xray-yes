#!/bin/bash
# Github: https://github.com/jiuqi9997/Xray-yes
# Script link: https://github.com/jiuqi9997/Xray-yes/raw/main/xray-yes-en.sh
#
# Thanks for using.
#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
stty erase ^?
script_version="1.1.34"
nginx_dir="/usr/local/nginx"
nginx_conf_dir="/usr/local/nginx/conf"
nginx_systemd_file="/etc/systemd/system/nginx.service"
website_dir="/home/wwwroot"
nginx_version="1.18.0"
openssl_version="1.1.1i"
jemalloc_version="5.2.1"
xray_dir="/usr/local/etc/xray"
xray_log_dir="/var/log/xray"
xray_access_log="$xray_log_dir/access.log"
xray_error_log="$xray_log_dir/error.log"
xray_conf="/usr/local/etc/xray/config.json"
cert_dir="/usr/local/etc/xray"
info_file="$HOME/xray.inf"

check_root() {
	if [[ $EUID -ne 0 ]]; then
		error "You have to run this script as root."
	fi
}

color() {
	Green="\033[32m"
	Red="\033[31m"
	Yellow="\033[33m"
	GreenBG="\033[42;37m"
	RedBG="\033[41;37m"
	Font="\033[0m"
}

info() {
	echo "[*] $@"
}

error() {
	echo -e "${Red}[-]${Font} $@"
	exit 1
}

success() {
	echo -e "${Green}[+]${Font} $@"
}

warning() {
	echo -e "${Yellow}[*]${Font} $@"
}

panic() {
	echo -e "${RedBG}$@${Font}"
	exit 1
}

update_script() {
	fail=0
	ol_ver=$(curl -sL github.com/jiuqi9997/Xray-yes/raw/main/xray-yes-en.sh | grep "script_version=" | head -1 | awk -F '=|"' '{print $3}' | sed 's/\.//g')
	if [[ $(expr $ol_ver / 1) && $ol_ver > $(echo $script_version | sed 's/\.//g') ]]; then
		wget -O xray-yes-en.sh github.com/jiuqi9997/Xray-yes/raw/main/xray-yes-en.sh || fail=1
		[[ $fail -eq 1 ]] && warning "Failed to update" && sleep 2 && return 0
		success "Successfully updated"
		sleep 2
		bash xray-yes-en.sh $@
		exit 0
	fi
}

install_all() {
	prepare_installation
	sleep 3
	check_env
	install_packages
	install_acme
	install_xray
	install_nginx
	issue_certificate
	configure_xray
	xray_restart
	configure_nginx
	finish
	exit 0
}

prepare_installation() {
	get_info
	read -rp "Your domain: " xray_domain
	[[ -z $xray_domain ]] && install_all
	echo ""
	echo "Method:"
	echo ""
	echo "1. IPv4 only"
	echo "2. IPv6 only"
	echo "3. IPv4 & IPv6"
	echo ""
	read -rp "Enter a number (default IPv4 only): " ip_type
	[[ -z $ip_type ]] && ip_type=1
	if [[ $ip_type -eq 1 ]]; then
		domain_ip=$(ping -4 $xray_domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -4 || fail=1)
		[[ $fail -eq 1 ]] && error "Failed to get local IP address"
		[[ $server_ip == $domain_ip ]] && success "The domain name has been resolved to the local IP address" && success=1
		if [[ $success -ne 1 ]]; then
			warning "The domain name is not resolved to the local IP address, the certificate application may fail"
			read -rp "Continue? (yes/no): " choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	elif [[ $ip_type -eq 2 ]]; then
		domain_ip=$(ping -6 $xray_domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -6 || fail=1)
		[[ $fail -eq 1 ]] && error "Failed to get the local IP address"
		[[ $server_ip == $domain_ip ]] && success "The domain name has been resolved to the local IP address" && success=1
		if [[ $success -ne 1 ]]; then
			warning "The domain name is not resolved to the local IP address, the certificate application may fail"
			read -rp "Continue? (yes/no):" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	elif [[ $ip_type -eq 3 ]]; then
		domain_ip=$(ping -4 $xray_domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -4 || fail=1)
		[[ $fail -eq 1 ]] && error "Failed to get the local IP address (IPv4)"
		[[ $server_ip == $domain_ip ]] && success "The domain name has been resolved to the local IP address (IPv4)" && success=1
		if [[ $success -ne 1 ]]; then
			warning "The domain name is not resolved to the local IP address (IPv4), the certificate application may fail"
			read -rp "Continue? (yes/no):" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
		domain_ip6=$(ping -6 $xray_domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip6=$(curl https://api64.ipify.org -6 || fail=1)
		[[ $fail -eq 1 ]] && error "Failed to get the local IP address (IPv6)"
		[[ $server_ip == $domain_ip ]] && success "The domain name has been resolved to the local IP address (IPv6)" && success=1
		if [[ $success -ne 1 ]]; then
			warning "The domain name is not resolved to the local IP address (IPv6), the certificate application may fail"
			read -rp "Continue? (yes/no):" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	else
		error "Please enter a correct number"
	fi
	read -rp "Please enter the passwd for xray (default UUID): " uuid
	read -rp "Please enter the port for xray (default 443): " port
	[[ -z $port ]] && port=443
	[[ $port > 65535 ]] && echo "Please enter a correct port" && install_all
	configure_firewall
	nport=$(rand 10000 20000)
	nport1=`expr $nport + 1`
	while [[ $(ss -tnlp | grep ":$nport ") || $(ss -tnlp | grep ":$nport1 ") ]]; do
		nport=$(rand 10000 20000)
		nport1=`expr $nport + 1`
	done
	success "Everything is ready, the installation is about to start."
}

get_info() {
	source /etc/os-release || source /usr/lib/os-release || panic "The operating system is not supported"
	if [[ $ID == "centos" ]]; then
		PM="yum"
		INS="yum install -y"
	elif [[ $ID == "debian" || $ID == "ubuntu" ]]; then
		PM="apt-get"
		INS="apt-get install -y"
	elif [[ $ID == "arch" ]]; then
		PM="pacman"
		INS="pacman -Syu --noconfirm"
	else
		error "The operating system is not supported"
	fi
}

configure_firewall() {
	fail=0
	if [[ $(type -P ufw) ]]; then
		if [[ $port -ne 443 ]]; then
			ufw allow $port/tcp || fail=1
			ufw allow $port/udp || fail=1
			success "Successfully opened port $port"
		fi
		ufw allow 22,80,443/tcp || fail=1
		ufw allow 22,80,443,1024:65535/udp || fail=1
		yes|ufw enable || fail=1
		yes|ufw reload || fail=1
	elif [[ $(type -P firewalld) ]]; then
		systemctl start --now firewalld
		if [[ $port -ne 443 ]]; then
			firewall-offline-cmd --add-port=$port/tcp || fail=1
			firewall-offline-cmd --add-port=$port/udp || fail=1
			success "Successfully opened port $port"
		fi
		firewall-offline-cmd --add-port=22/tcp --add-port=80/tcp --add-port=443/tcp || fail=1
		firewall-offline-cmd --add-port=22/udp --add-port=80/udp --add-port=443/udp --add-port=1024-65535/udp || fail=1
		firewall-cmd --reload || fail=1
	else
		warning "Please configure the firewall by yourself."
		return 0
	fi
	if [[ $fail -eq 1 ]]; then
		warning "Failed to configure the firewall, please configure by yourself."
	else
		success "Successfully configured the firewall"
	fi
}

rand() {
	min=$1
	max=$(($2-$min+1))
	num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
	echo $(($num%$max+$min))
}

check_env() {
	if [[ $(ss -tnlp | grep ":80 ") ]]; then
		error "Port 80 is occupied (it's required for certificate application)"
	fi
	if [[ $port -eq "443" && $(ss -tnlp | grep ":443 ") ]]; then
		error "Port 443 is occupied"
	elif [[ $(ss -tnlp | grep ":$port ") ]]; then
		error "Port $port is occupied"
	fi
}

install_packages() {
	info "Install the software packages"
	$PM update -y
	$PM upgrade -y
	$PM install -y wget curl
	rpm_packages="libcurl-devel tar gcc make zip unzip openssl openssl-devel libxml2 libxml2-devel libxslt* zlib zlib-devel libjpeg-devel libpng-devel libwebp libwebp-devel freetype freetype-devel lsof pcre pcre-devel crontabs icu libicu-devel c-ares libffi-devel bzip2 bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel xz-devel libtermcap-devel libevent-devel libuuid-devel git jq socat"
	apt_packages="libcurl4-openssl-dev gcc make zip unzip openssl libssl-dev libxml2 libxml2-dev zlib1g zlib1g-dev libjpeg-dev libpng-dev lsof libpcre3 libpcre3-dev cron net-tools swig build-essential libffi-dev libbz2-dev libncurses-dev libsqlite3-dev libreadline-dev tk-dev libgdbm-dev libdb-dev libdb++-dev libpcap-dev xz-utils git libgd3 libgd-dev libevent-dev libncurses5-dev uuid-dev jq bzip2 socat"
	if [[ $PM == "apt-get" ]]; then
		$INS $apt_packages
	elif [[ $PM == "yum" || $PM == "dnf" ]]; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
		$INS epel-release
		$INS $rpm_packages
	fi
	success "Completed the installaion of the packages"
}

install_acme() {
	info "Started installing acme.sh"
	fail=0
	curl https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh | bash -s -- --install-online || fail=1
	[[ $fail -eq 1 ]] &&
	error "Failed to install acme.sh"
	success "Successfully installed acme.sh"
}

install_xray() {
	info "Install Xray"
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install
	[[ ! $(ps aux | grep xray) ]] && error "Failed to install Xray"
	success "Successfully installed Xray"
}

install_nginx() {
	[[ ! -f /usr/local/lib/libjemalloc.so ]] && install_jemalloc
	info "Complie nginx $nginx_version"
	wget -O openssl-${openssl_version}.tar.gz https://www.openssl.org/source/openssl-$openssl_version.tar.gz
	wget -O nginx-${nginx_version}.tar.gz http://nginx.org/download/nginx-${nginx_version}.tar.gz
	[[ -d nginx-$nginx_version ]] && rm -rf nginx-$nginx_version
	tar -xzvf nginx-$nginx_version.tar.gz
	[[ -d openssl-$openssl_version ]] && rm -rf openssl-$openssl_version
	tar -xzvf openssl-$openssl_version.tar.gz
	cd nginx-$nginx_version
	echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
	ldconfig
	./configure --prefix=${nginx_dir} \
		--with-http_ssl_module \
		--with-http_gzip_static_module \
		--with-http_stub_status_module \
		--with-pcre \
		--with-http_realip_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_secure_link_module \
		--with-http_v2_module \
		--with-cc-opt="-O3" \
		--with-ld-opt="-ljemalloc" \
		--with-openssl=../openssl-$openssl_version
	make -j$(nproc --all) && make install
	cd ..
	rm -rf openssl-${openssl_version}* nginx-${nginx_version}*
	ln -s $nginx_dir/sbin/nginx /usr/bin/nginx
	nginx_systemd
	systemctl enable nginx
	systemctl stop nginx
	systemctl start nginx
	[[ ! $(type -P nginx) ]] &&
	error "Failed to complie nginx $nginx_version"
	success "Successfully complied nginx $nginx_version"
}

install_jemalloc(){
	wget -O jemalloc-$jemalloc_version.tar.bz2 https://github.com/jemalloc/jemalloc/releases/download/$jemalloc_version/jemalloc-$jemalloc_version.tar.bz2
	tar -xvf jemalloc-$jemalloc_version.tar.bz2
	cd jemalloc-$jemalloc_version
	info "Complie jamalloc $jemalloc_version"
	./configure
	make -j$(nproc --all) && make install
	echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
	ldconfig
	cd ..
	rm -rf jemalloc-${jemalloc_version}*
	[[ ! -f /usr/local/lib/libjemalloc.so ]] &&
	error "Failed to complie jamalloc $jemalloc_version"
	success "Successfully complied jamalloc $jemalloc_version"
}

nginx_systemd() {
	cat > $nginx_systemd_file <<EOF
[Unit]
Description=NGINX web server
After=syslog.target network.target remote-fs.target nss-lookup.target
[Service]
Type=forking
PIDFile=$nginx_dir/logs/nginx.pid
ExecStartPre=$nginx_dir/sbin/nginx -t
ExecStart=$nginx_dir/sbin/nginx -c ${nginx_dir}/conf/nginx.conf
ExecReload=$nginx_dir/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
}

issue_certificate() {
	fail=0
	info "Issue a ssl certificate"
	mkdir -p $nginx_conf_dir/vhost
	cat > $nginx_conf_dir/nginx.conf << EOF
worker_processes auto;
worker_rlimit_nofile 51200;

events
	{
		use epoll;
		worker_connections 51200;
		multi_accept on;
	}

http
	{
		include	   mime.types;
		default_type  application/octet-stream;
		charset utf-8;
		server_names_hash_bucket_size 512;
		client_header_buffer_size 32k;
		large_client_header_buffers 4 32k;
		client_max_body_size 50m;

		sendfile   on;
		tcp_nopush on;

		keepalive_timeout 60;

		tcp_nodelay on;

		fastcgi_connect_timeout 300;
		fastcgi_send_timeout 300;
		fastcgi_read_timeout 300;
		fastcgi_buffer_size 64k;
		fastcgi_buffers 4 64k;
		fastcgi_busy_buffers_size 128k;
		fastcgi_temp_file_write_size 256k;
		fastcgi_intercept_errors on;

		gzip on;
		gzip_min_length  1k;
		gzip_buffers	 4 16k;
		gzip_http_version 1.1;
		gzip_comp_level 2;
		gzip_types	 text/plain application/javascript application/x-javascript text/javascript text/css application/xml;
		gzip_vary on;
		gzip_proxied   expired no-cache no-store private auth;
		gzip_disable   "MSIE [1-6]\.";

		limit_conn_zone \$binary_remote_addr zone=perip:10m;
		limit_conn_zone \$server_name zone=perserver:10m;

		server_tokens off;
		access_log off;

		server
		{
			listen 80 default_server;
			listen [::]:80 default_server;

			return 444;

			access_log /dev/null;
			error_log /dev/null;
		}

		include $nginx_conf_dir/vhost/*.conf;
}
EOF
	cat > $nginx_conf_dir/vhost/$xray_domain.conf <<EOF
server
{
	listen 80;
	listen [::]:80;
	server_name $xray_domain;
	root $website_dir/$xray_domain;

	access_log /dev/null;
	error_log /dev/null;
}
EOF
	nginx -s reload
	/root/.acme.sh/acme.sh --issue -d $xray_domain --keylength ec-256 --fullchain-file $cert_dir/cert.pem --key-file $cert_dir/key.pem --webroot $website_dir/$xray_domain --renew-hook "systemctl restart xray" --force || fail=1
	[[ $fail -eq 1 ]] && error "Failed to issue a ssl certificate"
	generate_certificate
	chmod 600 $cert_dir/cert.pem $cert_dir/key.pem $cert_dir/self_signed_cert.pem $cert_dir/self_signed_key.pem
	if [[ $(grep nogroup /etc/group) ]]; then
		chown nobody:nogroup $cert_dir/cert.pem $cert_dir/key.pem $cert_dir/self_signed_cert.pem $cert_dir/self_signed_key.pem
	else
		chown nobody:nobody $cert_dir/cert.pem $cert_dir/key.pem $cert_dir/self_signed_cert.pem $cert_dir/self_signed_key.pem
	fi
	rm -rf $nginx_conf_dir/vhost/$xray_domain.conf
	success "Successfully issued the ssl certificate"
}

generate_certificate() {
	info "Generate a self-signed certificate"
	openssl genrsa -des3 -passout pass:xxxx -out server.pass.key 2048
	openssl rsa -passin pass:xxxx -in server.pass.key -out $cert_dir/self_signed_key.pem
	rm -rf server.pass.key
	openssl req -new -key $cert_dir/self_signed_key.pem -out server.csr -subj "/CN=$server_ip"
	openssl x509 -req -days 3650 -in server.csr -signkey $cert_dir/self_signed_key.pem -out $cert_dir/self_signed_cert.pem
	rm -rf server.csr
	[[ ! -f $cert_dir/self_signed_cert.pem || ! -f $cert_dir/self_signed_key.pem ]] && error "Failed to generate a self-signed certificate"
	success "Successfully generated a self-signed certificate"
}

configure_xray() {
	[[ -z $uuid ]] && uuid=$(xray uuid)
	xray_flow="xtls-rprx-direct"
	cat > $xray_conf << EOF
{
    "log": {
        "access": "$xray_access_log",
        "error": "$xray_error_log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "$xray_flow"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": $nport,
                        "xver": 1
                    },
                    {
                        "dest": $nport1,
                        "alpn": "h2",
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": ["h2","http/1.1"],
                    "minVersion": "1.2",
                    "certificates": [
                        {
                            "certificateFile": "$cert_dir/self_signed_cert.pem",
                            "keyFile": "$cert_dir/self_signed_key.pem"
                        },
                        {
                            "certificateFile": "$cert_dir/cert.pem",
                            "keyFile": "$cert_dir/key.pem",
                            "ocspStapling": 3600
                        }
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http","tls"]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

xray_restart() {
	systemctl restart xray
	[[ ! $(ps aux | grep xray) ]] && error "Failed to restart Xray"
	success "Successfully restarted Xray"
	sleep 2
}

configure_nginx() {
	rm -rf $website_dir/$xray_domain
	mkdir -p $website_dir/$xray_domain
	wget -O web.tar.gz https://github.com/jiuqi9997/Xray-yes/raw/main/web.tar.gz
	tar xzvf web.tar.gz -C $website_dir/$xray_domain
	rm -rf web.tar.gz
	cat > $nginx_conf_dir/vhost/$xray_domain.conf <<EOF
server
{
	listen 80;
	listen [::]:80;
	server_name $xray_domain;
	return 301 https://\$http_host\$request_uri;

	access_log  /dev/null;
	error_log  /dev/null;
}

server
{
	listen $nport default_server;
	listen [::]:$nport default_server;
	listen $nport1 http2 default_server;
	listen [::]:$nport1 http2 default_server;

	return 444;

	access_log /dev/null;
	error_log /dev/null;
}

server
{
	listen $nport proxy_protocol;
	listen [::]:$nport proxy_protocol;
	listen $nport1 http2 proxy_protocol;
	listen [::]:$nport1 http2 proxy_protocol;
	server_name $xray_domain;
	index index.html index.htm index.php default.php default.htm default.html;
	root $website_dir/$xray_domain;
	add_header Strict-Transport-Security "max-age=31536000" always;

	location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$
	{
		expires	  30d;
		error_log off;
		access_log /dev/null;
	}

	location ~ .*\.(js|css)?$
	{
		expires	  12h;
		error_log off;
		access_log /dev/null;
	}
	access_log  /dev/null;
	error_log  /dev/null;
}
EOF
	nginx -s reload
}

finish() {
	success "Successfully installed Xray (VLESS+tcp+xtls+nginx)"
	echo ""
	echo ""
	echo -e "$Red Xray configuration $Font" | tee $info_file
	echo -e "$Red Address: $Font $server_ip " | tee -a $info_file
	echo -e "$Red Port: $Font $port " | tee -a $info_file
	echo -e "$Red UUID/Passwd: $Font $uuid" | tee -a $info_file
	echo -e "$Red Flow: $Font $xray_flow" | tee -a $info_file
	echo -e "$Red Host: $Font $xray_domain" | tee -a $info_file
	echo -e "$Red TLS: $Font ${RedBG}XTLS${Font}" | tee -a $info_file
	echo ""
	echo -e "$Red Share link: $Font vless://$uuid@$xray_domain:$port?flow=xtls-rprx-direct&security=xtls#$server_ip" | tee -a $info_file
	echo ""
	echo -e "${GreenBG} Tip: ${Font}You can use flow control ${RedBG}xtls-rprx-splice${Font} on the Linux platform to get better performance."
}

update_xray() {
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install
	[[ ! $(ps aux | grep xray) ]] && error "Failed to update Xray"
	success "Successfully updated Xray"
}

uninstall_all() {
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- remove --purge
	systemctl stop nginx
	rm -rf /usr/bin/nginx
	rm -rf $nginx_systemd_file
	rm -rf $nginx_dir
	rm -rf $website_dir
	rm -rf $info_file
	success "Uninstalled Xray and nginx"
	exit 0
}

mod_uuid() {
	fail=0
	uuid_old=$(jq '.inbounds[].settings.clients[].id' $xray_conf || fail=1)
	[[ $(echo $uuid_old | jq '' | wc -l) > 1 ]] && error "There are multiple UUIDs, please modify by yourself"
	uuid_old=$(echo $uuid_old | sed 's/\"//g')
	read -rp "Please enter the password for Xray (default UUID): " uuid
	[[ -z $uuid ]] && uuid=$(xray uuid)
	sed -i "s/$uuid_old/$uuid/g" $xray_conf $info_file
	[[ $(grep "$uuid" $xray_conf ) ]] && success "Successfully modified the UUID"
	sleep 2
	xray_restart
	menu
}

mod_port() {
	fail=0
	port_old=$(jq '.inbounds[].port' $xray_conf || fail=1)
	[[ $(echo $port_old | jq '' | wc -l) > 1 ]] && error "There are multiple ports, please modify by yourself"
	read -rp "Please enter the port for Xray (default 443): " port
	[[ -z $port ]] && port=443
	[[ $port > 65535 ]] && echo "Please enter a correct port" && mod_port
	[[ $port -ne 443 ]] && configure_firewall $port
	configure_firewall
	sed -i "s/$port_old/$port/g" $xray_conf $info_file
	[[ $(grep $port $xray_conf ) ]] && success "Successfully modified the port"
	sleep 2
	xray_restart
	menu
}

show_access_log() {
	[[ -f $xray_access_log ]] && tail -f $xray_access_log || panic "The file doesn't exist"
}

show_error_log() {
	[[ -f $xray_error_log ]] && tail -f $xray_error_log || panic "The file doesn't exist"
}

show_configuration() {
	[[ -f $info_file ]] && cat $info_file && exit 0
	panic "The info file doesn't exist"
}

switch_to_cn() {
	wget -O xray-yes.sh https://github.com/jiuqi9997/Xray-yes/raw/main/xray-yes.sh
	echo "Chinese version: xray-yes.sh"
	sleep 5
	bash xray-yes.sh
	exit 0
}

menu() {
	clear
	echo ""
	echo -e "  XRAY-YES - Install and manage Xray $Red[$script_version]$Font"
	echo -e "  https://github.com/jiuqi9997/Xray-yes"
	echo ""
	echo -e " ---------------------------------------"
	echo -e "  ${Green}0.${Font} Update the script"
	echo -e "  ${Green}1.${Font} Install Xray (VLESS+tcp+xtls+nginx)"
	echo -e "  ${Green}2.${Font} Update Xray core"
	echo -e "  ${Green}3.${Font} Uninstall Xray&nginx"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}4.${Font} Modify the UUID"
	echo -e "  ${Green}5.${Font} Modify the port"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}6.${Font} View live access logs"
	echo -e "  ${Green}7.${Font} View live error logs"
	echo -e "  ${Green}8.${Font} View the Xray info file"
	echo -e "  ${Green}9.${Font} Restart Xray"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}10.${Font} 切换到中文"
	echo ""
	echo -e "  ${Green}11.${Font} Exit"
	echo ""
	read -rp "Please enter a number: " choice
	case $choice in
	0)
		update_script
		;;
	1)
		install_all
		;;
	2)
		update_xray
		;;
	3)
		uninstall_all
		;;
	4)
		mod_uuid
		;;
	5)
		mod_port
		;;
	6)
		show_access_log
		;;
	7)
		show_error_log
		;;
	8)
		show_configuration
		;;
	9)
		xray_restart
		;;
	10)
		switch_to_cn
		;;
	11)
		exit 0
		;;
	*)
		menu
		;;
	esac
}

main() {
	clear
	check_root
	color
	update_script $@
	case $1 in
	install)
		install_all
		;;
	update)
		update_xray
		;;
	remove)
		uninstall_all
		;;
	purge)
		uninstall_all
		;;
	uninstall)
		uninstall_all
		;;
	*)
		menu
		;;
	esac
}

main $@
