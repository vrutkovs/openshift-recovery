#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

ASSET_DIR=./assets
SNAPSHOT_FILE="${ASSET_DIR}/backup/etcd/member/snap/db"
ETCD_VERSION=v3.3.10
ETCDCTL="${ASSET_DIR}/bin/etcdctl"
ETCD_DATA_DIR=/var/lib/etcd
CONFIG_FILE_DIR=/etc/kubernetes
MANIFEST_DIR="${CONFIG_FILE_DIR}/manifests"
MANIFEST_STOPPED_DIR="${CONFIG_FILE_DIR}/manifests-stopped"
ETCD_MANIFEST="${MANIFEST_DIR}/etcd-member.yaml"

if [ "$1" != "" ]; then
  SNAPSHOT_FILE="$1"
fi

# TODO fix path this is for testing
source "./bin/recovery-tools"

function run {
  for f in init \
    backup_manifest \
    stop_etcd \
    backup_data_dir \
    remove_data_dir \
    restore_snapshot \
    start_etcd \
      ; do
    echo "${f}"
    "${f}"
  done
}

run
