#!/usr/bin/env bash
set -ex

BACKUP_DIR=/backup/lxd
HOSTS=($(lxc list -c n --format csv))

for HOST in "${HOSTS[@]}"
do
    BACKUP_NAME=${HOST}-$(date +"%Y-%m-%d")

    lxc snapshot ${HOST} auto-backup
    lxc publish ${HOST}/auto-backup --alias ${BACKUP_NAME}
    lxc image export ${BACKUP_NAME} ${BACKUP_DIR}/${BACKUP_NAME}
    lxc image delete ${BACKUP_NAME}
    lxc delete ${HOST}/auto-backup
done
find ${BACKUP_DIR}/ -maxdepth 1 -mtime +14 -type d -exec rm -rv {} ;