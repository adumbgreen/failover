#!/bin/bash

# failover.sh install

cp ./failover.sh /etc/init.d/failover
chmod +x /etc/init.d/failover
chown root:root /etc/init.d/failover

touch /var/log/failover.log

update-rc.d failover defaults
update-rc.d failover enable

if [ ! -d /etc/failover ]; then
    mkdir /etc/failover
fi

mv ./failover.hook.sh /etc/failover/failover.hook.sh
mv ./failover.conf /etc/failover/failover.conf
chmod +x /etc/failover/failover.hook.sh

echo
echo "failover install complete. Use sudo /etc/init.d/failover start to start the service."
echo "Configure options in /etc/failover/failover.conf and add a hook script in /etc/failover/failover.hook.sh"
echo