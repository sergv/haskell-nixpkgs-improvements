{ pkgs,
  pkgs-cross-win,
  lib,
  latest-ghc-field,
  latest-ghc-short-version,

  cabal
}:
let

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

  # Defines ‘x86_64-w64-mingw32-ghc’, ‘x86_64-w64-mingw32-ghc-pkg’, and ‘x86_64-w64-mingw32-hsc2hs,
  win-pkgs = pkgs-cross-win.pkgsCross.mingwW64;

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
  inherit wine-run-haskell;
  ghc-win     = ghc-win-wrapped;
  ghc-pkg-win = ghc-pkg-win-wrapped;
  hsc2hs-win  = hsc2hs-win-wrapped;
  cabal-win   = cabal-win-wrapped;
}

