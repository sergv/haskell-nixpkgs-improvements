{ pkgs
, pkgs-cross-win
, pinned-pkgs

, hutils
, is-32-bits
}:

let
  hlib = pkgs.haskell.lib;
  lib  = pkgs.lib;

  cabal-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "cabal";
    rev    = "d301de7a1bad90481fe4447a97c4605475ca1d1f"; #"dev";
    sha256 = "sha256-lSdPPeSN9wOJFM+o3ybDePiCNcv0NDHJYMs5i6BHXOE="; #pkgs.lib.fakeSha256;
  };

  doctest-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "doctest";
    rev    = "24ab3f7c16130569e80deb9a94eaadc3ae5e8aef";
    sha256 = "sha256-hI3/HVZAqQu/MYTbhfyOOpUIHDxo4/N41xOxh111MKQ="; #pkgs.lib.fakeSha256;
  };

  fast-tags-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "fast-tags";
    rev    = "6d37e45680bd306c6eca7c4f79eabd64bf649190";
    sha256 = "sha256-8QH3p2dQYNd0g0YKgtrRLrYPNLcE8YqIA7pLVXmJ6PI="; #pkgs.lib.fakeSha256;
  };

  faster-richer-tags-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "faster-richer-tags";
    rev    = "b0b1e3c007781d640e30b8c709bdb487d69c0a51";
    sha256 = "sha256-cG9f8I7ipALIwoa5xSJjREkPZv9oIdSr+vn568li3Xc="; #pkgs.lib.fakeSha256;
  };

  eventlog2html-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "eventlog2html";
    rev    = "1d4fc8cf0793e126eca1d7ccb73f0969b4781263";
    sha256 = "sha256-WVmvPmMl+UN5X9bJqcJNkReM/D5WSCo5mlGWALYipXo="; #pkgs.lib.fakeSha256;
  };

  # hpkgs = pkgs.haskell.packages.ghc945;
  # Doesn’t work but could be cool: static executables
  # hpkgs = pkgs.pkgsStatic.haskell.packages.ghc961.override {

  # hpkgs = pkgs.haskell.packages.ghc961.override {

  # Doesn’t work but could be cool: static executables
  # hpkgs948 = pkgs.pkgsStatic.haskell.packages.ghc945.override {

  hpkgs96 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc96;
  hpkgs912 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc912;

  overrideCabal = revision: editedSha: pkg:
    hlib.overrideCabal pkg {
      inherit revision;
      editedCabalFile = editedSha;
    };

  allowGhcReference = x: hlib.overrideCabal x (drv: { disallowGhcReference = false; });

  hpkgsGhcEventsAnalyze = hutils.fixedExtend hpkgs96 (_: old:
    builtins.mapAttrs hutils.makeHaskellPackageAttribSmaller (old // {
      # ghc-events-analyze = old.callHackage "ghc-events-analyze" "0.2.9" {};
      ghc-events-analyze =
        # version alone is not enough to distinguish working package here
        # warn-on-stale-override old
        hlib.doJailbreak
          (old.callHackageDirect
            {
              pkg    = "ghc-events-analyze";
              ver    = "0.2.9";
              sha256 = "sha256-HkHq3lmCsqZW21+n4u7G5OED0ao7CX//jW7qgpjn6a4="; #pkgs.lib.fakeSha256;
            }
            {});
      brick = hlib.doJailbreak old.brick;
    }));

  hpkgsCabal = hutils.fixedExtend haskell-package-sets.host.default (new: old: {
    # ghc = hutils.smaller-ghc(old.ghc);

    # builtins.mapAttrs (_name: value: hlib.doJailbreak value) old //
    Cabal =
      # Jailbreaking leads to infinite recursion because ‘jailbreak-cabal’ depends on ‘Cabal’.
      hlib.dontJailbreak
        (old.callCabal2nix
          "Cabal"
          (cabal-repo + "/Cabal")
          {});
    Cabal-described = old.callCabal2nix
      "Cabal-described"
      (cabal-repo + "/Cabal-described")
      {};
    Cabal-hooks = old.callCabal2nix
      "Cabal-hooks"
      (cabal-repo + "/Cabal-hooks")
      {};
    Cabal-syntax = old.callCabal2nix
      "Cabal-syntax"
      (cabal-repo + "/Cabal-syntax")
      {};
    Cabal-tests = old.callCabal2nix
      "Cabal-tests"
      (cabal-repo + "/Cabal-tests")
      {};
    cabal-install-solver = # hlib.doJailbreak
      (old.callCabal2nix
        "cabal-install-solver"
        (cabal-repo + "/cabal-install-solver")
        {});
    hooks-exe = # hlib.doJailbreak
      (old.callCabal2nix
        "hooks-exe"
        (cabal-repo + "/hooks-exe")
        {});
    # hlib.dontCheck
    # (old.callHackage "cabal-install-solver" "3.8.1.0" {});
    cabal-install = # hlib.doJailbreak
      (old.callCabal2nix
        "cabal-install"
        (cabal-repo + "/cabal-install")
        { inherit (new) Cabal-described Cabal-QuickCheck Cabal-tree-diff Cabal-tests;
        });

    hackage-security =
      # hlib.doJailbreak
      #   (old.callHackage "hackage-security" "0.6.3.1" {});
      # hlib.doJailbreak
      (overrideCabal
        "1"
        "sha256-5yidF8pwnRrPubtDQC68/mwSbv+eC9omvrPGh9isJuo=" #pkgs.lib.fakeSha256
        (old.callHackageDirect
          {
            pkg    = "hackage-security";
            ver    = "0.6.3.1";
            sha256 = "sha256-pbU35af2jqFhAtKDtkFRt4jY4m+BU5rpG1shr8qZiaQ="; #pkgs.lib.fakeSha256;
          }
          {}));

    # semaphore-compat = hlib.markUnbroken old.semaphore-compat;

    # # Force reinstall
    # semaphore-compat = old.callHackage "semaphore-compat" "1.0.0" {};

    # # Disable tests which take around 1 hour!
    # statistics = hlib.dontCheck old.statistics;

    # async = hlib.dontCheck old.async;

    # Requires doctest which requires ghc-paths which doesn’t support Cabal 3.17 we have.
    vector = hlib.dontCheck old.vector;

    # Brings entropy 0.4.1.11 which doesn’t build with Cabal 3.17+
    HTTP = hlib.dontCheck old.HTTP;

    # # file-io = hlib.dontCheck old.file-io;
    #
    # uuid-types = hlib.doJailbreak old.uuid-types;
    # strict = hlib.doJailbreak old.strict;

    # semaphore-compat = hlib.dontCheck
    #   (old.callHackageDirect
    #     {
    #       pkg    = "semaphore-compat";
    #       ver    = "2.0.1";
    #       sha256 = "sha256-171llLfOrmKQ27CLUSWEBLl5c8A+gwSEs7aGV+R6oH4="; #pkgs.lib.fakeSha256;
    #     }
    #     {});

    # unix = hlib.dontCheck
    #   (old.callHackageDirect
    #     {
    #       pkg    = "unix";
    #       ver    = "2.8.6.0";
    #       sha256 = "sha256-Tnkda3SJu5R2O9bYbrw+Fy/OQNxqOfWBP+Zv0jqDI6Q="; #pkgs.lib.fakeSha256;
    #     }
    #     {});

    # tasty = hlib.dontCheck
    #   (old.callHackageDirect
    #     {
    #       pkg    = "tasty";
    #       ver    = "1.5.2";
    #       sha256 = "sha256-ikV62VQAAxsekESCxp7vldxopYiQGoYTCANsvGJlGcs="; #pkgs.lib.fakeSha256;
    #     }
    #     {});

    # ghc-lib-parser = hlib.markBroken old.ghc-lib-parser;
    # ghc-prof = hlib.doJailbreak old.ghc-prof;

    # witherable = hlib.dontCheck
    #   (old.callHackage "witherable" "0.5" {});
    #
    # process = hlib.dontCheck
    #   (old.callHackage "process" "1.6.25.0" {});
    #
    # directory = hlib.dontCheck
    #   (old.callHackage "directory" "1.3.9.0" {});

    # tar = hlib.doJailbreak old.tar;
    # ed25519 = hlib.doJailbreak old.ed25519;
    # indexed-traversable = hlib.doJailbreak old.indexed-traversable;

    # ed25519 = #hlib.dontCheck
    #   (overrideCabal
    #     "7"
    #     "sha256-PbBNfBi55oul7vP6fuygXh4kiVjdGCKQyOawEMge9z4="
    #     #"sha256-JKx7Xz2fo8L3AmKzKfKnXyTn/YKfiMGJs4jvobzWfrI="
    #     (old.callHackageDirect {
    #       pkg = "ed25519";
    #       ver = "0.0.5.0";
    #       sha256 = "sha256-x/8O0KFlj2SDVDKp3IPIvqklmZHfBYKGwygbG48q5Ig=";
    #     }
    #       {}));
  });

  # pkgs.haskell.packages.ghc961
  # args.pkgs.haskellPackages
  threadscopePkgs = hutils.fixedExtend pkgs.haskell.packages.ghc928 (_: old:
    builtins.mapAttrs hutils.makeHaskellPackageAttribSmaller (old // {
      threadscope = hlib.doJailbreak old.threadscope;
    }));

  # nativeDeps = [
  #   pkgs.gmp
  #   pkgs.libffi
  #   pkgs.zlib
  # ];

  mk-relocatable-static-libs-ghc = ghc-pkg:
    ghc-pkg.override (_: {
      enableRelocatedStaticLibs = true;
    });

  # So that I won’t need to litter everywhere with those pesky trivial flake.nix & flak.lock files
  # that only enable zlib. Locks also require regular maintenance, which is unbearable.
  bakedInNativeDeps = [ pkgs.zlib ];

  pkg-config-path   =
    builtins.concatStringsSep ":"
      (builtins.concatMap (x: [(x + "/lib/pkgconfig") (x + "/share/pkgconfig")])
        (builtins.filter (x: x != null)
          (builtins.map (lib.getOutput "dev") bakedInNativeDeps)));

  wrap-cabal = pkg:
    pkgs.runCommand "wrapped-cabal"
      {
        # Will require at runtime both libraries and headers (development files) so we’re
        # taking both.
        buildInputs       = builtins.concatMap (x: if builtins.hasAttr "dev" x then [x x.dev] else [x]) bakedInNativeDeps;
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p "$out/bin"
        makeWrapper "${pkg}/bin/cabal" "$out/bin/cabal" --suffix "PKG_CONFIG_PATH" ":" "${pkg-config-path}"
      '';

  wrap-ghc-arch = old-arch-prefix: new-arch-prefix: old-version: new-version: alias-versions: pkg:
    assert (builtins.isString old-version);
    assert (builtins.isAttrs pkg);
    let old-prefix         = if builtins.isNull old-arch-prefix then "" else "${old-arch-prefix}-";
        new-prefix         = if builtins.isNull new-arch-prefix then "" else "${new-arch-prefix}-";
        new-version-suffix = if builtins.isNull new-version     then "" else "-${new-version}";
        f                  = alias-version:
          assert (builtins.isString alias-version || builtins.isNull alias-version);
          let suffix = if builtins.isNull alias-version then "" else "-${alias-version}";
          in ''ln -s "$out/bin/${old-prefix}$x-${old-version}" "$out/bin/${new-prefix}$x${suffix}"'';

        hasDocs = builtins.hasAttr "doc" pkg; # builtins.elem "doc" pkg.outputs;

        wrapped =
          pkgs.runCommand ("wrapped-ghc-" + old-version)
            {
              nativeBuildInputs = [];
            }
            # ln -s "${pkg}/bin/$x-${version}" "$out/bin/$x-${version}"
            # makeWrapper "${pkg}/bin/$x-${version}" "$out/bin/$x-${version}" --suffix "LD_LIBRARY_PATH" ":" "${pkgs.lib.makeLibraryPath bakedInNativeDeps}"
            ''
              ${if hasDocs
                then
                  ''
                    ln -s ${pkg.doc} "$doc"
                  ''
                else ""}

              mkdir -p "$out/bin"

              for x in ghc ghci ghc-pkg haddock hpc runghc; do

                if [[ -f "${pkg}/bin/${old-prefix}$x-${old-version}" ]]; then
                  ln -s "${pkg}/bin/${old-prefix}$x-${old-version}" "$out/bin/${new-prefix}$x${new-version-suffix}"
                elif [[ -f "${pkg}/bin/${old-prefix}$x-ghc-${old-version}" ]]; then
                  ln -s "${pkg}/bin/${old-prefix}$x-ghc-${old-version}" "$out/bin/${new-prefix}$x${new-version-suffix}"
                elif [[ -f "${pkg}/bin/${old-prefix}$x" ]]; then
                  ln -s "${pkg}/bin/${old-prefix}$x" "$out/bin/${new-prefix}$x${new-version-suffix}"
                else
                  echo "Cannot find source for ‘$x’ in ‘${pkg}/bin’" >&2
                  exit 1
                fi

                ${if builtins.isList alias-versions
                  then builtins.concatStringsSep "\n" (builtins.map f alias-versions)
                  else f alias-versions}
              done
            '';

        reapply-this = x:
          wrap-ghc-arch
            old-arch-prefix
            new-arch-prefix
            old-version
            new-version
            alias-versions
            x;

        final = (wrapped.overrideAttrs (old: {
          outputs =
            if hasDocs
            then ["out" "doc"]
            else ["out"];
        })) // {
          # These cannot go under overrideAttrs since they’re not arguments to mkDerivation
          overrideAttrs = x: reapply-this (pkg.overrideAttrs x);
          # overrideDerivation = x: reapply-this (pkg.overrideDerivation x);
          override = x: reapply-this (pkg.override x);
        };

    in
    final;

  wrap-ghc = version: alias-versions: pkg:
    wrap-ghc-arch null null version version alias-versions pkg;

  wrap-ghc-filter-selected-args = filtered-args: version: alias-version: pkg:
    let wrapped-ghc = pkgs.writeShellScript ("filtering-ghc-" + version)
          ''
            args=("''${@}")

            len="''${#args[@]}"

            for (( i = 0; i < "$len"; ++i )); do
              case "''${args[i]}" in
                ${builtins.concatStringsSep " | " filtered-args} )
                  unset args[i];
                ;;
              esac
            done

            exec "${pkg}/bin/ghc-${version}" "''${args[@]}"
          '';
    in
    pkgs.runCommand ("wrapped-filtering-ghc-" + version)
      {
        buildInptus = [ wrapped-ghc ];
      }
      ''
        mkdir -p "$out/bin"
        ln -s "${wrapped-ghc}" "$out/bin/ghc-${version}"
        ln -s "$out/bin/ghc-${version}" "$out/bin/ghc-${alias-version}"

        for x in ghci ghc-pkg haddock hpc runghc; do

          if [[ -f "${pkg}/bin/$x-${version}" ]]; then
            ln -s "${pkg}/bin/$x-${version}" "$out/bin/$x-${version}"
          elif [[ -f "${pkg}/bin/$x-ghc-${version}" ]]; then
            ln -s "${pkg}/bin/$x-ghc-${version}" "$out/bin/$x-${version}"
          elif [[ -f "${pkg}/bin/$x" ]]; then
            ln -s "${pkg}/bin/$x" "$out/bin/$x-${version}"
          else
            echo "Cannot find source for ‘$x’ in ‘${pkg}/bin’" >&2
            exit 1
          fi

          ln -s "$out/bin/$x-${version}" "$out/bin/$x-${alias-version}"
        done
      '';

  wrap-ghc-filter-hide-source-paths = wrap-ghc-filter-selected-args [
    "-fhide-source-paths"
  ];

  wrap-ghc-filter-all = wrap-ghc-filter-selected-args [
    "-fhide-source-paths"
    "-fprint-potential-instances"
    "-fprint-expanded-synonyms"
  ];

  wrap-ghc-rename = version: new-suffixes: pkg:
    let f = suffix:
          assert (builtins.isString suffix && !(suffix == ""));
          ''ln -s "${pkg}/bin/$x-${version}" "$out/bin/$x-${suffix}"'';
    in pkgs.runCommand ("wrapped-renamed-ghc-" + version)
      {
        # buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p "$out/bin"
        for x in ghc ghci ghc-pkg haddock-ghc runghc; do
          ${builtins.concatStringsSep "\n" (builtins.map f new-suffixes)}
        done
      '';

  disableAllHardening = x: x.overrideAttrs (old: {
    hardeningDisable = ["all"];
  });

  ghc-platform =
    { mkDerivation, base, lib
      # GHC source tree to build ghc-toolchain from
    , ghcSrc
    , ghcVersion
    }:
    mkDerivation {
      pname                 = "ghc-platform";
      version               = ghcVersion;
      src                   = ghcSrc;
      postUnpack            = ''sourceRoot="$sourceRoot/libraries/ghc-platform"'';
      libraryHaskellDepends = [base];
      description           = "Platform information used by GHC and friends";
      license               = pkgs.lib.licenses.bsd3;
    };

  ghc-toolchain =
    { mkDerivation, base, directory, filepath, ghc-platform, lib
    , process, text, transformers
      # GHC source tree to build ghc-toolchain from
    , ghcVersion
    , ghcSrc
    }:
    mkDerivation {
      pname                 = "ghc-toolchain";
      version               = ghcVersion;
      src                   = ghcSrc;
      postUnpack            = ''sourceRoot="$sourceRoot/utils/ghc-toolchain"'';
      libraryHaskellDepends = [base directory filepath ghc-platform process text transformers];
      description           = "Utility for managing GHC target toolchains";
      license               = pkgs.lib.licenses.bsd3;
    };

  build-ghc =
    { base-ghc-to-override,
      build-pkgs,
      version,
      rev,
      sha256,
      debug ? false,
      relocatable-static-libs ? false,
      docs ? true,
      hie-files ? false,
      profiling ? false,
      llvm ? false
    }:
    let ghcSrc = pkgs.fetchgit {
          url = "https://gitlab.haskell.org/ghc/ghc.git";
          inherit rev sha256;
        };

        ghc' = base-ghc-to-override.override (old: old // {
          bootPkgs = build-pkgs;
          inherit ghcSrc;
        });

        callPackage' = f: args: build-pkgs.callPackage f ({
          inherit ghcSrc;
          ghcVersion = version;
        } // args);

        ghc-platform-pkg  = callPackage' ghc-platform {};
        ghc-toolchain-pkg = callPackage' ghc-toolchain { ghc-platform = ghc-platform-pkg; };

        enableProfiling = profiling && !is-32-bits;
    in
    disableAllHardening ((ghc'.override (old: old // {
      # stdenv             = pkgs.llvmPackages.stdenv;

      # Need to disable for 32 bit builds, otherwise some big files within cannot be
      # compiled due to ld.gold exhausting memory.
      enableProfiledLibs = enableProfiling;

      enableShared = true;
      enableRelocatedStaticLibs = relocatable-static-libs;

      ghcFlavour =
        let
          hie-files-flavour =
            if hie-files && hutils.version-ge version "9.14"
            then "+hie_files"
            else "";
          debug-info =
            if debug
            then "+debug_info"
            else "";
          profiling-flavour =
            if enableProfiling
            then ""
            else "+no_profiled_libs";
          llvm-flavour =
            if llvm
            then "+llvm"
            else "";
          base       =
            if builtins.hasAttr "ghcFlavour" old
            then old.ghcFlavour
            else "release+split_sections";
        in
        base + hie-files-flavour + debug-info + profiling-flavour + llvm-flavour;

      enableNativeBignum = true;

      enableDocs         = docs; #false;

      bootPkgs = build-pkgs;

      hadrian  = hlib.doJailbreak (ghc'.hadrian.override (old2: old2 // {
        inherit ghcSrc;
        ghc-platform  = hutils.makeHaskellPackageSmaller ghc-platform-pkg;
        ghc-toolchain = hutils.makeHaskellPackageSmaller ghc-toolchain-pkg;
        ghcVersion    = version;
      }));

      inherit ghcSrc;
    })).overrideAttrs (old: {
      inherit version;
      # Silence warning about overriding ‘version’ field without touching ‘src’.
      __intentionallyOverridingVersion = true;

      postInstall =
        builtins.replaceStrings [ base-ghc-to-override.version ] [ "${version}" ] old.postInstall;

      dontStrip = debug;

      preConfigure = old.preConfigure +
        # builtins.replaceStrings [ base-ghc-to-override.version ] [ "${version}" ] old.preConfigure +

        # Do this if taking sources from git directly.
        ''
          echo ${version} > VERSION
          echo ${rev} > GIT_COMMIT_ID
          ./boot
        '';
    }));

  cabal = wrap-cabal (allowGhcReference (hlib.justStaticExecutables hpkgsCabal.cabal-install));

  latest-ghc-field         = "ghc9124";
  latest-ghc-short-version = "9.12";

  # ghc-build-pkgs = pkgs.haskell.packages.native-bignum.ghc9101;
  # ghc-build-pkgs = hpkgsCabal;
  # ghc-build-pkgs = hpkgs912;
  ghc-build-pkgs = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc910;
  latest-ghc-pkg = pkgs.haskell.compiler.native-bignum.ghc9141;

  ghc912-pkg = pkgs.haskell.compiler.native-bignum.ghc9124;

  build-914-ghc =
    cfg:
    build-ghc
      ({
        base-ghc-to-override    = latest-ghc-pkg;
        build-pkgs              = ghc-build-pkgs;
        version                 = "9.14.1";
        rev                     = "902339d332fb4ce2b3c87dcac1ee6495d41ad886";
        sha256                  = "sha256-wsClYVCoinEem20jHTFjiTOMgU8MsEaZ1RAgAMsK078="; #pkgs.lib.fakeSha256;
      } //
      cfg);


  ghc914-pkg           = pkgs.haskell.compiler.native-bignum.ghc9141;
  ghc914-pie-pkg       = build-914-ghc {
    debug                   = false;
    relocatable-static-libs = true;
    docs                    = false;
  };
  ghc914-pie-debug-pkg = build-914-ghc {
    debug                   = true;
    relocatable-static-libs = true;
    docs                    = false;
  };

  dev-ghc-version = "9.14.1";
  dev-ghc-short-version = "9.14";
  build-dev-ghc =
    cfg:
    build-ghc
      ({
        base-ghc-to-override    = latest-ghc-pkg;
        build-pkgs              = ghc-build-pkgs;
        version                 = "9.14.1";
        rev                     = "902339d332fb4ce2b3c87dcac1ee6495d41ad886";
        sha256                  = "sha256-wsClYVCoinEem20jHTFjiTOMgU8MsEaZ1RAgAMsK078="; #pkgs.lib.fakeSha256;
      } //
      cfg);

  dev-ghc-pkg = build-dev-ghc {
    debug                   = false;
    relocatable-static-libs = false;
    docs                    = false;
  };

  # Caused by process 1.6.30 tha conflicts with boot library but
  # ultimately only affects tests that depend on ‘tasty-inspection-testing’
  # or doctests (i.e. packages that involve ghc).
  process-on-914-workaround = x: hlib.allowInconsistentDependencies x;

  warn-on-stale-override = old: new-pkg:
    let
      pkg-name    = new-pkg.pname;
      new-version = new-pkg.version;
      noOverride  =
        builtins.hasAttr pkg-name old &&
        old."${pkg-name}" != null &&
        pkgs.lib.versionAtLeast old."${pkg-name}".version new-version;
    in
    pkgs.lib.warnIf
      noOverride
      "${pkg-name} >= ${new-version} is now in nixpkgs, the override is no longer needed"
      (if noOverride then old."${pkg-name}" else new-pkg);

  haskell-package-sets =
    let
      mkGhc914Pkgs = ghc-pkg:
        let
          hpkgs-base =
            hutils.premap-hpkgs-mk-derivation
              (args: args // {
                jailbreak = true;
                # doHaddock = false;
                # doCheck = true;
                # doBenchmark = false;
                # doHoogle = true;
                doHaddock = false;
                enableLibraryProfiling = false;
                # enableExecutableProfiling = false;
              })
              pkgs.haskell.packages.native-bignum.ghc9141;
          hpkgs =
            hutils.fixedExtend hpkgs-base (new: old:
              builtins.mapAttrs
                (_name: x: x)
                # (hutils.onlyApplyToHaskellPackages hlib.allowInconsistentDependencies)
                (/* old // */ {
                  ghc = ghc-pkg;

                  enummapset =
                    # version alone is not enough to distinguish working package here
                    # warn-on-stale-override old
                      (old.callCabal2nix
                        "enummapset"
                        (pkgs.fetchFromGitHub {
                          owner  = "Mikolaj";
                          repo   = "enummapset";
                          rev    = "601e862fbf93cf03ed297016920fa0c0110a5e4c";
                          sha256 = "sha256-H+sw32kl4AVJ7dTJkZpYt4Z4uXOgLWE3SoyxAAtiiAs="; #pkgs.lib.fakeSha256;
                        })
                        {});

                  # Broken with QuickCheck 2.18
                  dlist = hlib.dontCheck old.dlist;
                  # Take too long
                  statistics = hlib.dontCheck old.statistics;

                  QuickCheck =
                    warn-on-stale-override old
                      (hlib.dontCheck
                        (old.callHackage "QuickCheck" "2.18.0.0" {}));

                  quickcheck-instances =
                    warn-on-stale-override old
                      (old.callHackage "quickcheck-instances" "0.4" {});

                  skeletest =
                    warn-on-stale-override old
                      (process-on-914-workaround
                        (old.callHackage "skeletest" "0.4.2" {}));

                  process =
                    warn-on-stale-override old
                      (hlib.dontCheck
                        (old.callHackageDirect
                          {
                            pkg    = "process";
                            ver    = "1.6.30.0";
                            sha256 = "sha256-grK+qHD8wGYaHMd1a0KwsJyzml1XeXnz/1pPNg7p3aA="; #pkgs.lib.fakeSha256;
                          }
                          {}));

                  alfred-margaret =
                    warn-on-stale-override old
                      (old.callHackageDirect
                        {
                          pkg    = "alfred-margaret";
                          ver    = "2.1.1.1";
                          sha256 = "sha256-dVU9GUnVqwQQPoucQ51aX22QkX1kX1DE+1d3/UOHLCI="; #pkgs.lib.fakeSha256;
                        }
                        {});

                  prettyprinter-combinators =
                    warn-on-stale-override old
                      (old.callHackageDirect
                        {
                          pkg    = "prettyprinter-combinators";
                          ver    = "0.1.4";
                          sha256 = "sha256-axNM4gwijzvvwxMhM/D4v8bABHzTBfweLGeQJgNgYNk="; #pkgs.lib.fakeSha256;
                        }
                        {});

                  vector = process-on-914-workaround old.vector;
                  tasty-inspection-testing = process-on-914-workaround old.tasty-inspection-testing;
                  toml-reader = process-on-914-workaround old.toml-reader;
                  doctest-parallel = process-on-914-workaround old.doctest-parallel;
                  regex-tdfa = process-on-914-workaround old.regex-tdfa;
                  weeder = process-on-914-workaround old.weeder;

                  fast-tags =
                    # hlib.dontCheck
                    (old.callCabal2nix "fast-tags" fast-tags-repo {});

                  faster-richer-tags =
                    hlib.dontJailbreak
                      (old.callCabal2nix "faster-richer-tags" faster-richer-tags-repo {});

                  eventlog2html =
                    hlib.doJailbreak
                      (old.callCabal2nix "eventlog2html" eventlog2html-repo {});

                  doctest =
                    (x: hlib.dontCheck (process-on-914-workaround x))
                      ((old.callCabal2nix "doctest" doctest-repo {}).overrideAttrs (oldAttrs: oldAttrs // {
                        # buildInputs = [haskellPackages.GLFW-b];
                        configureFlags = oldAttrs.configureFlags ++ [
                          # cabal config passes RTS options to GHC so doctest will receive them too
                          # ‘cabal repl --with-ghc=doctest’
                          "--ghc-option=-rtsopts"
                        ];
                      }));

                  # Tests don’t pass with ghc 9.14.
                  ghc-prof = hlib.dontCheck old.ghc-prof;
                  generic-lens = hlib.dontCheck old.generic-lens;

                  algebraic-graphs =
                    warn-on-stale-override old
                      (process-on-914-workaround
                        (old.callCabal2nix
                          "alga"
                          (pkgs.fetchFromGitHub {
                            owner  = "snowleopard";
                            repo   = "alga";
                            rev    = "d4e43fb42db05413459fb2df493361d5a666588a";
                            sha256 = "sha256-sQRAjHV+bor/SBt/zDtcw3tN1ir7xjjevEdyYqilNWg="; #pkgs.lib.fakeSha256;
                          })
                          {}));
                }));
        in
        hutils.fixedExtend hpkgs (new: old: {
          buildHaskellPackages =
            hutils.fixedExtend old.buildHaskellPackages (new2: old2: {
              # Without this tools will be built with old ghc derivation package.
              ghc = ghc-pkg;
            });
          # Not needed any more.
          # hutils.fixedExtend old.buildHaskellPackages
          # (_new2: _old2: {
          #   # Override build tools used by Haskell mkDerivation to
          #   # avoid references to ghcHEAD compiler.
          #   hscolour        = new.hscolour; #pkgs.haskell.packages.native-bignum.ghc912.hscolour;
          #   jailbreak-cabal = new.jailbreak-cabal; #pkgs.haskell.packages.native-bignum.ghc912.jailbreak-cabal;
          # });
        });

    in {
      host = rec {
        default           = ghc914;
        default-pie       = ghc914-pie;
        default-pie-debug = ghc914-pie-debug;

        ghc914           = mkGhc914Pkgs ghc914-pkg;
        ghc914-pie       = mkGhc914Pkgs ghc914-pie-pkg;
        ghc914-pie-debug = mkGhc914Pkgs ghc914-pie-debug-pkg;
      };
    };

