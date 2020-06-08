#!/bin/sh

# Copyright 2020 Rancher Labs
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is only meant for use when operating in a non-containerized environment but using non-host binaries (i.e. K3s with k3s-root)

# Four step process to inspect for which version of iptables we're operating with.
# 1. Run iptables-nft-save and iptables-legacy-save to inspect for rules. If no rules are found from either binaries, then
# 2. Check /etc/alternatives/iptables on the host to see if there is a symlink pointing towards the iptables binary we are using, if there is, run the binary and grep it's output for version higher than 1.8 and "legacy" to see if we are operating in legacy
# 3. Last chance is to do a rough check of the operating system, to make an educated guess at which mode we can operate in.

# Bugs in iptables-nft 1.8.3 may cause it to get stuck in a loop in
# some circumstances, so we have to run the nft check in a timeout. To
# avoid hitting that timeout, we only bother to even check nft if
# legacy iptables was empty / mostly empty.

# --- helper functions for logs ---
info() {
    echo '[INFO] ' "$@"
}
warn() {
    echo '[WARN] ' "$@" >&2
}
fatal() {
    echo '[ERROR] ' "$@" >&2
    exit 1
}

script_name=xtables-set-mode.sh

# Validate that we are in the correct k3s-root path
validate() {
    # The existence of the iptables-set-mode.sh in the path indicates the directory we should be calling from.
    # Don't put this script in your path unless you want this script to overwrite your iptables links.
    if [ "${force}" = 0 ]; then
        if ! which $script_name >/dev/null; then
            fatal "$script_name was not found in PATH"
        fi
    fi
}

set_nft() {
    base_path=$(dirname $(which $script_name))

    for i in iptables iptables-save iptables-restore ip6tables; do ln -sf "xtables-nft-multi" "$base_path/$i"; done

    exit
}

set_legacy() {
    base_path=$(dirname $(which $script_name))

    for i in iptables iptables-save iptables-restore ip6tables; do ln -sf "xtables-legacy-multi" "$base_path/$i"; done

    exit
}

usage() {
    echo "usage: $script_name [[--mode nft|legacy] [--force] | [--help]]"
}

force=0

if [ -z "$1" ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
    -m | --mode)
        shift
        mode=$1
        ;;
    -f | --force)
        force=1
        ;;
    -h | --help)
        usage
        exit
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

validate

case $mode in
nft)
    set_nft
    exit
    ;;
legacy)
    set_legacy
    exit
    ;;
*)
    usage
    exit 1
    ;;
esac
