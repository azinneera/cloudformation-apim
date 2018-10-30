#!/usr/bin/env bash
exec > >(tee /var/log/user-data-env.log|logger -t user-data -s 2>/dev/console) 2>&1
# Echoes all commands before executing.
set -o verbose

# This script setup environment for WSO2 product deployment
readonly OS=$(echo "$2" | awk '{print tolower($0)}')
readonly USERNAME=$(echo "$2" | awk '{print tolower($0)}')
readonly DB_ENGINE=$4
readonly WUM_USER=$6
readonly WUM_PASS=$8
readonly JDK=${10}
readonly LIB_DIR=/home/${USERNAME}/lib
readonly TMP_DIR=/tmp

install_wum() {

    echo "127.0.0.1 $(hostname)" >> /etc/hosts
    if [ $OS = "ubuntu" ]; then
        wget -P ${LIB_DIR}  http://product-dist.wso2.com/downloads/wum/3.0.1/wum-3.0.1-linux-x64.tar.gz
    elif [ $OS = "centos" ]; then
        curl  http://product-dist.wso2.com/downloads/wum/3.0.1/wum-3.0.1-linux-x64.tar.gz --output ${LIB_DIR}/wum-3.0.1-linux-x64.tar.gz
    fi
    cd /usr/local/
    tar -zxvf "${LIB_DIR}/wum-3.0.1-linux-x64.tar.gz"
    chown -R ${USERNAME} wum/

    echo ">> Adding WUM installation directory to PATH ..."
    if [ $OS = "ubuntu" ]; then
        if [ $(grep -r "usr/local/wum/bin" /etc/profile | wc -l  ) = 0 ]; then
            echo "export PATH=\$PATH:/usr/local/wum/bin" >> /etc/profile
        fi
        source /etc/profile
    elif [ $OS = "centos" ]; then
        if [ $(grep -r "usr/local/wum/bin" /etc/profile.d/env.sh | wc -l  ) = 0 ]; then
            echo "export PATH=\$PATH:/usr/local/wum/bin" >> /etc/profile.d/env.sh
        fi
        source /etc/profile.d/env.sh
    fi

    echo ">> Initializing WUM ..."
    sudo -u ${USERNAME} /usr/local/wum/bin/wum init -u ${WUM_USER} -p ${WUM_PASS}
}

get_java_home() {

    JAVA_HOME=${ORACLE_JDK8}
    if [[ ${JDK} = "ORACLE_JDK9" ]]; then
        JAVA_HOME=${ORACLE_JDK9}
    elif [[ ${JDK} = "ORACLE_JDK10" ]]; then
        JAVA_HOME=${ORACLE_JDK10}
    elif [[ ${JDK} = "OPEN_JDK8" ]]; then
        JAVA_HOME=${OPEN_JDK8}
    elif [[ ${JDK} = "OPEN_JDK9" ]]; then
        JAVA_HOME=${OPEN_JDK9}
    elif [[ ${JDK} = "OPEN_JDK10" ]]; then
        JAVA_HOME=${OPEN_JDK10}
    fi

    echo ${JAVA_HOME}
}

setup_java() {

    echo "Setting up java"
    #Default environment variable file is /etc/profile

    ENV_VAR_FILE=/etc/environment

    echo JDK_PARAM=${JDK} >> /home/${USERNAME}/java.txt
    echo ORACLE_JDK9=${ORACLE_JDK9} >> /home/${USERNAME}/java.txt

    if [[ $OS = "ubuntu" ]]; then
        source ${ENV_VAR_FILE}
        JAVA_HOME=$(get_java_home)
        echo "JAVA_HOME=$JAVA_HOME" >> ${ENV_VAR_FILE}
    elif [[ $OS = "centos" ]]; then
        ENV_VAR_FILE="/etc/profile.d/env.sh"
        source ${ENV_VAR_FILE}
        JAVA_HOME=$(get_java_home)
        echo "export JAVA_HOME=$JAVA_HOME" >> ${ENV_VAR_FILE}
    fi

    source ${ENV_VAR_FILE}
}

setup_java_env() {
          JDK=ORACLE_JDK8
          source /etc/environment

          echo JDK_PARAM=${JDK} >> /opt/testgrid/java.txt
          REQUESTED_JDK_PRESENT=$(grep "^${JDK}=" /etc/environment | wc -l)
          if [ $REQUESTED_JDK_PRESENT = 0 ]; then
          printf "The requested JDK, ${JDK}, not found in /etc/environment: \n $(cat /etc/environment)."
          exit 1; // todo: inform via cfn-signal
          fi
            JAVA_HOME=$(grep "^${JDK}=" /etc/environment | head -1 | sed "s:${JDK}=\(.*\):\1:g" | sed 's:"::g')

           echo ">> Setting up JAVA_HOME ..."
            JAVA_HOME_EXISTS=$(grep -r "JAVA_HOME=" /etc/environment | wc -l  )
            if [ $JAVA_HOME_EXISTS = 0 ]; then
              echo ">> Adding JAVA_HOME entry."
              echo JAVA_HOME=$JAVA_HOME >> /etc/environment
            else
              echo ">> Updating JAVA_HOME entry."
              sed -i "/JAVA_HOME=/c\JAVA_HOME=$JAVA_HOME" /etc/environment
          fi
            source /etc/environment
            echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile
                      source /etc/profile
}

main() {
    mkdir -p ${LIB_DIR}
    install_wum
    setup_java_env
    echo "Done!"
}

main
