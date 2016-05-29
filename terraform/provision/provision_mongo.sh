#!/bin/bash

set -e

function get_response_code() {

    port=$1

    set +e

    curl_cmd=$(which curl)
    wget_cmd=$(which wget)

    if [[ ! -z ${curl_cmd} ]]; then
        response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${port})
    elif [[ ! -z ${wget_cmd} ]]; then
        response_code=$(wget --spider -S "http://localhost:${port}" 2>&1 | grep "HTTP/" | awk '{print $2}' | tail -1)
    else
        echo "Failed to retrieve response code from http://localhost:${port}: Neither 'cURL' nor 'wget' were found on the system"
        exit 1;
    fi

    set -e

    echo ${response_code}

}

function wait_for_server() {

    port=$1
    server_name=$2

    started=false

    echo "Running ${server_name} liveness detection on port ${port}"

    for i in $(seq 1 120)
    do
        response_code=$(get_response_code ${port})
        echo "[GET] http://localhost:${port} ${response_code}"
        if [ ${response_code} -eq 200 ] ; then
            started=true
            break
        else
            echo "${server_name} has not started. waiting..."
            sleep 1
        fi
    done
    if [ ${started} = false ]; then
        echo "${server_name} failed to start. waited for a 120 seconds."
        exit 1
    fi
}

function download() {

   url=$1
   name=$2

   if [ -f "`pwd`/${name}" ]; then
        echo "`pwd`/${name} already exists, No need to download"
   else
        # download to given directory
        echo "Downloading ${url} to `pwd`/${name}"

        set +e
        curl_cmd=$(which curl)
        wget_cmd=$(which wget)
        set -e

        if [[ ! -z ${curl_cmd} ]]; then
            curl -L -o ${name} ${url}
        elif [[ ! -z ${wget_cmd} ]]; then
            wget -O ${name} ${url}
        else
            echo "Failed to download ${url}: Neither 'cURL' nor 'wget' were found on the system"
            exit 1;
        fi
   fi

}


function untar() {

    tar_archive=$1
    destination=$2

    if [ ! -d ${destination} ]; then
        inner_name=$(tar -tf "${tar_archive}" | grep -o '^[^/]\+' | sort -u)
        echo "Untaring ${tar_archive}"
        tar -zxvf ${tar_archive}

        echo "Moving ${inner_name} to ${destination}"
        mv ${inner_name} ${destination}
    fi
}

TEMP_DIR='/tmp'
MONGO_TARBALL_NAME='mongodb-linux-x86_64-2.4.9.tgz'

################################
# Directory that will contain:
#  - MongoDB binaries
#  - MongoDB Database files
################################
MONGO_ROOT_PATH=${TEMP_DIR}/mongodb
MONGO_DATA_PATH=${MONGO_ROOT_PATH}/data
MONGO_BINARIES_PATH=${MONGO_ROOT_PATH}/mongodb-binaries
mkdir -p ${MONGO_ROOT_PATH}

cd ${TEMP_DIR}
download http://downloads.mongodb.org/linux/${MONGO_TARBALL_NAME} ${MONGO_TARBALL_NAME}
untar ${MONGO_TARBALL_NAME} ${MONGO_BINARIES_PATH}

echo "Creating MongoDB data directory in ${MONGO_DATA_PATH}"
mkdir -p ${MONGO_DATA_PATH}

echo "Successfully installed MongoDB"

PORT=27017
COMMAND="${MONGO_BINARIES_PATH}/bin/mongod --port ${PORT} --dbpath ${MONGO_DATA_PATH} --rest --journal --shardsvr --smallfiles"

echo "${COMMAND}"
nohup ${COMMAND} > /dev/null 2>&1 &
PID=$!

MONGO_REST_PORT=`expr ${PORT} + 1000`
wait_for_server ${MONGO_REST_PORT} 'MongoDB'

# this runtime porperty is used by the stop-mongo script.
echo "Successfully started MongoDB (${PID})"