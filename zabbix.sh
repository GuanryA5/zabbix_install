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

memu(){
        echo
    echo "#############################################################"
    echo "# Zabbix Auto Install Script for CentOS 6.+                 #"
    echo "# Def: Linux + Apache2.4 + MySQL5.7 + PHP7.0 + ZABBIX3.2    #"
    echo "# Author: Gruiy <guanry@chingo.com>                         #"
    echo "#############################################################"
    echo
    
    echo "Press any key to start ... or Press Ctrl+C to cannel"
    get_char
}
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
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
                fi
                iptabes -L -n | grep -qi 10050
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 10050 -j ACCEPT
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


help_menu(){
    echo "{Usage}:                                                  "
    echo " ./zabbix.sh  [ install | uninstall ]  [ server | agent ] "    
}
yum_repo_menu(){
    mysql_version=`yum repolist all |awk '/^mysql[0-9]+/{print $2,$3}' |awk 'a[$0]++'`
    
}
pre_installation_settting(){
    log "Info" "Starting configuare repository..."
    # add php repo 
    rpm -qa | grep "atomic-release" &>/dev/null
    if [ $? -ne 0 ]; then
         wget -c -t3 -T3 -qO- https://www.atomicorp.com/installers/atomic | bash
            if [ $? -ne 0 ]; then
                log "Error" "Can't download Atomic repository, Please configuare the HTTPS proxy ..."
                exit 1
            fi
    fi
    # add mysql repo
    rpm -qa |egrep "mysql.*-community-release" &>/dev/null
    if [ $? -ne 0 ]; then
        if centosversion 6; then
            yum -y install https://dev.mysql.com/get/mysql80-community-release-el6-1.noarch.rpm
        elif centosversion 7; then
            yum -y install https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
        fi
    fi
    # enable mysql57 version repository
    yum-config-manager --disable mysql80-community &>/dev/null  && yum-config-manager --enable mysql57-community
    # add epel repo
    rpm -qa |grep "epel-release" &>/dev/null
    if [ $? -ne 0 ]; then
        yum -y install epel-release
    fi
    # add zabbix repo
    rpm -qa |grep "zabbix-release" &>/dev/null
    if [ $? -ne 0 ]; then
        if centosversion 6; then
            yum -y install http://repo.zabbix.com/zabbix/3.2/rhel/6/x86_64/zabbix-release-3.2-1.el6.noarch.rpm
        elif centosversion 7; then 
            yum -y install http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
    fi
    log "Info" "repository has been configuare, Starting Install..."
}

install_zabbix(){
    # Remove Packages
    yum -y remove mysql*
    yum -y remove mariadb*
    yum -y remove php*
    # Install Lamp
    yum -y install httpd
    yum -y install mysql mysql-server
    yum -y install atomic-php70-php atomic-php70-php-cli atomic-php70-php-common atomic-php70-php-devel atomic-php70-php-pdo atomic-php70-php-mysqlnd atomic-php70-php-mcrypt atomic-php70-php-mbstring atomic-php70-php-xml atomic-php70-php-xmlrpc  atomic-php70-php-gd atomic-php70-php-bcmath atomic-php70-php-imap atomic-php70-php-odbc atomic-php70-php-ldap atomic-php70-php-json atomic-php70-php-intl atomic-php70-php-gmp atomic-php70-php-snmp atomic-php70-php-soap atomic-php70-php-tidy atomic-php70-php-opcache atomic-php70-php-enchant
    # Install zabbix
    yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent
}


####################################
# Init Configuare
####################################

conf_apache(){

}

conf_mysql(){
	
}

