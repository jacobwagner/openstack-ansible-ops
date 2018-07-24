#!/bin/bash

set -ex

export MNAIO_ANSIBLE_PARAMETERS=${MNAIO_ANSIBLE_PARAMETERS:-""}
export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-/opt/openstack-ansible-ops/multi-node-aio/playbooks/inventory/hosts}"

ansible-playbook -vv \
                 ${MNAIO_ANSIBLE_PARAMETERS} \
                 --force-handlers \
                 ../playbooks/fetch-osa-inventory.yml

AI="$ANSIBLE_INVENTORY,/tmp/osa_inv.sh"
export ANSIBLE_INVENTORY=$AI

ansible-playbook -vv \
                 ${MNAIO_ANSIBLE_PARAMETERS} \
                 -e postfix=${POSTFIX:-"snap"} \
                 --force-handlers \
                 ../playbooks/snapshot-create.yml
