#!/usr/bin/env bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# Echoes all commands before executing.
set -o verbose

readonly OS=$(echo "$2" | awk '{print tolower($0)}')
readonly USERNAME=$(echo "$2" | awk '{print tolower($0)}')
readonly DB_HOST=$4
readonly DB_PORT=$6
readonly DB_ENGINE=$(echo "$8" | awk '{print tolower($0)}')
readonly DB_VERSION=${10}
#Master DB connection details
readonly DB_USERNAME=${12}
readonly DB_PASSWORD=${14}
readonly APIM_HOST_NAME=${16}

readonly PRODUCT_NAME=${18}
readonly PRODUCT_VERSION=${20}
readonly WUM_PRODUCT_NAME=${PRODUCT_NAME}-${PRODUCT_VERSION}
readonly WUM_PRODUCT_DIR=/home/${USERNAME}/.wum-wso2/products/${PRODUCT_NAME}/${PRODUCT_VERSION}
readonly INSTALLATION_DIR=/opt/wso2
readonly PRODUCT_HOME="${INSTALLATION_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}"
readonly DB_SCRIPTS_PATH="${PRODUCT_HOME}/dbscripts"

readonly POSTGRES_DB="wso2db"
readonly SID="ORCL"

# databases
readonly AM_DB="wso2_am_db"
readonly MB_DB="wso2mb_db"
readonly GOV_REG_DB="wso2_greg_db"
readonly CONFIG_REG_DB="wso2_conf_db"
readonly METRICS_DB="wso2_metrics_db"

UM_USER=$DB_USERNAME
readonly UM_USER_PWD=$DB_PASSWORD
AM_USER=$DB_USERNAME
readonly AM_USER_PWD=$DB_PASSWORD
MB_USER=$DB_USERNAME
readonly MB_USER_PWD=$DB_PASSWORD
GOV_REG_USER=$DB_USERNAME
readonly GOV_REG_USER_PWD=$DB_PASSWORD
CONFIG_REG_USER=$DB_USERNAME
readonly CONFIG_REG_USER_PWD=$DB_PASSWORD
IDENTITY_USER=$DB_USERNAME
readonly IDENTITY_USER_PWD=$DB_PASSWORD
BPS_USER=$DB_USERNAME
readonly BPS_USER_PWD=$DB_PASSWORD
METRICS_USER=$DB_USERNAME
readonly METRICS_USER_PWD=$DB_PASSWORD


setup_wum_updated_pack() {

    sudo -u ${USERNAME} /usr/local/wum/bin/wum add ${WUM_PRODUCT_NAME} -y
    sudo -u ${USERNAME} /usr/local/wum/bin/wum update ${WUM_PRODUCT_NAME}
    mkdir -p ${INSTALLATION_DIR}
    chown -R ${USERNAME} ${INSTALLATION_DIR}
    echo ">> Copying WUM updated ${WUM_PRODUCT_NAME} to ${INSTALLATION_DIR}"
    sudo -u ${USERNAME} unzip ${WUM_PRODUCT_DIR}/$(ls -t ${WUM_PRODUCT_DIR} | grep .zip | head -1) -d ${INSTALLATION_DIR}
}

setup_mysql_databases() {
    echo "MySQL setting up"
    echo ">> Setting up MySQL databases ..."
    echo ">> Creating databases..."
    mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $AM_DB;
    DROP DATABASE IF EXISTS $MB_DB; DROP DATABASE IF
    EXISTS $GOV_REG_DB; DROP DATABASE IF EXISTS $CONFIG_REG_DB; DROP DATABASE IF EXISTS $METRICS_DB;
    CREATE DATABASE $AM_DB; CREATE DATABASE $MB_DB;
    CREATE DATABASE $GOV_REG_DB; CREATE DATABASE $CONFIG_REG_DB; CREATE DATABASE $METRICS_DB;"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    if [[ $DB_VERSION == "5.7*" ]]; then
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD -e "USE $AM_DB; SOURCE $DB_SCRIPTS_PATH/apimgt/mysql5.7.sql;
        USE $MB_DB; SOURCE $DB_SCRIPTS_PATH/mb-store/mysql-mb.sql;
        USE $GOV_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql5.7.sql; USE $CONFIG_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql5.7.sql;
        USE $METRICS_DB; SOURCE $DB_SCRIPTS_PATH/metrics/mysql.sql;"

    else
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD -e "USE $AM_DB; SOURCE $DB_SCRIPTS_PATH/apimgt/mysql.sql;
        USE $MB_DB; SOURCE $DB_SCRIPTS_PATH/mb-store/mysql-mb.sql;
        USE $GOV_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql.sql; USE $CONFIG_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql.sql;
        USE $METRICS_DB; SOURCE $DB_SCRIPTS_PATH/metrics/mysql.sql;"
    fi
    echo ">> Tables created!"
}

