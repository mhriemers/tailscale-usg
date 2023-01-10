#!/bin/sh

VERSION="${1:-latest}"

if [ "${VERSION}" = "latest" ]; then
  PACKAGE_URL="https://github.com/mhriemers/tailscale-usg/releases/latest/download/tailscale-usg.tgz"
else
  PACKAGE_URL="https://github.com/mhriemers/tailscale-usg/releases/download/${VERSION}/tailscale-usg.tgz"
fi

WORKDIR="$(mktemp -d || exit 1)"
trap 'rm -rf ${WORKDIR}' EXIT
TAILSCALE_TGZ="${WORKDIR}/tailscale.tgz"

curl -sSLf --ipv4 -o "$TAILSCALE_TGZ" "$PACKAGE_URL"

PACKAGE_ROOT="/config"
tar xzf "$TAILSCALE_TGZ" -C "$PACKAGE_ROOT"

TAILSCALE_ROOT="$PACKAGE_ROOT/tailscale"
"$TAILSCALE_ROOT/manage.sh" install
"$TAILSCALE_ROOT/manage.sh" start