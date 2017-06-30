#!/usr/bin/env bash

if [ -z "$SUDO_USER" ]
    then
        echo "orchestrate must be run through sudo"
        exit
fi

# determine this files directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$DIR/../app
DB_FILE=$DIR/../db/data.sql
CONTENT_DIR=$DIR/../wp-content
CONTENT_ARCHIVE=/tmp/wp-content.tar.gz
DEPLOYER_DIR=$PROJECT_DIR/.orchestrate
WORK_DIR=$DEPLOYER_DIR/workspace

if [ $# -lt 1 ]
then
    echo -e "RUNNING: start, stop, permissions\nSETUP: init-local, id-make [env], id-public [env], set-remote-addr env ip, init-remote [env]\nDEPLOYMENT: deploy [env], versions, current"
    exit
fi

case "$1" in

start)  echo "start local server container"
    ./app/run.sh
    ;;

stop)   echo "stop local server container"
    ./app/stop.sh
    ;;

permissions)   echo "set local file permissions"
    ./app/permissions.sh
    ;;

id-make)  echo "create credential"
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    ENV_DIR=$DEPLOYER_DIR/environments/$ENV
    mkdir -p $ENV_DIR
    ssh-keygen -t rsa -N "" -f $ENV_DIR/id_rsa
    openssl rsa -in $ENV_DIR/id_rsa -outform pem > $ENV_DIR/id_rsa.pem
    chmod 400 $ENV_DIR/id_rsa.pem
    ;;

id-public)
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    if [ ! -f $DEPLOYER_DIR/environments/$ENV/id_rsa.pub ]
    then
        echo "no public identity for environment: $ENV"
        exit 1
    fi

    cat $DEPLOYER_DIR/environments/$ENV/id_rsa.pub
    ;;

init-local)  echo "initialize local application"
    mkdir -p $DEPLOYER_DIR
    touch $DEPLOYER_DIR/remote_addr.txt
    touch $DEPLOYER_DIR/versions.txt
    touch $DEPLOYER_DIR/current.txt
    ;;

