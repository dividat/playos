# PlayOS Controller

Controller for PlayOS systems.

## Overview

PlayOS controller is an OCaml application that manages various system tasks for the PlayOS system (such as updating, health monitoring, offering a unified interface for configuration). Consult the PlayOS Architecture documentation for more information.

## Folders

- `bindings/`: bindings to various things
- `gui/`: static gui assets
- `nix/`: nix stuff
- `server/`: main application code
- `bin/`: binaries to start a dev server

## Quick start

Prerequisites: `connman` must be running on your system.

Run `nix-shell` to create a suitable development environment.

Then, start the the controller with `bin/dev-server`.

## Code style

- Author CSS according to the [BEM methodology](http://getbem.com/) in the format `d-Block__Element--Modifier`.

## See also

Many ideas have been taken from the [logarion](https://cgit.orbitalfox.eu/logarion/) project.
