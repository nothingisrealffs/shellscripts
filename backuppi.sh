#!/bin/bash
job1 = "sudo dd if=/dev/mmcblk0p1 of=/mnt/downloads/1.img bs=4M"
job2 = "sudo dd if=/dev/sda of=/mnt/downloads/2.img bs=4M"
array = (job1 job2)
compress_file() {
    local file="$1"
    sudo gzip "$file"
}
place(){
    local file = $(echo "$1" | awk -F 'of=' '{print $2}' | awk '{print $1}')
}
jobs(){
    local job = "$1"
    local known = $(place "$job")
    eval $job &
    pid=$!
    wait $pid
    compress_file "known"
pids=()
for job in "${array[@]}"; do
    jobs "${!job}" &
    pids +=($!)
done
for pid in "${pids[@]}"; do
    wait $pid
done

