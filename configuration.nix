{ config, pkgs, lib, pkgs-unstable, ... }:

let
  secrets = import ./secrets.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/users.nix
    ./modules/networking-simple.nix
    ./modules/web-services.nix
    ./modules/monitoring.nix
  ];

  # System basics
  system.stateVersion = "24.05";

  # Boot loader
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = false;
  };

  # Hostname
  networking.hostName = "vps";

  # Time zone and locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # Enable flakes system-wide
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    bun
    nodejs
    python3
    python3Packages.pip
    python3Packages.virtualenv
    rsync
    tmux
    tree

    # Neovim and dependencies
    pkgs-unstable.neovim  # Use unstable for Neovim 0.10+
    gcc
    gnumake
    ripgrep
    fd
    unzip
    xclip  # For clipboard support

    # Debugging tools
    lsof
    netcat
    tcpdump
    dig
  ];

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Root user SSH keys
  users.users.root.openssh.authorizedKeys.keys = secrets.sshKeys;
}
