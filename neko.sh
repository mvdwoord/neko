#!/bin/sh

# Version 0.1
#
# Copyright © 2008, 2009, 2010, 2011, 2012 Rubin Simons
#
# This file is part of Neko (formerly known as netconfig).
#
# Neko is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Neko is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Neko. If not, see <http://www.gnu.org/licenses/>.


# checkIpFormat() <ip>: Check ip string format.
checkIpFormat(){
    local IFS=.
    set -- $1
    if [ $# -eq 4 ]; then
        for SEQUENCE do
            case $SEQUENCE in
                ""|*[!0-9]*)
                return 1;
                break
                ;;
                *)
                [ $SEQUENCE -gt 255 ] && return 1
                ;;
            esac
        done
    else
        return 1
    fi
    unset IFS
    echo "$1.$2.$3.$4"
}

# checkHostFormat() <host>: Check host string format and length.
checkHostFormat(){
    if [ `expr length $1` -lt 9 ]; then
        echo "$1" | sed "s/[\~\!\@\#\$\%\^\&\*\(\)\_\+\=\,\.\/\?\;\`\'\:\"\{\}\[\]\\]*//g" \
            | sed "s/\-$//g" \
            | sed "s/localhost//g" \
            | sed -n '/^[a-z][a-z0-9]/p'
    else
        echo "Hostname too long."
    fi;
}

# mask2Cidr(): Calculates the cidr notation from a complete netmask.
mask2Cidr() {
    nbits=0
    local IFS=.
    for dec in $1 ; do
        case $dec in
            255) nbits=`expr $nbits + 8`;;
            254) nbits=`expr $nbits + 7`;;
            252) nbits=`expr $nbits + 6`;;
            248) nbits=`expr $nbits + 5`;;
            240) nbits=`expr $nbits + 4`;;
            224) nbits=`expr $nbits + 3`;;
            192) nbits=`expr $nbits + 2`;;
            128) nbits=`expr $nbits + 1`;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
    unset IFS
}

# cidr2Mask(): Calculates the netmask notation from a cidr number.
cidr2Mask() {
    mask=0.0.0.0
    case $1 in
        32) mask=255.255.255.255;;
        31) mask=255.255.255.254;;
        30) mask=255.255.255.252;;
        29) mask=255.255.255.248;;
        28) mask=255.255.255.240;;
        27) mask=255.255.255.224;;
        26) mask=255.255.255.192;;
        25) mask=255.255.255.128;;
        24) mask=255.255.255.0;;
        23) mask=255.255.254.0;;
        22) mask=255.255.252.0;;
        21) mask=255.255.248.0;;
        20) mask=255.255.240.0;;
        19) mask=255.255.224.0;;
        18) mask=255.255.192.0;;
        17) mask=255.255.128.0;;
        16) mask=255.255.0.0;;
        15) mask=255.254.0.0;;
        14) mask=255.252.0.0;;
        13) mask=255.248.0.0;;
        12) mask=255.240.0.0;;
        11) mask=255.224.0.0;;
        10) mask=255.192.0.0;;
        9) mask=255.128.0.0;;
        8) mask=255.0.0.0;;
        7) mask=254.0.0.0;;
        6) mask=252.0.0.0;;
        5) mask=248.0.0.0;;
        4) mask=240.0.0.0;;
        3) mask=224.0.0.0;;
        2) mask=192.0.0.0;;
        1) mask=128.0.0.0;;
        0);;
        *) echo "Error: $1 is not recognised"; exit 1
    esac
    echo "$mask"
}

# ip2Int(): Convert a dotted-quad ip address to a decimal number.
ip2Int(){
    oct1=`echo "$1"|awk -F\. '{print $1}'`;
    oct2=`echo "$1"|awk -F\. '{print $2}'`;
    oct3=`echo "$1"|awk -F\. '{print $3}'`;
    oct4=`echo "$1"|awk -F\. '{print $4}'`;

    out1=$(($oct1 << 24));
    out2=$(($oct2 << 16));
    out3=$(($oct3 << 8));
    out4=$oct4;

    echo `expr $out1 + $out2 + $out3 + $out4`;
}

