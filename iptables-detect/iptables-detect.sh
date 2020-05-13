#!/bin/sh

# Copyright 2019 The Kubernetes Authors.
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

# Four step process to inspect for which version of iptables we're operating with.
# 1. Run iptables-nft-save and iptables-legacy-save to inspect for rules. If no rules are found from either binaries, then
# 2. Check /etc/alternatives/iptables on the host to see if there is a symlink pointing towards the iptables binary we are using, if there is, run the binary and grep it's output for version higher than 1.8 and "legacy" to see if we are operating in legacy
# 3. Last chance to detect is to inspect `/proc/modules` to check for `nft` modules being existent, if there are, then operate in `nft` mode, otherwise, operate in legacy.

# Bugs in iptables-nft 1.8.3 may cause it to get stuck in a loop in
# some circumstances, so we have to run the nft check in a timeout. To
# avoid hitting that timeout, we only bother to even check nft if
# legacy iptables was empty / mostly empty.

mode=unknown

rule_check() {
    num_legacy_lines=$( (
        iptables-legacy-save || true
        ip6tables-legacy-save || true
    ) 2>/dev/null | grep '^-' | wc -l)
    if [ "${num_legacy_lines}" -ge 10 ]; then
        mode=legacy
    else
        num_nft_lines=$( (timeout 5 sh -c "iptables-nft-save; ip6tables-nft-save" || true) 2>/dev/null | grep '^-' | wc -l)
        if [ "${num_legacy_lines}" -gt "${num_nft_lines}" ]; then
            mode=legacy
        elif [ "${num_nft_lines}" = 0 ]; then
            mode=unknown
        else
            mode=nft
        fi
    fi
}

alternatives_check() {
    readlink /etc/alternatives/iptables >/dev/null

    if [ $? = 0 ]; then
        /etc/alternatives/iptables --version | egrep -v "v1.[0-7]." | egrep "legacy"
        if [ $? = 0 ]; then
            mode=legacy
        fi
        /etc/alternatives/iptables --version | egrep -v "v1.[0-7]." | egrep "nf_tables"
        if [ $? = 0 ]; then
            mode=nft
        fi
    fi
}

proc_modules_check() {
    num_nft_modules_lines=$(cat /proc/modules | grep "nf_tables" | wc -l)
    if [ "${num_nft_modules_lines}" -ge 1 ]; then
        mode=nft
    else
        mode=legacy
    # fall back to legacy in the event we do not find nf_tables modules in /proc/modules
    fi
}

if [ ! -z "$IPTABLES_MODE" ]; then
    mode=${IPTABLES_MODE}
else
    rule_check
    if [ ${mode} == "unknown" ]; then
        alternatives_check
        if [ ${mode} == "unknown" ]; then
            proc_modules_check
        fi
    fi
fi

xtables-set-mode.sh -m ${mode} >/dev/null

exec "$0" "$@"
