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
    _cmd="sed -e 's/%%MY_IP%%/$MY_IP/g' "
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

    chown cyrus:cyrus /etc/opiekeys
}

mk_imap_dirs() {
    for _d in /var/imap /var/imap/socket /var/imap/sync /var/imap/db /var/spool/imap; do
	mkdir -p $_d
	chown -Rf cyrus:cyrus $_d
    done
}

mk_imap_users()
{
    echo imap users $MAIL_USERS
    if [ ! -f /root/chpasswd ]; then
	echo no chpasswd tool found
	exit 1
    fi

    if [ ! -f /root/addmailuser ]; then
	echo no add mail user tool  found
    fi

    chmod +x /root/chpasswd
    chmod +x /root/addmailuser

    /root/chpasswd cyrus "$cyrus_PASSWD"
    
    for _user in `echo $MAIL_USERS`; do
	pw user add $_user -m
	_z1=`echo $_user PASSWD | sed 's/ /_/g'`
        _z2="echo \$$_z1"
	_passwd=`eval $_z2`
	/root/chpasswd $_user $_passwd
    done
    
    /root/addmailuser "$cyrus_PASSWD" $MAIL_USERS
}

[ ! -f /root/postfix.conf ] && \
    echo "No configuration of Postfix found" && \
    exit 1

. /root/postfix.conf

if [ -z "$DEFAULT_PASSWD" ]; then
    DEFAULT_PASSWD="aaa123"
fi

if [ -z "$CYRUS_PASSWD" ]; then
    CYRUS_APSSWD="aaa123"
fi

# pkg install -y  py37-asciinema fish

mk_sasl_passwd

mk_sasl_users $MAIL_USERS

mk_keyfile

fix_files

mk_postfix_dbs

mk_aliases

mk_opiekeys

mk_imap_dirs

sysrc  sendmail_enable="NONE"

sysrc  dkimproxy_out_enable="YES"
sysrc  cyrus_imapd_enable="YES"
sysrc  saslauthd_enable="YES"
sysrc  postfix_enable="YES"
sysrc  sshd_enable="YES"

service sshd start
service dkimproxy_out start
service saslauthd start
service postfix start
service imapd start

mk_imap_users
