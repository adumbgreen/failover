failover.sh
=====

This script will monitor two WAN devices for link. If link is lost on the primary interface, it will switch to the backup interface. When link returns to the primary interface, it will switch back to the primary interface.

This is accomplished by adding ```ip``` routes and changing them as necessary based on connectivity.

Install using ```sudo bash install.sh``` and configure at ```/etc/failover/failover.conf```.

Configuring the hook script
===
The location for a script to be run by the daemon for each ping is specified
in the configuration file. By default, the script lives at ```/etc/failover/failover.hook.sh```.

The script is executed as ``<script.sh> hook_event timestamp``.

- ``ok`` => both primary and backup link connected
- ``backup_down`` => backup link is down, primary is up
- ``primary_down`` => initial failover event - primary down
- ``primary_down_still`` => subsequent notification of failover state
- ``primary_returned`` => primary link returned, reverting to primary

``timestamp`` is the result of calling ``date``.