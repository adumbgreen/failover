failover.sh
===

This script will monitor two WAN devices for link. If link is lost on the primary interface, it will switch to the backup interface. When link returns to the primary interface, it will switch back to the primary interface.

This is accomplished by adding ```ip``` routes and changing them as necessary based on connectivity.

Options can be configured in ```/etc/failover.conf```.


