# Alpine based Linux system

This is an experiment to create a build system capable of creating Alpine Linux based custom Linux systems.

## Quick start

```
nix-shell
make
make qemu
```

## Components

### [Nix](https://nixos.org/nix/)

Nix is used to get sources from remote locations reliably, provide consistent build environments and efficiently cache build artifacts.

### [System builder](alpine/system-builder)

Given a list of apks (Alpine Linux packages) it will create a root filesystem with the given packages installed.

It can do this without a VM or root access by using [`proot`](https://proot-me.github.io/).

### [APK builder](alpine/apk-builder)

Given an APKBUILD file it will build an apk that can be installed on Alpine Linux Systems. This works by creating a Alpine Linux system with all development tools (and depdencies to build package) and running the Alpine build tools in `proot`.

See the [`aports`](aports/) folder for examples.

### [Image builder](./Makefile)

Create a bootable disk image given a root file system.


## Problems

### Nix to build Alpine

Experiment extensively uses Nix to build the system but at times needs to drop down to Alpine Linux tools. This interfacing is a hassle and hackey.


### Alpine Linux

 -  Documentation of Alpine Linux internals is flakey
 -  Upgrading from one release to the next is a big deal. Alpine Linux does not do rolling releases and upgrades include lot of changes to internals that are used by the ad-hoc build system (attempt to Alpine Linux 3.8 failed)

### Cross-compilation

No cross-compilation support. Host and target needs to be x64. `Nix` offers extensive cross-compilation machinery that is not used/can not be used.


## Conclusion

This is a pain in the ass and will be even more of a pain in the ass to maintain. Most trouble is mix of build tools and philosophies (Nix vs. Alpine).


