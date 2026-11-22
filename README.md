<p align="center">
  <a href="https://openimages.cloud/images/flatcar/">
    <img src="https://openimages.cloud/img/og/flatcar.png" alt="Flatcar Container Linux cloud image for OpenStack and Proxmox" width="720">
  </a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/flatcar/"><img alt="Latest version" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fimages.openimages.cloud%2Fflatcar%2Flatest%2FMANIFEST.json&query=%24.version&label=latest&color=2459c4&cacheSeconds=3600"></a>
  <a href="https://github.com/open-img-cloud/flatcar/actions/workflows/release.yml"><img alt="Release" src="https://github.com/open-img-cloud/flatcar/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://openimages.cloud/verify/"><img alt="Signed with Sigstore cosign" src="https://img.shields.io/badge/signed-Sigstore%20cosign-2459c4"></a>
  <a href="https://openimages.cloud/quality/"><img alt="Boot-tested on OpenStack" src="https://img.shields.io/badge/boot--tested-OpenStack-2459c4"></a>
  <a href="LICENSE"><img alt="License GPL-2.0" src="https://img.shields.io/badge/license-GPL--2.0-555"></a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/flatcar/"><b>Catalog page</b></a> ·
  <a href="https://images.openimages.cloud/flatcar/latest/">Download</a> ·
  <a href="https://openimages.cloud/verify/">Verify</a> ·
  <a href="https://github.com/open-img-cloud/docs">Documentation</a> ·
  <a href="https://github.com/open-img-cloud/flatcar/issues">Report an issue</a>
</p>

