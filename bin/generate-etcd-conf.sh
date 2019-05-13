#!/bin/bash

usage () {
    echo 'Input and output file required: ./script.sh config.in mc.out'
    exit
}

if [ "$1" == "" ] || [ "$2" == "" ]; then
    usage
fi

if ! [ -x "$(command -v urlencode)" ]; then
  echo 'Error: urlencode is not installed and is required.' >&2
  exit 1
fi

IN_RAW=$(cat "$1")
OUT="$2"

gen_config() {
  URL_ENCODED_CONTENT=$(urlencode "$IN_RAW")

  read -r -d '' TEMPLATE << EOF

apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-etcd-conf
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:,${URL_ENCODED_CONTENT}
        filesystem: root
        mode: 0644
        path: /etc/etcd/etcd.conf
EOF
    echo "${TEMPLATE}" > $OUT
    echo "MachineConfig is now available $OUT"
}

gen_config
