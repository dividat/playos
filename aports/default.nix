{apkBuilder, fetchurl}:
{
  nodm = apkBuilder {
    name = "nodm";
    makedepends = map fetchurl (import ./nodm/makedepends.nix);
    apkbuild-dir = ./nodm;
  };
}
