#!/usr/bin/env bash
# step 5 of migrate-wsl/README.md, inside the new NixOS-WSL wyvern, after `tailscale up`.
# usage: bash restore.sh [backup dir]   (default /mnt/c/wyvern-migration)
# puts back what backup.sh saved: docker volumes first (into stopped, empty containers' places),
# then home, then the ssh host keys, then starts honcho and the user services again.
set -euo pipefail

SRC=${1:-/mnt/c/wyvern-migration}
cd "$SRC"

echo "== checking the backup"
sha256sum -c --quiet SHA256SUMS

echo "== stopping the fresh honcho stack the bootstrap started"
running=$(docker ps -q)
[ -z "$running" ] || docker stop $running
docker compose -p honcho-local --project-directory ~/.honcho/profiles/local down 2>/dev/null || true

echo "== docker volumes"
docker pull -q alpine >/dev/null
for f in volumes/*.tar.zst; do
  v=$(basename "$f" .tar.zst)
  echo "  $v"
  docker volume rm -f "$v" >/dev/null
  # same labels as before, so compose adopts the volume as its own instead of warning
  labels=$(jq -r --arg v "$v" '.[] | select(.Name == $v) | .Labels // {} | to_entries[] | "--label=\(.key)=\(.value)"' meta/volumes.json)
  docker volume create $labels "$v" >/dev/null
  zstd -dc "$f" | docker run --rm -i -v "$v":/v alpine tar -C /v -xpf -
done

echo "== home"
zstd -dc home.tar.zst | tar -C ~ -xpf -

# the old daemon unit ran bun from the old store; the profile path survives rebuilds
sed -i -E 's#/nix/store/[^/ ]*-bun-[^/ ]*/bin/bun#/etc/profiles/per-user/raihan/bin/bun#' ~/.config/systemd/user/*.service

if [ -f ssh-host-keys.tar ]; then
  echo "== ssh host keys (sudo)"
  sudo tar -C /etc/ssh -xpf ssh-host-keys.tar
  sudo systemctl restart sshd
else
  echo "== no ssh host keys in the backup: on loong, ssh-keygen -R wyvern once"
fi

echo "== honcho"
docker compose -p honcho-local --project-directory ~/.honcho/profiles/local up -d
for i in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' honcho-local-api-1 2>/dev/null)" = healthy ] && break
  sleep 2
done
sudo systemctl restart honcho-mcp honcho-tailnet honcho-mcp-tailnet

echo "== user services"
systemctl --user daemon-reload
for unit in $(cat meta/enabled-user-units.txt); do
  # tray units need a desktop session, which wsl does not have
  case $unit in lerd-tray.service|tray.target) continue ;; esac
  systemctl --user enable "$unit" 2>/dev/null || echo "  could not enable $unit"
done
systemctl --user restart internal-workflow goodnite goodnite-bot mem-compact solana-scanner || true
systemctl --user start twg-upkeep.timer || true

echo "== checks"
curl -fsS -o /dev/null http://127.0.0.1:8000/openapi.json && echo "  honcho api ok" || echo "  honcho api NOT answering"
for unit in internal-workflow goodnite goodnite-bot mem-compact; do
  echo "  $unit: $(systemctl --user is-active $unit)"
done
tailscale status --self --peers=false | head -1
echo
echo "left for you (README step 6): lerd, the other docker stacks, and the checks from loong."
