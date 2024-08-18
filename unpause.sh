#!/bin/sh

case $1 in
  post)
    # Commands to run after resume
    paused_dock=$(docker container ls -f status=paused --format "{{.Names}}")
    paused_vms=$(virsh list --name --state-running)

    for vm in $paused_vms; do
        virsh resume "$vm"
    done
    for dock in $paused_dock; do
        docker container unpause "$dock"
    done
    ;;
esac
