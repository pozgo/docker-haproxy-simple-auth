#!/bin/sh

set -u

# User params
HAPROXY_CONFIG=${HAPROXY_CONFIG:="/etc/haproxy/haproxy.cfg"}
HAPROXY_ADDITIONAL_CONFIG=${HAPROXY_ADDITIONAL_CONFIG:=""}
HAPROXY_PORTS=${HAPROXY_PORTS:="80,443"}
HAPROXY_PRE_RESTART_CMD=${HAPROXY_PRE_RESTART_CMD:=""}
HAPROXY_POST_RESTART_CMD=${HAPROXY_POST_RESTART_CMD:=""}
HAPROXY_USER_PARAMS=$@

# Default config parameters. Used only if default config is used.
CONF_DEFAULT=${CONF_DEFAULT:="true"}
CONF_LISTEN_PORT=${CONF_LISTEN_PORT:="80"}
CONF_DEFAULT_SERVER_NAME=${CONF_DEFAULT_SERVER_NAME:="node1"}
CONF_DEFAULT_SERVER_ADDRESS=${CONF_DEFAULT_SERVER_ADDRESS:='web.server'}
CONF_DEFAULT_SERVER_PORT=${CONF_DEFAULT_SERVER_PORT:="80"}
CONF_STATS_USERNAME=${CONF_STATS_USERNAME:="admin"}
CONF_STATS_PASSWORD=${CONF_STATS_PASSWORD:="admin"}
CONF_STATS_URI=${CONF_STATS_URI:="/stats"}
CONF_SIMPLE_AUTH_USERNAME=${CONF_SIMPLE_AUTH_USERNAME:="user"}
CONF_SIMPLE_AUTH_PASSWORD=${CONF_SIMPLE_AUTH_PASSWORD:="password"}

# Internal params
HAPROXY_PID_FILE="/var/run/haproxy.pid"
HAPROXY_CMD="/usr/sbin/haproxy -f ${HAPROXY_CONFIG} ${HAPROXY_USER_PARAMS} -D -p ${HAPROXY_PID_FILE}"
HAPROXY_CHECK_CONFIG_CMD="/usr/sbin/haproxy -f ${HAPROXY_CONFIG} -c"

#######################################
# Echo/log function
# Arguments:
#   String: value to log
#######################################
log() {
  if [[ "$@" ]]; then echo "[`date +'%Y-%m-%d %T'`] $@";
  else echo; fi
}

update_config() {
  sed -i 's|CONF_LISTEN_PORT|'${CONF_LISTEN_PORT}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_DEFAULT_SERVER_NAME|'${CONF_DEFAULT_SERVER_NAME}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_DEFAULT_SERVER_ADDRESS|'${CONF_DEFAULT_SERVER_ADDRESS}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_DEFAULT_SERVER_PORT|'${CONF_DEFAULT_SERVER_PORT}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_STATS_USERNAME|'${CONF_STATS_USERNAME}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_STATS_PASSWORD|'${CONF_STATS_PASSWORD}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_STATS_URI|'${CONF_STATS_URI}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_SIMPLE_AUTH_USERNAME|'${CONF_SIMPLE_AUTH_USERNAME}'|g' ${HAPROXY_CONFIG}
  sed -i 's|CONF_SIMPLE_AUTH_PASSWORD|'${CONF_SIMPLE_AUTH_PASSWORD}'|g' ${HAPROXY_CONFIG}
}

# Add backend to config
if [ ${CONF_DEFAULT} == "true" ]; then
  if [ ${CONF_SIMPLE_AUTH_USERNAME} != "user" ]; then
    cat << EOF >> ${HAPROXY_CONFIG}
backend out
    server CONF_DEFAULT_SERVER_NAME CONF_DEFAULT_SERVER_ADDRESS:CONF_DEFAULT_SERVER_PORT check
    acl allow http_auth(authorized)
    http-request auth realm Authorized if !allow
EOF
    update_config
  else
    cat << EOF >> ${HAPROXY_CONFIG}
backend out
    server CONF_DEFAULT_SERVER_NAME CONF_DEFAULT_SERVER_ADDRESS:CONF_DEFAULT_SERVER_PORT check
EOF
    update_config
  fi
fi

#######################################
# Dump current $HAPROXY_CONFIG
#######################################
print_config() {
  log "Current HAProxy config $HAPROXY_CONFIG:"
  printf '=%.0s' {1..100} && echo
  cat $HAPROXY_CONFIG
  printf '=%.0s' {1..100} && echo
}

# Launch HAProxy.
# In the default attached haproxy.cfg `web.server` host is used for back-end nodes.
# If that host doesn't exist in /etc/hosts, create it and point to localhost,
# so HAProxy can start with the default haproxy.cfg config without throwing errors.
grep -e "web.server" /etc/hosts || echo "127.0.0.1 web.server" >> /etc/hosts

log $HAPROXY_CMD && print_config
$HAPROXY_CHECK_CONFIG_CMD
$HAPROXY_CMD
# Exit immidiately in case of any errors or when we have interactive terminal
if [[ $? != 0 ]] || test -t 0; then exit $?; fi
log "HAProxy started with $HAPROXY_CONFIG config, pid $(cat $HAPROXY_PID_FILE)." && log

# Check if config has changed
# Note: also monitor /etc/hosts where the new back-end hosts might be provided.
while inotifywait -q -e create,delete,modify,attrib /etc/hosts $HAPROXY_CONFIG $HAPROXY_ADDITIONAL_CONFIG; do
  if [ -f $HAPROXY_PID_FILE ]; then
    log "Restarting HAProxy due to config changes..." && print_config
    $HAPROXY_CHECK_CONFIG_CMD
    $ENABLE_SYN_DROP
    sleep 0.2
    log "Executing pre-restart hook..."
    $HAPROXY_PRE_RESTART_CMD
    log "Restarting haproxy..."
    $HAPROXY_CMD -sf $(cat $HAPROXY_PID_FILE)
    log "Executing post-restart hook..."
    $HAPROXY_POST_RESTART_CMD
    $DISABLE_SYN_DROP
    log "HAProxy restarted, pid $(cat $HAPROXY_PID_FILE)." && log
  else
    log "Error: no $HAPROXY_PID_FILE present, HAProxy exited."
    break
  fi
done