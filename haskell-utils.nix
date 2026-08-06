{ hlib
, lib
}:
let # Disable profiling and haddock
    makeHaskellPackageSmaller = x:
      hlib.dontHaddock
       (hlib.disableLibraryProfiling
         (hlib.disableExecutableProfiling x));

    makeHaskellPackageAttribSmaller = name: x:
      onlyApplyToHaskellPackages makeHaskellPackageSmaller name x;

    # Apply function f only to haskell packages. Designed to be mapped over whole
    # haskell package set, e.g.
    #
    # > fixedExtend hpkgs (_: old:
    # >   builtins.mapAttrs makeHaskellPackageAttribSmaller old
    # > );
    onlyApplyToHaskellPackages = f: name: x:
      if builtins.isNull x ||
        builtins.elem
          name
          # May need to add more attributes here...
           ["callCabal2nix" "callCabal2nixWithOptions" "haskellSrc2nix" "ghc" "mkDerivation" "buildHaskellPackages" "callHackage" "callHackageDirect" "callPackage" "hackage2nix" "generateOptparseApplicativeCompletion" "generateOptparseApplicativeCompletions" "native-bignum"]
          # "jailbreak-cabal"
      then x
      else
       # # If we missed something in the above check, uncomment this and see what’s being accessed
       # builtins.trace { inherit name; type = builtins.typeOf x; }
       f x;

    version-ge = to-check: target-version:
      builtins.compareVersions to-check target-version >= 0;

    ghc-pkg-version-ge = ghc-pkg: target-version:
      (ghc-pkg ? version) && version-ge ghc-pkg.version target-version;

    smaller-ghc = ghc-pkg:
      if ghc-pkg-version-ge ghc-pkg "9.6"
      then
        let args = lib.functionArgs ghc-pkg.override;
            is-non-bin-distribution = args ? enableNativeBignum || args ? enableDocs;
        in
          if is-non-bin-distribution
          then ghc-pkg.override (_: {
            enableNativeBignum = true;
            enableDocs         = false;
          })
          else ghc-pkg
      else
        # Don’t bother with older ghcs.
        ghc-pkg;

    addElemToAttrUniq = x: attr: composite: default:
      if builtins.hasAttr attr composite
      then
        let value = builtins.getAttr attr composite;
        in
          if builtins.isList value &&
             !(builtins.elem "--hash-unit-ids" value)
          then value ++ [x]
          else value
      else
        default;

    enable-unit-ids-for-newer-ghc = ghc-pkg:
      if ghc-pkg-version-ge ghc-pkg "9.8" &&
         # Use presence of ‘buildPhase’ as a marker for whether we’re really building
         # from source or downloading a binary. The binary doesn’t have the ‘buildPhase’.
         builtins.hasAttr "buildPhase" ghc-pkg
      then
        ghc-pkg.overrideAttrs (old: {
          hadrianFlags = addElemToAttrUniq "--hash-unit-ids" "hadrianFlags" old [];
          hadrianArgs  = addElemToAttrUniq "--hash-unit-ids" "hadrianArgs"  old [];

          # haskell.nix ghc builder does not expose hadrian arguments so we have to hack
          # hadrian shell invocation here instead of using hadrianFlags/hadrianArgs
          buildPhase = builtins.replaceStrings [" --flavour="] [" --hash-unit-ids --flavour="] old.buildPhase;
        })
      else
        ghc-pkg;

    # Regular extend doesn’t work with haskell packages - it nukes .override
    # thus preventing further calls to .override.
    #
    # f should be of the form
    # (self: super: { ... })
    # aka
    # (final: prev: { ... })
    fixedExtend = target: f:
      target.override (old: {
        overrides = lib.composeExtensions (old.overrides or (_: _: {})) f;
      });

    premap-hpkgs-mk-derivation = f: package-set:
      fixedExtend
        package-set
        (
          new:
          old:
          {
            mkDerivation = args: old.mkDerivation
              (if args.pname == "jailbreak-cabal"
               then
                 # Important to keep changes to administractive packages
                 # like jailbreak-cabal to a minimum.
                 args
               else (f args));
          })
      // {
        overrideScope =
          scope: premap-hpkgs-mk-derivation f (package-set.overrideScope scope);
      };

    # e.g.
    # enable-hpkgs-debugging pkgs.haskell.packages.native-bignum.ghc9141
    # enable-hpkgs-debugging derived-haskell-tools.haskell-package-sets.host.ghc914-pie
    enable-hpkgs-debugging =
      premap-hpkgs-mk-derivation
        (args: args // {
          configureFlags = (args.configureFlags or []) ++
            [
              "--ghc-option=-g"
              "--disable-executable-stripping"
              "--disable-library-stripping"
            ];
          dontStrip = true;
        });

    enable-hpkgs-PIC =
      premap-hpkgs-mk-derivation
        (args: args // {
          configureFlags = (args.configureFlags or []) ++ ["--ghc-option=-fPIC"];
        });

in {
  inherit makeHaskellPackageSmaller makeHaskellPackageAttribSmaller fixedExtend ghc-pkg-version-ge version-ge;
  inherit onlyApplyToHaskellPackages;

  inherit enable-unit-ids-for-newer-ghc;

  inherit premap-hpkgs-mk-derivation enable-hpkgs-debugging enable-hpkgs-PIC;

  smaller-hpkgs-no-ghc = hpkgs:
    fixedExtend hpkgs (_: old:
      builtins.mapAttrs makeHaskellPackageAttribSmaller old
    );

  # inherit smaller-ghc;

  smaller-hpkgs = hpkgs:
    # builtins.trace (builtins.attrNames hpkgs)
    (fixedExtend hpkgs (_: old:
      builtins.mapAttrs makeHaskellPackageAttribSmaller (old // {
        ghc = smaller-ghc old.ghc;
      })));
}