setup_mariadb_databases() {
    echo ">> Setting up MariaDB databases ..."
    echo ">> Creating databases..."
    mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $AM_DB;
    DROP DATABASE IF EXISTS $MB_DB; DROP DATABASE IF EXISTS $GOV_REG_DB; DROP DATABASE IF EXISTS $CONFIG_REG_DB;
    DROP DATABASE IF EXISTS $METRICS_DB;
    CREATE DATABASE $AM_DB; CREATE DATABASE $MB_DB; CREATE DATABASE $GOV_REG_DB; CREATE DATABASE $CONFIG_REG_DB;
    CREATE DATABASE $METRICS_DB;"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD -e "USE $AM_DB; SOURCE $DB_SCRIPTS_PATH/apimgt/mysql.sql;
    USE $MB_DB; SOURCE $DB_SCRIPTS_PATH/mb-store/mysql-mb.sql;
    USE $GOV_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql.sql; USE $CONFIG_REG_DB; SOURCE $DB_SCRIPTS_PATH/mysql.sql;
    USE $METRICS_DB; SOURCE $DB_SCRIPTS_PATH/metrics/mysql.sql;"
    echo ">> Tables created!"
}

setup_oracle_databases() {
    export ORACLE_SID=$SID
    GOV_REG_USER=$GOV_REG_DB
    CONFIG_REG_USER=$CONFIG_REG_DB
    METRICS_USER=$METRICS_DB

    echo ">> Setting up Oracle user create script ..."
    #Create database scripts
    echo "CREATE USER $AM_DB IDENTIFIED BY $DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO $AM_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO $AM_DB;" >> oracle.sql
    echo "CREATE USER $MB_DB IDENTIFIED BY $DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO $MB_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO $MB_DB;" >> oracle.sql
    echo "CREATE USER $GOV_REG_DB IDENTIFIED BY $DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO $GOV_REG_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO $GOV_REG_DB;" >> oracle.sql
    echo "CREATE USER $CONFIG_REG_DB IDENTIFIED BY $DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO $CONFIG_REG_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO $CONFIG_REG_DB;" >> oracle.sql
    echo "CREATE USER $METRICS_DB IDENTIFIED BY $DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO $METRICS_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO $METRICS_DB;" >> oracle.sql

    echo ">> Setting up Oracle schemas ..."
    echo exit | sqlplus64 $DB_USERNAME/$DB_PASSWORD@//$DB_HOST/$SID @oracle.sql
    echo ">> Setting up Oracle tables ..."
    echo exit | sqlplus64 $AM_DB/$DB_PASSWORD@//$DB_HOST/$SID @$DB_SCRIPTS_PATH/apimgt/oracle.sql
    echo exit | sqlplus64 $MB_DB/$DB_PASSWORD@//$DB_HOST/$SID @$DB_SCRIPTS_PATH/mb-store/oracle-mb.sql
    echo exit | sqlplus64 $GOV_REG_DB/$DB_PASSWORD@//$DB_HOST/$SID @$DB_SCRIPTS_PATH/oracle.sql
    echo exit | sqlplus64 $CONFIG_REG_DB/$DB_PASSWORD@//$DB_HOST/$SID @$DB_SCRIPTS_PATH/oracle.sql
    echo exit | sqlplus64 $METRICS_DB/$DB_PASSWORD@//$DB_HOST/$SID @$DB_SCRIPTS_PATH/metrics/oracle.sql
    echo ">> Tables created ..."
}

