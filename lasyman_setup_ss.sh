#!/bin/bash
##########################################
# File Name: lasy_setup_ss.sh
# Author: Allan Xing
# Email: xingpeng2012@gmail.com
# Date: 20150301
# Version: v2.0
# History:
#	add centos support@0319
#----------------------------------------
#   fix bugs and code optimization@0319
#----------------------------------------
#	modify for new ss-panel version and add start-up for service@0609
##########################################

#----------------------------------------
#mysql data
HOST="localhost"
MHOST="localhost"
USER="root"
PORT="3306"
ROOT_PASSWD=""
DB_NAME="shadowsocks"
SQL_FILES="invite_code.sql ss_user_admin.sql ss_node.sql ss_reset_pwd.sql user.sql"
CREATED=0
RESET=1
#----------------------------------------

#check OS version
CHECK_OS_VERSION=`cat /etc/issue |sed -n 1"$1"p|awk '{printf $1}' |tr 'a-z' 'A-Z'`

#list the software need to be installed to the variable FILELIST
UBUNTU_TOOLS_LIBS="htop nload python-pip python-m2crypto git supervisor \
				 language-pack-zh*"

CENTOS_TOOLS_LIBS="php55w php55w-opcache mysql55w mysql55w-server php55w-mysql php55w-gd libjpeg* \
				php55w-imap php55w-ldap php55w-odbc php55w-pear php55w-xml php55w-xmlrpc php55w-mbstring \
				php55w-mcrypt php55w-bcmath php55w-mhash libmcrypt m2crypto python-setuptools httpd"

## check whether system is Ubuntu or not
function check_OS_distributor(){
	echo "checking distributor and release ID ..."
	if [[ "${CHECK_OS_VERSION}" == "UBUNTU" ]] ;then
		echo -e "\tCurrent OS: ${CHECK_OS_VERSION}"
		UBUNTU=1
	elif [[ "${CHECK_OS_VERSION}" == "CENTOS" ]] ;then
		echo -e "\tCurrent OS: ${CHECK_OS_VERSION}!!!"
		CENTOS=1
	else
		echo "not support ${CHECK_OS_VERSION} now"
		exit 1
	fi
}

## update system
function update_system()
{
	if [[ ${UNUNTU} -eq 1 ]];then
	{
		echo "apt-get update"
		apt-get update
	}
	elif [[ ${CENTOS} -eq 1 ]];then
	{
		##Webtatic EL6 for CentOS/RHEL 6.x
		rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
		yum install mysql.`uname -i` yum-plugin-replace -y
		yum replace mysql --replace-with mysql55w -y
		yum replace php-common --replace-with=php55w-common -y
	}
	fi
}

#install one software every cycle
function install_soft_for_each(){
	echo "check OS version..."
	check_OS_distributor
	if [[ ${UBUNTU} -eq 1 ]];then
		echo "Will install below software on your Ubuntu system:"
		update_system
		for file in ${UBUNTU_TOOLS_LIBS}
		do
			trap 'echo -e "\ninterrupted by user, exit";exit' INT
			echo "========================="
			echo "installing $file ..."
			echo "-------------------------"
			apt-get install $file -y
			sleep 1
			echo "$file installed ."
		done
		pip install --upgrade pip
		pip install setuptools cymysql shadowsocks
		echo_supervisord_conf > /etc/supervisord.conf
		sed -i '$a\\n[program:ss]\ndirectory=/root/shadowsocks/shadowsocks/\ncommand=python server.py\nuser=root\nautostart=true\nautoresart=true\nstartsecs=10\nstartretries=36\nstderr_logfile=/var/log/supervisor/ss.stderr.log\nstdout_logfile=/var/log/supervisor/ss.stdout.log\n' /etc/supervisord.conf

	elif [[ ${CENTOS} -eq 1 ]];then
		echo "Will install softwears on your CentOs system:"
		update_system
		for file in ${CENTOS_TOOLS_LIBS}
		do
			trap 'echo -e "\ninterrupted by user, exit";exit' INT
			echo "========================="
			echo "installing $file ..."
			echo "-------------------------"
			yum install $file -y
			sleep 3
			echo "$file installed ."
		done
		easy_install pip
		pip install cymysql shadowsocks
		echo "=======ready to reset mysql root password========"
		reset_mysql_root_pwd
		if [ $RESET -eq 0 ];then
			reset_mysql_root_pwd
		fi
	else
		echo "Other OS not support yet, please try Ubuntu or CentOs"
		exit 1
	fi
}


## configure firewall
function setup_firewall()
{
	for port in 443 80 `seq 50000 60000`
	do
		iptables -I INPUT -p tcp --dport $port -j ACCEPT
	done
	/etc/init.d/iptables save
	/etc/init.d/iptables restart
}

#setup manyuser ss
function setup_manyuser_ss()
{
	SS_ROOT=/root/shadowsocks/shadowsocks
	echo -e "download manyuser shadowsocks\n"
	cd /root
	git clone -b manyuser https://github.com/jccg/shadowsocks.git
	cd ${SS_ROOT}
	#modify Config.py
	echo -e "modify Config.py...\n"
	sed -i "/^MYSQL_HOST/ s#'.*'#'${MHOST}'#" ${SS_ROOT}/Config.py
	sed -i "/^MYSQL_USER/ s#'.*'#'${USER}'#" ${SS_ROOT}/Config.py
	sed -i "/^MYSQL_PASS/ s#'.*'#'${ROOT_PASSWD}'#" ${SS_ROOT}/Config.py
	sed -i "/rc4-md5/ s#"rc4-md5"#aes-256-cfb#" ${SS_ROOT}/config.json
}

#====================
# main
#
#judge whether root or not
if [ "$UID" -eq 0 ];then
read -p "(Please input MySQL ip:):" MHOST
read -p "(Please input New MySQL root password):" ROOT_PASSWD
if [ "$ROOT_PASSWD" = "" ]; then
echo "Error: Password can't be NULL!!"
exit 1
fi
	install_soft_for_each
	setup_manyuser_ss
else
	echo -e "please run it as root user again !!!\n"
	exit 1
fi
