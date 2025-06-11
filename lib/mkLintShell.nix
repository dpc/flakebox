{
  pkgs,
  config,
  docs,
  mkFenixToolchain,
  lib,
  mergeArgs,
  mkStdTargets,
}:
let
  rustfmt = config.toolchain.rustfmt;
in

{
  packages ? [ ],
  stdenv ? pkgs.stdenv,
  targets ? lib.getAttrs [ "default" ] (mkStdTargets { }),
  toolchain ? mkFenixToolchain {
    inherit targets stdenv;
    channel = config.toolchain.channel;
    components = config.toolchain.components;
    isLintShell = true;
  },
  ...
}@args:
let
  cleanedArgs = removeAttrs args [
    "toolchain"
    "packages"
  ];
in
let
  mkShell =
    if toolchain ? stdenv then pkgs.mkShell.override { stdenv = toolchain.stdenv; } else pkgs.mkShell;
  args = cleanedArgs // {
    packages =
      [
        toolchain.toolchain
        rustfmt
      ]
      ++ (builtins.attrValues {
        # Core & generic
        inherit (pkgs)
          git
          coreutils
          parallel
          shellcheck
          ;
        # Nix
        inherit (pkgs) nixfmt-rfc-style;
        # TODO: make conditional on `config.just.enable`
        inherit (pkgs) just;
      })
      # Note: order seems important, direct args should have priority
      ++ config.env.shellPackages
      ++ packages;

    shellHook = ''
      # set the root dir
      git_root="$(git rev-parse --show-toplevel)"
      export FLAKEBOX_PROJECT_ROOT_DIR="''${git_root:-$PWD}"
      export PATH="''${git_root}/.config/flakebox/bin/:''${PATH}"
    '';
  };
in
mkShell (mergeArgs toolchain.shellArgs args)
