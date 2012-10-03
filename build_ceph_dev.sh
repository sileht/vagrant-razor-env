#!/bin/bash

RUN=$1

set -e 
############
# REAL ENV #
############

PRIVATE_CIDR="10.241.0.0/24"
PUBLIC_CIDR="10.241.0.0/24"

MON_SERVERS="mon-1 mon-2 mon-3"
RGW_SERVERS="rgw-1 rgw-2 rgw-3"

OSDLOW_SERVERS="osdlow-1 osdlow-2 osdlow-3"
OSDMED_SERVERS="osdmed-1 osdmed-2 osdmed-3 osdmed-4 osdmed-5 osdmed-6"
OSDHIGH_SERVERS="osdhigh-1 osdhigh-2 osdhigh-3 osdhigh-4 osdhigh-5 osdhigh-6 osdhigh-7 osdhigh-8 osdhigh-9 osdhigh-10 osdhigh-11 osdhigh-12"

OSD_ALL_SERVERS="$OSDLOW_SERVERS $OSDMED_SERVERS $OSDHIGH_SERVERS"

case $RUN 
    low)
NB_OSD_PER_SERVER=$((12*3)) # LOW 3T
OSD_SERVERS=$OSDLOW_SERVERS
    ;;
    med)
NB_OSD_PER_SERVER=$((12*3)) # MED 3T
OSD_SERVERS=$OSDMED_SERVERS
    ;;
    high)
NB_OSD_PER_SERVER=$((24 + 12)) # HIGH
OSD_SERVERS=$OSDHIGH_SERVERS
    ;;
    vagrant)


###############
# VAGRANT ENV #
###############

PRIVATE_CIDR="192.168.100.0/24"
PUBLIC_CIDR="192.168.100.0/24"
MON_SERVERS="ceph2 ceph3 ceph4"
RADOSGW_SERVERS="ceph5"
OSD_SERVERS="ceph2 ceph3 ceph4"
OSD_ALL_SERVERS="ceph2 ceph3 ceph4"
NB_OSD_PER_SERVER=5

    *)
    echo "usage: $(basename $1) [low|med|high|vagrant]"
    exit 1
    ;;
esac

###############

