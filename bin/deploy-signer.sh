#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

ASSET_DIR=./assets

init() {
  ASSET_BIN=${ASSET_DIR}/bin
  if [ ! -d "$ASSET_BIN" ]; then
    echo "Creating asset directory ${ASSET_DIR}"
    for dir in {bin,tmp,shared,backup,templates}; do
      if [ ! -e ${ASSET_DIR}/${dir} ]; then
        /usr/bin/mkdir -p ${ASSET_DIR}/${dir}
      else
        echo "${ASSET_DIR}/${dir} exists"
      fi
    done
  fi
}


download_template() {
  curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/master/manifests/kube-etcd-cert-signer.yaml.template -o $ASSET_DIR/templates/kube-etcd-cert-signer.yaml.template
}

populate_template() {
  echo "Populating template.."
  MASTER_HOSTNAME=$(hostname)
  TEMPLATE=$ASSET_DIR/templates/kube-etcd-cert-signer.yaml.template

  cp $TEMPLATE $ASSET_DIR/tmp

  FIND='__MASTER_HOSTNAME__'
  REPLACE="${MASTER_HOSTNAME}"
  sed -i "s@${FIND}@${REPLACE}@" $ASSET_DIR/tmp/kube-etcd-cert-signer.yaml.template
}

deploy_pod() {
  echo "Deploying kube-etcd-cert-signer.yaml to /etc/kubernetes/manifests"
  mv $ASSET_DIR/tmp/kube-etcd-cert-signer.yaml.template /etc/kubernetes/manifests-stopped/kube-etcd-cert-signer.yaml
}

init
download_template
populate_template
deploy_pod