setup_sqlserver_databases() {
    echo ">> Setting up SQLServer databases ..."
    echo ">> Creating databases..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "DROP DATABASE IF EXISTS $AM_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "DROP DATABASE IF EXISTS $MB_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "DROP DATABASE IF EXISTS $GOV_REG_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "DROP DATABASE IF EXISTS $CONFIG_REG_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "DROP DATABASE IF EXISTS $METRICS_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $AM_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $MB_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $GOV_REG_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $CONFIG_REG_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $METRICS_DB"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $AM_DB -i $DB_SCRIPTS_PATH/apimgt/mssql.sql
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $MB_DB -i $DB_SCRIPTS_PATH/mb-store/mssql-mb.sql
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $GOV_REG_DB -i $DB_SCRIPTS_PATH/mssql.sql
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $CONFIG_REG_DB -i $DB_SCRIPTS_PATH/mssql.sql
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $METRICS_DB -i $DB_SCRIPTS_PATH/metrics/mssql.sql
}

setup_postgres_databases() {
    echo "Postgres setting up"
    export PGPASSWORD=$DB_PASSWORD
    echo ">> Setting up Postgres databases ..."
    echo ">> Creating databases..."
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d postgres -c "CREATE DATABASE $AM_DB;"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d postgres -c "CREATE DATABASE $MB_DB;"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d postgres -c "CREATE DATABASE $GOV_REG_DB;"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d postgres -c "CREATE DATABASE $CONFIG_REG_DB;"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d postgres -c "CREATE DATABASE $METRICS_DB;"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $AM_DB -f $DB_SCRIPTS_PATH/apimgt/postgresql.sql
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $MB_DB -f $DB_SCRIPTS_PATH/mb-store/postgresql-mb.sql
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $GOV_REG_DB -f $DB_SCRIPTS_PATH/postgresql.sql
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $CONFIG_REG_DB -f $DB_SCRIPTS_PATH/postgresql.sql
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $METRICS_DB -f $DB_SCRIPTS_PATH/metrics/postgresql.sql
    echo ">> Tables created!"
}

copy_libs() {
    echo ">> Copying $DB_ENGINE jdbc driver "
    if [[ $DB_ENGINE =~ 'oracle' ]]; then
        cp /home/$USERNAME/sql-drivers/oracle-se.jar ${PRODUCT_HOME}/repository/components/lib
    elif [[ $DB_ENGINE =~ 'sqlserver' ]]; then
        cp /home/$USERNAME/sql-drivers/sqlserver-ex.jar ${PRODUCT_HOME}/repository/components/lib
    elif [[ $DB_ENGINE =~ 'mariadb' ]]; then
        cp /home/$USERNAME/sql-drivers/mysql.jar ${PRODUCT_HOME}/repository/components/lib
    else
        cp /home/$USERNAME/sql-drivers/$DB_ENGINE.jar ${PRODUCT_HOME}/repository/components/lib
    fi
}

