# Blatant misuse of make to create nice shortcuts for different build profiles. The real build tool is nix.

# Get the git branch
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

.PHONY: default
default:
	nix-build

.PHONY: vm
vm:
	nix-build \
		--arg buildInstaller false \
		--arg buildBundle false \
		--arg buildDisk false
	@echo "Run ./result/bin/run-playos-in-vm to start a VM"

.PHONY: validation
validation:
	[[ $(BRANCH) = "validation" ]]
	nix-build \
    --arg updateCert ./pki/validation/cert.pem \
		--arg updateUrl http://dist.dividat.com/releases/playos/validation/ \
		--arg deployUrl s3://dist.dividat.ch/releases/playos/validation/ \
    --arg kioskUrl https://val-play.dividat.com/ \
		--arg buildDisk false
	@echo "Run ./result/bin/deploy-playos-update to deploy"
