#!/bin/bash
# Description: install Apache + mysql5.7 + PHP7 + Zabbix 3.2.x automatically
# Deploy on CentOS 7


###########################
#	public
###########################

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear

cur_dir=`pwd`

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

log(){
    if   [ "${1}" == "Warning" ]; then
        echo -e "[${YELLOW}${1}${PLAIN}] ${2}"
    elif [ "${1}" == "Error" ]; then
        echo -e "[${RED}${1}${PLAIN}] ${2}"
    elif [ "${1}" == "Info" ]; then
        echo -e "[${GREEN}${1}${PLAIN}] ${2}"
    else
        echo -e "[${1}] ${2}"
    fi
}

host_ip(){
ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^127\.|^255\.|^0\." | head -n 1
}

###########################
#	check
###########################
rootness(){
    if [[ ${EUID} -ne 0 ]]; then
       log "Error" "This script must be run as root"
       exit 1
    fi
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

centosversion(){
	local code=${1}
	local version=$(grep -oE  "[0-9.]+" /etc/redhat-release)
	local mian_ver=${version%%.*}
	if [ "main_ver" == "$code" ]; then
		return 0
	else
		return 1
	fi
}

sync_time(){
	log "Info" "Starting to sync time..."
	check_command_exist nptdate
	nptdate -d time.zju.edu.cn > /dev/ null 2>&1
	rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock -w > /dev/null 2>&1
    log "Info" "Sync time completed..."
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

firewall_set(){
    log "Info" "Starting set Firewall..."

    if centosversion 6; then
        if [ -e /etc/init.d/iptables ];then 
            /etc/init.d/iptables status > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                iptables -L -n | grep -qi 80
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -J ACCEPT
                fi
                iptabes -L -n | grep -qi 10051
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 10051 -j ACCEPT
                fi
                /etc/init.d/iptables save > /dev/null 2>&1
                /etc/init.d/iptables restart > /dev/null 2>&1
            else
                log "Warning" "iptables looks like not running, please manually set if necessary."
                sleep 5
            fi
        else
            log "Warning" "iptables look like not installed."
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-service=http > /dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=10050/tcp > /dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=10051/tcp > /dev/null 2>&1
        fi
    fi
    log "Info" "Firewall set completed..."
}

boot_start(){

}
configuare_proxy(){
    read -p "Do you need to setting http/https proxy? yes/no:(Default no) " HT_proxy
    if [ -z $HT_proxy]
    
    log "Eroor" "Cann't connect URL, Please check the ${cur_dir}/zabbix.log  manually..."
}

####################################
# Install Apache+MySQL+PHP+ZABBIX
####################################
zabbix_configure_args(){
    --prefix=/usr/local/zabbix \
    --enable-server \
    --enable-agent \
    --with-mysql \
    --with-net-snmp \
    --with-libcurl \
    --with-libxml2 \
}


pre_installation_sett(){
    echo
    echo "#############################################################"
    echo "# Zabbix Auto yum Install Script for CentOS 6.+             #"
    echo "# Def: Linux + Apache2.4 + MySQL5.7 + PHP7.0 + ZABBIX3.2    #"
    echo "# Author: Gruiy <guanry@chingo.com>                         #"
    echo "#############################################################"
    echo
    log "Info" "Starting configuare Atomic repository..."
    rpm -qa | grep "atomic-release" &>/dev/null
    if [ $? -ne 0 ]; then
         wget -c -t3 -T3 -qO- https://www.atomicorp.com/installers/atomic | bash
            if [ $? -ne 0 ]; then
                log "Error" "Can't connect Atomic, Please configuare the HTTPS proxy..."
                read -p "Put in the proxy address (Example: 10.10.10.10:8080 ):"  Ht_proxy
                wget -c -t3 -T3 -qO-  https://www.atomicorp.com/installers/atomic -e use_proxy=yes -e https_proxy=$(Ht_proxy) |bash
            fi
    fi
    # Remove Packages
    yum -y remove mysql*
    yum -y remove mariadb*
    yum -y remove php*
    # Install Lamp
    yum -y install httpd
    yum -y install mysql mysql-server
    yum -y install php70w php70w-cli php70w-bcmath php70w-common php70w-dba php70w-devel php70w-enchant php70w-fpm php70w-gd php70w-mbstring php70w-mcrypt php70w-mysql php70w-pdo php70w-xml php70w-xmlrpc php70w-snmp php70w-pecl-redis && return
}

install_zabbix(){
    tarball_name=`ls ${cur_dir}/package/`
    soft_name=`tar xf $tarball_name `
    cpusum=`cat /proc/cpuinfo |grep 'processor'|wc -l`
    tar xf ${soft_name}
    
    make -j${cpusum} && make install
    if [ $? -ne 0 ]; then
        distro=`get_opsy`
        version=`cat /proc/verson`
        architecture=`uname -m`
        mem=`free -m`
        disk=`df -ah`
        zabbix=``
        cat >>${cur_dir}/zabbix_install.log <<EOF
        Errors Detail:
        Distributions:$distro
        Architecture:$architecture
        Version:$version
        Memery:
        ${mem}
        Disk:
        ${disk}
        Zabbix Version: $zabbix
        Zabbix compile parrmeter:${zabbix_configure_args}
        Issu:Failed to install Zabbix
EOF
    log "Error" "Installation ZABBIX failed."
    exit 1
    fi
}


####################################
# Init Configuare
####################################

conf_apache(){
	log "Info" "Starting configuare Apache..."
	yum -y install httpd
	cp -f ${cur_dir}/conf/httpd.conf /etc/httpd/conf/httpd.conf
	rm -f /etc/httpd/conf.d/welcome.conf /
}

conf_mysql(){
	log "Info" "Starting Install MySQL5.7"
	yum -y install https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
}

