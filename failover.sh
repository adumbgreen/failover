#!/bin/bash
### BEGIN INIT INFO
# Provides:          failover
# Required-Start:    $all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Montior WAN for failover capabilities.
### END INIT INFO

EXIT=0

init_check_routes() {
  echo "Initializing routes for check IPs."

  ip route add default via "$BACKUP_GW" table "$BACKUP_IF"
  ip rule add from "$BACKUP_IP" lookup "$BACKUP_IF"
}

exec_hook() {
  if [ -e $HOOK_SCRIPT ]; then
    if [ ! -x $HOOK_SCRIPT ]; then
      chmod +x $HOOK_SCRIPT
    fi
    TIMESTAMP=$(date)
    $HOOK_SCRIPT $1 $TIMESTAMP
  fi
}

start() {
  if [ -e /etc/failover/failover.conf ]; then
    . /etc/failover/failover.conf
  fi

  # Set defaults if not provided by config file
  CHECK_DELAY=${CHECK_DELAY:-5}
  CHECK_IP=${CHECK_IP:-1.1.1.1}
  PING_TIMEOUT=${PING_TIMEOUT:-3}
  PRIMARY_IF=${PRIMARY_IF:-enp0s25}
  PRIMARY_GW=${PRIMARY_GW:-192.168.2.1}
  BACKUP_IF=${BACKUP_IF:-enx00a0c6000000}
  BACKUP_IP=${BACKUP_IP:-192.168.1.4}
  BACKUP_GW=${BACKUP_GW:-192.168.1.1}
  HOOK_SCRIPT=${HOOK_SCRIPT:-"/etc/failover/failover.hook.sh"}

  # Hook script executed as:
  # > failover.hook.sh event_type time_stamp
  # where event_type is one of:
  # - "ok" => both primary and backup link connected
  # - "backup_down" => backup link is down, primary is up
  # - "primary_down" => initial failover event - primary down
  # - "primary_down_still" => subsequent notification of failover state
  # - "primary_returned" => primary link returned, reverting to primary

  if [ $PRIMARY_IF = "$(ip route get "$CHECK_IP" | sed -rn 's/^.*dev ([^ ]*).*$/\1/p')" ]; then
    USING_PRIMARY_IF=1
  else
    USING_PRIMARY_IF=0
  fi

  grep -q "$PRIMARY_IF" "/etc/iproute2/rt_tables"

  if [ $? -ne 0 ]; then
    echo "12 $PRIMARY_IF" >> /etc/iproute2/rt_tables
    echo "Added $PRIMARY_IF entry to rt_tables".
  fi

  grep -q "$BACKUP_IF" "/etc/iproute2/rt_tables"

  if [ $? -ne 0 ]; then
    echo "13 $BACKUP_IF" >> /etc/iproute2/rt_tables
    echo "Added $BACKUP_IF entry to rt_tables."
  fi

  # Cycle healthcheck continuously with specified delay
  while [ $EXIT -ne 1 ]
  do
    sleep "$CHECK_DELAY"
    init_check_routes
    if [ $USING_PRIMARY_IF -eq 1 ]; then # If we are using the primary interface
      echo
      echo "Currently using primary interface. Pinging..."
      if ping -W "$PING_TIMEOUT" -c 1 "$CHECK_IP" &>/dev/null # and the ping succeeds
      then
        echo "Primary link is up. Testing backup..."
        if ping -W "$PING_TIMEOUT" -c 1 -I "$BACKUP_IF" "$CHECK_IP"  &>/dev/null
        then
          exec_hook "ok"
          echo "Backup link also ok."
        else
          exec_hook "backup_down" 
          echo "Backup link is down."
        fi
      else # switch to the backup interface.
        echo "Ping failed. Switching to backup interface."
        ip route replace default via "$BACKUP_GW" dev "$BACKUP_IF"
        USING_PRIMARY_IF=0

        exec_hook "primary_down" # execute hooks after link switched to avoid interference
      fi
    else # if we're using the backup interface
      echo
      echo "Currently using backup interface. Pinging primary check IP..."
      if ping -W "$PING_TIMEOUT" -c 1 "$CHECK_IP" &>/dev/null # but primary ping succeeds
      then
        echo "Primary link returned. Switching back."
        ip route replace default via "$PRIMARY_GW" dev "$PRIMARY_IF"
        USING_PRIMARY_IF=1

        exec_hook "primary_returned" # execute hooks after link switched to avoid interference
      else
        exec_hook "primary_down_still"
        echo "Primary link still down. Remaining on backup."
      fi
    fi
  done &
}

case "$1" in
  start)
    start > /dev/null 2>&1 &
  ;;

  stop)
    EXIT=1
    exit 0
esac
