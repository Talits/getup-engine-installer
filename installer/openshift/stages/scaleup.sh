#!/bin/bash

case "$TARGET_RELEASE" in
    v3.9|v3.10)
        ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/openshift-node/scaleup.yml
        ;;
    *)
        ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml
esac