set-remote-addr)  echo "set the IP address of remote server"
    # must have two arguments
    if [ $# -lt 3 ]
    then
        echo "Usage : set-remote-addr ENVIRONMENT IP"
        exit
    fi
    ENV="$2"
    ADDR="$3"

    echo $ADDR > $DEPLOYER_DIR/environments/$ENV/remote_addr.txt
    echo "REMOTE_ADDR: $ADDR"
    ;;

init-remote)  echo  "initialize remote server"
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    # ensure remote address file exists
    if [ ! -f $DEPLOYER_DIR/environments/$ENV/remote_addr.txt ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # ensure remote address can be read
    REMOTE_ADDR=$(<$DEPLOYER_DIR/environments/$ENV/remote_addr.txt)
    if [ -z $REMOTE_ADDR ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # login to remote system and install docker
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
apt-get update
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-cache policy docker-engine
apt-get install -y linux-image-extra-virtual
apt-get install -y docker-engine
service docker start
systemctl enable docker
EOF
    ;;


login)  echo  "login to remote server"
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    # ensure remote address file exists
    if [ ! -f $DEPLOYER_DIR/environments/$ENV/remote_addr.txt ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # ensure remote address can be read
    REMOTE_ADDR=$(<$DEPLOYER_DIR/environments/$ENV/remote_addr.txt)
    if [ -z $REMOTE_ADDR ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # login to remote system and install docker
    echo "sudo ssh ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem"
    ;;


versions)
    cat $DEPLOYER_DIR/versions.txt
    ;;

current)
    cat $DEPLOYER_DIR/current.txt
    ;;

deploy-content)
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    # make sure remote address is set
    if [ ! -f $DEPLOYER_DIR/environments/$ENV/remote_addr.txt ]
    then
        echo "remote address is not set"
        exit 1
    fi
    REMOTE_ADDR=$(<$DEPLOYER_DIR/environments/$ENV/remote_addr.txt)
    if [ -z $REMOTE_ADDR ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # tar the files
    rm -rf $CONTENT_ARCHIVE
    if tar -czf $CONTENT_ARCHIVE $CONTENT_DIR ; then
        echo -e "\nCREATE DEPLOYMENT ARCHIVE: OK"
    else
        echo -e "\nCREATE DEPLOYMENT ARCHIVE: FAILED"
        exit 1
    fi

    # copy the tar
    scp -o StrictHostKeyChecking=no -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem $CONTENT_ARCHIVE ubuntu@$REMOTE_ADDR:/tmp/wp-content.tar.gz
    echo -e "\nCOPY DATA: OK"

    # move and extract file
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
mkdir -p /app/wp-content
rm -rf /app/wp-content-backup
mv /app/wp-content /app/wp-content-backup
mv /tmp/wp-content.tar.gz /app/wp-content.tar.gz
cd /app
tar xzf ./wp-content.tar.gz
rm ./wp-content.tar.gz
chown www-data ./wp-content -R
chgrp www-data ./wp-content -R
EOF
    echo -e "\nEXTRACTED DATA: OK"

    ;;

deploy-db)
    # set the environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    # make sure remote address is set
    if [ ! -f $DEPLOYER_DIR/environments/$ENV/remote_addr.txt ]
    then
        echo "remote address is not set"
        exit 1
    fi
    REMOTE_ADDR=$(<$DEPLOYER_DIR/environments/$ENV/remote_addr.txt)
    if [ -z $REMOTE_ADDR ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # make db folder
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
mkdir -p /app/db
EOF
    echo -e "\nCREATE REMOTE DIRECTORY: OK"

    # compress file?

    # copy db file
    scp -o StrictHostKeyChecking=no -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem $DB_FILE ubuntu@$REMOTE_ADDR:/tmp/data.sql
    echo -e "\nCOPY DATA: OK"

    # move file
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
mv /tmp/data.sql /app/db/data.sql
EOF
    echo -e "\nMOVE DATA: OK"
    ;;

deploy)  echo  "deploy a new version"
    # set the target environement
    if [ -z $2 ]
        then
            ENV="default"
    else
        ENV="$2"
    fi

    # initialize working dir
    mkdir -p $WORK_DIR
    rm -rf $WORK_DIR
    mkdir -p $WORK_DIR

    # create a working bundle
    WORK_ARCHIVE=$WORK_DIR/app.tar
    if tar --exclude .git --exclude .orchestrate --exclude node_modules -cf $WORK_ARCHIVE $PROJECT_DIR ; then
        echo -e "\nCREATE WORKING ARCHIVE: OK"
    else
        echo -e "\nCREATE WORKING ARCHIVE: FAILED"
        exit 1
    fi

    # extract a working bundle
    if tar -xf $WORK_ARCHIVE -C $WORK_DIR; then
        echo -e "\nEXTRACT WORKING ARCHIVE: OK"
    else
        echo -e "\nEXTRACT WORKING ARCHIVE: FAILED"
        exit 1
    fi
    rm $WORK_DIR/app.tar

    # copy production run and stop scripts
    cp ./app/production/*.sh $WORK_DIR/app
    chmod +x $WORK_DIR/app/run.sh
    chmod +x $WORK_DIR/app/stop.sh

    # make sure remote address is set
    if [ ! -f $DEPLOYER_DIR/environments/$ENV/remote_addr.txt ]
    then
        echo "remote address is not set"
        exit 1
    fi
    REMOTE_ADDR=$(<$DEPLOYER_DIR/environments/$ENV/remote_addr.txt)
    if [ -z $REMOTE_ADDR ]
    then
        echo "remote address is not set"
        exit 1
    fi

    # create the versions file (if it doesn't exist)
    touch $DEPLOYER_DIR/versions.txt

    # read last version in the file
    VERSION=$(tail -1 $DEPLOYER_DIR/versions.txt)

    # check if there is not version yet
    if [ -z $VERSION ]
    then
        VERSION=1
    else
        VERSION=$(($VERSION + 1))
    fi

    echo "$VERSION" >> $DEPLOYER_DIR/versions.txt
    echo -e "NEW VERSION: $VERSION"

    # create a new bundle
    ARCHIVE_DIR="$DEPLOYER_DIR/archives"
    mkdir -p $ARCHIVE_DIR
    ARCHIVE=$ARCHIVE_DIR/app-v$VERSION.tar.gz
    if tar --exclude node_modules -czf $ARCHIVE $WORK_DIR ; then
        echo -e "\nCREATE DEPLOYMENT ARCHIVE: OK"
    else
        echo -e "\nCREATE DEPLOYMENT ARCHIVE: FAILED"
        exit 1
    fi

    # make new remote directory for version
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
mkdir -p /app/persistent
mkdir -p /app/persistent/log
mkdir -p /app
mkdir -p /app/version
mkdir -p /app/version/$VERSION
EOF
    echo -e "\nCREATE REMOTE DIRECTORY: OK"

    # copy new application version
    scp -o StrictHostKeyChecking=no -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem $ARCHIVE ubuntu@$REMOTE_ADDR:/tmp/app.tar.gz
    echo -e "\nCOPY DEPLOYMENT ARCHIVE: OK"

    # extract new application version
    # stop the current version
    ssh -o StrictHostKeyChecking=no ubuntu@$REMOTE_ADDR -i $DEPLOYER_DIR/environments/$ENV/id_rsa.pem << EOF
sudo bash
mv /tmp/app.tar.gz /app/version/$VERSION/app.tar.gz
cd /app/version/$VERSION && tar xzf ./app.tar.gz --strip-components=3
cd /app/version/$VERSION/app && ./stop.sh
cd /app/version/$VERSION/app && ./run.sh production
EOF
    echo -e "\nREMOTE ARCHIVE EXTRATED: OK"
    echo -e "\nSTOP PREVIOUS VERSION: OK"
    echo -e "\nSTART NEW VERSION: OK"

    # update the current.txt file
    echo $VERSION > $DEPLOYER_DIR/current.txt

    ;;


*) echo "Unknown command: $1"
   ;;
esac
