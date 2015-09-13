#!/usr/bin/env bash

user="$(echo $USER)"
if [ "$user" != root ]; then
    echo "You have to be root to run this script."
    echo ""
    exit 1
fi

if [ -d "/etc/neko" ]; then
    cfgdir="/etc/neko"
elif [ -d "/usr/local/etc/neko" ]; then
     cfgdir="/etc/local/etc/neko"
else
    echo "No configuration directory found."
    echo "Please create a directory at either"
    echo "/etc/neko or /usr/local/etc/neko"
    echo "and add a connect/disconnect scripts,"
    echo "route and dns configuration."
    echo ""
    exit 1
fi

config="$1"
if [ ! "$config" ]; then
    echo "Please specify which network you want to configure for."
    echo "The following configurations are known to me:"
    ls "$cfgdir"
    exit 1
fi

if [ ! -d "$cfgdir/$config" ]; then
    echo "Please specify an existing configuration."
    echo "The following configurations are known to me:"
    ls "$cfgdir"
    exit 1
fi

# Platform detection.
uname="$(uname | tr A-Z a-z)"
if [[ "$uname" =~ "linux" ]]; then
    environment="linux"
    platform="linux"
elif [[ "$uname" =~ "bsd" ]]; then
    environment="bsd"
    platform="bsd"
elif [[ "$uname" =~ "darwin" ]]; then
    environment="macosx"
    platform="macosx"
elif [[ "$uname" =~ "uwin" ]]; then
    environment="uwin"
    platform="windows"
elif [[ "$uname" =~ "mingw" ]]; then
    environment="mingw"
    platform="windows"
elif [[ "$uname" =~ "cygwin" ]]; then
    environment="cygwin"
    platform="windows"
else
    environment="unknown"
    platform="unknown"
fi

# Function mask2Cidr(): Calculates the cidr notation from a complete netmask.
mask2Cidr() {
    nbits=0
    IFS=.
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
}

# Function writeRoute(): Writes a route command string.
writeRoute() {
    action="$1"
    destination="$2"
    netmask="$3"
    gateway="$4"

    if [ "$netmask" = "255.255.255.255" ]; then
        type="host";
    else
        type="net";
    fi

    if [ "$action" = "add" ]; then
        case "$platform" in
            windows)
            metric="10"
            echo "route add $destination mask $netmask $gateway metric $metric"
            ;;
            linux)
            if [ "$type" = "net" ]; then
                echo "route add -$type $destination netmask $netmask gw $gateway"
            elif [ "$type" = "host" ]; then
                echo "route add -$type $destination gw $gateway"
            fi
            ;;
            bsd|darwin)
            echo "route add -$type $destination $gateway $netmask"
            ;;
            *)
            echo "# unsupported plaform $platform"
            ;;
        esac
    elif [ "$action" = "del" ]; then
        case "$platform" in
            "windows")
            echo "route delete $destination"
            ;;
            "linux")
            if [ "$type" = "net" ]; then
                echo "route del -$type $destination netmask $netmask"
            elif [ "$type" = "host" ]; then
                echo "route del -$type $destination"
            fi
            ;;
            "bsd"|"darwin")
            echo "route del -$type $destination $gateway $netmask"
            ;;
            *)
            echo "# unsupported plaform $platform"
            ;;
        esac
    else
        echo "unsupported action $action"
        return 1
    fi
}

# Generate add/del route commands.
generateRoutes() {
    for action in add del; do
        out="/tmp/neko-route-$action-$config.out"

        if [ ! -e "$out" ]; then
            echo "#!/usr/bin/env bash" > "$out"
            while read -r line; do
                destination="$(echo $line | awk '{ print $1 }')"
                gateway="$(echo $line | awk '{ print $2 }')"
                netmask="$(echo $line | awk '{ print $3 }')"
                writeRoute $action $destination $netmask $gateway >> "$out"
            done < "$cfgdir/$config/routes.txt"
        fi
    done
}

generateDns() {
    old="/tmp/neko-dns-resolvconf-old-$config.out"
    new="$cfgdir/$config/dns.txt"

    if [ ! -e "$old" ]; then
        cp /etc/resolv.conf "$old"
    fi

    for action in add del; do
        out="/tmp/neko-dns-$action-$config.out"
        if [ ! -e "$out" ]; then
            echo "#!/usr/bin/env bash" > "$out"
            if [ "$action" = "add" ]; then
                echo "cp $new /etc/resolv.conf" >> "$out"
            elif [ "$action" = "del" ]; then
                echo "cp $old /etc/resolv.conf" >> "$out"
            fi
        fi
    done


}

# Main case statement.
case "$2" in
    "on")
    generateRoutes
    generateDns
    bash "$cfgdir/$config/connect.sh"
    bash "/tmp/neko-route-add-$config.out"
    bash "/tmp/neko-dns-add-$config.out"


    ;;
    "off")
    generateRoutes
    generateDns
    bash "$cfgdir/$config/disconnect.sh"
    bash "/tmp/neko-route-del-$config.out"
    bash "/tmp/neko-dns-del-$config.out"
    ;;
    *)
    echo "Usage: $0 <config> on|off"
    echo ""
    exit 1
    ;;
esac

