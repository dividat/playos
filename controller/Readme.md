# PlayOS Controller

Controller for PlayOS systems.

## Overview

PlayOS controller is an OCaml application that manages various system tasks for the PlayOS system (such as updating, health monitoring, offering a unified interface for configuration). Consult the PlayOS Architecture documentation for more information.

## Folders

- `bindings/`: bindings to various things
- `gui/`: static gui assets and client side code
- `nix/`: nix stuff
- `server/`: main application code

## Quick start

Create a suitable development environment with `nix-shell` and build the controller with following command:

```
dune build @install --profile release
```

This will build the controller application and place all other required artifacts in the `_build/install/default/` folder. You can start the controller with `./_build/install/default/bin/playos-controller`.

Notes:

- The controller application requires certain artifacts to be in a specific location relative to binary location. The `dune build @install` command ensures this.
- The `--profile release` option disables dune from failing on warnings (which are currently present in the `obus` library)

## See also

Many ideas have been taken from the [logarion](https://cgit.orbitalfox.eu/logarion/) project.

