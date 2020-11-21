#!/bin/sh

mk_sasl_passwd() {
    cat >/usr/local/etc/postfix/sasl_passwd <<EOF
$RELAY_SERVER $RELAY_USER:$RELAY_PASSWD
EOF
}

mk_sasl_users() {
    _file="/usr/local/etc/postfix/sasl_senders"

    if [ -f $_file ]; then
	rm -Rf $_file
    fi
    
    touch $_file
    for x in $*; do
	echo "$x@$DOMAIN $x" >>$_file
    done
}

mk_keyfile() {
    cp /root/$KEYFILE /usr/local/etc/postfix/mail.relay.$DOMAIN.pem
}

fix_file() {
    _file="$1"
    _tmp=`mktemp fix.XXXXXX`
    cp $_file $_tmp
    _cmd="sed -e 's/%%MY_IP%%/$IP/g' "
    _cmd="$_cmd -e 's/%%MY_DOMAIN%%/$DOMAIN/g'"
    _cmd="$_cmd -e 's/%%MY_FQDN%%/$MY_FQDN/g'"
    _cmd="$_cmd -e 's/%%RELAY_SERVER%%/$RELAY_SERVER/g'"
    cat $_tmp | eval "$_cmd" >$_file
}

get_my_ip() {
    ifconfig -a | \
	grep inet | \
	grep -v inet6 | \
	grep -v 127.0.0.1 | \
	awk '{ print $2}'
}

files_to_be_fixed() {
    echo dkimproxy_out.conf imapd.conf
    echo postfix/generic postfix/master.cf
    echo postfix/main.cf
}

fix_files() {
    MY_IP=`get_my_ip`
    MY_FQDN=`hostname`.$DOMAIN

    for _f in `files_to_be_fixed | xargs echo`; do
	fix_file /usr/local/etc/$_f
    done
}

mk_postfix_dbs()
{
    for _x in generic sasl_passwd sasl_senders; do
	postmap /usr/local/etc/postfix/$_x
    done
}

mk_aliases()
{
    cd /etc/mail && make
}

mk_opiekeys() {
    touch /etc/opiekeys

    chown postfix:postfix /etc/opiekeys
}

mk_imap_dirs() {
    for _d in /var/imap /var/imap/socket /var/imap/sync /var/imap/db /var/spoool/imap; do
	mkdir -p $_d
	chown -Rf cyrus:cyrus $_d
    done
}

mk_imap_user() {
    _user="$1"

    pw user add $_user -m
    echo "cm user/$_user" | cyradm -u cyrus `get_my_ip`
}

mk_imap_users()
{
    for _user in $MAIL_USERS; do
	mk_imap_user
    done
}

[ ! -f /root/postfix.conf ] && \
    echo "No configuration of Postfix found" && \
    exit 1

source /root/postfix.conf

pkg install -y  py37-asciinema fish

mk_sasl_passwd

mk_sasl_users $MAIL_USERS

mk_keyfile

fix_files

mk_postfix_dbs

mk_aliases

mk_opiekeys

mk_imap_dirs

mk_imap_users

sysrc -n sendmail_enable="NONE"

sysrc -n dkimproxy_out_enable="YES"
sysrc -n cyrus-imapd_enable="YES"
sysrc -n saslauthd_enable="YES"
sysrc -n postfix_enable="YES"
sysrc -n sshd_enable="YES"

service sshd start
service dkimproxy_out start
service saslauthd start
service postfix start
service imapd start

