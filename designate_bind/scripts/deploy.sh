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

## Shell Opts ----------------------------------------------------------------

set -e -u -x
set -o pipefail

export BASE_DIR=${BASE_DIR:-"/opt/openstack-ansible"}
export MY_BASE_DIR=${MY_BASE_DIR:-"/opt/openstack-ansible-ops/designate_bind"}

source ${BASE_DIR}/scripts/functions.sh
source ${MY_BASE_DIR}/scripts/functions.sh

# Perform peliminary configurations for Designate
setup_designate
deploy_container
deploy_bind

# Install Designate
deploy_designate

# Open Ports
setup_firewall
