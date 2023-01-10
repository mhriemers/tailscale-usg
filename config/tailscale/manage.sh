#!/bin/sh

export TAILSCALE_ROOT="${TAILSCALE_ROOT:-/config/tailscale}"
export TAILSCALE="${TAILSCALE_ROOT}/tailscale"
export TAILSCALED="${TAILSCALE_ROOT}/tailscaled"
export TAILSCALED_SOCK="${TAILSCALED_SOCK:-/var/run/tailscale/tailscaled.sock}"

tailscale_install() {
  VERSION="${1:-$(curl -sSLq --ipv4 https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r ".tag_name" | cut -c 2-)}"
  WORKDIR="$(mktemp -d || exit 1)"
  trap 'rm -rf ${WORKDIR}' EXIT
  TAILSCALE_TGZ="${WORKDIR}/tailscale.tgz"

  echo "Installing Tailscale v${VERSION} in ${TAILSCALE_ROOT}..."
  curl -sSLf --ipv4 -o "${TAILSCALE_TGZ}" "https://pkgs.tailscale.com/stable/tailscale_${VERSION}_mips64.tgz" || {
    echo "Failed to download Tailscale v${VERSION} from https://pkgs.tailscale.com/stable/tailscale_${VERSION}_mips64.tgz"
    echo "Please make sure that you're using a valid version number and try again."
    exit 1
  }

  tar xzf "${TAILSCALE_TGZ}" -C "${WORKDIR}"
  mkdir -p "${TAILSCALE_ROOT}"
  cp -R "${WORKDIR}/tailscale_${VERSION}_mips64"/* "${TAILSCALE_ROOT}"

  echo "Installation complete, run '$0 start' to start Tailscale"
}

tailscale_start() {
  PORT="${PORT:-41641}"
  TAILSCALE_FLAGS="${TAILSCALE_FLAGS:-""}"
  TAILSCALED_FLAGS="${TAILSCALED_FLAGS:-"--tun userspace-networking"}"
  LOG_FILE="${TAILSCALE_ROOT}/tailscaled.log"

  if tailscale_is_running; then
    echo "Tailscaled is already running"
  else
    echo "Starting Tailscaled..."
    "$TAILSCALED" --cleanup > "${LOG_FILE}" 2>&1

    # shellcheck disable=SC2086
    setsid "$TAILSCALED" \
      --state "${TAILSCALE_ROOT}/tailscaled.state" \
      --socket "${TAILSCALED_SOCK}" \
      --port "${PORT}" \
      ${TAILSCALED_FLAGS} >> "${LOG_FILE}" 2>&1 &

    # Wait a few seconds for the daemon to start
    sleep 5

    if tailscale_is_running; then
      echo "Tailscaled started successfully"
    else
      echo "Tailscaled failed to start"
      exit 1
    fi

    # Run tailscale up to configure
    echo "Running tailscale up to configure interface..."
    # shellcheck disable=SC2086
    "$TAILSCALE" up $TAILSCALE_FLAGS
  fi
}

tailscale_stop() {
  "$TAILSCALE" down || true
  pkill tailscaled 2>/dev/null || true
  "$TAILSCALED" --cleanup
}

tailscale_uninstall() {
  "$TAILSCALED" --cleanup
  rm -rf "$TAILSCALE_ROOT"
}

tailscale_status() {
  if tailscale_is_running; then
    echo "Tailscaled is running"
    "$TAILSCALE" --version
  else
    echo "Tailscaled is not running"
  fi
}

tailscale_is_running() {
  if [ -e "${TAILSCALED_SOCK}" ]; then
    return 0
  else
    return 1
  fi
}

tailscale_has_update() {
  CURRENT_VERSION="$("$TAILSCALE" --version | head -n 1)"
  TARGET_VERSION="${1:-$(curl -sSLq --ipv4 https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r ".tag_name" | cut -c 2-)}"
  if [ "${CURRENT_VERSION}" != "${TARGET_VERSION}" ]; then
    return 0
  else
    return 1
  fi
}

tailscale_update() {
  tailscale_stop
  tailscale_install "$1"
  tailscale_start
}

case $1 in
  "status")
    tailscale_status
    ;;
  "start")
    tailscale_start
    ;;
  "stop")
    tailscale_stop
    ;;
  "restart")
    tailscale_stop
    tailscale_start
    ;;
  "install")
    if tailscale_is_running; then
      echo "Tailscale is already installed, if you wish to update it, run '$0 update'"
      exit 0
    fi

    tailscale_install "$2"
    ;;
  "uninstall")
    tailscale_stop
    tailscale_uninstall
    ;;
  "update")
    if tailscale_has_update "$2"; then
      if tailscale_is_running; then
        echo "Tailscaled is running, please stop it before updating"
        exit 1
      fi

      tailscale_install "$2"
    else
      echo "Tailscale is already up to date"
    fi
    ;;
  "update!")
    if tailscale_has_update "$2"; then
      tailscale_update "$2"
    else
      echo "Tailscale is already up to date"
    fi
    ;;
  "on-boot")
    . "${TAILSCALE_ROOT}/tailscale-env"

    if [ "${TAILSCALE_AUTOUPDATE}" = "true" ]; then
      tailscale_has_update && tailscale_update || echo "Not updated"
    fi

    tailscale_start
    ;;
  *)
    echo "Usage: $0 {status|start|stop|restart|install|uninstall|update}"
    exit 1
    ;;
esac
