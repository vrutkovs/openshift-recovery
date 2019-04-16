#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

ASSET_DIR=./assets
ETCD_VERSION=v3.3.10
MANIFEST_DIR=/etc/kubernetes/manifests
ETCD_MANIFEST=etcd-member.yaml
ETCDCTL=$ASSET_DIR/bin/etcdctl
ETCD_DATA_DIR=/var/lib/etcd
MANIFEST=/etc/kubernetes/manifests/${ETCD_MANIFEST}

init() {
  ASSET_BIN=${ASSET_DIR}/bin
  if [ ! -d "$ASSET_BIN" ]; then
    echo "Creating asset directory ${ASSET_DIR}"
    for dir in {bin,tmp,shared,backup}
    do
      /usr/bin/mkdir -p ${ASSET_DIR}/${dir}
    done
  fi
  dl_etcdctl $ETCD_VERSION
}

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

backup_manifest() {
  echo "Backing up ${MANIFEST_DIR}/${ETCD_MANIFEST} to ${ASSET_DIR}/backup/"
  cp ${MANIFEST_DIR}/${ETCD_MANIFEST} ${ASSET_DIR}/backup/
}

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
      echo -e "Waiting for $name to stop"
      sleep 10
    done
  done
}

backup_data_dir() {
  cp -rap ${ETCD_DATA_DIR}  $ASSET_DIR/backup/
}

restore_snapshot() {
  IP=$(curl s http://169.254.169.254/latest/meta-data/local-ipv4)
  HOSTNAME=$(dig +noall +answer -x $IP | awk '{ print $5 }' | sed 's/\.$//g')
  ETCD_NAME=etcd-member-${HOSTNAME}

  source /run/etcd/environment

  if [ -e $ASSET_DIR/backup/etcd/member/snap/db ]; then
    echo -e "Backup found removing exising data-dir"
    rm -rf /var/lib/etcd
  fi

  sleep 2

  echo "Restoring etcd.."

  env ETCDCTL_API=3 ${ETCDCTL} snapshot restore $ASSET_DIR/backup/etcd/member/snap/db \
    --name ${ETCD_NAME} \
    --initial-cluster ${ETCD_NAME}=https://${ETCD_IPV4_ADDRESS}:2380 \
    --initial-cluster-token etcd-cluster-1 \
    --skip-hash-check=true \
    --initial-advertise-peer-urls https://${ETCD_IPV4_ADDRESS}:2380 \
    --data-dir /var/lib/etcd/
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
