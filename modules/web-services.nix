{ config, pkgs, ... }:

let
  secrets = import ../secrets.nix;
in
{
  # Ensure website directories are readable by nginx
  systemd.tmpfiles.rules = [
    "d /srv/websites/example-static 0755 example-static example-static -"
    "d /srv/websites/example-app 0755 example-app example-app -"
    "d /srv/websites/example-spa 0755 example-spa example-spa -"
  ];


  # Example: Static site deployment service
  systemd.services.example-static-deploy = {
    description = "Deploy static website";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "example-static";
      WorkingDirectory = "/srv/websites/example-static/repo";
      ExecStart = "/srv/scripts/deploy-static.sh";
      RemainAfterExit = true;
    };
  };

  # Example: Node.js/Bun application service
  systemd.services.example-app = {
    description = "Example Node.js Application";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "example-app";
      Group = "example-app";
      WorkingDirectory = "/srv/websites/example-app/repo";

      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.nodejs}/bin/npm run start'";

      Restart = "always";
      RestartSec = "10s";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/srv/websites/example-app" ];

      # Resource limits
      MemoryMax = "512M";
      CPUQuota = "50%";

      Environment = [
        "NODE_ENV=production"
        "PORT=3000"
        "PATH=${pkgs.nodejs}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
    };
  };

  # Example: FastAPI/Python backend service
  systemd.services.example-api = {
    description = "Example FastAPI Backend";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "example-spa";
      Group = "example-spa";
      WorkingDirectory = "/srv/websites/example-spa/backend";

      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.python3.withPackages(ps: [ ps.fastapi ps.uvicorn ps.pydantic ])}/bin/uvicorn main:app --host 127.0.0.1 --port 8000'";

      Restart = "always";
      RestartSec = "10s";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/srv/websites/example-spa" ];

      MemoryMax = "512M";
      CPUQuota = "50%";

      Environment = [
        "PYTHONUNBUFFERED=1"
        "PATH=${pkgs.python3}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
    };
  };
}
