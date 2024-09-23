#!/bin/sh
#
#**********************************************************
#@Author: 		    zhanghl
#@Date:			      2023-6-27
#@FileName:		    minio.sh
#@Copyright (C): 	2021 All rights reserved
#**********************************************************
#
# Shell script to install distribute
#  file system for ismart.
#
set -e
set -o noglob

CURDIR=$(
  cd $(dirname "$0")
  pwd
)

# --- helper functions for logs ---
info() {
  echo -e "\e[1;32m" '[INFO] ' "$@" "\e[0m"
}
load() {
  echo -e "\e[1;36m" '[LOAD] ' "$@" "\e[0m"
}
push() {
  echo -e "\e[1;36m" '[PUSH] ' "$@" "\e[0m"
}
warn() {
  echo -e "\e[1;33m" '[WARN] ' "$@" "\e[0m" >&2
}
fatal() {
  echo -e "\e[1;31m" '[ERROR] ' "$@" "\e[0m" >&2
  exit 1
}

# judge controller is running
judge_pod() {
  namespace="minio-operator"
  if [ -n "$4" ]; then
    namespace=$4
  fi
  while [ "$(kubectl -n "${namespace}" get "$1" "$2" | awk '{print $2}' | sed -n 2p | awk -F '/' '{print $1}')" != "$3" ]; do
    warn "waiting for $1/$2 started..."
    sleep 10
  done

  info "$1/$2 install finished!"
}

# --- install kubernetes minio plugin ---
minio_plugin() {
  info "install kubernetes minio plugin..."
  \cp ${CURDIR}/bin/kubectl-minio /usr/local/bin/kubectl-minio
  if [ -n "$(kubectl minio version)" ] ; then
    info "kubernetes minio plugin install successfully..."
  fi
}

# --- install minio crds and operator ---
crds_operator() {
  info "install minio crds and operator..."
  kubectl minio init \
    --cluster-domain cluster.local \
    --console-image /operator:v5.0.5 \
    --default-kes-image /kes:2023-05-02T22-48-10Z \
    --default-minio-image /minio:RELEASE.2023-06-23T20-26-00Z \
    --image /operator:v5.0.5 \
    --namespace minio-operator \
    --prometheus-name prometheus
  judge_pod deploy console 1
  judge_pod deploy minio-operator 2
}

# --- install minio cluster ---
minio_cluster() {
  REPLICAS=1
  kubectl minio tenant create minio \
    --capacity 300Gi \
    --servers ${REPLICAS} \
    --volumes $((2*REPLICAS)) \
    --disable-tls \
    --image /minio:RELEASE.2023-06-23T20-26-00Z \
    --namespace ismart
  judge_pod statefulset minio-ss-0 ${REPLICAS}
}

# --- main ---
main() {
  minio_plugin
  crds_operator
  minio_cluster
}

# --- entry ---
main "$@"
exit 0
