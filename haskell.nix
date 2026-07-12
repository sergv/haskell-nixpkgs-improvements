{ pkgs
, pkgs-cross-win
, pinned-pkgs

, lib
, hlib
, hutils
, is-32-bits
}:

let
  cabal-repo = pkgs.fetchFromGitHub {
    owner  = "sergv";
    repo   = "cabal";
    rev    = "ebd0f9435b3b2576c8ce620bcc0eefec82645598"; #"dev";
    sha256 = "sha256-dBTcZVrgvjtCMrdTG848XNWZZqj/dpkWuU8TX5tLXuU="; #pkgs.lib.fakeSha256;
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

  # hpkgs948 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc948;
  hpkgs96 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc96;
  hpkgs910 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc910;
  hpkgs912 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc912;
  hpkgs914 = haskell-package-sets.host.default;
  # hpkgs981 = hutils.smaller-hpkgs-no-ghc pkgs.haskell.packages.native-bignum.ghc981;

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

  hpkgsEventlog2html = hutils.fixedExtend hpkgs914 (_: old: {

    eventlog2html = hlib.doJailbreak (old.callCabal2nix "eventlog2html" eventlog2html-repo {});

    # vector-binary-instances = hlib.doJailbreak old.vector-binary-instances;

    # ghc-events = old.callHackage "ghc-events" "0.20.0.0" {};
    # Disable tests which take around 1 hour!
    # statistics = hlib.dontCheck old.statistics;
  });

  hpkgsProfiterole = hutils.fixedExtend hpkgs912 (final: old:
    builtins.mapAttrs hutils.makeHaskellPackageAttribSmaller (old // {
      ghc-prof = hlib.dontCheck old.ghc-prof;
    }));

  # pkgs.haskell.packages.ghc961
  hpkgsCabal = hutils.fixedExtend hpkgs914 (new: old: {
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

    semaphore-compat = hlib.dontCheck
      (old.callHackageDirect
        {
          pkg    = "semaphore-compat";
          ver    = "2.0.0";
          sha256 = "sha256-s7SAtaEFR+QJ9ZeWn/0k/qq5PgwU1BsiSu/HUoDrQBo="; #pkgs.lib.fakeSha256;
        }
        {});

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

  hpkgsFastTags = hutils.fixedExtend hpkgs914 (_: old: {
    fast-tags = hlib.dontCheck (old.callCabal2nix "fast-tags" fast-tags-repo {});
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

  relocatable-static-libs-ghc = ghc-pkg:
    ghc-pkg.override (_: {
      enableRelocatedStaticLibs = true;
    });

  # So that I won’t need to litter everywhere with those pesky trivial flake.nix & flak.lock files
  # that only enable zlib. Locks also require regular maintenance, which is unbearable.
  bakedInNativeDeps = [ pkgs.zlib ];

  wrap-cabal = pkg:
    pkgs.runCommand "wrapped-cabal"
      {
        # Will require at runtime both libraries and headers (development files) so we’re
        # taking both.
        buildInputs       = pkgs.lib.lists.concatMap (x: if builtins.hasAttr "dev" x then [x x.dev] else [x]) bakedInNativeDeps;
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p "$out/bin"
        makeWrapper "${pkg}/bin/cabal" "$out/bin/cabal" --suffix "PKG_CONFIG_PATH" ":" "${pkgs.lib.makeSearchPathOutput "dev" "share/pkgconfig" bakedInNativeDeps}"
      '';

  symlink-exe-to = pkg: source: dests:
    assert (builtins.isString source);
    let f = dest:
          assert (builtins.isString dest || builtins.isNull dest);
          let suffix = if builtins.isNull dest then "" else "-${dest}";
          in ''ln -s "${pkg}/bin/${source}" "$out/bin/${dest}"'';
    in
    pkgs.runCommand ("wrapped-" + source)
      {
        nativeBuildInputs = [];
      }
      ''
        mkdir -p "$out/bin"
        ${if builtins.isList dests
          then builtins.concatStringsSep "\n" (builtins.map f dests)
          else f dests}
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
      license               = lib.licenses.bsd3;
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
      license               = lib.licenses.bsd3;
    };

  build-ghc = { base-ghc-to-override, build-pkgs, version, rev, sha256 }:

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

    in
    disableAllHardening ((ghc'.override (old: old // {
      # stdenv             = pkgs.llvmPackages.stdenv;

      # Need to disable for 32 bit builds, otherwise some big files within cannot be
      # compiled due to ld.gold exhausting memory.
      enableProfiledLibs = !is-32-bits;

      enableShared = true;
      enableRelocatedStaticLibs = false; #true;

      ghcFlavour =
        let hie_files =
              if hutils.version-ge version "9.14"
              then "+hie_files"
              else "";
            base =
              if builtins.hasAttr "ghcFlavour" old
              then old.ghcFlavour
              else "release+split_sections";
        in
        base + hie_files;

      enableNativeBignum = true;

      # enableDocs         = true; #false;

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

      preConfigure = old.preConfigure +
      # builtins.replaceStrings [ base-ghc-to-override.version ] [ "${version}" ] old.preConfigure +

      # Do this if taking sources from git directly.
      ''
        echo ${version} > VERSION
        echo ${rev} > GIT_COMMIT_ID
        ./boot
      '';
    }));

  cabal = wrap-cabal (hlib.justStaticExecutables hpkgsCabal.cabal-install);

  latest-ghc-field         = "ghc9124";
  latest-ghc-short-version = "9.12";

  # ghc-build-pkgs = pkgs.haskell.packages.native-bignum.ghc9101;
  # ghc-build-pkgs = hpkgsCabal;
  ghc-build-pkgs = hpkgs910;
  latest-ghc-pkg = pkgs.haskell.compiler.native-bignum.9141;

  ghc912-pkg = pkgs.haskell.compiler.native-bignum.ghc9124;

  ghc914-pkg = pkgs.haskell.compiler.native-bignum.ghc9141;

  dev-ghc-version = "9.14.1";
  dev-ghc-short-version = "9.14";
  dev-ghc-pkg = build-ghc {
    base-ghc-to-override = latest-ghc-pkg;
    build-pkgs           = ghc-build-pkgs;
    version              = "9.14.1";
    rev                  = "902339d332fb4ce2b3c87dcac1ee6495d41ad886";
    sha256               = pkgs.lib.fakeSha256;
  };

  ghc-win =
    let
      # Defines ‘x86_64-w64-mingw32-ghc’, ‘x86_64-w64-mingw32-ghc-pkg’, and ‘x86_64-w64-mingw32-hsc2hs,
      win-pkgs = pkgs-cross-win.pkgsCross.mingwW64;

      versionGE = to-check: target-version:
        builtins.compareVersions to-check target-version >= 0;

      # wine = pkgs-cross-win.wine64Packages.minimal.overrideAttrs (old: {
      #   patches = builtins.filter (x: !(pkgs.lib.strings.hasSuffix "wine-add-dll-directory-11.patch" x)) old.patches;
      # });

      wine = pkgs.wine64Packages.minimal.overrideAttrs (old: {
        # Issue with UNC device file paths is fixed in nixos starting from 26.05.
        # Avoid dependency on X11
        configureFlags = (old.configureFlags or []) ++ [ "--without-x" ];
      });

      ghc-win-pkg = (win-pkgs.pkgsBuildHost.haskell-nix.compiler."${latest-ghc-field}".override (_: {
        enableNativeBignum = true;
      })).overrideAttrs(old: {
        # haskell.nix ghc builder does not expose hadrian argumens so we have to hack
        # hadrian shell invocation here instead of using hutils.enable-unit-ids-for-newer-ghc :[
        buildPhase = builtins.replaceStrings [ " --flavour=" ] [ " --hash-unit-ids --flavour=" ] old.buildPhase;
      }); # pkgsBuildHost == buildPackages

      haskell-win-runner-dll-pkgs = [
        # win-pkgs.libffi
        # win-pkgs.gmp
        # win-pkgs.windows.mcfgthreads
        # win-pkgs.windows.pthreads
        # win-pkgs.buildPackages.gcc.cc
      ];

      win-exes = win-pkgs.haskell-nix.iserv-proxy-exes."${latest-ghc-field}";

      win-iserv-proxy-interpreter = win-exes.iserv-proxy-interpreter.override (old: {
        # Without these flags the executable with fail with error
        # Mingw-w64runtimefailure:
        # 32 bit pseudo relocation at 00000001401203C6 out of range, targeting 0000000000468160, yielding the value FFFFFFFEC0347D96.
        setupBuildFlags = ["--ghc-option=-optl-Wl,--disable-dynamicbase,--disable-high-entropy-va,--image-base=0x400000" ];
      });

      wine-iserv-wrapper-script =
        let
          iserv-proxy  = win-exes.iserv-proxy;
          exe-name     = win-iserv-proxy-interpreter.exeName;
          no-load-call = lib.optionalString (exe-name != "remote-iserv.exe") "--no-load-call";
          # win-pkgs.windows.pthreads - not needed
        in
        pkgs.pkgsBuildBuild.writeScriptBin "iserv-wrapper"
          ''
            #!${pkgs-cross-win.pkgsBuildBuild.bash}/bin/bash

            set -euo pipefail

            ISERV_ARGS=''${ISERV_ARGS:-}
            PROXY_ARGS=''${PROXY_ARGS:-}

            # May lead to a too large environment so best to unset it.
            unset configureFlags
            unset configurePhase
            # Not really needed
            unset pkgsHostTargetAsString

            REMOTE_ISERV=/tmp/iserv-tmpdir
            if [[ ! -d "$REMOTE_ISERV" ]]; then
                mkdir -p "$REMOTE_ISERV/tmp"
                ln -s ${win-iserv-proxy-interpreter}/bin/*.dll "$REMOTE_ISERV"

                for p in ${pkgs.lib.concatStringsSep " " haskell-win-runner-dll-pkgs}; do
                    find "$p" -iname '*.dll' -exec ln -sf {} $REMOTE_ISERV \;
                    find "$p" -iname '*.dll.a' -exec ln -sf {} $REMOTE_ISERV \;
                done

                # Some DLLs have a `lib` prefix but we attempt to load them without the prefix.
                # This was a problem for `double-conversion` package when used in TH code.
                # Creating links from the `X.dll` to `libX.dll` works around this issue.
                for dll in "$REMOTE_ISERV"/*.dll; do
                    small=$(basename "$dll")
                    ln -s "$dll" "$REMOTE_ISERV/''${small#lib}"
                done
            fi

            WINEDLLOVERRIDES="winemac.drv=d" \
                WINEDEBUG=warn-all,fixme-all,-menubuilder,-mscoree,-ole,-secur32,-winediag \
                WINEPREFIX="$REMOTE_ISERV/prefix" \

            ${iserv-proxy}/bin/iserv-proxy "''${@}" --pipe ${lib.getExe wine} ${win-iserv-proxy-interpreter}/bin/${exe-name} "$REMOTE_ISERV/tmp" --stdio ${no-load-call} $ISERV_ARGS
          '';

      wine-run-haskell =
        let dll-path =
              win-pkgs.lib.strings.concatStringsSep
                ";"
                (
                  # win-pkgs.windows.mcfgthreads
                  map (x: "${x}/bin") [win-pkgs.libffi win-pkgs.gmp] ++
                  map (x: "${x}/lib") [win-pkgs.buildPackages.gcc.cc.lib]
                );
        in pkgs-cross-win.pkgsBuildBuild.writeShellApplication {
          name          = "wine-run-haskell";
          runtimeInputs = [
          ];
          text          =
            ''
              WINEDLLOVERRIDES="winemac.drv=d" \
                  WINEDEBUG="-all" \
                  WINEPATH="${dll-path};''${WINEPATH:-}" \
                  ${wine}/bin/wine64 \
                  "''${@}"
            '';
        };

      # "-L${pthreads}/lib"
      # "-L${pthreads}/bin"
      # "-L${gmp}/lib"
      wrap-win-ghc = pkg: ghc-exe: new-names:
        let wrapped =
              pkgs-cross-win.pkgsBuildBuild.writeShellApplication {
                name          = ghc-exe + "-wrapped";
                runtimeInputs = [
                  pkg
                  # So that ghc and its subcommands will be able to run ‘x86_64-w64-mingw32-gcc’
                  win-pkgs.buildPackages.gcc.cc
                  # For ‘x86_64-w64-mingw32-windres’
                  win-pkgs.buildPackages.binutils
                ];
                # "-L${win-pkgs.libffi}/bin" \
                # "-L${win-pkgs.libffi}/lib" \
                # "-L${win-pkgs.gmp}/bin" \
                # "-L${win-pkgs.gmp}/lib" \
                # "-L${win-pkgs.windows.pthreads}/lib" \
                # "-L${win-pkgs.windows.pthreads}/bin" \
                # "-L${win-pkgs.windows.mcfgthreads}/bin" \
                # "-L${win-pkgs.windows.mcfgthreads}/lib" \
                text          =
                  ''
                    ${pkg}/bin/${ghc-exe} \
                      -fexternal-interpreter \
                      -pgmi ${wine-iserv-wrapper-script}/bin/iserv-wrapper \
                      -optc-Wno-incompatible-pointer-types \
                      -L${win-pkgs.windows.pthreads}/lib \
                      -L${win-pkgs.windows.pthreads}/bin \
                      "''${@}"
                  '';
              };
        in symlink-exe-to wrapped wrapped.name new-names;

      wrap-win-ghc-pkg = pkg: exe: new-names:
        let wrapped =
              pkgs-cross-win.pkgsBuildBuild.writeShellApplication {
                name          = exe + "-wrapped";
                runtimeInputs = [pkg];
                text          =
                  ''
                    ${pkg}/bin/${exe} "''${@}"
                  '';
              };
        in symlink-exe-to wrapped wrapped.name new-names;

      wrap-win-hsc2hs = pkg: exe: new-names:
        let wrapped =
              pkgs-cross-win.pkgsBuildBuild.writeShellApplication {
                name          = exe + "-wrapped";
                runtimeInputs = [pkg];
                text          =
                  ''
                    ${pkg}/bin/${exe} --cross-compile --via-asm "''${@}"
                  '';
              };
        in symlink-exe-to wrapped wrapped.name new-names;

      ghc-win-exe-name     = "ghc-win";
      ghc-pkg-win-exe-name = "ghc-pkg-win";
      hsc2hs-win-exe-name  = "hsc2hs-win";

      ghc-win-wrapped     = wrap-win-ghc ghc-win-pkg "x86_64-w64-mingw32-ghc" ["ghc-${latest-ghc-short-version}-win" ghc-win-exe-name];
      ghc-pkg-win-wrapped = wrap-win-ghc-pkg ghc-win-pkg "x86_64-w64-mingw32-ghc-pkg" ["ghc-pkg-${latest-ghc-short-version}-win" ghc-pkg-win-exe-name];
      hsc2hs-win-wrapped  = wrap-win-hsc2hs ghc-win-pkg "x86_64-w64-mingw32-hsc2hs" ["hsc2hs-${latest-ghc-short-version}-win" hsc2hs-win-exe-name];

      cabal-win-wrapped =
        let test-wrapper =
              #win-pkgs.pkgsBuildBuild.winePackages.minimal
              win-pkgs.pkgsBuildBuild.writeScriptBin
                "cabal-win-test-wrapper"
                ''
                  #!${win-pkgs.pkgsBuildBuild.stdenv.shell}
                  set -euo pipefail
                  # Link all the DLLs we might need into one place so we can add
                  # just that one location to WINEPATH.

                  PREFIX="/tmp/cabal-win-test-runner-wine-prefix"
                  if [[ ! -d "$PREFIX" ]]; then
                    mkdir -p "$PREFIX"

                    ln --force -s ${win-iserv-proxy-interpreter}/bin/*.dll "$PREFIX"

                    for p in ${win-pkgs.lib.concatStringsSep " " haskell-win-runner-dll-pkgs}; do
                      find "$p" -iname '*.dll' -exec ln --force -s {} $PREFIX \;
                      find "$p" -iname '*.dll.a' -exec ln --force -s {} $PREFIX \;
                    done

                    # Some DLLs have a `lib` prefix but we attempt to load them without the prefix.
                    # This was a problem for `double-conversion` package when used in TH code.
                    # Creating links from the `X.dll` to `libX.dll` works around this issue.
                    (
                      cd $PREFIX
                      for l in lib*.dll; do
                        ln --force -s "$l" "''${l#lib}"
                      done
                      )
                  fi
                  WINEPATH=$PREFIX \
                    WINEDLLOVERRIDES="winemac.drv=d" \
                    WINEDEBUG=warn-all,fixme-all,-menubuilder,-mscoree,-ole,-secur32,-winediag \
                    WINEPREFIX=$PREFIX \
                    ${wine}/bin/wine64 \
                    "''${@}"
                '';
        in
        pkgs-cross-win.pkgsBuildBuild.writeShellApplication {
          name          = "cabal-win";
          runtimeInputs = [
            cabal
            ghc-win-wrapped
            ghc-pkg-win-wrapped
            hsc2hs-win-wrapped
            # For ‘x86_64-w64-mingw32-ld’
            win-pkgs.buildPackages.binutils
          ];
          text          =
            ''
              cmd="$1"
              shift
              cabal "$cmd" \
                --with-compiler ${ghc-win-exe-name} \
                --with-hc-pkg ${ghc-pkg-win-exe-name} \
                --with-hsc2hs ${hsc2hs-win-exe-name} \
                --with-ld "x86_64-w64-mingw32-ld" \
                --test-wrapper "${test-wrapper}/bin/cabal-win-test-wrapper" \
                "''${@}"
            '';
        };
    in {
      inherit ghc-win-wrapped ghc-pkg-win-wrapped hsc2hs-win-wrapped wine-run-haskell cabal-win-wrapped;
    };

  haskell-package-sets =
    let mkGhc914Pkgs = ghc-pkg:
          let hpkgs =
                hutils.fixedExtend pkgs.haskell.packages.native-bignum.ghc9141 (new: old:
                  builtins.mapAttrs
                    (name: x: x)
                    # (hutils.onlyApplyToHaskellPackages hlib.allowInconsistentDependencies)
                    (old // {
                      ghc          = ghc-pkg;
                      mkDerivation = drv:
                        # Important to keep changes to administractive packages like jailbreak-cabal
                        # to a minimum.
                        if drv.pname == "jailbreak-cabal"
                        then old.mkDerivation drv
                        else
                          old.mkDerivation (drv // {
                            jailbreak = true;
                            # doHaddock = false;
                            # doCheck = true;
                            # doBenchmark = false;
                            # doHoogle = true;
                            doHaddock = false;
                            enableLibraryProfiling = false;
                            # enableExecutableProfiling = false;
                          });

                      enummapset =
                        old.callCabal2nix
                          "enummapset"
                          (pkgs.fetchFromGitHub {
                            owner  = "Mikolaj";
                            repo   = "enummapset";
                            rev    = "601e862fbf93cf03ed297016920fa0c0110a5e4c";
                            sha256 = "sha256-H+sw32kl4AVJ7dTJkZpYt4Z4uXOgLWE3SoyxAAtiiAs="; #pkgs.lib.fakeSha256;
                          })
                          {};

                      # Broken with QuickCheck 2.18
                      dlist = hlib.dontCheck old.dlist;
                      # Take too long
                      statistics = hlib.dontCheck old.statistics;

                      QuickCheck =
                        hlib.dontCheck
                          (old.callHackage "QuickCheck" "2.18.0.0" {});

                      quickcheck-instances =
                        (old.callHackage "quickcheck-instances" "0.4" {});

                      process = hlib.dontCheck
                        (old.callHackageDirect
                          {
                            pkg    = "process";
                            ver    = "1.6.30.0";
                            sha256 = "sha256-grK+qHD8wGYaHMd1a0KwsJyzml1XeXnz/1pPNg7p3aA="; #pkgs.lib.fakeSha256;
                          }
                          {});

                      # Caused by process 1.6.30 tha conflicts with boot library but
                      # ultimately only affects tests that depend on ‘tasty-inspection-testing’
                      # or doctests (i.e. packages that involve ghc).
                      vector = hlib.allowInconsistentDependencies old.vector;
                      doctest = hlib.allowInconsistentDependencies old.doctest;
                      tasty-inspection-testing = hlib.allowInconsistentDependencies old.tasty-inspection-testing;

                      # integer-logarithms =
                      #   (old.callHackageDirect {
                      #     pkg    = "integer-logarithms";
                      #     ver    = "1.0.5";
                      #     sha256 = "sha256-fVcwxYyw7Ant0YfS2QrYb+lk6GhCSG1hYbar4TwBwnM="; #pkgs.lib.fakeSha256;
                      #   }
                      #     {});

                      # algebraic-graphs =
                      #   old.callCabal2nix
                      #     "alga"
                      #     (pkgs.fetchFromGitHub {
                      #       owner  = "snowleopard";
                      #       repo   = "alga";
                      #       rev    = "d4e43fb42db05413459fb2df493361d5a666588a";
                      #       sha256 = "sha256-sQRAjHV+bor/SBt/zDtcw3tN1ir7xjjevEdyYqilNWg="; #pkgs.lib.fakeSha256;
                      #     })
                      #     {};
                    }));
          in
          hpkgs;
          # Not needed any more.
          #   hutils.fixedExtend hpkgs (new: old: {
          #   buildHaskellPackages =
          #     hutils.fixedExtend hpkgs
          #       # hutils.fixedExtend old.buildHaskellPackages
          #       (_new2: _old2: {
          #         # Override build tools used by Haskell mkDerivation to
          #         # avoid references to ghcHEAD compiler.
          #         hscolour        = new.hscolour; #pkgs.haskell.packages.native-bignum.ghc912.hscolour;
          #         jailbreak-cabal = new.jailbreak-cabal; #pkgs.haskell.packages.native-bignum.ghc912.jailbreak-cabal;
          #       });
          # });

    in {
      host = rec {
        default    = ghc914;
        ghc914     = mkGhc914Pkgs ghc914-pkg;
        ghc914-pie = mkGhc914Pkgs (relocatable-static-libs-ghc ghc914-pkg);
      };
    };

  hpkgsDoctest = hutils.fixedExtend haskell-package-sets.host.default (_: old:
    builtins.mapAttrs hutils.makeHaskellPackageAttribSmaller (old // {
      doctest =
        (x: hlib.dontCheck (hlib.allowInconsistentDependencies x))
          ((old.callCabal2nix "doctest" doctest-repo {}).overrideAttrs (oldAttrs: oldAttrs // {
            # buildInputs = [haskellPackages.GLFW-b];
            configureFlags = oldAttrs.configureFlags ++ [
              # cabal config passes RTS options to GHC so doctest will receive them too
              # ‘cabal repl --with-ghc=doctest’
              "--ghc-option=-rtsopts"
            ];
          }));

      # primitive = hlib.dontCheck (old.callHackage "primitive" "0.8.0.0" {});
      # tagged = old.callHackage "tagged" "0.8.7" {};
      # size-based = hlib.doJailbreak old.size-based;
      #
      # syb = old.callHackage "syb" "0.7.2.3" {};
    }));

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
     cross-win = ghc-win;
   });

  lib = {
    inherit build-ghc;
  };

  tools = {
    inherit cabal;

    alex               = hlib.justStaticExecutables hpkgs914.alex;
    happy              = hlib.justStaticExecutables hpkgs914.happy;
    doctest            = allowGhcReference (hlib.justStaticExecutables hpkgsDoctest.doctest);
    eventlog2html      = hlib.justStaticExecutables hpkgsEventlog2html.eventlog2html;
    fast-tags          = hlib.justStaticExecutables hpkgsFastTags.fast-tags;
    ghc-events-analyze = hlib.justStaticExecutables hpkgsGhcEventsAnalyze.ghc-events-analyze;
    hp2pretty          = hlib.justStaticExecutables hpkgs914.hp2pretty;
    pretty-show        = hlib.justStaticExecutables hpkgs914.pretty-show;
    profiterole        = hlib.justStaticExecutables hpkgsProfiterole.profiterole;
    weeder             = hlib.justStaticExecutables haskell-package-sets.host.default.weeder;
    # hspec-discover     = hlib.justStaticExecutables hpkgs96.hspec-discover;
    # threadscope        = threadscopePkgs.threadscope;
  };

}
