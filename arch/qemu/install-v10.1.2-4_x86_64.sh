#!/usr/bin/env bash
# Automates QEMU downloads for version 10.1.2-4 on x86-64 systems

pkgs="qemu-audio-alsa qemu-audio-dbus qemu-audio-jack qemu-audio-oss qemu-audio-pa qemu-audio-pipewire qemu-audio-sdl qemu-audio-spice qemu-base qemu-block-curl qemu-block-dmg qemu-block-nfs qemu-block-ssh qemu-chardev-spice qemu-common qemu-desktop qemu-hw-display-qxl qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-gl qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-gpu-pci-gl qemu-hw-display-virtio-gpu-pci-rutabaga qemu-hw-display-virtio-gpu-rutabaga qemu-hw-display-virtio-vga qemu-hw-display-virtio-vga-gl qemu-hw-display-virtio-vga-rutabaga qemu-hw-uefi-vars qemu-hw-usb-host qemu-hw-usb-redirect qemu-hw-usb-smartcard qemu-img qemu-system-mips qemu-system-x86 qemu-system-x86-firmware qemu-ui-curses qemu-ui-dbus qemu-ui-egl-headless qemu-ui-gtk qemu-ui-opengl qemu-ui-sdl qemu-ui-spice-app qemu-ui-spice-core qemu-user qemu-user-static qemu-vhost-user-gpu"
out_dir="/var/cache/pacman/pkg/"
base_url="https://archive.archlinux.org/packages/q/"
version="10.1.2-4-x86_64"

# If you want .sig files, uncomment the lines below
for pkg in $pkgs; do
  fname="${pkg}-${version}.pkg.tar"
  zst_file="${fname}.zst"
  #sig_file="${zst_file}.sig"

  zst_ofile="${out_dir}${zst_file}"
  #sig_ofile="${out_dir}${sig_file}"

  zst_url="${base_url}${pkg}/${zst_file}"
  #sig_url="${base_url}${pkg}/${sig_file}"
  
  # Do not download these packages again
  if [[ -f "$zst_ofile" ]]; then
    echo "Skipping file: ${zst_ofile}"
    continue
  fi
	
  # Perhaps you misspelled some packages
  if wget --server-response --spider "$zst_url" 2>&1 | grep -q "200 OK" ; then
    sudo wget -O "${zst_ofile}" "$zst_url" 
    #sudo wget -O "${sig_ofile}" "$sig_url"
  else
    echo -e "Not found: ${zst_url}\n\n"
  fi
done

# Then proceed with the installation with:
# sudo pacman -U /var/cache/pacman/pkg/qemu-*-10.1.2-4-x86_64.pkg.tar.zst
