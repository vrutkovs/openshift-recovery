#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

ASSET_DIR=./assets
SNAPSHOT_FILE=$ASSET_DIR/backup/etcd/member/snap/db
ETCD_VERSION=v3.3.10
ETCD_MANIFEST=etcd-member.yaml
ETCDCTL=$ASSET_DIR/bin/etcdctl
ETCD_DATA_DIR=/var/lib/etcd
MANIFEST_DIR=/etc/kubernetes/manifests
MANIFEST=/etc/kubernetes/manifests/${ETCD_MANIFEST}

if [ "$1" != "" ]; then
  SNAPSHOT_FILE="$1"
fi

init() {
  ASSET_BIN=${ASSET_DIR}/bin
  if [ ! -d "$ASSET_BIN" ]; then
    echo "Creating asset directory ${ASSET_DIR}"
    for dir in {bin,tmp,shared,backup,restore}
    do
      /usr/bin/mkdir -p ${ASSET_DIR}/${dir}
    done
  fi
  dl_etcdctl $ETCD_VERSION
}

# download and test etcdctl from upstream release assets
dl_etcdctl() {
  ETCD_VER=$1
  GOOGLE_URL=https://storage.googleapis.com/etcd
  DOWNLOAD_URL=${GOOGLE_URL}

  echo "Downloading etcdctl binary.."
  curl -s -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o $ASSET_DIR/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
    && tar -xzf $ASSET_DIR/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C $ASSET_DIR/shared --strip-components=1 \
    && mv $ASSET_DIR/shared/etcdctl $ASSET_DIR/bin \
    && rm $ASSET_DIR/shared/etcd \
    && ETCDCTL_API=3 $ASSET_DIR/bin/etcdctl version
}

# backup current etcd-member pod manifest
backup_manifest() {
  echo "Backing up ${MANIFEST_DIR}/${ETCD_MANIFEST} to ${ASSET_DIR}/backup/"
  cp ${MANIFEST_DIR}/${ETCD_MANIFEST} ${ASSET_DIR}/backup/
}

# stop etcd by moving the manifest out of /etcd/kubernetes/manifests
# we wait for all etcd containers to die.
stop_etcd() {
  BACKUP_DIR=/etc/kubernetes/manifests-stopped

  echo "Stopping etcd.."

  if [ ! -d "$BACKUP_DIR" ]; then
    mkdir $BACKUP_DIR
  fi

  if [ -e "$MANIFEST" ]; then
    mv $MANIFEST /etc/kubernetes/manifests-stopped/
  fi

  for name in {etcd-member,etcd-metric}
  do
    while [ "$(crictl pods -name $name | wc -l)" -gt 1  ]; do
      echo "Waiting for $name to stop"
      sleep 10
    done
  done
}

backup_data_dir() {
  if [ -f "$ASSET_DIR/backup/etcd/member/snap/db" ]; then
    echo "etcd data-dir backup found $ASSET_DIR/backup/etcd.."
  else
    echo "Backing up etcd data-dir.."
    cp -rap ${ETCD_DATA_DIR}  $ASSET_DIR/backup/
    if [ ! -f "$SNAPSHOT_FILE" ]; then
      echo "Snapshot file not found: $SNAPSHOT_FILE."
      exit 1
    fi
  fi
}

restore_snapshot() {
  HOSTNAME=$(hostname)
  HOSTDOMAIN=$(hostname -d)
  ETCD_NAME=etcd-member-${HOSTNAME}.${HOSTDOMAIN}

  source /run/etcd/environment

  sleep 2

  echo "Restoring etcd member $ETCD_NAME from snapshot.."

  env ETCDCTL_API=3 ${ETCDCTL} snapshot restore $SNAPSHOT_FILE \
    --name $ETCD_NAME \
    --initial-cluster ${ETCD_NAME}=https://${ETCD_DNS_NAME}:2380 \
    --initial-cluster-token etcd-cluster-1 \
    --skip-hash-check=true \
    --initial-advertise-peer-urls https://${ETCD_IPV4_ADDRESS}:2380 \
    --data-dir $ETCD_DATA_DIR 
  }

start_etcd() {
  echo "Starting etcd.."
  mv /etc/kubernetes/manifests-stopped/${ETCD_MANIFEST} $MANIFEST
}

init
backup_manifest
backup_data_dir
stop_etcd
restore_snapshot
start_etcd
