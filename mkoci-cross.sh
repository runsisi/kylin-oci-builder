#!/bin/bash

set -e
set -a

IMAGE=${IMAGE:=ubuntu-23.04-cross-builder}
TAG=${TAG:=$(date +%Y%m%d)}
REGISTRY=${REGISTRY:=192.168.1.71:5000}

TOOLS_URL=${TOOLS_URL:=http://192.168.1.71/dev-tools}

noPolicy=0
noPush=0

usage() {
    cat <<EOF
buildah unshare sh $(basename $0) [OPTIONS]
OPTIONS:
    -h, --help                  Print this help message.
    -n, --name <name>           Image name (default "$IMAGE").
    -t, --tag <tag>             Image tag (default "$TAG").
    -r, --registry <registry>   Image registry to push (default "$REGISTRY").
    --no-policy                 Do not generate default policy (i.e., "insecureAcceptAnything").
    --no-push                   Do not push image to registry (i.e., local container & image will be kept).
EOF
    exit 1
}

# parse options

if ! options=$(getopt -o 'hn:t:r:' -l 'help,name:,tag:,registry:,no-push' -- "$@"); then
    usage
fi
eval set -- "$options"
unset options

while [ $# -gt 0 ]; do
    case $1 in
    -n | --name)
        IMAGE="$2"
        shift 2
        ;;
    -t | --tag)
        TAG="$2"
        shift 2
        ;;
    -r | --registry)
        REGISTRY="$2"
        shift 2
        ;;
    --no-policy)
        noPolicy=1
        shift
        ;;
    --no-push)
        noPush=1
        shift
        ;;
    -h | --help) usage ;;
    --)
        shift
        break
        ;;
    esac
done

if [ $# -gt 0 ]; then
    echo >&2 "error - excess arguments \"$*\""
    echo >&2
    usage
fi

if [ $(id -u) -eq 0 ]; then
    echo >&2 "error - please run as a non-root user"
    exit 1
fi

if [ -z "$(command -v buildah || :)" ]; then
    echo >&2 "error - buildah not found"
    exit 1
fi

if [ ! -e /etc/containers/policy.json ]; then
    if [ $noPolicy -ne 0 ]; then
        echo >&2 "error - /etc/containers/policy.json does not exist"
        exit 1
    else
        sudo mkdir -p /etc/containers
        sudo tee /etc/containers/policy.json <<EOF
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF
    fi
fi

buildah unshare bash -e mkoci-cross-impl.sh
