# InsightAccess (work) dev stack, moved over from the mac on 2026-10-21.
#
# v3 (FastAPI + bun/vite) runs from ~/Projects/InsightAccess/v3-insightaccess
# with its infra in docker (postgres 5433, pgvector 5437, redis 6381,
# localstack 4566). V1 (Laravel pms/bsc/sm/tms/spcp) runs on lerd, which is
# rootless podman + quadlet units, serving https://<module>.localhost. MySQL
# for V1 is the `ia-mysql` docker container on 3306 (DBngin on the mac).
# The `ia` CLI (~/tools/ia) shells out to everything listed below.
# lerd setup follows github:lerd-env/lerd-nixos, minus its .test dns block:
# the sites use .localhost, which resolves to loopback without any dns.
{
  pkgs,
  lerd,
  ...
}: {
  # lerd's containers. docker stays the default runtime (honcho, v3 infra),
  # so no dockerCompat.
  virtualisation.podman.enable = true;
  virtualisation.containers.enable = true;
  # podman's default pool is 10.x; keep it off docker's 172.17-172.29 too
  virtualisation.containers.containersConf.settings.network.default_subnet_pools = [
    {
      base = "172.30.0.0/16";
      size = 24;
    }
  ];

  # the V1 .env files use DB_HOST=host.containers.internal (podman machine maps
  # it to the mac's loopback). on linux it is the lan address, where nothing
  # listens: point it at docker0 instead, where ia-mysql also publishes 3306
  # (host-only, not reachable from the lan).
  virtualisation.containers.containersConf.settings.containers.host_containers_internal_ip = "172.17.0.1";

  # lerd's rootless nginx binds 80/443 for https://<module>.localhost
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # keep lerd's user containers up outside a graphical session
  users.users.raihan.linger = true;

  # lerd-ui / lerd-watcher exec ~/.local/bin/lerd; the binary lives in the system profile
  systemd.user.tmpfiles.rules = ["L %h/.local/bin/lerd - - - - /run/current-system/sw/bin/lerd"];
  # lerd's generated units hardcode fhs paths (ExecStartPre=/bin/mkdir on the
  # fpm quadlets, /bin/true, /usr/bin/systemctl); nixos only ships /bin/sh
  systemd.tmpfiles.rules = [
    "L+ /bin/mkdir - - - - ${pkgs.coreutils}/bin/mkdir"
    "L+ /bin/true - - - - ${pkgs.coreutils}/bin/true"
    "L+ /usr/bin/systemctl - - - - /run/current-system/sw/bin/systemctl"
  ];

  environment.systemPackages = with pkgs; [
    lerd.packages.${pkgs.stdenv.hostPlatform.system}.default
    rtk # claude code bash hook (token-trimmed output)
    agent-browser # ia shot / ia record
    chromium # browser agent-browser drives (its own chrome download needs FHS)
    ffmpeg # ia record / ia proof joins and contact sheets
    poppler-utils # pdftoppm for pdf proof shots
    postgresql_18 # psql/pg_dump: ia reset-passwords, ia db-sync dev
    mysql84 # mysql client: ia db / ia db-sync for V1
    gnumake # v3 Makefiles: dev.sh workers, sqs-init
    lsof # ia restarts backends by port
    netcat-openbsd
    ripgrep # agent rules search with rg/fff
    mkcert
    unzip # lerd unpacks fnm (its node manager) with it
    nss.tools # certutil: lerd adds its CA to the browsers' nss stores
  ];

  # lerd's mkcert root CA, so curl/php/node trust https://<module>.localhost.
  # public cert only; the key stays in ~/.local/share/mkcert. a fresh
  # `lerd install` makes a new CA: copy its rootCA.pem over this file.
  security.pki.certificateFiles = [../certs/lerd-rootCA.pem];

  environment.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
}
