#!/bin/sh

if [ -f /root/iocage_tools/bin/apply_role.sh ]; then
   sh /root/iocage_tools/bin/apply_role.sh jails/mail/postfix setup
fi
