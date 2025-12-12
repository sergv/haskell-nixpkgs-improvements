{
  description = "Useful additions to nixpkgs-contained ghcs";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs";
    };

    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    };

    nixpkgs-18-09 = {
      url = "tarball+https://github.com/NixOS/nixpkgs/archive/a7e559a5504572008567383c3dc8e142fa7a8633.tar.gz";
      flake = false;
    };

    nixpkgs-19-09 = {
      url = "tarball+https://github.com/NixOS/nixpkgs/archive/75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1.tar.gz";
      flake = false;
    };

    nixpkgs-20-03 = {
      url = "nixpkgs/nixos-20.03";
    };

    nixpkgs-20-09 = {
      url = "nixpkgs/nixos-20.09";
    };

    nixpkgs-22-11 = {
      url = "nixpkgs/nixos-22.11";
    };

    nixpkgs-23-11 = {
      url = "nixpkgs/nixos-23.11";
    };

  };

  # # inputs.nixpkgs.url = "github:nixos/nixpkgs";
  # # inputs.flake-utils.url = "github:numtide/flake-utils";
  # inputs.hackage-server.url = "github:bgamari/hackage-server/wip/doc-builder-tls";
  # inputs.cabal.url = "github:haskell/cabal/cabal-install-v3.10.3.0";
  # inputs.cabal.flake = false;
  # inputs.hackage-security.url = "github:haskell/hackage-security/hackage-security/v0.6.2.6";
  # inputs.hackage-security.flake = false;

  outputs =
    inputs@
      { self
      , nixpkgs
      , nixpkgs-unstable
      , flake-utils
      , haskellNix

      , nixpkgs-18-09
      , nixpkgs-19-09
      , nixpkgs-20-03
      , nixpkgs-20-09
      , nixpkgs-22-11
      , nixpkgs-23-11

      , ...
      }:
    #flake-utils.lib.eachDefaultSystem
    flake-utils.lib.eachSystem ["x86_64-linux" "i686-linux"] (system:

      let hlib = nixpkgs.haskell.lib;
          lib = nixpkgs.lib;
          hutils = import ./haskell-utils.nix { inherit hlib lib; };

          # No point to have this as on overlay - let internal ghcs within /nix/store not have
          # unit ids - we won’t be exposing them to the user so there’s no harm.
          #
          # However, lets build internal tools with the same ghc that’s being exposed to the user.
          enable-ghc-unit-ids-overlay = final: prev: {
            haskell = prev.haskell // {
              compiler =
                builtins.mapAttrs (_: hutils.enable-unit-ids-for-newer-ghc) prev.haskell.compiler // {
                  native-bignum = builtins.mapAttrs (_: hutils.enable-unit-ids-for-newer-ghc) prev.haskell.compiler.native-bignum;
                };
            };
          };

          smaller-haskell-overlay = final: prev: {
            haskellPackages = hutils.fixedExtend (hutils.smaller-hpkgs prev.haskell.packages.native-bignum.ghc967) (_: prev2: {
              # Make everything smaller at the core by altering arguments to mkDerivation.
              # This is hacky but is needed because Isabelle’s naproche dependency cannot
              # be coerced to not do e.g. profiling by standard Haskell infrastructure
              # because it’s not a Haskell package so hlib.disableLibraryProfiling
              # doesn’t work.
              mkDerivation = x: prev2.mkDerivation (x // {
                doHaddock                 = false;
                enableLibraryProfiling    = false;
                enableExecutableProfiling = false;
                # enableSharedExecutables   = false;
                # enableSharedLibraries     = false;
              });
            });

            haskell = prev.haskell // {
              packages = builtins.mapAttrs (_: hutils.smaller-hpkgs-no-ghc) prev.haskell.packages // {
                native-bignum = builtins.mapAtrs (_: hutils.smaller-hpkgs-no-ghc) prev.haskell.packages.native-bignum;
              };
            };
          };

          # Tests of these packages fail, presumable because of -march.
          disable-problematic-haskell-crypto-pkgs-checks = prev: prev2: {
            cryptonite              = hlib.dontCheck prev2.cryptonite;
            crypton                 = hlib.dontCheck prev2.crypton;
            # x509-validation         = hlib.dontCheck prev2.x509-validation;
            crypton-x509-validation = hlib.dontCheck prev2.crypton-x509-validation;
            tls                     = hlib.dontCheck prev2.tls;
          };

          temporarily-disable-problematic-haskell-pkgs-checks = prev: prev2: {
            # Fails on GHC 9.6.4, should work on others
            unicode-data = hlib.dontCheck prev2.unicode-data;
          };

          haskell-disable-checks-overlay = _: prev: {

            haskellPackages = hutils.fixedExtend prev.haskellPackages
              (_: prev2: temporarily-disable-problematic-haskell-pkgs-checks prev prev2 // disable-problematic-haskell-crypto-pkgs-checks prev prev2);

            haskell = prev.haskell // {
              packages = prev.haskell.packages // {
                # Doesn’t work: overwrites changes made by ‘smaller-haskell-overlay’.
                # ghc962 = prev.haskell.packages.ghc962.override {
                #   overrides = _: prev2: {
                #     x509-validation = hlib.dontCheck prev2.x509-validation;
                #   };
                # };

                # ghc94 = hutils.fixedExtend prev.haskell.packages.ghc94 (_: prev2: {
                #   x509-validation = hlib.dontCheck prev2.x509-validation;
                # });

                # ghc947 = hutils.fixedExtend prev.haskell.packages.ghc947 (_: prev2: {
                #   x509-validation = hlib.dontCheck prev2.x509-validation;
                # });

                # ghc964 = hutils.fixedExtend prev.haskell.packages.ghc964 (_: prev2: temporarily-disable-problematic-haskell-pkgs-checks prev prev2 // disable-problematic-haskell-crypto-pkgs-checks prev prev2);
                ghc965 = hutils.fixedExtend prev.haskell.packages.ghc965 (_: prev2: temporarily-disable-problematic-haskell-pkgs-checks prev prev2 // disable-problematic-haskell-crypto-pkgs-checks prev prev2);
                ghc966 = hutils.fixedExtend prev.haskell.packages.ghc966 (_: prev2: temporarily-disable-problematic-haskell-pkgs-checks prev prev2 // disable-problematic-haskell-crypto-pkgs-checks prev prev2);
                ghc967 = hutils.fixedExtend prev.haskell.packages.ghc967 (_: prev2: temporarily-disable-problematic-haskell-pkgs-checks prev prev2 // disable-problematic-haskell-crypto-pkgs-checks prev prev2);
              };
            };
          };

          fixes-overlay = final: prev: {
            # To avoid infinite recursion
            cabal2nix-unwrapped = hlib.justStaticExecutables
              (final.haskell.packages.native-bignum.ghc967.generateOptparseApplicativeCompletions ["cabal2nix"]
                final.haskell.packages.native-bignum.ghc967.cabal2nix);
          };

          # Remove dependency on mcfgthreads mingw library. If we keep it
          # then cross-compiling cabal will have a hard time building network
          # packge because it will try to link executables to see whether all
          # libraries are available but without properly passed mcfgthreads
          # the linking will fail.
          use-win32-thread-model-overlay = final: prev: {
            threadsCross = {
              model = "win32";
              package = null;
            };
          };


          # nixpkgs-18-09 = builtins.fetchTarball {
          #   url    = "https://github.com/NixOS/nixpkgs/archive/a7e559a5504572008567383c3dc8e142fa7a8633.tar.gz";
          #   sha256 = "sha256:16j95q58kkc69lfgpjkj76gw5sx8rcxwi3civm0mlfaxxyw9gzp6";
          # };
          #
          # nixpkgs-19-09 = builtins.fetchTarball {
          #   url    = "https://github.com/NixOS/nixpkgs/archive/75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1.tar.gz";
          #   sha256 = "sha256:157c64220lf825ll4c0cxsdwg7cxqdx4z559fdp7kpz0g6p8fhhr";
          # };

          pinned-pkgs = {
            nixpkgs-18-09 = import nixpkgs-18-09 { inherit system; };
            nixpkgs-19-09 = import nixpkgs-19-09 { inherit system; };
            nixpkgs-20-03 = import nixpkgs-20-03 { inherit system; };
            nixpkgs-20-09 = import nixpkgs-20-09 { inherit system; };
            nixpkgs-22-11 = import nixpkgs-22-11 { inherit system; };
            nixpkgs-23-11 = import nixpkgs-23-11 { inherit system; };
          };

          # pkgs = import nixpkgs {
          #   inherit system;
          #   overlays = self.overlays.host;
          # };
          #
          # pkgs-cross-win = import nixpkgs-unstable {
          #   inherit system;
          #   # inherit (arch) localSystem;
          #
          #   config = self.config.cross.win;
          #
          #   overlays = self.overlays.cross.win;
          # };

          host-overlay = lib.composeManyExtensions [
            fixes-overlay
            haskell-disable-checks-overlay
            smaller-haskell-overlay
            enable-ghc-unit-ids-overlay
          ];

      in {

        lib = {

          # Expects to receive packages with corresponding overlays in this flake applied.
          # Other overlays may be applied as well.
          derive-ghcs = vanilla-pkgs: cross-win-pkgs:
            import ./haskell.nix {
              inherit lib hlib hutils;
              inherit pinned-pkgs;
              pkgs = vanilla-pkgs;
              pkgs-cross-win = cross-win-pkgs;
              is-32-bits = system == "i686-linux";
            };
        };

        # (builtins.getFlake "path:/path/to/directory").packages.x86_64-linux.default
        # packages = {
        #   host = ;
        #   cross = {
        #     win = ;
        #   };
        # };
        #   import ./haskell.nix {
        #   inherit pkgs pkgs-cross-win;
        #   inherit lib hlib hutils;
        #   inherit pinned-pkgs;
        #   is-32-bits = system == "i686-linux";
        # };

        config = {
          host = {};
          cross-win = haskellNix.config;
        };

        overlays = {
          host = host-overlay;
          cross-win =
            lib.composeManyExtensions [
              use-win32-thread-model-overlay
              haskellNix.overlay
              host-overlay
            ];
        };
      }

      #   packages = rec {
      #     hackage-server = inputs.hackage-server.packages.${system}.hackage-server;
      #     run-hackage-build = pkgs.callPackage ./run-hackage-build.nix {};
      #     inherit (pkgs) cabal-install;
      #   };
      #
      #   apps = rec {
      #     # Deployment initialization
      #     init-deployment = flake-utils.lib.mkApp {
      #       drv = pkgs.writeScriptBin "init-deployment" ''
      #         #!/bin/sh
      #         set -e
      #         cd /var/lib/hackage-doc-builder
      #         sudo -u hackage-doc-builder ${self.packages.${system}.hackage-server}/bin/hackage-server init
      #       '';
      #       exePath = "/bin/init-deployment";
      #     };
      #
      #     hackage-build = flake-utils.lib.mkApp {
      #       drv = self.packages.${system}.run-hackage-build;
      #       exePath = "/bin/hackage-build";
      #     };
      #
      #     default = hackage-build;
      #   };
      #
      #   checks = {
      #     default = self.packages.${system}.run-hackage-build;
      #   };
      # }
    );
    # // {
    #   overlays.default = final: super2:
    #     let hsPkgs = final.haskell.packages.ghc96;
    #     in {
    #       hackage-server = inputs.hackage-server.packages.x86_64-linux.hackage-server;
    #       inherit (self.packages.x86_64-linux) run-hackage-build;
    #
    #       cabal-install = hsPkgs.callCabal2nix "cabal-install" "${inputs.cabal}/cabal-install" { inherit (final) Cabal cabal-install-solver hackage-security; };
    #       cabal-install-solver = hsPkgs.callCabal2nix "cabal-install-solver" "${inputs.cabal}/cabal-install-solver" { inherit (final) Cabal; };
    #       Cabal = (hsPkgs.callCabal2nix "Cabal" "${inputs.cabal}/Cabal" { inherit (final) Cabal-syntax; }).overrideAttrs (prev: {
    #         patches = (prev.patches or []) ++ [./cabal-hsc2hs-args-patch.diff];
    #       });
    #       Cabal-syntax = hsPkgs.callCabal2nix "Cabal-syntax" "${inputs.cabal}/Cabal-syntax" { };
    #       Cabal-described = hsPkgs.callCabal2nix "Cabal-described" "${inputs.cabal}/Cabal-described" { };
    #       Cabal-QuickCheck = hsPkgs.callCabal2nix "Cabal-QuickCheck" "${inputs.cabal}/Cabal-QuickCheck" { };
    #       Cabal-tests = hsPkgs.callCabal2nix "Cabal-tests" "${inputs.cabal}/Cabal-tests" { };
    #       Cabal-tree-diff = hsPkgs.callCabal2nix "Cabal-tree-diff" "${inputs.cabal}/Cabal-tree-diff" { };
    #       hackage-security = hsPkgs.callCabal2nix "hackage-security" "${inputs.hackage-security}/hackage-security" { inherit (final) Cabal Cabal-syntax; };
    #     };
    #
    #   nixosModules.doc-builder = {pkgs, ...}: {
    #     imports = [ ./deploy.nix ];
    #     nixpkgs.overlays = [ self.overlays.default ];
    #   };
    # };
}
