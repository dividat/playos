self: super: {
  ocamlPackages = super.ocamlPackages.overrideScope' (self: super: {

    hmap = self.callPackage ./ocaml-modules/hmap {};

    semver = self.callPackage ./ocaml-modules/semver {};

    opium_kernel = self.callPackage ./ocaml-modules/opium_kernel {};
    opium = self.callPackage ./ocaml-modules/opium {};

    obus = self.callPackage ./ocaml-modules/obus {};

    cohttp-lwt-jsoo = super.cohttp.overrideAttrs (oldAttrs: {
      buildPhase = "jbuilder build -p cohttp-lwt-jsoo";
      propagatedBuildInputs = with self; [ cohttp cohttp-lwt ocaml_lwt js_of_ocaml js_of_ocaml-lwt js_of_ocaml-ppx ppx_tools_versioned ];
    });
  });
}