Flatcar Container Linux (qcow2) for **OpenStack** and **Proxmox VE**: the official Stable
OpenStack image, **republished unchanged** after checking the Flatcar signing key, then signed
with Sigstore cosign and boot-tested on a real OpenStack like every
[openimages.cloud](https://openimages.cloud) image. Flatcar is a minimal, immutable OS for
containers, configured with Ignition (Butane) rather than cloud-init, which updates itself.

> Community mirror, not an official Flatcar release channel. Flatcar Container Linux is a
> [CNCF](https://www.cncf.io/projects/flatcar-container-linux/) project; official images and
> documentation: [flatcar.org](https://www.flatcar.org/).

## At a glance

| | |
|---|---|
| **Upstream** | `flatcar_production_openstack_image.img` of the [Stable channel](https://www.flatcar.org/releases), byte for byte |
| **Verification** | `DIGESTS.asc` signed by the Flatcar image signing key (primary `F88C FEDE FF29 A5B4 D952 3864 E25D 9AED 0593 B34A`), SHA-512 checked |
| **Default user** | `core`, SSH key only, passwordless `sudo` |
| **Provisioning** | Ignition or Butane in the user data; without user data, the SSH keys and hostname come from the config drive or the metadata service (afterburn) |
| **Firmware** | BIOS (boot-tested) and UEFI (EFI partition included upstream) |
| **Format** | qcow2, x86_64, 12.3 GiB virtual size (flavor disk of 13 GB or more), ROOT grown to the disk at first boot |
| **Version** | Flatcar Stable release, e.g. `4757.2.3` ([all versions](https://images.openimages.cloud/flatcar/versions.json)) |

## Quick start

```sh
M=https://images.openimages.cloud/flatcar/latest/MANIFEST.json
V=$(curl -fsS $M | jq -r .version); F=$(curl -fsS $M | jq -r .filename)
curl -fLO https://images.openimages.cloud/flatcar/$V/$F
```

<details>
<summary><b>OpenStack</b></summary>

```sh
openstack image create --disk-format qcow2 --container-format bare \
  --property hw_qemu_guest_agent=yes --property os_admin_user=core \
  --file "$F" "Flatcar $V"

# SSH key only: no user data needed
openstack server create --image "Flatcar $V" --flavor <disk >= 13 GB> \
  --network <net> --key-name <key> flatcar

# Or configure it with Butane, transpiled to Ignition
butane --pretty --strict config.bu > config.ign
openstack server create ... --user-data config.ign flatcar
```

</details>

<details>
<summary><b>Proxmox VE</b></summary>

Import the disk as for any image (commands on the
[catalog page](https://openimages.cloud/images/flatcar/)), then use a cloud-init drive in the
**configdrive2** format, which this image reads:

```sh
qm set <vmid> --ide2 local-lvm:cloudinit --citype configdrive2 \
  --sshkeys ~/.ssh/id_ed25519.pub --agent 1
```

The SSH key and the VM name apply. For an Ignition configuration, put it in a snippet and pass
it as the user data (`--cicustom user=local:snippets/config.ign`). Flatcar also publishes a
dedicated `proxmoxve` image (NoCloud drive) on [flatcar.org](https://www.flatcar.org/docs/latest/deploy/virt-options/proxmoxve/).

</details>

<details>
<summary><b>Verify the signature</b></summary>

```sh
curl -fLO https://images.openimages.cloud/flatcar/$V/$F.bundle
cosign verify-blob "$F" --bundle "$F.bundle" \
  --certificate-identity-regexp '^https://github.com/open-img-cloud/\.github/\.github/workflows/build-(libguestfs|dib|nix-flake|freebsd)-image\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

The file is also identical to the upstream one: its SHA-512 is in Flatcar's signed
`flatcar_production_openstack_image.img.DIGESTS.asc` for the same version.

</details>

## Good to know

- **Automatic updates and reboots.** Flatcar downloads new releases by itself and **reboots
  about 5 minutes later** by default. The published version is only the starting point:
  instances move on. To control it, set a reboot strategy or a maintenance window in your
  Butane configuration, or disable updates:
  ```yaml
  variant: flatcar
  version: 1.0.0
  storage:
    files:
      - path: /etc/flatcar/update.conf
        overwrite: true
        contents:
          inline: |
            REBOOT_STRATEGY=off
  ```
  See [update strategies](https://www.flatcar.org/docs/latest/updates-releases/releases/update-strategies/).
- **Console auto-login.** The OpenStack image logs `core` in automatically on the VNC and
  serial consoles (upstream choice for clouds). Restrict who can open the console in your
  cloud.
- **Ignition runs once**, at the first boot: a new configuration needs a new instance.
- **Guest agent.** `qemu-guest-agent` is part of Flatcar and starts by itself when the
  channel exists (`hw_qemu_guest_agent=yes` on OpenStack, `--agent 1` on Proxmox).

## What this image contains

Exactly the upstream file. [`release.yml`](.github/workflows/release.yml) fetches it with its
`DIGESTS.asc`, verifies the OpenPGP signature against the pinned primary key of the Flatcar
image signing key (the subkeys rotate yearly), checks the SHA-512, and fails unless the
published file keeps the upstream hash.

Every release must pass the [runtime contract](https://openimages.cloud/quality/) on OpenStack,
adapted to Ignition: SSH as `core` with the injected key, systemd first boot finished, DNS,
hostname, ROOT grown to the disk, passwordless `sudo`, guest agent, IPv6 address and egress.

## How releases happen

1. Every day at 07:44 UTC a watcher reads the Stable channel version and opens a pull request
   that bumps [`VERSION`](VERSION) once the signed digests of the new release are published.
2. Merging it is all it takes: the release is tagged, then the image is verified, signed,
   boot-tested and published, and `latest/` and the
   [catalog](https://openimages.cloud/images/) move to it.

## License

The tooling in this repository is under [GPL-2.0](LICENSE). The image keeps the licensing terms
of Flatcar Container Linux and of the packages it contains
([licenses](https://www.flatcar.org/docs/latest/), per-release `flatcar_production_image_licenses.json`).
Flatcar is a trademark of the Linux Foundation; this project is not affiliated with it.
