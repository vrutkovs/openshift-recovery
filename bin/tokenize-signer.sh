#!/usr/bin/env bash

set -e

usage () {
    echo 'Master hostname required: ./script.sh $MASTER_HOSTNAME'
    exit
}

if [ "$1" == "" ]; then
    usage
fi

MASTER_HOSTNAME=$1

ASSET_DIR=./assets

init() {
ASSET_BIN=${ASSET_DIR}/bin
  echo "Creating asset directory ${ASSET_DIR}"
  for dir in {bin,tmp,shared,backup,templates,manifests}; do
    if [ ! -e ${ASSET_DIR}/${dir} ]; then
      /usr/bin/mkdir -p ${ASSET_DIR}/${dir}
    else
      echo "${ASSET_DIR}/${dir} exists"
    fi
  done
}


download_template() {
  curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/master/manifests/kube-etcd-cert-signer.yaml.template -o $ASSET_DIR/templates/kube-etcd-cert-signer.yaml.template
}

populate_template() {
  echo "Populating template.."
  TEMPLATE=$ASSET_DIR/templates/kube-etcd-cert-signer.yaml.template

  cp $TEMPLATE $ASSET_DIR/tmp

  FIND='__MASTER_HOSTNAME__'
  REPLACE="${MASTER_HOSTNAME}"
  sed -i "s@${FIND}@${REPLACE}@" $ASSET_DIR/tmp/kube-etcd-cert-signer.yaml.template
}

copy_manifest() {
  echo "Tokenized template now ready: $ASSET_DIR/manifests/kube-etcd-cert-signer.yaml"
  mv $ASSET_DIR/tmp/kube-etcd-cert-signer.yaml.template $ASSET_DIR/manifests/kube-etcd-cert-signer.yaml
}

init
download_template
populate_template
copy_manifest
