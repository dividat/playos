# [Unreleased]

## Changed

- updater: Support SemVer 2.0 versioning, respecting pre-release identifiers
- controller: Leave service units a moment to shut down gracefully

# [2019.4.0] - 2019-04-03

First stable release on master channel.

## Changed

- updater: new bundle signature for validation channel

# [2019.3.0-VALIDATION] - 2019-03-30

## Added

- controller: add localization settings for timezone, keyboard and locale
- live system image to run PlayOS from removable media

## Changed

- system: enable wifi on first boot

# [2019.2.6-beta] - 2019-02-21

## Added

- installer: preserve machine-id on reinstallation

## Removed

- system: disable local root access

# [2019.2.5-beta] - 2019-02-19

## Added

- controller: print labels

## Changed

- controller: show more information and add ability to remove service

# [2019.2.4-beta] - 2019-02-15

## Changed

- kiosk: enable Qt WebEngine Developer Tools
- controller: initialize network parallel to server startup

## Fixed

- WebGL support in kiosk

# [2019.2.3-beta] - 2019-02-12

## Changed

- controller: gui style

## Fixed

- system: start RAUC and ConnMan before playos-controller

## Attempted Fix

- ConnMan issue with "No Carrier"

# [2019.2.2-beta] - 2019-02-11

## Added

- controller: basic UI for wireless network configuration

## Fixes

- Pin version of pscslite to be compatible with statically compiled driver
- Fix card reader support by blacklisting conflicting pn533

# [2019.2.1-beta] - 2019-02-05

## Fixes

- system/connman: use wifi as default route when also connected to ethernet

# [2019.2.0-beta0] - 2019-02-05

Initial beta release
