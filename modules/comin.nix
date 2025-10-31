{ config, pkgs, lib, ... }:

let
  secrets = import ../secrets.nix;
in
{
  # Comin - GitOps for NixOS
  # Automatically pulls and rebuilds NixOS configuration from Git
  services.comin = {
    enable = true;

    remotes = [
      {
        name = "origin";
        url = secrets.comin.repoUrl;  # e.g., "https://github.com/yourusername/nixos-config"

        # Watch the main branch
        branches.main.name = "main";

        # Authentication for private repositories
        # Uncomment if using a private repository
        # auth.access_token_path = secrets.comin.tokenPath;
      }
    ];
  };

  # Note: Comin service is automatically configured by the module
  # No need for additional systemd service customization
}
