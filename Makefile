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
		--arg buildLive false \
		--arg buildDisk false
	@echo "Run ./result/bin/run-playos-in-vm to start a VM"

.PHONY: develop
develop:
	[[ $(BRANCH) = "develop" ]]
	nix-build \
		--arg updateCert ./pki/develop/cert.pem \
		--arg updateUrl http://dist.dividat.com/releases/playos/develop/ \
		--arg deployUrl s3://dist.dividat.ch/releases/playos/develop/ \
		--arg kioskUrl https://dev-play.dividat.com/ \
		--arg buildDisk false
	@echo "Run ./result/bin/deploy-playos-update to deploy"

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

.PHONY: master
master:
	[[ $(BRANCH) = "master" ]]
	nix-build \
		--arg updateCert ./pki/master/cert.pem \
		--arg updateUrl http://dist.dividat.com/releases/playos/master/ \
		--arg deployUrl s3://dist.dividat.ch/releases/playos/master/ \
		--arg kioskUrl https://play.dividat.com/ \
		--arg buildDisk false
	@echo "Run ./result/bin/deploy-playos-update to deploy"


.PHONY: lab-key
lab-key:
	nix-build \
		--arg kioskUrl https://lab.dividat.com/ \
		--arg buildInstaller false \
		--arg buildBundle false \
		--arg buildDisk false
