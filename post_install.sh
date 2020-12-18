#!/bin/sh

if [ -f /root/bin/apply_role.sh ]; then
   sh /root/bin/apply_role.sh jails/mail/postfix setup
fi
