#!/bin/bash

if [ -e /etc/failover.conf ]; then
  . /etc/failover.conf
fi

# Set defaults if not provided by config file
CHECK_DELAY=${CHECK_DELAY:-5}
CHECK_IP=${CHECK_IP:-8.8.8.8}
CHECK_IP_BACKUP=${CHECK_IP_BACKUP:-8.8.4.4}
PING_TIMEOUT=3
PRIMARY_IF=${PRIMARY_IF:-enp0s25}
PRIMARY_GW=${PRIMARY_GW:-192.168.2.1}
BACKUP_IF=${BACKUP_IF:-enx00a0c6000000}
BACKUP_GW=${BACKUP_GW:-192.168.1.1}

# Compare arg with current default gateway interface for route to healthcheck IP
gateway_if() {
  [[ "$1" = "$(ip route get "$CHECK_IP" | sed -rn 's/^.*dev ([^ ]*).*$/\1/p')" ]]
}

if gateway_if "$PRIMARY_IF"
then
  USING_PRIMARY_IF=1
else
  USING_PRIMARY_IF=0
fi

init_check_routes() {
  echo "Initializing routes for check IPs."

  # Dedicate CHECK_IP to the PRIMARY_IF
  ip route add "$CHECK_IP" via "$PRIMARY_GW" dev "$PRIMARY_IF" &> /dev/null

  # Dedicate CHECK_IP_BACKUP to the BACKUP_IF
  ip route add "$CHECK_IP_BACKUP" via "$BACKUP_GW" dev "$BACKUP_IF" &> /dev/null
}

# Cycle healthcheck continuously with specified delay
while sleep "$CHECK_DELAY"
do
  init_check_routes
  if [ $USING_PRIMARY_IF -eq 1 ]; then # If we are using the primary interface
    echo
    echo "Currently using primary interface. Pinging..."
    if ping -W "$PING_TIMEOUT" -c 1 "$CHECK_IP" &>/dev/null # and the ping succeeds
    then
      echo "Primary link is up. Testing backup..."
      if ping -W "$PING_TIMEOUT" -c 1 "$CHECK_IP_BACKUP"  &>/dev/null
      then
        echo "Backup link also ok."
      else
        echo "Backup link is down."
      fi
    else # switch to the backup interface.
      echo "Ping failed. Switching to backup interface."
      ip route replace default via "$BACKUP_GW" dev "$BACKUP_IF"
      USING_PRIMARY_IF=0
    fi
  else # if we're using the backup interface
    echo
    echo "Currently using backup interface. Pinging primary check IP..."
    if ping -W "$PING_TIMEOUT" -c 1 "$CHECK_IP" &>/dev/null # but primary ping succeeds
    then
      echo "Primary link returned. Switching back."
      ip route replace default via "$PRIMARY_GW" dev "$PRIMARY_IF"
      USING_PRIMARY_IF=1
    else
      echo "Primary link still down. Remaining on backup."
    fi
  fi
done