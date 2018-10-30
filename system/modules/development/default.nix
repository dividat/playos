{ config, pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    sudo
    grub2
  ];

  warnings = [ "Development configuration active." ];

  users.users.dev = {
    isNormalUser = true;
    home = "/home/dev";
    extraGroups = [ "wheel" ];
    password = "123";
  };

}