in {

  inherit haskell-package-sets;

  ghc = {
    host = rec {
      ghc710     = wrap-ghc-filter-all               "7.10.3" "7.10"        pinned-pkgs.nixpkgs-18-09.haskell.packages.ghc7103.ghc;
      ghc80      = wrap-ghc-filter-hide-source-paths "8.0.2"  "8.0"         pinned-pkgs.nixpkgs-18-09.haskell.packages.ghc802.ghc;

      ghc82      = wrap-ghc                          "8.2.2"  "8.2"         pinned-pkgs.nixpkgs-19-09.haskell.packages.ghc822.ghc;
      ghc84      = wrap-ghc                          "8.4.4"  "8.4"         pinned-pkgs.nixpkgs-20-03.haskell.packages.ghc844.ghc;

      ghc86      = wrap-ghc                          "8.6.5"  "8.6"         pinned-pkgs.nixpkgs-20-09.haskell.packages.ghc865.ghc;

      ghc88      = wrap-ghc                          "8.8.4"  "8.8"         pinned-pkgs.nixpkgs-23-11.haskell.packages.ghc884.ghc;

      ghc810     = wrap-ghc                          "8.10.7" "8.10"        pinned-pkgs.nixpkgs-23-11.haskell.packages.ghc8107.ghc;
      # ghc902    = wrap-ghc                          "9.0.2"  "9.0"         (hutils.smaller-ghc pinned-pkgs.nixpkgs-23-11.haskell.packages.ghc902.ghc);
      ghc92      = wrap-ghc                          "9.2.8"  "9.2"         pinned-pkgs.nixpkgs-23-11.haskell.packages.ghc928.ghc;
      ghc94      = wrap-ghc                          "9.4.8"  "9.4"         pinned-pkgs.nixpkgs-23-11.haskell.packages.ghc948.ghc;

      ghc96      = wrap-ghc                          "9.6.7"  "9.6"         pkgs.haskell.compiler.native-bignum.ghc967;
      ghc98      = wrap-ghc                          "9.8.4"  "9.8"         pkgs.haskell.compiler.native-bignum.ghc984;

      ghc910     = wrap-ghc                          "9.10.2" "9.10"        pkgs.haskell.compiler.native-bignum.ghc9103;

      ghc912     = wrap-ghc                          "9.12.4" "9.12"        ghc912-pkg;

      ghc914     = wrap-ghc                          "9.14.1" ["9.14" null] ghc914-pkg;

      default    = ghc914;

      # callPackage = newScope {
      #   haskellLib = haskellLibUncomposable.compose;
      #   overrides = pkgs.haskell.packageOverrides;
      # };

      # ghc961  = wrap-ghc "9.6.0.20230111" (import ./ghc-9.6.1-alpha1.nix {
      #   inherit (pkgs)
      #     lib
      #     stdenv
      #     fetchurl
      #     perl
      #     gcc
      #     ncurses5
      #     ncurses6
      #     gmp
      #     libiconv
      #     numactl
      #     libffi
      #     llvmPackages
      #     coreutils
      #     targetPackages;
      #
      #   # llvmPackages = pkgs.llvmPackages_13;
      # });

    };

  } //
  (if pkgs-cross-win == null
   then {}
   else {
     cross-win = import ./cross-win.nix {
       inherit pkgs pkgs-cross-win lib latest-ghc-field latest-ghc-short-version;
       inherit cabal;
     };
   });

  lib = {
    inherit build-ghc;
  };

  tools = {
    inherit cabal;

    alex               = hlib.justStaticExecutables haskell-package-sets.host.default.alex;
    happy              = hlib.justStaticExecutables haskell-package-sets.host.default.happy;
    doctest            = allowGhcReference (hlib.justStaticExecutables haskell-package-sets.host.default.doctest);
    eventlog2html      = hlib.justStaticExecutables haskell-package-sets.host.default.eventlog2html;
    fast-tags          = hlib.justStaticExecutables haskell-package-sets.host.default.fast-tags;
    faster-richer-tags = hlib.justStaticExecutables haskell-package-sets.host.default.faster-richer-tags;
    ghc-events-analyze = allowGhcReference (hlib.justStaticExecutables hpkgsGhcEventsAnalyze.ghc-events-analyze);
    hp2pretty          = hlib.justStaticExecutables haskell-package-sets.host.default.hp2pretty;
    pretty-show        = hlib.justStaticExecutables haskell-package-sets.host.default.pretty-show;
    profiterole        = hlib.justStaticExecutables haskell-package-sets.host.default.profiterole;
    weeder             = hlib.justStaticExecutables haskell-package-sets.host.default.weeder;
    # hspec-discover     = hlib.justStaticExecutables hpkgs96.hspec-discover;
    # threadscope        = threadscopePkgs.threadscope;
  };

}
