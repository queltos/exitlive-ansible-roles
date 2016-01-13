#! /bin/bash
set -e

### 
# Starts the Dart Remote Builder at reboot
###

# This script is copied to VMs local disk (i.e. /home/vagrant) at provision time
# and a crontab is added that runs this script at @reboot. This is due to the fact
# that at @reboot time the network shares aren't available yet

DART="/usr/bin/dart"
REMOTE_BUILDER="/vagrant/vagrant/provisioning/roles/vagrant/files/remote_builder.dart"

. /etc/environment

until "$DART" "$REMOTE_BUILDER"
do
  echo 'remote_builder.dart crashed, respawning..'
  sleep 1
done
