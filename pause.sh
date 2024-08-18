#!/bin/bash
running_vms=$(virsh list --name --state-running)
running_docker=$(docker container ls)
for vm in $running_vms; do
    virsh suspend "$vm"
done
for dock in $running_docker; do
    docker container pause "$dock"
done
