# PlayOS Controller

Controller for PlayOS systems.

## Overview

PlayOS controller is an OCaml application that manages various system tasks for the PlayOS system (such as updating, health monitoring, offering a unified interface for configuration). Consult the PlayOS Architecture documentation for more information.

## Folders

- `bindings/`: bindings to various things
- `gui/`: static gui assets
- `server/`: main application code
- `bin/`: binaries to start a dev server

## Prerequisites

Since the controller uses `Connman` for managing networks, it must be configured on your host if you want to run the controller directly.

You should be able to build and run the controller on any Linux system, using the Nix package manager.

If you are on NixOS, a minimal setup can be achieved as follows (remember to fill in `<your-host-name>`):

```nix
{ pkgs, config, ... }:
{
  networking = {
    hostName = <your-hostname>;
    wireless.enable = true;
    networkmanager.enable = false;
  };

  services.connman = {
    enable = true;
    networkInterfaceBlacklist = [ "vboxnet" "zt" ];
  };
}
```

Note the `networkmanager.enable = false` and check for any conflicting existing configuration.

## Quick start


Run `nix-shell` to create a suitable development environment.

Then, start the the controller with `bin/dev-server`.

## Code style

- Author CSS according to the [BEM methodology](http://getbem.com/) in the format `d-Block__Element--Modifier`.

## See also

Many ideas have been taken from the [logarion](https://cgit.orbitalfox.eu/logarion/) project.