# int2Ip(): Convert a decimal number to an ip address.
int2Ip(){
    out1=$(($1 >> 24));
    out2=$(($(($1 >> 16)) & 255))
    out3=$(($(($1 >> 8)) & 255))
    out4=$(($1 & 255))
    echo $out1.$out2.$out3.$out4;
}

# ip2Net(): Get the network address for a given ip address and netmask.
ip2Net(){
    addr="$1"
    mask="$2"
    file="/tmp/ipnet-$addr.py"
    printf %s "\
    #!/usr/bin/env python  
    address=\"$addr\"  
    netmask=\"$mask\"  
    addr=address.split(\".\")  
    mask=netmask.split(\".\")  
    network=str(int(addr[0])&int(mask[0]))+\".\"+str(int(addr[1])&int(mask[1]))+\".\"+str(int(addr[2])&int(mask[2]))+\".\"+str(int(addr[3])&int(mask[3]))
    print network
    " | sed 's/^[[:space:]]*//' > "$file"
    python "$file"
    rm -f "$file"
}

# Specify the toplevel domain.
TOPLEVEL="example.com."

# Specify the authorative DNS networks here. The distinction between frontend 
# and backend is that only frontend networks get to set default route.
DOMAINS_BACKEND="mgt.$TOPLEVEL"
DOMAINS_FRONTEND="use.prd.$TOPLEVEL app.prd.$TOPLEVEL dat.prd.$TOPLEVEL use.acc.$TOPLEVEL app.acc.$TOPLEVEL dat.acc.$TOPLEVEL use.tst.$TOPLEVEL app.tst.$TOPLEVEL dat.tst.$TOPLEVEL dev.$TOPLEVEL inf.$TOPLEVEL tel.$TOPLEVEL p2p.$TOPLEVEL dmz.$TOPLEVEL"
DOMAINS_DMZ="dmz.$TOPLEVEL"
DOMAINS="$DOMAINS_BACKEND $DOMAINS_FRONTEND $DOMAINS_DMZ"


# Specify which networks require a static route over which network.
# Syntax is: <from-domain_backend>^<to-network>
STATIC_ROUTES="mgt.${TOPLEVEL}^10.10.10.0/24"


# Our input is a short hostname (ie. not an fqdn).
HOST=$1


# Check if input is given.
if [ -z $1 ]; then
    echo "Usage: $0 [short_hostname]"
    exit 1
fi;

# Check format and length of given hostname.
if ! checkHostFormat $HOST
then
    echo "Invalid or too long hostname: $HOST"
    exit 1
fi

# Check if user is root.
if [ ! $USER = "root" ]; then
    echo "You need to be root to run this script."
    exit 1
fi;

# Discover our Linux distribution

if [ -f /etc/SuSE-release ]
then
    # We are on SuSE
    DISTRO='SLES'
    SLES_VERSION="`cat /etc/SuSE-release | grep VERSION | cut -d= -f 2 | sed 's/^[[:space:]]*//'`"
    echo "This is a SLES $SLES_VERSION machine"
    # Configuration file location.
    CONFIG_LOCATION="/etc/sysconfig"
    mkdir -p "$CONFIG_LOCATION/network"
elif [ -f /etc/redhat-release ]
then
    # We are on RHEL
    DISTRO='RHEL'
    echo "This is a RedHat machine"
    # Configuration file location.
    CONFIG_LOCATION="/etc/sysconfig"
    mkdir -p "$CONFIG_LOCATION/network-scripts"
elif [ -f /etc/debian_version ]
then
    # We are on Debian or Ubuntu
    echo "This is a Debian or Ubuntu machine"
    echo "    ... which is not suported yet :-("
    DISTRO=''
    echo "Configure the network by hand"
    exit 1
else
    # Distro is unknown
    echo "Cannot discover distro"
    DISTRO=''
    echo "Configure the network by hand"
    exit 1
fi

# Make sure we can resolve names.
NAMESERVERS_ADM="172.26.168.1 172.26.168.2"
NAMESERVERS_INF="172.25.168.1 172.25.168.2"
NAMESERVERS_DMZ="172.27.1.11 172.27.1.12"
NAMESERVERS="$NAMESERVERS_ADM $NAMESERVERS_INF $NAMESERVERS_DMZ"
for NAMESERVER in $NAMESERVERS; do
    EXISTS="`cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2 | grep $NAMESERVER` $EXISTS"
done;
if [ -z "$EXISTS" ]; then
    echo "Unknown nameserver specified in /etc/resolv.conf."
    echo "I found this: `cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2`"
    echo "I expected one of these: $NAMESERVERS"
    exit 1
fi;

# Find a working nameserver, take the fist one
MYNAMESERVER=""
for NAMESERVER in $NAMESERVERS ; do 
    if [ -z "$MYNAMESERVER" ]; then
        if dig @$NAMESERVER > /dev/null; then 
            MYNAMESERVER="$NAMESERVER"
        fi
    fi
done

if  [ -z "$MYNAMESERVER" ]
then
    echo "Can not find an working nameserver!"
    exit 1
fi;

echo "Using nameserver $MYNAMESERVER"


# Remove previous state files.
rm -f /tmp/arping.out*
rm -f /tmp/hosts.out*
rm -f /tmp/resolv.out*

# Create a default /etc/hosts with only localhost entries.
if [ ! -e /etc/hosts.orig ]; then
    cp /etc/hosts /etc/hosts.orig
fi;
echo "# /etc/hosts"                               > /etc/hosts
echo ""                                          >> /etc/hosts
echo "127.0.0.1 localhost.localdomain localhost" >> /etc/hosts
echo "::1 localhost6.localdomain6 localhost6"    >> /etc/hosts
echo ""                                          >> /etc/hosts

# Make sure we don't have any resolv.conf backups.
rm -f /etc/resolv.conf.*

# Make sure we have a backup of resolv.conf.
if [ ! -e /etc/resolv.conf.orig ]; then
    cp /etc/resolv.conf /etc/resolv.conf.orig
fi;


# Clean up before we begin. Should fix this sometime.
rm -f $CONFIG_LOCATION/network/routes
for OLD_FILE in `ls $CONFIG_LOCATION/network/*ifcfg* | grep -v ifcfg-lo`; do
    rm -f $OLD_FILE
done;

# Iterate over all networks.
for DOMAIN in $DOMAINS; do

    # Our wanted IP address is what DNS tells us.
    DETECTED_ADDR=`host "$HOST.$DOMAIN" "$MYNAMESERVER" | grep "has address" | cut -d " " -f 4`

    # If we get an IP back, lets see if it's valid and act accordingly.
    if checkIpFormat "$DETECTED_ADDR" > /dev/null
    then
        DETECTED_DOMAINS="$DETECTED_DOMAINS $DOMAIN"
        echo "Found $HOST.$DOMAIN in DNS:"
        for DEVICE in `ifconfig -a | grep -i "hwaddr" | awk '{print $1}' | grep -v vmnic`; do
            ITSALIVE=`ifconfig $DEVICE | grep -i "inet addr" | awk '{print $2}' | cut -d ":" -f 2`
            # If this device was configured already, use its netmask.
            IFisUP="`checkIpFormat $ITSALIVE`"
            if [ -n "$IFisUP" ]
            then
                DETECTED_MASK=`ifconfig $DEVICE | grep -i "mask" | cut -d ":" -f 4`
                # Else use the first found configured netmask.
            else
                DETECTED_MASK=`ifconfig -a | grep -i bcast | head -n1 | cut -d ":" -f 4`
            fi;

            # Set globals for each detected device iteration.
            DETECTED_CIDR=`mask2Cidr "$DETECTED_MASK"`
            DETECTED_NETS=`ip2Net "$DETECTED_ADDR" "$DETECTED_MASK"`
            NR_BITS=`expr 32 - "$DETECTED_CIDR"`
            NR_MAXHOSTS=`awk "BEGIN{print 2^$NR_BITS}"`
            NR_BEGIN=`ip2Int "$DETECTED_NETS"`
            NR_END=`expr "$NR_BEGIN" + "$NR_MAXHOSTS" - 1`

            if echo "$DOMAINS_DMZ" | grep -w "$DOMAIN" > /dev/null; then
                # The DMZ has default gateway on lowest valid address in network
                NR_GWAY=`expr $NR_BEGIN + 1`
            else
                # The other networks have default gateway on highets valid address in network
                NR_GWAY=`expr $NR_BEGIN + $NR_MAXHOSTS - 2`
            fi
            DETECTED_GWAY=`int2Ip $NR_GWAY`

            # Uncomment to turn on debugging information.
            #echo nr_bits=$NR_BITS, nr_maxhosts=$NR_MAXHOSTS, nr_begin=$NR_BEGIN, nr_end=$NR_END, nr_gway=$NR_GWAY
            #echo addr=$DETECTED_ADDR, mask=$DETECTED_MASK, cidr=$DETECTED_CIDR, nets=$DETECTED_NETS, gway=$DETECTED_GWAY

            # If we have a valid configured device, act accordingly.
            if [ -n "$IFisUP" ]
            then
                echo " * Device $DEVICE is alive ($ITSALIVE), starting probe.."
                arping -f -b -I "$DEVICE" -c1 -w2 "$DETECTED_GWAY" > /tmp/arping.out.$DEVICE.$DOMAIN
            else
                # Else we have a valid device, but which is unconfigured, act accordingly.
                echo " * Device $DEVICE is down. Temporarily activating and starting probe.."
                ifconfig "$DEVICE" "$DETECTED_ADDR" netmask "$DETECTED_MASK"
                arping -f -b -I "$DEVICE" -c10  "$DETECTED_GWAY " > /tmp/arping.out.$DEVICE.$DOMAIN
            fi
            if grep "Unicast reply from $DETECTED_GWAY"  /tmp/arping.out.$DEVICE.$DOMAIN
            then
                # Network was found, write out interface configuration.
                echo "   - Network ($DETECTED_NETS/$DETECTED_CIDR) exists on $DEVICE!"
                echo "   - Setting up $DETECTED_ADDR on $DEVICE."

                HWADDR=`ifconfig "$DEVICE" | grep -i "hwaddr" | awk '{print $5}'`

                case "$DISTRO" in
                SLES)
                    if [ $SLES_VERSION -lt "11" ]; then
                        DEVICE_FILE="$CONFIG_LOCATION/network/ifcfg-eth-id-$HWADDR"
                    else
                        DEVICE_FILE="$CONFIG_LOCATION/network/ifcfg-$DEVICE"
                    fi

                    echo "BOOTPROTO=static"                      > $DEVICE_FILE
                    echo "HWADDR=$HWADDR"                       >> $DEVICE_FILE
                    echo "IPADDR=$DETECTED_ADDR/$DETECTED_CIDR" >> $DEVICE_FILE
                    echo "STARTMODE=auto"                       >> $DEVICE_FILE
                    echo "USERCONTROL=no"                       >> $DEVICE_FILE
                    echo ""                                     >> $DEVICE_FILE
                    ;;
                RHEL)
                    DEVICE_FILE=$CONFIG_LOCATION/network-scripts/ifcfg-$DEVICE
                    echo "DEVICE=$DEVICE"              > $DEVICE_FILE
                    echo "BOOTPROTO=static"           >> $DEVICE_FILE
                    echo "ONBOOT=yes"                 >> $DEVICE_FILE
                    echo "HWADDR=$HWADDR"             >> $DEVICE_FILE
                    echo "IPADDR=$DETECTED_ADDR"      >> $DEVICE_FILE
                    echo "NETMASK=$DETECTED_MASK"     >> $DEVICE_FILE
                    echo ""                           >> $DEVICE_FILE
                    ;;
                *)
                    # Something went wrong
                    exit 1
                    ;;
                esac
               
                # Add a regular host entry.
                echo "   - Creating hosts entry for $DETECTED_ADDR."
                echo "$DETECTED_ADDR $HOST.${DOMAIN%.}" > /tmp/hosts.out.$DEVICE.$DOMAIN

                # Add a regular resolver entry.
                echo "   - Creating resolve entry for $DETECTED_ADDR."
                echo "search ${DOMAIN%.}"          > /tmp/resolv.out.$DEVICE.$DOMAIN
                if echo "$DOMAINS_FRONTEND $DOMAINS_DMZ" | grep -w "$DOMAIN"
                then
                    # Network is a frontend- or dmz-network, write out routing configuration.
                    echo "   - Adding default route through $DETECTED_GWAY."
                    case "$DISTRO" in
                    SLES)
                        echo "default $DETECTED_GWAY - -" >> $CONFIG_LOCATION/network/routes
                        ;;
                    RHEL)
                        echo "NETWORKING=yes"          > $CONFIG_LOCATION/network
                        echo "NETWORKING_IPV6=no"     >> $CONFIG_LOCATION/network
                        echo "HOSTNAME=$HOST"         >> $CONFIG_LOCATION/network
                        echo "GATEWAY=$DETECTED_GWAY" >> $CONFIG_LOCATION/network
                        echo ""                       >> $CONFIG_LOCATION/network
                        ;;
                    esac

                    # Re-add host entry with short-name appended.
                    echo "   - Creating hosts entry for $DETECTED_ADDR."
                    echo "$DETECTED_ADDR $HOST.${DOMAIN%.} $HOST" > /tmp/hosts.out.$DEVICE.$DOMAIN

                fi;

                if echo "$STATIC_ROUTES" | grep -w "$DOMAIN"
                then
                    for ROUTE in "$STATIC_ROUTES"; do
                        SOURCE=`echo $ROUTE | cut -d "^" -f 1`
                        TARGET=`echo $ROUTE | cut -d "^" -f 2`
                        TARGET_ADDR=`echo $TARGET | cut -d "/" -f 1`
                        TARGET_CIDR=`echo $TARGET | cut -d "/" -f 2`
                        TARGET_MASK=`cidr2Mask $TARGET_CIDR`
                        TARGET_NETS=`ip2Net $TARGET_ADDR $TARGET_MASK`
                        if [ `echo "$DOMAIN" | grep "$SOURCE"` ]; then
                            echo "   - Adding static route for $TARGET."
                            case "$DISTRO" in
                            SLES)
                                if [ $SLES_VERSION -lt "11" ]; then
                                    HWADDR=`ifconfig $DEVICE | grep -i "hwaddr" | awk '{print $5}'`
                                    echo "$TARGET_NETS $DETECTED_GWAY $TARGET_MASK eth-id-$HWADDR" >> $CONFIG_LOCATION/network/routes
                                else
                                    echo "$TARGET_NETS $DETECTED_GWAY $TARGET_MASK $DEVICE" >> $CONFIG_LOCATION/network/routes
                                fi
                                ;;
                            RHEL)
                                echo "GATEWAY0=$DETECTED_GWAY"  > $CONFIG_LOCATION/network-scripts/route-$DEVICE
                                echo "ADDRESS0=$TARGET_NETS"   >> $CONFIG_LOCATION/network-scripts/route-$DEVICE
                                echo "NETMASK0=$TARGET_MASK"   >> $CONFIG_LOCATION/network-scripts/route-$DEVICE
                                echo ""                        >> $CONFIG_LOCATION/network-scripts/route-$DEVICE
                                ;;
                            esac
                        fi;
                    done;
                fi;
            else
                # Network was not found on this interface.
                echo "   - Network NOT found on $DEVICE ($DETECTED_NETS/$DETECTED_CIDR)."
            fi;
            if [ -z "$IFisUP" ]
            then
                # Device was down, so bring is down again
                ifconfig $DEVICE 0.0.0.0
                ifconfig $DEVICE down
            fi;
        done;
        echo ""
    fi;
