#!/bin/sh
#
#**********************************************************
#@Author: 		    zhanghl
#@Date:			      2023-5-4
#@FileName:		    clickhouse.sh
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
  namespace="clickhouse-operator"
  if [ -n "$4" ]; then
    namespace=$4
  fi
  while [ "$(kubectl -n "${namespace}" get "$1" "$2" | awk '{print $2}' | sed -n 2p | awk -F '/' '{print $1}')" != "$3" ]; do
    warn "waiting for $1/$2 started..."
    sleep 10
  done

  info "$1/$2 install finished!"
}

# --- install clickhouse crds and operator ---
crds_operator() {
  # Namespace to install operator into
  OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-clickhouse-operator}"
  # Namespace to install metrics-exporter into
  METRICS_EXPORTER_NAMESPACE="${OPERATOR_NAMESPACE}"
  # Operator's docker image
  OPERATOR_IMAGE="${OPERATOR_IMAGE:-/clickhouse-operator:0.21.2}"
  # Metrics exporter's docker image
  METRICS_EXPORTER_IMAGE="${METRICS_EXPORTER_IMAGE:-/metrics-exporter:0.21.2}"

  # Setup clickhouse-operator into specified namespace
  info "install clickhouse crds and operator..."
  kubectl create namespace clickhouse-operator || warn "namespace clickhouse-operator exists, skip create..."
  if [ -f ${CURDIR}/manifest/clickhouse-operator-install-template.yaml ]; then
    OPERATOR_IMAGE="${OPERATOR_IMAGE}" \
    OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE}" \
    METRICS_EXPORTER_IMAGE="${METRICS_EXPORTER_IMAGE}" \
    METRICS_EXPORTER_NAMESPACE="${METRICS_EXPORTER_NAMESPACE}" \
    envsubst < ${CURDIR}/manifest/clickhouse-operator-install-template.yaml | \
    kubectl apply --namespace="${OPERATOR_NAMESPACE}" -f -
    judge_pod deploy clickhouse-operator 1
  fi
}

# --- install clickhouse cluster ---
clickhouse_cluster() {
  if [ -f ${CURDIR}/manifest/clickhouse-cluster.yaml ]; then
    kubectl create -f ${CURDIR}/manifest/clickhouse-cluster.yaml
  fi
}

# --- main ---
main() {
  crds_operator
  clickhouse_cluster
}

# --- entry ---
main "$@"
exit 0
