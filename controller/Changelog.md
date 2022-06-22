# [UNRELEASED]

# [2022.4.0-VALIDATION.1] - 2022-06-22

## Added

- controller: Add option to limit screen resolution to Full HD

# [2022.4.0-VALIDATION] - 2022-04-29

## Added

- controller: Show a loader in submit buttons when submitting forms

## Changed

- os: Update nixpkgs channel to 21.11
- os: Disable virtual terminals that are not used by PlayOS
- controller: Reorganize layout with an aside menu and a header bar
- controller: Split proxy configuration form into multiple inputs for greater ease of use
- controller: Provide a more helpful error message when network connection is failing
- controller: Mark connected network services in service list
- controller: Improve robustness of connectivity check in Network Settings
- kiosk: Show a loader when connecting to Play
- kiosk: Show an informative error page when connecting to Play has failed
- kiosk: Open System Settings (Ctrl+Shift+F12) and Network Login (behind captive portal) in a dialog

## Fixed

- controller: Suppress a confusing error message during regular system updates
- controller: Prevent “Already connected” errors when connecting to a network
- kiosk: Fix use of proxy credentials containing special characters

# [2021.9.0] - 2021-11-11

# [2021.9.0-VALIDATION] - 2021-09-28

## Added

- driver: Upgrade to support Senso Flex
- controller: Hide the passphrase by default in the network form
- controller: Display IP addresses in network list

## Changed

- controller: Move network interface list to network page
- os: Make system journal persist across reboots

# [2021.3.0] - 2021-04-08

# [2021.3.0-VALIDATION] - 2021-03-24

## Added

- controller: Enable HTTPS support for system update hosts
- os: Support manually configured authenticated proxies
- system: Add status screen to tty8
- controller: Add support for static IP configuration

## Changed

- controller: Format machine-id in groups of 4 for readability
- os: Update nixpkgs channel to 20.09
- controller: Display network configuration on separate pages
- controller: Enable remote management on demand only

## Fixed

- controller: Display interfaces' IP even if there is no gateway
- controller: Fix timezone save when shorter than the previous saved one

# [2020.7.0] - 2020-09-23

# [2020.7.0-VALIDATION] - 2020-07-08

## Added

- controller: Add update status types for manually pinned systems and dual-slot system failure

## Changed

- system: Update rauc to 1.2
- system: Remember manual boot choice on reboot
- os: Update nixpkgs channel to 20.03

# [2020.1.0] - 2020-02-11

# [2020.1.0-VALIDATION] - 2020-01-22

## Added

- controller: Add a refresh button in the network page
- controller: Show network strengths in the network page
- controller: Show PlayOS changelog

## Changed

- controller: Improve UI

## Fixed

- controller: Allow subsequent connections after a connection error
- controller: Stabilize WIFI connection scanning

# [2019.9.0] - 2019-10-15

# [2019.9.0-VALIDATION] - 2019-09-28

## Added

- kiosk: Enable connection to captive portals
- kiosk: Include PlayOS version in user-agent string

## Changed

- os: Use breeze cursor theme for larger, friendlier cursor symbols
- os: Enable connman online check to improve default route selection

# [2019.8.0] - 2019-08-24

# [2019.8.0-VALIDATION.1] - 2019-08-23

## Added

- Add installer ISO to archived assets

# [2019.8.0-VALIDATION] - 2019-08-13

## Changed

- updater: Support SemVer 2.0 versioning, respecting pre-release identifiers
- controller: Leave service units a moment to shut down gracefully
- installer: Suppress machine-id recovery warnings on first install
- os: Update nixpkgs channel to 19.03

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