done;

# Setting hostname.
echo $HOST > /etc/HOSTNAME

# Append collected hosts entries and contruct /etc/hosts.
cat /tmp/hosts.out* >> /etc/hosts

# Create the initial search string.
SEARCH_STRING=search

# Remove the last dot from the top level.
TOPLEVEL="`echo "$TOPLEVEL" | sed 's|\.$||g'`"

# The front-end lan should always go first.
for DOMAIN in `cat /tmp/resolv.out* | grep search | cut -d " " -f 2 | sort`; do
    if echo "$DOMAINS_FRONTEND" | grep -w "$DOMAIN" > /dev/null
    then
        for COUNTERPART_DOMAIN in $DOMAIN; do
            CHILD_NAME=`echo $COUNTERPART_DOMAIN | cut -d "." -f 1`
            PARENT_DOMAIN=`echo $COUNTERPART_DOMAIN | sed "s|^$CHILD_NAME\.||"`
            if [ "$PARENT_DOMAIN" != "$TOPLEVEL" ]; then
                for HIT in `echo $DOMAINS_FRONTEND | grep $PARENT_DOMAIN`; do
                    if [ ! -z $HIT ]; then
                        FOUND=`echo $HIT | grep $PARENT_DOMAIN | grep -v $DOMAIN`
                        OUTPUT="${OUTPUT%.} ${FOUND%.}"
                    fi;
                done;
            fi
        done;

        COUNTERPART_DOMAINS=`echo $OUTPUT | tr " " "\n" | sort | tr "\n" " "`
        SEARCH_STRING="$SEARCH_STRING $DOMAIN $COUNTERPART_DOMAINS"
    fi;
