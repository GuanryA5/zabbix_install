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