# [2025.3.2-VALIDATION] - 2025-11-21

## Changed

- os: Optimize the WiFi scanning strategy for stationary clients
- os: Enable retries when connecting to WPA3 WiFi networks fails
- os: Increase the number of permitted retries for failed WiFi connections

## Fixed

- os: Prevent the network manager from attempting to route Internet traffic to the Senso in networks with delayed DHCP
- os: Prevent captive portals with HTTPS addresses from stalling the network manager

# [2025.3.1] - 2025-07-04

# [2025.3.1-VALIDATION] - 2025-06-06

## Changed

- os: Downgrade connman to 1.42 to prevent known network issue
- driver: Upgrade to 2.6.0 for Flex v5 support

# [2025.3.0-VALIDATION] - 2025-03-20

## Added

- kiosk: Migrate to Qt6
- kiosk: Open settings with a long press on the Menu key
- kiosk: Add hotplugging support for HDMI screens
- os: Improve installation device selection
- os: Add end-to-end system tests
- os: Hide mouse cursor when idle
- controller: Enable spatial navigation using the arrow keys
- controller: Add factory reset button to System Status page
- controller: Add system switch calls to System Status page

## Changed

- driver: Bump to 2.5.0 for extended discovery time in firmware updates
- controller: Suppress password prompt for open WiFi networks
- controller: Explicitly mark WiFi networks with unsupported authentication methods
- controller: Improve error messages when connecting to WiFi networks fails
- os: Extend Power Button handling to multiple devices

## Removed

- controller: Remove unused label printing functionality

# [2024.7.0] - 2024-08-02

# [2024.7.0-VALIDATION] - 2024-07-02

## Added

- kiosk: Add a key combination to perform hard refresh (Ctrl-Shift-R)
- os: Added localization options for Polish and Czech
- controller: Add licensing page in System Settings
- status screen: Display MAC addresses in text and QR code

## Changed

- os: Update nixpkgs channel to 23.11
- os: Set noexec for volatile root and persistent storage mounts
- os: Restrict remote maintenance to the ZeroTier network
- os: Limit permitted SSH modes and forwarding options
- os: Ignore suspend and hibernation key presses, but interpret as poweroff when long-pressed
- driver: Upgrade to add support for Senso firmware updates via app

## Removed

- os: Remove unnecessary administration capabilities for hardening

# [2023.9.1] - 2024-03-15

# [2023.9.1-VALIDATION] - 2024-03-12

## Changed

- kiosk: Automatically give keyboard focus to active web views

# [2023.9.0] - 2023-09-12

# [2023.9.0-VALIDATION] - 2023-09-11

## Changed

- os: Make Full HD the default screen resolution
- os: Widen rules for captive portal detection
- os: Split system definition into base and application layers
- os: Make build outputs and displayed system name configurable through application layer
- os: Change installer script to exclude installer medium from installation targets
- os: Include live system ISO in deployed outputs
- os: Update nixpkgs channel to 23.05
- status screen: Display persistent storage usage statistics
- controller: Allow opening captive portal when settings are open

# [2023.2.0] - 2023-03-06

# [2023.2.0-VALIDATION] - 2023-02-27

## Added

- os: Include basic network troubleshooting command-line tools

## Changed

- driver: Upgrade to 2.3.0 for recent versions of Senso Flex
- os: Route audio output to both line-out and attached HDMI/DisplayPort outputs
- os: Update nixpkgs channel to 22.11

## Fixed

- controller: Fix a file descriptor leak that could lead to the controller interface becoming unusable
- os: Add a mechanism to recover from a status file corruption that could prevent systems from updating

# [2022.4.0] - 2022-07-06

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
