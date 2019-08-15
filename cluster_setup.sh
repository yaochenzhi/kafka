#!/usr/bin/env bash
# Used for: auto set up for kafka cluster
# Date: 2019/08/15
##############################################################
# ZOOKEEPER CONFIG:
#   dataDir=/tmp/zookeeper
#   clientPort=2181

# KAFKA CONFIG:
#   broker.id=0
#   port=9092
#   log.dirs=/tmp/kafka-logs
#   zookeeper.connect=<zookeeper.ip>:2181;<zookeeper.ip>:2181;
#-------------------------------------------------------------

KAFKA_PORT=9092

ZOOKEEPER_CONFIG="config/zookeeper.properties"
KAFKA_SERVER_CONFIG="config/server.properties"

KAFKA_LOGDIR="log/kafka"
ZOOKEEPER_DATADIR="data/zookeeper"

ETCHOSTS_REQUIRED=""

function getUserInput(){
    read -p "KAFKA_RELEASE: " KAFKA_RELEASE
    read -p "KAFKA_RELEASE_PUTDIR: " KAFKA_RELEASE_PUTDIR
    read -p "KAFKA_NODE_NUM: " KAFKA_NODE_NUM
}

function preCheck(){
    # Check KAFKA_RELEASE
    if ! [ -e "$KAFKA_RELEASE" ];then
        echo "$KAFKA_RELEASE NOT exit ! Please check !"
        exit
    fi 

    # Check KAFKA_RELEASE_PUTDIR
    if ! [ -e "$KAFKA_RELEASE_PUTDIR" ];then
        read -p "PATH NOT EXST! mkdir ${KAFKA_RELEASE_PUTDIR} ?(y/n)" y
        if [ "$y" = "y" ];then
            mkdir ${KAFKA_RELEASE_PUTDIR}
        else
            exit
        fi
    fi
}

function overview(){
    echo '
    KAFKA_PORT=9092
    KAFKA_LOGDIR="log/kafka"
    ZOOKEEPER_DATADIR="data/zookeeper"
    KAFKA_RELEASE_PUTDIR="'$KAFKA_RELEASE_PUTDIR'"
    
    ETCHOSTS_REQUIRED:
        "'$ETCHOSTS_REQUIRED'"
    '
}

function genManageScript(){
    kafka_release_node=$1
    
    echo '
    jps
    ' > $kafka_release_node/s.sh
    
    echo '
    `pwd`/bin/zookeeper-server-start.sh -daemon config/zookeeper.properties
    `pwd`/bin/kafka-server-start.sh -daemon config/server.properties
    ' > $kafka_release_node/start.sh
    
    echo '
    `pwd`/bin/kafka-server-stop.sh --daemon config/server.properties
    ' > $kafka_release_node/stop.sh
}

function main(){
    getUserInput
    preCheck
    
    for node_index in `seq 0 $(echo $KAFKA_NODE_NUM-1 | bc -l)`;
    do
        kafka_release_node="${KAFKA_RELEASE}_NODE_${node_index}"
        kafka_release_node="${KAFKA_RELEASE_PUTDIR}/${kafka_release_node}"
        kafka_release_node_list="$kafka_release_node_list\n$kafka_release_node"

        zookeeper_config="${kafka_release_node}/${ZOOKEEPER_CONFIG}"
        kafka_server_config="${kafka_release_node}/${KAFKA_SERVER_CONFIG}"
        
        cp -a $KAFKA_RELEASE $kafka_release_node
        # [CONFIG ZOOKEEPER]
        zookeeper_datadir=$kafka_release_node/$ZOOKEEPER_DATADIR
        [ -e zookeeper_datadir ] || mkdir -p $zookeeper_datadir

        #sed -i 's/dataDir.*\/dataDir='"${zookeeper_datadir}"'/' $ZOOKEEPER_CONFIG
        sed -i 's|dataDir.*|dataDir='"${zookeeper_datadir}"'|' $zookeeper_config    
        # [CONFIG KAFKA NODE SERVER]
        broker_id=$node_index
        kafka_log_dir=$kafka_release_node/$KAFKA_LOGDIR
        [ -e "$kafka_log_dir" ] || mkdir -p $kafka_log_dir
        zookeeper_connect=''
        for i in `seq 0 $(echo $KAFKA_NODE_NUM-1 | bc -l)`;
        do
            if ! [ -n "$zookeeper_connect" ];then
                zookeeper_connect="kafka_node_${i}:2181"
            else
                zookeeper_connect="${zookeeper_connect},kafka_node_${i}:2181"
            fi
        done
        ETCHOSTS_REQUIRED="$ETCHOSTS_REQUIRED  kafka_node_${node_index}"

        sed -i 's|broker.id=.*|broker.id='"${broker_id}"'|' $kafka_server_config
        sed -i 's|log.dirs=.*|log.dirs='"${kafka_log_dir}"'|' $kafka_server_config
        sed -i 's|zookeeper.connect=.*|zookeeper.connect='"${zookeeper_connect}"'|' $kafka_server_config
        echo -e "\nport=$KAFKA_PORT" >>$kafka_server_config
        
        genManageScript "$kafka_release_node"
    done
    
    overview

}


main
#<<<END