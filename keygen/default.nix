{ compiler ? "ghc865"
, rev      ? "d5291756487d70bc336e33512a9baf9fa1788faf"
, sha256   ? "0mhqhq21y5vrr1f30qd2bvydv4bbbslvyzclhw0kdxmkgg3z4c92"
, pkgs     ?
    import (builtins.fetchTarball {
      url    = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256; }) {
      config.allowBroken = false;
      config.allowUnfree = true;
    }
}:
let gitignore = pkgs.callPackage (pkgs.fetchFromGitHub {
      owner = "siers";
      repo = "nix-gitignore";
      rev = "4f2d85f2f1aa4c6bff2d9fcfd3caad443f35476e";
      sha256 = "1vzfi3i3fpl8wqs1yq95jzdi6cpaby80n8xwnwa8h2jvcw3j7kdz";
    }) {};

in
pkgs.haskell.packages.${compiler}.developPackage {
  name = builtins.baseNameOf ./.;
  root = gitignore.gitignoreSource [".git" "README.md"] ./.;
  overrides = self: super: with pkgs.haskell.lib;

  # Working on getting this function upstreamed into nixpkgs.
  # (See https://github.com/NixOS/nixpkgs/pull/52848 for status)
  # This actually gets things directly from hackage and doesn't
  # depend on the state of nixpkgs.  Allows you to have fewer
  # fetchFromGitHub overrides.
  let callHackageDirect = {pkg, ver, sha256}@args:
        let pkgver = "${pkg}-${ver}";
        in self.callCabal2nix pkg (pkgs.fetchzip {
             url = "http://hackage.haskell.org/package/${pkgver}/${pkgver}.tar.gz";
             inherit sha256;
           }) {};
  in {
    # Don't run a package's test suite
    cereal = dontCheck super.cereal;

    cryptonite = callHackageDirect {
      pkg = "cryptonite";
      ver = "0.26";
      sha256 = "067qv3psrr1r67rfzlp3f6h6mwkcb9fldjnw4frma8j370ya238a";
    };

    # To discover more functions that can be used to modify haskell
    # packages, run "nix-repl", type "pkgs.haskell.lib.", then hit
    # <TAB> to get a tab-completed list of functions.
  };
  source-overrides = {
    # Use a specific hackage version using callHackage. Only works if the
    # version you want is in the version of all-cabal-hashes that you have.
    # bytestring = "0.10.8.1";
    #
    # Use a particular commit from github
    # parsec = pkgs.fetchFromGitHub
    #   { owner = "hvr";
    #     repo = "parsec";
    #     rev = "c22d391c046ef075a6c771d05c612505ec2cd0c3";
    #     sha256 = "0phar79fky4yzv4hq28py18i4iw779gp5n327xx76mrj7yj87id3";
    #   };
  };
  modifier = drv: pkgs.haskell.lib.overrideCabal drv (attrs: {
    buildTools = (attrs.buildTools or []) ++ [
      pkgs.haskell.packages.${compiler}.cabal-install
      pkgs.haskell.packages.${compiler}.ghcid
    ];
  });
}
