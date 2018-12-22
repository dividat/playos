{ config, pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    sudo
    grub2
  ];

  warnings = [ "Development configuration active." ];

  services.mingetty.helpLine = "Development configuration! Login as root.";
  users.users.root.initialHashedPassword = "";

}
