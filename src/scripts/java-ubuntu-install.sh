#!/bin/bash

# License: https://github.com/elastic/azure-marketplace/blob/master/LICENSE.txt
#
# Russ Cam (Elastic)
#

export DEBIAN_FRONTEND=noninteractive

#########################
# HELP
#########################

help()
{
    echo "This script installs Java on Ubuntu using the oracle-java8-installer apt package"
    echo ""
    echo "Options:"
    echo "   -h         this help message"
}

log()
{
    echo \[$(date +%d%m%Y-%H:%M:%S)\] \["install_java"\] "$1"
    echo \[$(date +%d%m%Y-%H:%M:%S)\] \["install_java"\] "$1" >> /var/log/arm-install.log
}

#########################
# Parameter handling
#########################

while getopts h optname; do
    log "Option $optname set with value ${OPTARG}"
  case ${optname} in
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

install_java_package()
{
  apt-get -yq $@ install oracle-java8-installer
}

install_java()
{
    log "adding apt repository for java"
    (add-apt-repository -y ppa:webupd8team/java || (sleep 15; add-apt-repository -y ppa:webupd8team/java))
    log "updating apt-get"
    (apt-get -y update || (sleep 15; apt-get -y update)) > /dev/null
    log "updated apt-get"
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
    log "installing java"
    (install_java_package || (sleep 15; install_java_package))
    command -v java >/dev/null 2>&1 || { sleep 15; rm /var/cache/oracle-jdk8-installer/jdk-*; apt-get install -f; }

    #if the previous did not install correctly we go nuclear, otherwise this loop will early exit
    for i in $(seq 30); do
      if $(command -v java >/dev/null 2>&1); then
        log "installed java!"
        return
      else
        sleep 5
        rm /var/cache/oracle-jdk8-installer/jdk-*;
        rm -f /var/lib/dpkg/info/oracle-java8-installer*
        rm /etc/apt/sources.list.d/*java*
        apt-get -yq purge oracle-java8-installer*
        apt-get -yq autoremove
        apt-get -yq clean
        (add-apt-repository -y ppa:webupd8team/java || (sleep 15; add-apt-repository -y ppa:webupd8team/java))
        apt-get -yq update
        install_java_package --reinstall
        log "seeing if java is installed after nuclear retry ${i}/30"
      fi
    done
    command -v java >/dev/null 2>&1 || { log "java did not get installed properly even after a retry and a forced installation" >&2; exit 50; }
}

install_java
