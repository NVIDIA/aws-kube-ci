#! /usr/bin/env bash
set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

source ${CONFIG_DIR}/install_${CONTAINER_RUNTIME%%@*}.sh ${CONTAINER_RUNTIME#*@}
