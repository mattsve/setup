#!/bin/bash
for i in $(lxc list -c n --format csv)
do
     echo "Making backup of ${i} ..."
     lxc export "${i}" "/backups/lxd/${i}-backup.tar.xz" --optimized-storage
done