PRIVATE_NET=${PRIVATE_CIDR%.*}
PUBLIC_NET=${PUBLIC_CIDR%.*}
PRIVATE_NET_LEN=${PRIVATE_CIDR#*/}
PUBLIC_NET_LEN=${PUBLIC_CIDR#*/}
NB_OSD_SERVERS=$(echo $OSD_SERVERS | wc -w)

chr() {
    [ ${1} -lt 256 ] || return 1
    printf \\$(printf '%03o' $1) | tr '[A-Z]' '[a-z]'
}
ord() {
    LC_CTYPE=C printf '%d' "'$1"
}

print_with_sep(){
    list="$1"
    sep="$2"
    if [ -z "$sep" ]; then
        echo "$list"
    else
        echo "$list" | sed "s/  */$sep/g"
    fi
}

get_radosgw_nodes(){
    print_with_sep "$RADOSGW_SERVERS" "$1"
}

get_all_osd_nodes(){
    print_with_sep "$OSD_ALL_SERVERS" "$1"
}
get_osd_nodes(){
    print_with_sep "$OSD_SERVERS" "$1"
}

get_mon_nodes(){
    print_with_sep "$MON_SERVERS" "$1"
}

get_id_from_name(){
    echo $1 | sed -ne 's/.*\([[:digit:]][[:digit:]]*\)$/\1/p'
}
clean_logs(){
    pdsh -u root -R ssh -w "$(get_all_nodes ,)" "rm -rf /var/log/ceph/*"
}
reset_mon_disk(){
    pdsh -u root -R ssh -w "$(get_mon_nodes ,)" 'rm -rf /srv/ceph/mon*'
    pdsh -u root -R ssh -w "$(get_mon_nodes ,)" 'id=$(hostname -s) ; id=${id##*-} ; mkdir -p /srv/ceph/mon$id'
}
reset_osd_disk(){
cat > /tmp/reset-osd.sh <<EOF
id=\$(hostname -s)
id=\${id##*-}
EOF
    for i in $(seq 1 $NB_OSD_PER_SERVER); do 
        letter=$(chr $(($i + 1 + 64)))
cat >> /tmp/reset-osd.sh <<EOF
#if [ -e /dev/sd${letter} ] ; then
#fi
if [ -e /dev/sd${letter}1 ] ; then
mkdir -p /srv/ceph/osd\${id}${i}
umount \$(readlink -f /dev/sd${letter}1) || true
mkfs.xfs -f /dev/sd${letter}1
mount -t xfs -o rw,noexec,nodev,noatime,nodiratime,barrier=0 /dev/sd${letter}1 /srv/ceph/osd\${id}${i}
fi
EOF
    done

    pdcp -u root -R ssh -w "$(get_all_osd_nodes ,)" /tmp/reset-osd.sh /tmp/reset-osd.sh
    pdsh -u root -R ssh -w "$(get_all_osd_nodes ,)" 'chmod a+x /tmp/reset-osd.sh ; /tmp/reset-osd.sh'
}

clear_cache(){
    pdsh -u root -R ssh -w "$(get_osd_nodes ,)" 'echo 3 > /proc/sys/vm/drop_caches'
}

ensure_ceph_stopped(){
    pdsh -u root -R ssh -w "$(get_radosgw_nodes ,)" '/etc/init.d/radosgw stop'
    pdsh -u root -R ssh -w "$(get_radosgw_nodes ,)" 'killall radosgw-admin'

    pdsh -u root -R ssh -w "$(get_all_osd_nodes ,)" 'killall ceph-osd'
    pdsh -u root -R ssh -w "$(get_mon_nodes ,)" 'killall ceph-mon'
    sleep 1
    pdsh -u root -R ssh -w "$(get_all_osd_nodes ,)" 'killall -9 ceph-osd'
    pdsh -u root -R ssh -w "$(get_mon_nodes ,)" 'killall -9 ceph-mon'
}

gen_ceph_conf(){
cat <<EOF
[global]
    auth supported = cephx
    keyring = /etc/ceph/keyring.admin

[osd]
    osd data = /srv/ceph/osd\$id
    osd journal = /srv/ceph/osd\$id/journal

    # for tmpfs purpose
    ;osd journal = /dev/shm/journal-\$id
    ;journal dio = false

    ; osd journal size = {2 * (expected throughput * filestore min sync interval)}
    osd journal size = 512
    keyring = /etc/ceph/keyring.\$name

    ; solve rbd data corruption (sileht: disable by default in 0.48)
    filestore fiemap = false

    public network = $PUBLIC_CIDR
    cluster network = $PRIVATE_CIDR

[mon]
    mon data = /srv/ceph/mon\$id

EOF

for h in $(get_osd_nodes) ; do
    id=$(get_id_from_name $h)
    for i in $(seq 1 $NB_OSD_PER_SERVER); do
cat <<EOF
[osd.$id$i]
    host = $h
EOF
    done
done

for h in $(get_mon_nodes) ; do
    id=$(get_id_from_name $h)
cat <<EOF
[mon.$id]
    host = $h
    mon addr = ${PUBLIC_NET}.15${id}:6789
EOF
done

cat <<EOF
[client.radosgw.gateway]
        host = ##DUMPHOST##
#       keyring = /etc/ceph/keyring.radosgw.gateway
        rgw socket path = /tmp/radosgw.sock
        log file = /var/log/ceph/radosgw.log
EOF

} # end gen_ceph_conf

generate_cluster(){
    # Create cluster
    #osdmaptool --print --createsimple $(($NB_OSD_PER_SERVER * $NB_OSD_SERVERS + 1)) --clobber /tmp/osdmap
	/sbin/mkcephfs -a -c /etc/ceph/ceph.conf -k /etc/ceph/keyring.admin #--osdmap /tmp/osdmap

    # Gen key for ragosgw
    #ceph-authtool --create-keyring /etc/ceph/keyring.radosgw.gateway
    #ceph-authtool /etc/ceph/keyring.radosgw.gateway -n client.radosgw.gateway --gen-key
    #ceph-authtool -n client.radosgw.gateway --cap osd 'allow rwx' --cap mon 'allow r' /etc/ceph/keyring.radosgw.gateway
    #radosgw_key=$(ceph-authtool --print-key /etc/ceph/keyring.radosgw.gateway --name client.radosgw.gateway)
    #ceph-authtool /etc/ceph/keyring.admin --name client.radosgw.gateway --add-key "$radosgw_key"
    #ceph -k /etc/ceph/keyring.admin auth add client.radosgw.gateway -i /etc/ceph/keyring.radosgw.gateway

    # Gen key directly in admin keyring
    ceph-authtool /etc/ceph/keyring.admin -n client.radosgw.gateway --gen-key 
    ceph-authtool /etc/ceph/keyring.admin -n client.radosgw.gateway --cap osd 'allow rwx' --cap mon 'allow r'

    # Extract admin key for testing purpose
    ceph-authtool --print-key /etc/ceph/keyring.admin | tee /root/client.admin 
}

copy_keyring(){
    chmod 644 /etc/ceph/keyring.admin # not really secure
    pdcp -u root -R ssh -w "$(get_osd_nodes ,),$(get_mon_nodes ,),$(get_radosgw_nodes ,)" /etc/ceph/keyring.admin /etc/ceph/keyring.admin
}

setup_additionnal_auth(){
    ceph -k /etc/ceph/keyring.admin auth add client.radosgw.gateway -i /etc/ceph/keyring.admin
}

install_ceph_conf(){
    gen_ceph_conf > /etc/ceph/ceph.conf
    pdcp -u root -R ssh -w "$(get_osd_nodes ,),$(get_mon_nodes ,),$(get_radosgw_nodes ,)" /etc/ceph/ceph.conf /etc/ceph/ceph.conf
    pdsh -u root -R ssh -w "$(get_radosgw_nodes ,)" 'bash -c "sed -i \"s/##DUMPHOST##/$(hostname -s)/g\" /etc/ceph/ceph.conf"'
}

create_radosgw_user(){
    h=$(get_radosgw_nodes)
    h=${h% *}
    ssh root@$h radosgw-admin user create --uid="testuser" --display-name="testuser" --secret="BENCH" --access-key="BENCH"
    ssh root@$h radosgw-admin subuser create --uid="testuser" --subuser="testuser:swift" --secret="BENCH" --access-key="BENCH" --access=full
}

start_ceph(){
    /etc/init.d/ceph -a start
}
start_radosgw(){
    pdsh -u root -R ssh -w "$(get_radosgw_nodes ,)" '/etc/init.d/radosgw start'
    pdsh -u root -R ssh -w "$(get_radosgw_nodes ,)" '/etc/init.d/apache2 restart'
}

_do(){
    echo
    echo "**************** START $@ ******************"
    $@
    echo
    echo "**************** END $@   ******************"
}

# START SCRIPT #
_do ensure_ceph_stopped
_do reset_osd_disk
_do reset_mon_disk
_do clean_logs
_do generate_cluster
_do install_ceph_conf
_do copy_keyring
_do start_ceph
_do setup_additionnal_auth
_do start_radosgw
_do create_radosgw_user
_do clear_cache
# END SCRIPT

exit 0