copy_config_files() {
    echo ">> Copying configuration files "
    cp -r -v product-configs/* ${PRODUCT_HOME}/repository/conf/
    echo ">> Done!"
}

get_jdbc_connection_url() {
    URL=""
    if [[ $DB_ENGINE = "postgres" ]]; then
        URL="jdbc:postgresql://$DB_HOST:$DB_PORT/$1"
    elif [[ $DB_ENGINE = "mysql" ]]; then
	    URL="jdbc:mysql://$DB_HOST:$DB_PORT/$1?useSSL=false"
    elif [[ $DB_ENGINE =~ 'oracle' ]]; then
        URL="jdbc:oracle:thin:@$DB_HOST:$DB_PORT/$SID"
    elif [[ $DB_ENGINE =~ 'sqlserver' ]]; then
        URL="jdbc:sqlserver://$DB_HOST:$DB_PORT;databaseName=$1"
    elif [[ $DB_ENGINE = "mariadb" ]]; then
        URL="jdbc:mysql://$DB_HOST:$DB_PORT/$1?useSSL=false"
    fi
    echo $URL
}

configure_product() {
    DRIVER_CLASS=$(get_driver_class)
    echo ">> Configuring product "
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_APIM_LB_HOSTNAME_#/'$APIM_HOST_NAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's|#_AM_DB_CONNECTION_URL_#|'$(get_jdbc_connection_url $AM_DB)'|g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AM_USER_#/'$AM_USER'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AM_USER_PWD_#/'$AM_USER_PWD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's|#_MB_DB_CONNECTION_URL_#|'$(get_jdbc_connection_url $MB_DB)'|g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MB_USER_#/'$MB_USER'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MB_USER_PWD_#/'$MB_USER_PWD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's|#_GOV_REG_DB_CONNECTION_URL_#|'$(get_jdbc_connection_url $GOV_REG_DB)'|g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_GOV_REG_USER_#/'$GOV_REG_USER'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_GOV_REG_USER_PWD_#/'$GOV_REG_USER_PWD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's|#_CONFIG_REG_DB_CONNECTION_URL_#|'$(get_jdbc_connection_url $CONFIG_REG_DB)'|g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_CONFIG_REG_USER_#/'$CONFIG_REG_USER'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_CONFIG_REG_USER_PWD_#/'$CONFIG_REG_USER_PWD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's|#_METRICS_DB_CONNECTION_URL_#|'$(get_jdbc_connection_url $METRICS_DB)'|g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_METRICS_USER_#/'$METRICS_USER'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_METRICS_USER_PWD_#/'$METRICS_USER_PWD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DRIVER_CLASS_#/'$DRIVER_CLASS'/g'
    echo "Done!"
}

get_driver_class() {
    DRIVER_CLASS=""
    if [[ $DB_ENGINE = "postgres" ]]; then
        DRIVER_CLASS="org.postgresql.Driver"
    elif [[ $DB_ENGINE = "mysql" ]]; then
	    DRIVER_CLASS="com.mysql.jdbc.Driver"
    elif [[ $DB_ENGINE =~ 'oracle' ]]; then
        DRIVER_CLASS="oracle.jdbc.driver.OracleDriver"
    elif [[ $DB_ENGINE =~ 'sqlserver' ]]; then
        DRIVER_CLASS="com.microsoft.sqlserver.jdbc.SQLServerDriver"
    elif [[ $DB_ENGINE = "mariadb" ]]; then
        DRIVER_CLASS="com.mysql.jdbc.Driver"
    fi
    echo $DRIVER_CLASS
}

start_product() {
    chown -R ${USERNAME} ${PRODUCT_HOME}
    echo ">> Starting WSO2 API Manager ... "
    if [[ $OS = "ubuntu" ]]; then
        sudo -u ${USERNAME} bash ${PRODUCT_HOME}/bin/wso2server.sh start
    elif [[ $OS = "centos" ]]; then
        bash ${PRODUCT_HOME}/bin/wso2server.sh start
    fi
}

main() {
    setup_wum_updated_pack
    if [[ $OS = "ubuntu" ]]; then
        source /etc/environment
    elif [[ $OS = "centos" ]]; then
        source /etc/profile.d/env.sh
    fi
    if [[ $DB_ENGINE = "postgres" ]]; then
        setup_postgres_databases
    elif [[ $DB_ENGINE = "mysql" ]]; then
	    setup_mysql_databases
    elif [[ $DB_ENGINE =~ 'oracle' ]]; then
        setup_oracle_databases
    elif [[ $DB_ENGINE =~ 'sqlserver' ]]; then
        setup_sqlserver_databases
    elif [[ $DB_ENGINE = "mariadb" ]]; then
        setup_mariadb_databases
    fi
    copy_libs
    copy_config_files
    configure_product
    start_product
}

main
