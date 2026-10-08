#!/usr/bin/env bash
# Runs inside the Arch live ISO over SSH. Wipes /dev/sda and installs a
# minimal EFI Arch system. No reboot: Packer shuts the live VM down and
# exports the disk afterwards.
set -euo pipefail

ROOT_USER="${ROOT_USER:-root}"
ROOT_PASSWORD="${ROOT_PASSWORD:?ROOT_PASSWORD must be set}"
LINUX_USER="${LINUX_USER:-linux}"
LINUX_PASSWORD="${LINUX_PASSWORD:-${ARCH_PASSWORD:-changeme}}"

DISK=/dev/sda
EFI_PART=${DISK}1
ROOT_PART=${DISK}2

sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:efi "$DISK"
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:root "$DISK"
partprobe "$DISK"
udevadm settle

mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F -L root "$ROOT_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

pacstrap -K /mnt base linux linux-firmware sudo openssh grub efibootmgr \
    virtualbox-guest-utils-nox
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
echo 'arch-template' > /mnt/etc/hostname
cat > /mnt/etc/hosts <<'EOF'
127.0.0.1 localhost
::1       localhost
127.0.1.1 arch-template
EOF

echo "${ROOT_USER}:${ROOT_PASSWORD}" | arch-chroot /mnt chpasswd
arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$LINUX_USER"
echo "${LINUX_USER}:${LINUX_PASSWORD}" | arch-chroot /mnt chpasswd
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /mnt/etc/sudoers.d/wheel
chmod 440 /mnt/etc/sudoers.d/wheel

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot \
    --bootloader-id=GRUB --removable
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt systemctl enable sshd vboxservice systemd-networkd systemd-resolved
cat > /mnt/etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=en*
[Network]
DHCP=yes
EOF

arch-chroot /mnt truncate -s 0 /etc/machine-id
arch-chroot /mnt rm -f /var/lib/dbus/machine-id
arch-chroot /mnt ln -s /etc/machine-id /var/lib/dbus/machine-id
arch-chroot /mnt pacman -Scc --noconfirm

umount -R /mnt
