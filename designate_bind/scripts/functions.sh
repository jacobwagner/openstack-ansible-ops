#!/usr/bin/env bash
# Copyright 2014-2018, Rackspace US, Inc.
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

# openstack-ansible base dir
if [ -d "/opt/openstack-ansible" ]; then
    export OSA_BASE_DIR=/opt/openstack-ansible
else
    export OSA_BASE_DIR=${BASE_DIR}/openstack-ansible
fi

function deploy_bind {
    openstack-ansible ../install-bind.yml
}

function deploy_designate {
    openstack-ansible ../install-os-designate.yml
}

function deploy_container {
    # build container
    cd ${OSA_BASE_DIR}/playbooks
    openstack-ansible lxc-containers-create.yml --limit hosts:designate_all:designate_bind_all
    openstack-ansible openstack-hosts-setup.yml --tags openstack-hosts
}

function setup_designate {
    openstack-ansible ../setup-os-designate.yml
}

function setup_firewall {
    openstack-ansible ../setup-firewall.yml
}