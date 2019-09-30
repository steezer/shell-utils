#!/bin/bash
#docker增强工具集

exec_name=$1
shift

dkcp(){
    if [ ! -d '.dkcp' ];then
        mkdir .dkcp
    fi

    if [ $# -lt 2 ];then
        echo "Please specify two params at least!"
        exit
    fi

    source_path="$1"
    docker cp $source_path .dkcp/
    shift

    for target in "$@"
    do
        docker cp .dkcp/* $target
    done

    rm -rf .dkcp
}

dkupdate(){
    for cname in "$@"
    do
        echo "search ${cname} ..."
        containerId=$(docker ps -a --filter "name=${cname}" | grep -v CONTAINER | awk '{print $1}')
        imageId=$(docker ps -a --filter "name=${cname}" | grep -v CONTAINER | awk '{print $2}')
        docker rm -f $containerId
        docker rmi -f $imageId
        docker pull $imageId
    done
}

case "$exec_name" in
    cp)
        dkcp $@
    ;;
    update)
        dkupdate $@
    ;;
esac