done;

# Then any management-class lans.
for DOMAIN in `cat /tmp/resolv.out* | grep search | cut -d " " -f 2 | sort -r `; do
    if echo "$DOMAINS_BACKEND" | grep -w "$DOMAIN"
    then
        SEARCH_STRING="$SEARCH_STRING $DOMAIN"
    fi;
done;

# Write out the final search string and append TOPLEVEL.
echo "# /etc/resolv.conf"                    > /tmp/resolv.conf
echo ""                                     >> /tmp/resolv.conf
echo "$SEARCH_STRING $TOPLEVEL" | tr -s " " >> /tmp/resolv.conf

# Now add the nameserver strings.
for DOMAIN in `cat /tmp/resolv.out* | grep search | cut -d " " -f 2` ; do
    if echo "$DOMAINS_FRONTEND" | grep -w "$DOMAIN" > /dev/null
    then
        # Front-end interface found, use the infra lan interface.
        echo "Front-end interface found, using regular infrastructure for resolving"
        for NAMESERVER in $NAMESERVERS_INF; do
            echo "nameserver $NAMESERVER" >> /tmp/resolv.conf
        done;
    elif echo "$DOMAINS_DMZ" | grep -w "$DOMAIN" > /dev/null
    then
        # DMZ interface found, use the DMZ lan.
        echo "DMZ interface found, using DNZ infrastructure for resolving"
        for NAMESERVER in $NAMESERVERS_DMZ; do
            echo "nameserver $NAMESERVER" >> /tmp/resolv.conf
        done;
    elif echo "$DOMAINS_BACKEND" | grep -w "$DOMAIN" > /dev/null
    then
        # Back-end interface found, use a management lan interface.
        # Note: If a machine has both, frontend and backend interfaces we will receive 4 'nameserver' lines in resolv.conf
        # Only the first 3 will be used, the 4th is ignored
        echo "Back-end interface found, using management lan for resolving"
        for NAMESERVER in $NAMESERVERS_ADM; do
            echo "nameserver $NAMESERVER" >> /tmp/resolv.conf
        done;
    fi
done;
mv /tmp/resolv.conf /etc/resolv.conf

# Remove created state files.
rm -f /tmp/arping.out*
rm -f /tmp/hosts.out*
rm -f /tmp/resolv.out*
echo "Done."
