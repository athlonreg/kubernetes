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
  namespace="postgres-operator"
  if [ -n "$4" ]; then
    namespace=$4
  fi
  while [ "$(kubectl -n "${namespace}" get "$1" "$2" | awk '{print $2}' | sed -n 2p | awk -F '/' '{print $1}')" != "$3" ]; do
    warn "waiting for $1/$2 started..."
    sleep 10
  done

  info "$1/$2 install finished!"
}

# --- install postgres crds and operator ---
crds_operator() {
  if [ -d ${CURDIR}/manifest/operator ]; then
    kubectl create -k ${CURDIR}/manifest/operator/default
    judge_pod deploy pgo 1
    judge_pod deploy pgo-upgrade 1
  fi
}

# --- install postgis cluster ---
postgis_cluster() {
#  # standalone
#  if [ -d ${CURDIR}/manifest/standalone ]; then
#    kubectl create -k ${CURDIR}/manifest/standalone
#  fi

  # cluster
  if [ -d ${CURDIR}/manifest/high-availability ]; then
    kubectl create -k ${CURDIR}/manifest/high-availability
  fi

  while [ "$(kubectl get postgrescluster postgis -o json | jq '.status.conditions[].status' | grep -cv True > /dev/null || echo True)" != "True" ]; do
    echo "waiting postgres cluster running..."
    sleep 10
  done

  # Postgres Operator will generate password randomly, so change the password by patch
  kubectl patch secret postgis-pguser-postgres -p '{"stringData": {"password": "123456" ,"verifier": ""}}'
}

# --- print cluster install info ---
print_info() {
  info "postgres cluster install successfully, cluster information is here"

  info "dbname: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['dbname']}" | base64 --decode && echo)
  info "user: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['user']}" | base64 --decode && echo)
  info "password: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['password']}" | base64 --decode && echo)
  info "host: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['host']}" | base64 --decode && echo)
  info "port: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['port']}" | base64 --decode && echo)
  info "uri: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['uri']}" | base64 --decode && echo)
  info "jdbc-uri: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['jdbc-uri']}" | base64 --decode && echo)
  info "pgbouncer-host: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['pgbouncer-host']}" | base64 --decode && echo)
  info "pgbouncer-port: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['pgbouncer-port']}" | base64 --decode && echo)
  info "pgbouncer-uri: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['pgbouncer-uri']}" | base64 --decode && echo)
  info "pgbouncer-jdbc-uri: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['pgbouncer-jdbc-uri']}" | base64 --decode && echo)
  info "verifier: " $(kubectl get secret postgis-pguser-postgres -o jsonpath="{['data']['verifier']}" | base64 --decode && echo)
}

# --- main ---
main() {
  crds_operator
  postgis_cluster

  print_info
}

# --- entry ---
main "$@"
exit 0
