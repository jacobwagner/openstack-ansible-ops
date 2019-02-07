Install Designate with BIND9 DNS front end
##################
:tags: openstack, ansible, designate

About this repository
---------------------
This set of playbooks will deploy Designate ontop of a running Openstack Ansible
installation. It will then configure the infra hosts as BIND DNS servers to be used
with Designate.

**These playbooks require Ansible 2.3+.**

Deployment Process
------------------

Clone the repo

.. code-block:: bash

    cd /opt
    git clone https://github.com/openstack/openstack-ansible-ops

Run deploy.sh
.. code-block:: bash
    cd /opt/openstack-ansible-ops/designate-bind/scripts
    ./deploy.sh


## TODO:

* Currently we are using the infra hosts for everything, we may want to actually install the BIND DNS servers somewhere else??
* This is a WIP: it needs to be tested!!
* Do I need seperate networks via container-extra-networks???
