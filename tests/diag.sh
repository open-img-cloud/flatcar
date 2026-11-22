#!/usr/bin/env bash
# Boots the image (OPN-style: $IMAGE_FILE, OS_* in the environment) on OpenStack
# and prints first-boot diagnostics: partitions, growth, failed units.
set -uo pipefail
T=oic-diag-${GITHUB_RUN_ID:-local}; W=$(mktemp -d)
O=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR -o BatchMode=yes -i "$W/id")
cleanup() { openstack server delete --wait "$T" 2>/dev/null; openstack image delete "$T" 2>/dev/null; openstack keypair delete "$T" 2>/dev/null; openstack security group delete "$T" 2>/dev/null; }
trap cleanup EXIT
ssh-keygen -q -t ed25519 -N '' -f "$W/id"
openstack keypair create --public-key "$W/id.pub" "$T" >/dev/null
openstack security group create "$T" >/dev/null
openstack security group rule create --proto tcp --dst-port 22 "$T" >/dev/null
openstack image create --disk-format qcow2 --container-format bare --file "$IMAGE_FILE" --property hw_qemu_guest_agent=yes "$T" >/dev/null
openstack server create --flavor a2-ram4-disk20-perf1 --image "$T" --key-name "$T" --security-group "$T" --network ext-net1 --wait "$T" >/dev/null
IP=$(openstack server show -f json -c addresses "$T" | jq -r '[.addresses[][]] | map(select(test("^[0-9.]+$")))[0]')
for _ in $(seq 1 40); do ssh "${O[@]}" "core@$IP" true 2>/dev/null && break; sleep 8; done
ssh "${O[@]}" "core@$IP" 'set -x; lsblk -o NAME,SIZE,TYPE,PARTLABEL,MOUNTPOINT; sudo sgdisk -p /dev/vda 2>/dev/null || sudo fdisk -l /dev/vda; df -h /; systemctl status --no-pager extend-filesystems.service; journalctl -b --no-pager -u extend-filesystems.service; systemctl --failed --no-legend; systemctl cat systemd-networkd-wait-online.service | head -20; networkctl; journalctl -b --no-pager -u systemd-networkd-wait-online | tail -5'
