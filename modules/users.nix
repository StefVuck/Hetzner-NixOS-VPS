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
}
