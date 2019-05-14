#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

ASSET_DIR=./assets
SNAPSHOT_FILE=$ASSET_DIR/backup/etcd/member/snap/db
ETCD_VERSION=v3.3.10
ETCDCTL=$ASSET_DIR/bin/etcdctl
ETCD_DATA_DIR=/var/lib/etcd
MANIFEST_DIR=/etc/kubernetes/manifests
ETCD_MANIFEST="${MANIFEST_DIR}/etcd-member.yaml"

if [ "$1" != "" ]; then
  SNAPSHOT_FILE="$1"
fi

source "$ASSET_DIR/bin/recovery-tools"

function run {
  for f in init \
    backup_manifest \
    stop_etcd \
    backup_data_dir \
    remove_data_dir \
    restore_snapshot \
    start_etcd \
      ; do
    "${f}"
  done
}

run
