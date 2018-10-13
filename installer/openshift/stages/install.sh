#!/bin/bash

case "$TARGET_RELEASE" in
    v3.9|v3.10)
        ansible-playbook $@ /openshift-ansible/playbooks/prerequisites.yml
        ansible-playbook $@ /openshift-ansible/playbooks/deploy_cluster.yml
        ansible-playbook $@ /openshift-ansible/playbooks/openshift-grafana/config.yml
    ;;
    *)
        ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
esac
