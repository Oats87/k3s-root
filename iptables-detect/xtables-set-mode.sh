#!/bin/sh

# --- helper functions for logs ---
info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

script_name=xtables-set-mode.sh

# Validate that we are in the correct k3s-root path
validate() 
{
    # The existence of the iptables-set-mode.sh in the path indicates the directory we should be calling from.
    # Don't put this script in your path unless you want this script to overwrite your iptables links.
    if ! which $script_name; then
        fatal "$script_name was not found in PATH"
    fi
}


set_nft()
{
    base_path=$(dirname $(which $script_name))

    for i in iptables iptables-save iptables-restore ip6tables ebtables ebtables-restore ebtables-save arptables arptables-restore arptables-save; do ln -s "$base_path/xtables-nft-multi" "$base_path/$i"; done

    exit
}

set_legacy()
{
    base_path=$(dirname $(which $script_name))

    for i in iptables iptables-save iptables-restore ip6tables ebtables ebtables-restore ebtables-save arptables arptables-restore arptables-save; do ln -s "$base_path/xtables-legacy-multi" "$base_path/$i"; done

    exit
}

usage()
{
    echo "usage: $script_name [[--mode nft|legacy] [--force] | [--help]]"
}

interactive=
force=0

if [ "$1" == "" ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
        -m | --mode )           shift
                                mode=$1
                                ;;
        -f | --force )          force=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

validate

case $mode in
    nft )                   set_nft
                            exit
                            ;;
    legacy )                set_legacy
                            exit
                            ;;
    * )                     usage  
                            exit 1
esac