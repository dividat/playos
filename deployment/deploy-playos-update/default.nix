{ substituteAll
, version, keyring, unsignedRaucBundle
, rauc, python36
}:
substituteAll {
  src = ./deploy-playos-update.py;
  inherit version keyring unsignedRaucBundle;
  inherit rauc python36;
}
