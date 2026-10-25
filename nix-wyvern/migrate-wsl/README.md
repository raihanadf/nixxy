# wyvern: bare-metal NixOS → Windows 10 + NixOS-WSL

wyvern stays wyvern: same hostname, same tailnet name, same `~`, same honcho
data and JWT secret (so loong's tokens keep working), same ssh host keys (so
loong's known_hosts does not complain). Only the hardware owner changes.

The new system is `nixosConfigurations.wyvern` (`../wsl.nix`,
`../home-wsl.nix`). The old one (`wyvern`) is untouched until step 7.

## The disk, as it is now

| partition | what | fate |
|---|---|---|
| nvme0n1p1 100M vfat | **the shared ESP**: Windows Boot Manager *and* NixOS's systemd-boot (mounted at `/boot/efi`) | **keep**, only NixOS's folders go |
| nvme0n1p2 16M | Microsoft reserved | keep |
| nvme0n1p3 295G ntfs | Windows 10 (C:) | keep, grows into p4+p5 |
| nvme0n1p4 1G vfat `BOOT` | NixOS leftover | delete in step 7 |
| nvme0n1p5 180G btrfs | NixOS root | delete in step 7 |

**Done on 2026-10-25:** steps 0 and 1 ran with sudo: `nixos.wsl`, the ssh
host keys and the whole backup are on `C:\wyvern-migration` and on loong in
`~/wyvern-migration` (with `HANDOFF.md` and the secrets). The "fast path"
notes below are only for when the C: copy is gone.

Until step 7 the old NixOS still boots from the boot menu, so every step
before it can be backed out.

## 0. Windows, once: fast startup off

Boot Windows, open an admin PowerShell, run `powercfg /h off`, then **shut down**
(not restart). Linux can only write to C: when Windows did not hibernate it.

## 1. NixOS: build the image and back up

```sh
cd ~/.nixxy/nix-wyvern
# commit and push nixxy first (git add wsl.nix home-wsl.nix migrate-wsl flake.*), it is in the backup either way
mkdir -p ~/wyvern-migration
nix build path:$PWD#nixosConfigurations.wyvern.config.system.build.tarballBuilder
sudo ./result/bin/nixos-wsl-tarball-builder ~/wyvern-migration/nixos.wsl
sudo chown raihan ~/wyvern-migration/nixos.wsl
bash migrate-wsl/backup.sh
```

`backup.sh` lists repos with uncommitted or unpushed work (they are in the
backup exactly as they are on disk, nothing needs pushing), stops every service
and container, and writes everything to `~/wyvern-migration`, to loong
(`~/wyvern-migration`) and to `C:\wyvern-migration`. It asks for sudo twice:
the ssh host keys and mounting C:.

From here wyvern is down: Chat, the WhatsApp bot, Nite, honcho. Honcho
messages from loong wait in loong's retain queue.

## 2. Windows: make it a host

Boot Windows. Admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File C:\wyvern-migration\migrate-wsl\windows-setup.ps1
```

Fast path: there is no `C:\wyvern-migration`, fetch the script from GitHub:

```powershell
iwr https://raw.githubusercontent.com/raihanadf/nixxy/main/nix-wyvern/migrate-wsl/windows-setup.ps1 -OutFile $env:TEMP\ws.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\ws.ps1
```

Reboot. Then turn on **automatic sign-in**, since the task that keeps NixOS
running starts at sign-in: `netplwiz` → untick "Users must enter a user name
and password" (if the box is missing: Settings → Accounts → Sign-in options →
turn off "Require Windows Hello sign-in"), or Sysinternals **Autologon**.

## 3. Windows: import NixOS

```powershell
wsl --import NixOS C:\WSL\NixOS C:\wyvern-migration\nixos.wsl --version 2
wsl --set-default NixOS
wsl -d NixOS -u root passwd raihan     # sudo needs it, like on the old wyvern
wsl -d NixOS
```

Fast path, no `nixos.wsl`: import the official release, then switch it to
this flake (the distro's default user is `nixos` until the switch):

```powershell
iwr https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl -OutFile $env:TEMP\nixos.wsl
wsl --import NixOS C:\WSL\NixOS $env:TEMP\nixos.wsl --version 2
wsl -d NixOS -u root -- nixos-rebuild boot --option experimental-features 'nix-command flakes' --flake 'github:raihanadf/nixxy?dir=nix-wyvern#wyvern'
wsl --terminate NixOS
wsl -d NixOS -u root passwd raihan
wsl -d NixOS
```

The first start runs honcho-bootstrap, which brings up a fresh, empty honcho.
That is expected: step 5 replaces it.

## 4. NixOS-WSL: join the tailnet as `wyvern`

In the Tailscale admin console, **remove the old `wyvern` machine first**,
otherwise the new one becomes `wyvern-1` and every honcho client misses it.
Then:

```sh
sudo tailscale up --hostname=wyvern     # open the printed link in a Windows browser
```

## 5. NixOS-WSL: restore

```sh
bash /mnt/c/wyvern-migration/migrate-wsl/restore.sh
```

Fast path: the backup is on loong. From loong, once `ssh wyvern` works
(loong's key is in `wsl.nix`; accept the new host key after `ssh-keygen -R wyvern`):

```sh
rsync -a --exclude secrets ~/wyvern-migration/ wyvern:wyvern-migration/
ssh -t wyvern 'bash ~/wyvern-migration/migrate-wsl/restore.sh ~/wyvern-migration'
```

It checks the checksums, puts the docker volumes back, unpacks `~`, repoints
the internal-workflow unit's bun at the profile, restores the ssh host keys,
starts honcho and the user services, and prints checks.

## 6. NixOS-WSL: the rest, by hand

- **lerd**: its units point at the old store. Run `lerd install`, then `lerd doctor`.
- **The other docker stacks** come back on their volumes:
  `docker compose up -d` in `~/Projects/InsightAccess/v3-insightaccess/superadmin-be`;
  `ia-mysql`, `v3-ai-pgvector` and `v3-redis` through the `ia` tooling
  (`meta/containers.json` has how they were created).
- **twg**: `twg login --force` if its session did not survive.
- **From loong**: `ssh wyvern` (no host key warning), Claude Code honcho recall
  works, `mem search test`, the Remote page shows wyvern online, Chat answers,
  a WhatsApp message to the bot gets a reply, Nite status says linked.
- Rebuilds: plain `sudo nixos-rebuild switch` (the outputs were renamed on
  2026-10-25: `#wyvern` is this wsl system, `#wyvern-metal` the old install).

Give it a day or two of normal use before step 7.

## 7. Windows: remove NixOS

Admin PowerShell:

1. Disk Management (`diskmgmt.msc`): delete the 1G `BOOT` volume and the 180G
   btrfs volume (both right after C:). Right-click C: → Extend Volume into the
   freed space.
2. The ESP: `mountvol S: /s`, then delete only NixOS's folders:
   `Remove-Item -Recurse S:\EFI\systemd, S:\EFI\nixos, S:\loader` (whichever exist).
   **Leave `S:\EFI\Microsoft`.**
3. `bcdboot C:\Windows /s S: /f UEFI` rewrites Windows' boot files, the
   `EFI\Boot` fallback (systemd-boot had put itself there) and puts Windows
   Boot Manager first. Then `mountvol S: /d`.
4. `bcdedit /enum firmware`: delete the "Linux Boot Manager" entry with
   `bcdedit /delete {its id}`.
5. Reboot and check it goes straight to Windows, and that wyvern comes back
   on the tailnet by itself (automatic sign-in → keepalive task → NixOS).

## 8. Clean up the backup copies

They hold `daemon/.env`, the honcho JWT secret, Claude logins and the ssh
host keys. Once wyvern has run fine for a week, delete `C:\wyvern-migration`,
and loong's `~/wyvern-migration`.
