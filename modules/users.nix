{ config, pkgs, ... }:

{
  # Service users for web applications
  users.users = {
    example-static = {
      isSystemUser = true;
      group = "example-static";
      home = "/srv/websites/example-static";
      createHome = true;
      shell = pkgs.bash;
    };

    example-app = {
      isSystemUser = true;
      group = "example-app";
      home = "/srv/websites/example-app";
      createHome = true;
      shell = pkgs.bash;
    };

    example-spa = {
      isSystemUser = true;
      group = "example-spa";
      home = "/srv/websites/example-spa";
      createHome = true;
      shell = pkgs.bash;
    };
  };

  users.groups = {
    example-static = {};
    example-app = {};
    example-spa = {};
  };

  # Ensure home directories are readable by nginx for static file serving
  # Note: Use 'Z' to recursively set permissions on existing directories
  systemd.tmpfiles.rules = [
    # Service user home directories
    "d /srv/websites/example-static 0755 example-static example-static -"
    "d /srv/websites/example-app 0755 example-app example-app -"
    "d /srv/websites/example-spa 0755 example-spa example-spa -"

    # Nginx serving directories - ensure they're readable
    # Adjust these paths based on your actual build output directories
    "Z /srv/websites/example-static/dist 0755 example-static example-static -"
    "Z /srv/websites/example-spa/dist 0755 example-spa example-spa -"
  ];

  # Apply tmpfiles rules during activation (not just on boot)
  # This ensures permissions are fixed after each deployment
  system.activationScripts.fixWebsitePermissions = {
    text = ''
      ${pkgs.systemd}/bin/systemd-tmpfiles --create
    '';
    deps = [];
  };
}
