{ substituteAll
, version, updateCert, unsignedRaucBundle
, deployUrl, updateUrl
, rauc, awscli, python36
}:
substituteAll {
  src = ./deploy-playos-update.py;
  dummyBuildCert = ../../testing/pki/cert.pem;
  inherit version updateCert unsignedRaucBundle deployUrl updateUrl;
  inherit rauc awscli python36;
}
