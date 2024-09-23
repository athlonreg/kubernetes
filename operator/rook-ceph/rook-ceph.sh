#!/bin/sh
#
#**********************************************************
#@Author: 		    zhanghl
#@Date:			      2023-5-4
#@FileName:		    rook-ceph.sh
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
  namespace="rook-ceph"
  if [ -n "$4" ]; then
    namespace=$4
  fi
  while [ "$(kubectl -n "${namespace}" get "$1" "$2" | awk '{print $2}' | sed -n 2p | awk -F '/' '{print $1}')" != "$3" ]; do
    warn "waiting for $1/$2 started..."
    sleep 10
  done

  info "$1/$2 install finished!"
}

# --- install rook crds and operator ---
crds_operator() {
  if [ -d ${CURDIR}/manifest ]; then
    kubectl create -f ${CURDIR}/manifest/crds.yaml -f ${CURDIR}/manifest/common.yaml -f ${CURDIR}/manifest/operator.yaml
    judge_pod deploy rook-ceph-operator 1
    kubectl create -f ${CURDIR}/manifest/cluster.yaml
  fi
}

# --- install rook ceph cluster ---
ceph_cluster() {
  if [ -f ${CURDIR}/manifest/cluster.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/cluster.yaml
    judge_pod deploy csi-cephfsplugin-provisioner 2
    judge_pod deploy csi-rbdplugin-provisioner 2
    judge_pod deploy rook-ceph-mon-a 1
    judge_pod deploy rook-ceph-mon-b 1
    judge_pod deploy rook-ceph-mon-c 1
    judge_pod deploy rook-ceph-mgr-a 1
    judge_pod deploy rook-ceph-mgr-b 1
    judge_pod deploy rook-ceph-osd-0 1
    judge_pod deploy rook-ceph-osd-1 1
    judge_pod deploy rook-ceph-osd-2 1
  fi
}

# --- install rook ceph cluster toolbox and dashboards---
toolbox_dashboards() {
  info "install toolbox..."
  if [ -f ${CURDIR}/manifest/toolbox.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/toolbox.yaml
    judge_pod deploy rook-ceph-tools 1
  fi

  info "install dashboard..."
  if [ -f ${CURDIR}/manifest/dashboard-nodeport.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/dashboard-nodeport.yaml
  fi

  info "install ceph filesystem storage class..."
  if [ -f ${CURDIR}/manifest/cephfs-sc.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/cephfs-sc.yaml
  fi

  info "install ceph block storage class..."
  if [ -f ${CURDIR}/manifest/ceph-block-sc.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/ceph-block-sc.yaml
  fi
}

# --- print cluster install info ---
print_info() {
  info "Ceph Cluster install successfully, status is here"
  kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

  info "dashboard access address"
  kubectl -n rook-ceph get service rook-ceph-mgr-dashboard-external-https

  info "dashboard access user/password"
  info "user: admin"
  info "password: " $(kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo)
}

# --- main ---
main() {
  crds_operator
  ceph_cluster
  toolbox_dashboards

  print_info
}

# --- entry ---
main "$@"
exit 0
