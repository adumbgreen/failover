failover.sh
===

This script will monitor two WAN devices for link. If link is lost on the primary interface, it will switch to the backup interface. When link returns to the primary interface, it will switch back to the primary interface.

This is accomplished by having static routes to two specified check IP addresses, one for each interface, and pinging the appropritate IP based on the current connection.

Options can be configured in ```/etc/failover.conf```.


