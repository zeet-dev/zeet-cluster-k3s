#!/bin/bash

while [ ! -e /dev/nvme1n1 ]; do
  sleep 1
done

if [[ $(lsblk -f /dev/nvme1n1 -n -o FSTYPE) != "ext4" ]]; then
  mkfs -t ext4 /dev/nvme1n1
fi

mkdir /data
mount /dev/nvme1n1 /data
echo /dev/nvme1n1 /data ext4 defaults 0 2 >>/etc/fstab

curl -sfL https://get.k3s.io | K3S_TOKEN="${cluster_token}" \
  INSTALL_K3S_VERSION="${k3s_version}" \
  INSTALL_K3S_EXEC="server --https-listen-port=2337 \
      --tls-san=${cluster_dns} \
      --data-dir=/data/k3s \
      --default-local-storage-path=/data/k3s-storage" sh -
