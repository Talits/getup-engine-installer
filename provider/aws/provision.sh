#!/bin/sh

set -ex

exec 2>&1
exec >>/var/log/provision.log

date

## Configure NewRelic
if [ -n "${NEWRELIC_LICENSE_KEY}" ]; then
    yum install -y https://yum.newrelic.com/pub/newrelic/el5/x86_64/newrelic-repo-5-3.noarch.rpm
    yum install -y newrelic-sysmond
    nrsysmond-config --set "license_key=${NEWRELIC_LICENSE_KEY}"
    /etc/init.d/newrelic-sysmond start
else
    echo "NewRelic license key not found. Skipping..."
fi
