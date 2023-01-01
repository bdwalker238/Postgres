#!/usr/bin/env bash
set -x
myhostname=$(hostname -s)
echo "Hostname ${myhostname}"
sudo /opt/psql/local/bin/repmgr_vip.sh -o delete
sudo systemctl stop postgresql-11
exit 0