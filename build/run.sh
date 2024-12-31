#!/bin/bash

set -e
[ "${DEBUG:-false}" == 'true' ] && set -x

if [ ! -d /var/spool/postfix/public ]; then
  mkdir -p /var/spool/postfix/public
fi
if [ ! -d /var/spool/postfix/maildrop ]; then
  mkdir -p /var/spool/postfix/maildrop
fi

HOST=`hostname`

if [ "$HOST"  = "mail_ee" ]; then
  exec cat postfix_crontabs_default | crontab -
fi

# if [ "$HOST"  = "mail_lt" ]; then
#   exec cat postfix_crontab_lt | crontab -
#   postconf -e mydomain="dragonweb.lt"
# fi

# Set timezone if set
if [ ! -z "${TZ}" ]; then
    echo "smtp >> Info: setting timezone to ${TZ}"
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# Allow local customization scripts that run on every startup
if [ -d /etc/entrypoint.d/ ]; then
    /bin/run-parts -v /etc/entrypoint.d
fi

# Fix issue with dpkg-reconfigure and locales not installed "perl: warning: Setting locale failed."
unset LANG

cd /etc/postfix

# Copy default spool from cache
if [ ! -d /var/spool/postfix ]; then
   cp -a /var/spool/postfix.cache/* /var/spool/postfix/
else
  # Fix spool directory permissions
  chgrp -R postdrop /var/spool/postfix/public
  chgrp -R postdrop /var/spool/postfix/maildrop
  postfix set-permissions
fi

# Cleanup stale pids incase we hadn't exited cleanly
rm -f /var/spool/postfix/pid/*

# configure instance (populate etc)
/usr/lib/postfix/configure-instance.sh

# check postfix is happy (also will fix some things)
echo "postfix >> Checking Postfix Configuration"
postfix check

echo "Restart syslog-ng"
/etc/init.d/syslog-ng restart
echo "Start cron"
/etc/init.d/cron start

mkdir -p /etc/opendkim/keys
chown -R opendkim:opendkim /etc/opendkim
chmod 744 /etc/opendkim/keys
rm -f /var/run/opendkim/opendkim.pid
# echo "opendkim >> Start opendkim"
/etc/init.d/opendkim start

# # Get CPU count from machine
# echo "Setting smtp_destination_concurrency_limit"
# postconf -e smtp_destination_concurrency_limit=`grep -c processor /proc/cpuinfo`

echo "postfix >> Start postfix"
# start postfix in foreground
exec /usr/sbin/postfix start-fg

echo "Running command $*"
exec "$@"

