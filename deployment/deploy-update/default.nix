{ substituteAll
, application, updateCert, unsignedRaucBundle, docs, installer
, deployUrl, updateUrl, kioskUrl
, rauc, awscli, python39
}:
substituteAll {
  src = ./deploy-update.py;
  dummyBuildCert = ../../pki/dummy/cert.pem;
  inherit updateCert unsignedRaucBundle docs installer deployUrl updateUrl kioskUrl;
  inherit rauc awscli python39;
  inherit (application) fullProductName safeProductName version;
}
