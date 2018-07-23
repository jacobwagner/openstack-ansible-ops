#!/bin/bash

#set -x

##########################################################################
# Function : Gather location of openstack-ansible dynamic inventory file #
# Pre Pike Release: Inside top level playbooks/ directory                #
# Post Pike Release: Inside top level inventory/ directory               #
##########################################################################
set_dyn_inv_file()
{
echo 'Setting OSA dynamic inventory file location'
virsh list --all 2>&1 | grep infra1 | grep running > /dev/null
if [ $? == 0 ] ; then
  ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
if [ -d "/opt/rpc-openstack/openstack-ansible" ]; then
  if [ -x "/opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py" ]; then
    DYN_INV_FILE="/opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py"
  elif [ -x "/opt/rpc-openstack/openstack-ansible/inventory/dynamic_inventory.py" ]; then
    DYN_INV_FILE="/opt/rpc-openstack/openstack-ansible/inventory/dynamic_inventory.py"
  else
    echo "Couldn't find dynamic_inventory.py"
    exit 255
  fi
elif [ -d "/opt/openstack-ansible" ]; then
  if [ -x "/opt/openstack-ansible/playbooks/inventory/dynamic_inventory.py" ]; then
    DYN_INV_FILE="/opt/openstack-ansible/playbooks/inventory/dynamic_inventory.py"
  elif [ -x "/opt/openstack-ansible/inventory/dynamic_inventory.py" ]; then
    DYN_INV_FILE="/opt/openstack-ansible/inventory/dynamic_inventory.py"
  else
    echo "Couldn't find dynamic_inventory.py"
    exit 255
  fi
fi
echo $DYN_INV_FILE > /tmp/dynamic_inventory.txt
EOF
fi
}

set_galera_container()
{
echo 'Setting the first galera container variable'
set_dyn_inv_file
virsh list --all 2>&1 | grep infra1 | grep running > /dev/null
if [ $? == 0 ] ; then
  ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
export DYN_INV_FILE=`cat /tmp/dynamic_inventory.txt`
GALERA_CONTAINER=`ansible -i ${DYN_INV_FILE} 'galera_all[0]' --list-hosts | awk '/galera_container/ {$1=$1; print}'`
echo $GALERA_CONTAINER > /tmp/galera_container.txt
EOF
fi
}

##############################################
# Stop galera and rabbitmq on all but infra1
##############################################
echo "Starting galera and rabbit shutdowns"
set_dyn_inv_file
virsh list --all 2>&1 | grep infra1 | grep running > /dev/null
if [ $? == 0 ] ; then
  echo "Shutting down galera and rabbit on all but infra1"
  ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
export DYN_INV_FILE=`cat /tmp/dynamic_inventory.txt`
ansible -i ${DYN_INVENTORY_FILE} 'galera_all:!galera_all[0]' -m service -a 'name=mysql state=stopped'
ansible -i ${DYN_INVENTORY_FILE} 'rabbitmq_all:!rabbitmq_all[0]' -m service -a 'name=rabbitmq-server state=stopped'
EOF

  # Sleep a few
  sleep 10
fi

########################
# Shutdown all nodes
########################
echo "Starting node shutdowns"
WAITSHUT=0
for CURNODE in $(virsh list --all | awk '/running/{print $2}') ; do
  echo "virsh shutdown ${CURNODE}"
  virsh shutdown ${CURNODE} > /dev/null 2>&1
  WAITSHUT=1
done

# Wait for infra and cinder nodes as they take a while
if [ $WAITSHUT == 1 ] ; then
  sleep 300
fi

# Force stop any that are stuck
WAITDEST=0
for CURNODE in $(virsh list --all | awk '/running/{print $2}') ; do
  echo "virsh destroy ${CURNODE}"
  virsh destroy ${CURNODE} > /dev/null 2>&1
  WAITDEST=1
done

if [ $WAITDEST == 1 ] ; then
  sleep 20
fi

##############################
# Revert all nodes snapshots
##############################
echo "Starting vm snapshot merging"
for CURNODE in $(virsh list --all | awk '/shut off/{print $2}') ; do

  if [ -e "/dev/vg01/${CURNODE}_snap" ] ; then

    echo "lvconvert --merge /dev/vg01/${CURNODE}_snap"
    lvconvert --merge /dev/vg01/${CURNODE}_snap
    if [ $? != 0 ] ; then
        echo "lvconvert failed.  Please investigate"
        exit 255
    fi
    sleep 5
  fi
done

###########################################################
# Bring up infra1 and make sure galera is up.
###########################################################

echo "Starting infra1 and checking clusters if needed"
virsh list --all | grep infra1 | grep 'shut off' > /dev/null 2>&1
if [ $? == 0 ] ; then

    echo "Starting infra1"
    virsh start infra1

    echo "Sleeping 900 after infra1 startup"
    sleep 900
fi

echo "Bringing up mysql galera cluster on infra1"
set_dyn_inv_file
set_galera_container
ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
export DYN_INV_FILE=`cat /tmp/dynamic_inventory.txt`
export GALERA_CONTAINER=`cat /tmp/galera_container.txt`
ansible -i ${DYN_INVENTORY_FILE} 'galera_all[0]' -m shell -a 'ps -p $(cat /var/lib/mysql/${GALERA_CONTAINER}.pid) > /dev/null 2>&1; if [ $? != 0 ] ; then /etc/init.d/mysql start --wsrep-new-cluster; fi' > /dev/null 2>&1
EOF

##########################
# Bring up other servers
##########################
for CURNODE in $(virsh list --all | awk '/shut off/{print $2}') ; do
  virsh start $CURNODE
done

# Give quite a bit of time for the clusters to join
echo "Sleeping 900 after startup of other infra nodes"
sleep 900

echo "Restart mysql on infra1 to utilize the systemd utilities"
set_dyn_inv_file
ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
export DYN_INV_FILE=`cat /tmp/dynamic_inventory.txt`
export GALERA_CONTAINER=`cat /tmp/galera_container.txt`
ansible -i ${DYN_INVENTORY_FILE} 'galera_all[0]' -m shell -a 'ps -p $(cat /var/lib/mysql/${GALERA_CONTAINER}.pid) > /dev/null 2>&1; if [ $? == 0 ] ; then kill -SIGQUIT $(cat /var/lib/mysql/${GALERA_CONTAINER}.pid); fi' > /dev/null 2>&1
ansible -i ${DYN_INVENTORY_FILE} 'galera_all[0]' -m service -a 'name=mysql state=started'
EOF

echo "Snapshots Complete"
