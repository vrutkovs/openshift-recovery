#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/unify/bin/etcd-member-recover.sh -o /usr/local/bin/etcd-member-recover.sh
chmod 755 /usr/local/bin/etcd-member-recover.sh

curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/unify/bin/etcd-snapshot-restore.sh -o /usr/local/bin/etcd-snapshot-restore.sh
chmod 755 /usr/local/bin/etcd-snapshot-restore.sh

curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/unify/bin/openshift-recovery-tools -o /usr/local/bin/etcd-snapshot-restore.sh

curl -s https://raw.githubusercontent.com/hexfusion/openshift-recovery/unify/bin/tokenize-signer.sh -o /usr/local/bin//tokenize-signer.sh
chmod 755 /usr/local/bin/tokenize-signer.sh


