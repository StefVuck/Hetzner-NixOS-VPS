{
  description = "NixOS VPS Configuration - Multi-project hosting with monitoring";

  inputs = {
    # Pin to NixOS stable channel for production reliability
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Add unstable for newer packages like Neovim 0.10+
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Optional: Add home-manager for user configuration
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-24.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs: {
    nixosConfigurations = {
      # Main VPS configuration
      # Replace "vps" with your actual hostname
      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          # Main configuration file
          ./configuration.nix

          # Pass unstable packages and flake inputs to all modules
          {
            _module.args = {
              inherit inputs;
              pkgs-unstable = import nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
          }
        ];
      };
      
      # Optional: Add more hosts (staging, development, etc.)
      # staging = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   modules = [ ./hosts/staging/configuration.nix ];
      # };
    };
  };
}
