{ substituteAll
, version, updateCert, unsignedRaucBundle, installer
, deployUrl, updateUrl, kioskUrl
, rauc, awscli, python39
}:
substituteAll {
  src = ./deploy-playos-update.py;
  dummyBuildCert = ../../pki/dummy/cert.pem;
  inherit version updateCert unsignedRaucBundle installer deployUrl updateUrl kioskUrl;
  inherit rauc awscli python39;
}
