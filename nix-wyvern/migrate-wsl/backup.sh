#!/usr/bin/env bash
# step 1 of migrate-wsl/README.md, on the old bare-metal wyvern.
# stops everything that writes state, then saves into ~/wyvern-migration:
#   home.tar.zst        all of ~ except caches, podman images and home-manager's store links
#   volumes/<v>.tar.zst every named docker volume, taken while its container is stopped
#   honcho.sql.gz       a pg_dump of honcho on top, in case a raw volume will not start
#   ssh-host-keys.tar   so loong's known_hosts keeps trusting wyvern (secret, delete when done)
#   meta/               enabled user units, container and volume inspect json, dirty repos
# then copies the lot to loong (~/wyvern-migration) and to the windows partition (C:\wyvern-migration).
# nothing is restarted at the end: what happens after the backup would not be migrated.
# honcho's retain queue on loong holds new memories until the new wyvern is up.
set -euo pipefail

OUT=$HOME/wyvern-migration
WIN_PART=/dev/nvme0n1p3
WIN_MNT=/mnt/win

mkdir -p "$OUT/volumes" "$OUT/meta"
cd "$OUT"
# windows needs these scripts before any linux runs there
cp -r ~/.nixxy/nix-wyvern/migrate-wsl "$OUT/"
[ -f nixos.wsl ] || { echo "build nixos.wsl into $OUT first (README step 1)"; exit 1; }

echo "== repos with uncommitted or unpushed work (kept as-is in home.tar, listed for you)"
for d in ~/Projects/*/ ~/Projects/InsightAccess/*/ ~/tools/*/ ~/.nixxy/; do
  [ -d "$d/.git" ] || continue
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
  ahead=$(git -C "$d" log --oneline '@{u}..' 2>/dev/null | wc -l)
  [ "$dirty$ahead" = "00" ] || echo "$d dirty=$dirty unpushed=$ahead"
done | tee meta/dirty-repos.txt

echo "== honcho pg_dump"
docker exec honcho-local-database-1 pg_dump -U postgres postgres | gzip > honcho.sql.gz

echo "== stopping user services and every container"
systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $1}' > meta/enabled-user-units.txt
systemctl --user stop internal-workflow goodnite goodnite-bot mem-compact solana-scanner twg-upkeep.timer || true
docker inspect $(docker ps -aq) > meta/containers.json
docker volume inspect $(docker volume ls -q) > meta/volumes.json
running=$(docker ps -q)
[ -z "$running" ] || docker stop $running

echo "== docker volumes"
docker pull -q alpine >/dev/null
for v in $(docker volume ls -q); do
  # anonymous volumes (64 hex chars) belong to no one and are left behind
  [[ $v =~ ^[0-9a-f]{64}$ ]] && continue
  echo "  $v"
  docker run --rm -v "$v":/v:ro alpine tar -C /v -cf - . | zstd -q -T0 > "volumes/$v.tar.zst"
done

echo "== ssh host keys (sudo)"
sudo sh -c 'cd /etc/ssh && tar -cf - ssh_host_*' > ssh-host-keys.tar
chmod 600 ssh-host-keys.tar

echo "== home"
# home-manager's links point into this machine's store, the new system makes its own
(cd ~ && find . -xdev -type l -lname '/nix/store/*') > meta/hm-links.txt
cat > meta/home-excludes.txt <<'EOF'
./wyvern-migration
./.cache
./.local/share/containers
./.local/share/Trash
./.npm/_cacache
./.nix-profile
./.nix-defexpr
./.local/state/nix
./.local/state/home-manager
EOF
# tar exits 1 when a file changed while it was read; that is a warning, not a failure
tar -C ~ --exclude-from=meta/home-excludes.txt --exclude-from=meta/hm-links.txt -cpf - . | zstd -q -T0 > home.tar.zst || [ $? -eq 1 ]

sha256sum home.tar.zst honcho.sql.gz ssh-host-keys.tar volumes/* > SHA256SUMS
du -sh "$OUT"

echo "== copy to loong"
rsync -a --partial --info=progress2 "$OUT/" raihan@loong:wyvern-migration/

echo "== copy to the windows partition (sudo)"
sudo mkdir -p "$WIN_MNT"
sudo mount -t ntfs3 "$WIN_PART" "$WIN_MNT"
sudo rsync -rt --info=progress2 "$OUT/" "$WIN_MNT/wyvern-migration/"
sudo umount "$WIN_MNT"

echo
echo "done. backup is in $OUT, on loong at ~/wyvern-migration and on windows at C:\\wyvern-migration."
echo "everything is stopped. to back out instead: systemctl --user start internal-workflow goodnite goodnite-bot mem-compact; honcho start"
