#!/bin/sh

VER=$(curl -sL https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r ".tag_name" | cut -c 2-)
if ! [ -x "$(command -v tailscale)" ] || [ "$VER" != "$(tailscale version | head -n1)" ]; then
  echo "Downloading latest tailscale version"
  curl "https://pkgs.tailscale.com/stable/tailscale_${VER}_mips64.tgz" | tar xvz -C /tmp
  cp /tmp/tailscale_*/tailscale* /config/
fi

ln -sf /config/tailscale /usr/bin/tailscale
ln -sf /config/tailscaled /usr/sbin/tailscaled

mkdir -p /var/lib/tailscale/
mkdir -p /config/auth/

if [ -f /var/lib/tailscale/tailscaled.state ] && ! [ -L /var/lib/tailscale/tailscaled.state ]; then
  echo "/var/lib/tailscale/tailscaled.state exists and is not a symlink"
  mv /var/lib/tailscale/tailscaled.state /config/auth/tailscaled.state
fi

if [ -f /config/auth/tailscaled.state ]; then
  echo "/config/auth/tailscaled.state exists, linking to /var/lib/tailscale/tailscaled.state"
  ln -sf /config/auth/tailscaled.state /var/lib/tailscale/tailscaled.state
fi

sudo tailscaled > /dev/null 2>&1 &
disown

sudo tailscale up
