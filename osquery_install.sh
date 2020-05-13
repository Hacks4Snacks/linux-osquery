#!/bin/bash

if [[ "$1" == "--uninstall" ]]; then
    do_uninstall=true
else
    do_install_osquery=true
    do_install_rsyslog=true
fi

if [[ -f /etc/os-release ]]; then
	source /etc/os-release
elif [[ -f /etc/redhat-release ]]; then
	NAME=`sed -rn 's/(\w+).*/\1/p' /etc/redhat-release`
	VERSION_ID=`grep -o '[0-9]\.[0-9]' /etc/redhat-release`
else
	echo "Can not identify OS"
	exit 1
fi

if [[ "${NAME}" == "Ubuntu"  ]]; then
	UBUNTU=true
    if [[ "${VERSION_ID}" == "18.04" ]]; then
        UBUNTU_18=true
	elif [[ "${VERSION_ID}" == "16.04" ]]; then
		UBUNTU_16=true	
	else
		echo "Unsupported Ubuntu Version"
		echo "${NAME}"
		echo "${VERSION_ID}"
		exit 1
	fi

elif [[ "${NAME}" == "CentOS Linux" ]]; then
	if [[ "${VERSION_ID}" == "7" ]]; then
		CENTOS=true
		CENTOS_7=true
	fi
elif [[  -f /etc/redhat-release ]]; then
	if [[ "${NAME}" == "CentOS" ]]; then
		CENTOS=true
		if [[ "${VERSION_ID}" == "6.6" || "${VERSION_ID}" == "6.7" || "${VERSION_ID}" == "6.8" ]]; then
			CENTOS_6=true
		elif [[ "${VERSION_ID}" == "7.0" || "${VERSION_ID}" == "7.1" || "${VERSION_ID}" == "7.2" || "${VERSION_ID}" == "7.3" ]]; then
			CENTOS_7=true
		else
			echo "Unsupported CentOS Version"
			echo "${NAME}"
			echo "${VERSION_ID}"
			exit 1
		fi
	#elif [[ "${NAME}" == "Red Hat Enterprise Linux Server" ]]; then
	elif [[ "${NAME}" == "Red"* ]]; then
#		Treat redhat like centos
		CENTOS=true
		if [[ "${VERSION_ID}" == "7.3" || "${VERSION_ID}" == "7.2" || "${VERSION_ID}" == "7.1" ]]; then
			CENTOS_7=true
		elif [[ "${VERSION_ID}" == "6.6" || "${VERSION_ID}" == "6.7" || "${VERSION_ID}" == "6.8" ]]; then
			CENTOS_6=true
		else
			echo "Unsupported RedHat Version"
			echo "${NAME}"
			echo "${VERSION_ID}"
			exit 1
		fi
	else
		echo "Unsupported Redhat Distribution"
		echo "${NAME}"
		echo "${VERSION_ID}"
		exit 1
	fi
else
	echo "Unsupported Distribution"
	echo "${NAME}"
	echo "${VERSION_ID}"
	exit 1
fi

unset sudo

if [[ "$EUID" != "0" ]]; then
	sudo=sudo
fi

#### INSTALL FUNCTIONS ####

install_osquery() {
	if [[ "${UBUNTU}" == "true" ]]; then
            if [[ "${UBUNTU_18}" == "true" ]]; then
                install_osquery_ubuntu_18
		elif [[ "${UBUNTU_16}" == "true" ]]; then
			install_osquery_ubuntu_16
		fi
	elif [[ "${CENTOS}" == "true" ]]; then
		if [[ "${CENTOS_6}" == "true" ]]; then
			install_osquery_centos_66
			setup_osquery_centos_amazon
		elif [[ "${CENTOS_7}" == "true" ]]; then
			install_osquery_centos_70
			setup_osquery_centos_amazon
		fi
	fi
}

install_osquery_ubuntu() {
	${sudo} apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C9D8B80B
	${sudo} add-apt-repository "${REPO}"
	${sudo} apt-get update
	${sudo} apt-get install osquery
	setup_osquery_ubuntu
}

install_osquery_ubuntu_16() {
	REPO="deb https://osquery-packages.s3.amazonaws.com/xenial xenial main"
	install_osquery_ubuntu
}

install_osquery_ubuntu_18() {
	REPO="deb [arch=amd64] https://pkg.osquery.io/deb deb main"
	install_osquery_ubuntu
}

install_osquery_centos_66() {
	${sudo} rpm -ivh https://osquery-packages.s3.amazonaws.com/centos6/noarch/osquery-s3-centos6-repo-1-0.0.noarch.rpm
	${sudo} yum -y install osquery
}

install_osquery_centos_70() {
	${sudo} rpm -ivh https://osquery-packages.s3.amazonaws.com/centos7/noarch/osquery-s3-centos7-repo-1-0.0.noarch.rpm
	${sudo} yum -y install osquery
}

install_rsyslog() {
    if [[ "${UBUNTU}" == "true" ]]; then
            install_rsyslog_ubuntu
		fi
	elif [[ "${CENTOS}" == "true" ]]; then
		if [[ "${CENTOS_6}" == "true" ]]; then
			install_rsyslog_centos_66
		elif [[ "${CENTOS_7}" == "true" ]]; then
			install_rsyslog_centos_70
		fi
	fi
}

install_rsyslog_ubuntu() {
	${sudo} apt-get update
	${sudo} apt-get install 
	setup_rsyslog_ubuntu
}

#### SETUP FUNCTIONS (CONFIGURE) ####

setup_osquery() {
	${sudo} cp osquery.conf /etc/osquery/osquery.conf
}

setup_osquery_ubuntu() {
	setup_osquery
    ${sudo} update-rc.d osqueryd defaults
}

setup_rsyslog_ubuntu() {
    read -p "Please enter the IP of the USM Sensor: " SENSORIP
    ${sudo} echo "*.*	@$SENSORIP:514" | sudo tee -a /etc/rsyslog.d/50-default.conf > /dev/null
    ${sudo} systemctl enable rsyslog
    ${sudo} systemctl start rsyslog
}

setup_osquery_centos_amazon() {
	setup_osquery
	${sudo} chkconfig --add osqueryd
}

#### UNINSTALL FUNCTIONS ####

uninstall_osquery_ubuntu() {
    ${sudo} service osqueryd stop
    ${sudo} update-rc.d -f osqueryd remove
    ${sudo} apt-get purge --auto-remove osquery
    ${sudo} rm -rf /etc/osquery
    ${sudo} rm -rf /var/osquery
    ${sudo} rm -rf /var/log/osquery
}

uninstall_osquery_redhat() {
    ${sudo} service osqueryd stop
    ${sudo} chkconfig --del osqueryd
    ${sudo} yum -y remove osquery
    ${sudo} rm -rf /usr/share/osquery
    ${sudo} rm -rf /etc/osquery
    ${sudo} rm -rf /var/osquery
    ${sudo} rm -rf /var/log/osquery
}

osquery_uninstall() {
	if [[ "${UBUNTU}" == "true" ]]; then
	    uninstall_osquery_ubuntu
	elif [[ "${CENTOS}" == "true" ]]; then
            uninstall_osquery_redhat
	fi
}

if [ "$do_install_osquery" = true ] ; then
	install_osquery
	${sudo} service osqueryd restart
fi

if [ "$do_install_rsyslog" = true ] ; then
	install_rsyslog
	${sudo} systemctl restart rsyslog
fi

if [ "$do_uninstall" = true ] ; then
    osquery_uninstall
    uninstall_awslogs
fi
