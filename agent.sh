#!bin/bash

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

rootness(){
    if [[ ${EUID} -ne 0 ]]; then
       log "Error" "This script must be run as root"
       exit 1
    fi
}

boot_start(){
    if centosversion 6; then
        checkconfig --add zabbix-agent
        checkconfig zabbix-agent on
    elif centosversion 7; then
        systemctl enable zabbix-agent
    fi
}


install_agent(){
    log "Info" "Starting configuare repositroy..."
    rpm -qa |grep "zabbix-release" &>/dev/null
    if [ $? -ne 0 ]; then
        if centosversion 6; then
            yum -y install http://repo.zabbix.com/zabbix/3.2/rhel/6/x86_64/zabbix-release-3.2-1.el6.noarch.rpm
        elif centosversion 7; then 
            yum -y install http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
    log "Info" "repository has been configuare, Starting Install..."
    yum -y install zabbix-agent 
    boot_start
}

config_agent(){
    agent_hostname=`hostname`
    read -p "What's Agent hostname, Default(${host_name})? :" change_hostname
    change_hostname=${change_hostname:-{agent_hostname}}
    echo "your agent hostname is: ${change_hostname} "
    # change hostname
    hostname ${change_hostname}
    sed -i "/^127.0.0.1/s/^127.0.0.1/&    ${change_hostname}/g" /etc/hosts
    sed -i "/^::1/s/^::1/&    ${change_hostname}/g" /etc/hosts
    sed -i "s/^HOSTNAME.*/HOSTNAME=${change_hostname}/g" /etc/sysconfig/network
    #configuare zabbix 
	sed -i "s/Server=127.0.0.1/Server=${server_ip}/g" /etc/zabbix/zabbix_agentd.conf
	sed -ri "s/(ServerActive=).*/\1${server_ip}/" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^.*Hostname=.*$/Hostname=${g_ZABBIX_AGENT_HOSTNAME}/g" /etc/zabbix/zabbix_agentd.conf
	sed -ri 's@(LogFile=).*@\1/var/log/zabbix/zabbix_agentd.log@' /etc/zabbix/zabbix_agentd.conf
	sed -i 's/LogFileSize=0/LogFileSize=10/' /etc/zabbix/zabbix_agentd.conf
    #check pataerm
    CHECK=`grep "EnableRemoteCommands=1" /etc/zabbix/zabbix_agentd.conf | wc -l `
    if [[ ${CHECK} == 0 ]]
    then
	    sed -ri '/EnableRemoteCommands=/a EnableRemoteCommands=1' /etc/zabbix/zabbix_agentd.conf
    fi
    CHECK=`grep "^HostMetadata" /etc/zabbix/zabbix_agentd.conf | wc -l `
    if [[ ${CHECK} == 0 ]]
    then
	    sed -ri "/HostMetadata=/a HostMetadata=${HostMetadata}" /etc/zabbix/zabbix_agentd.conf
    fi
    # zabbix_agentd.conf.d
    CHECK=`grep "^Include=/etc/zabbix/zabbix_agentd.conf.d/" /etc/zabbix/zabbix_agentd.conf|wc -l`
    if [[ "$CHECK" == "0" ]]
    then
        mkdir -p /etc/zabbix/zabbix_agentd.conf.d/
        echo 'Include=/etc/zabbix/zabbix_agentd.conf.d/' >> /etc/zabbix/zabbix_agentd.conf
    fi
    # UnsafeUserParameters=1
    CHECK=`grep "^UnsafeUserParameters=1" /etc/zabbix/zabbix_agentd.conf|wc -l`
    if [[ "$CHECK" == "0" ]]
    then
        sed -ri '/UnsafeUserParameters=/a UnsafeUserParameters=1' /etc/zabbix/zabbix_agentd.conf
    fi
    # Timeout=10
    CHECK=`grep "^Timeout=3" /etc/zabbix/zabbix_agentd.conf|wc -l`
    if [[ "$CHECK" == "0" ]]
    then
        sed -ri '/Timeout=3/a Timeout=10' /etc/zabbix/zabbix_agentd.conf
    fi
    # AllowRoot=1
    CHECK=`grep "^AllowRoot=1" /etc/zabbix/zabbix_agentd.conf|wc -l`
    if [[ "$CHECK" == "0" ]]
    then
        sed -ri '/AllowRoot=0/a AllowRoot=1' /etc/zabbix/zabbix_agentd.conf
    fi
	mkdir -p /var/log/zabbix && chown -R zabbix:zabbix /var/log/zabbix/
	mkdir -p /var/run/zabbix && chown -R zabbix:zabbix /var/run/zabbix/
}

if [ $# != 3 ]; then
    echo "Usage: $0  [Serverip] [Hostname] [HostMetadata]"
    echo "eg: $0 10.10.10.10 agent_01 Linux"
    exit 1
else
    server_ip=$1
    change_hostname=$2
    HostMetadata=$3

    rootness
    install_agent
    config_agent

    clear
    log "Info" "zabbix_agentd has installed sucessful !"
fi