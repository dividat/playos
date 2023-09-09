{ substituteAll
, application, updateCert, unsignedRaucBundle, docs, installer, live
, deployUrl, updateUrl, kioskUrl
, rauc, awscli, python3
}:
substituteAll {
  src = ./deploy-update.py;
  dummyBuildCert = ../../pki/dummy/cert.pem;
  inherit updateCert unsignedRaucBundle docs installer live deployUrl updateUrl kioskUrl;
  inherit rauc awscli python3;
  inherit (application) fullProductName safeProductName version;
}
