{ substituteAll
, version, updateCert, unsignedRaucBundle
, deployUrl, updateUrl, kioskUrl
, rauc, awscli, python36
}:
substituteAll {
  src = ./deploy-playos-update.py;
  dummyBuildCert = ../../pki/dummy/cert.pem;
  inherit version updateCert unsignedRaucBundle deployUrl updateUrl kioskUrl;
  inherit rauc awscli python36;
}
