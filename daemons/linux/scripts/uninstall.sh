#!/bin/bash
set -euo pipefail

INSTALL_DIR="${CLOUDE_INSTALL_DIR:-/opt/cloude-agent}"
SYSTEMD_DIR="${CLOUDE_SYSTEMD_DIR:-/etc/systemd/system}"
for service in cloude-tunnel cloude-agent; do
  if [ -f "$SYSTEMD_DIR/$service.service" ] && grep -Fq "$INSTALL_DIR/" "$SYSTEMD_DIR/$service.service"; then
    sudo systemctl disable --now "$service"
    sudo rm "$SYSTEMD_DIR/$service.service"
  fi
done
sudo systemctl daemon-reload
echo "Afto services removed. Installation files, agent logins, pairing identity, and chat history were kept."
echo "Remove $INSTALL_DIR and ${CLOUDE_DATA:-$HOME/.cloude-agent} yourself only if you also want to erase them."
