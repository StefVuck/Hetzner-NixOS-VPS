{ config, pkgs, ... }:

let
  secrets = import ../secrets.nix;
in
{
  # ACME / Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = secrets.acme.email;
  };

  # Nginx - simplified for initial setup
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Status endpoint for Prometheus nginx exporter
    statusPage = true;

    virtualHosts = {
      # Example: Static site (replace with your domain)
      "${secrets.domains.main}" = {
        enableACME = true;
        addSSL = true;
        root = "/srv/websites/example-static/dist";
      };

      # Example: Dynamic application (Node.js/etc)
      "app.${secrets.domains.main}" = {
        enableACME = true;
        addSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      # Grafana monitoring dashboard
      "grafana.${secrets.domains.main}" = {
        enableACME = true;
        addSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      # Example: API + SPA (FastAPI/Flask + React/Vue)
      "api.${secrets.domains.main}" = {
        enableACME = true;
        addSSL = true;
        root = "/srv/websites/example-spa/build";

        # API endpoints
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:8000";
        };

        # Frontend SPA
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
      };
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [];
    trustedInterfaces = [ "lo" ];
  };
}
