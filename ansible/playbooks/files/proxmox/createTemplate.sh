#!/bin/bash
set -e
if ! qm list | awk '{print $1}' | grep -q 9000; then
    wget -q https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
    qm create 9000 --name "ubuntu-2004-cloudinit-template" --memory 2048 --net0 virtio,bridge=vmbr0
    qm importdisk 9000 focal-server-cloudimg-amd64.img local-zfs
    qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
    qm set 9000 --ide2 local-zfs:cloudinit
    qm set 9000 --boot c --bootdisk scsi0
    qm set 9000 --serial0 socket --vga serial0
    qm template 9000
    rm focal-server-cloudimg-amd64.img
    echo "Template created"
else
    echo "Nothing done"
fi