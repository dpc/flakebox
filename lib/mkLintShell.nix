{ pkgs
, config
, docs
, mkFenixToolchain
, lib
, mergeArgs
}:
let
  defaultToolchain = config.toolchain.default;
  rustfmt = config.toolchain.rustfmt;
in

{ packages ? [ ]
, toolchain ? mkFenixToolchain { toolchain = defaultToolchain; isLintShell = true; }
, ...
} @ args:
let
  cleanedArgs = removeAttrs args [
    "toolchain"
    "packages"
  ];
in
let
  args = {
    strictDeps = true;
  } // cleanedArgs // {
    packages =
      packages ++ [
        toolchain.toolchain
        rustfmt
      ] ++ config.env.shellPackages ++ (builtins.attrValues {
        # Core & generic
        inherit (pkgs) git coreutils parallel shellcheck;
        # Nix
        inherit (pkgs) nixpkgs-fmt;
        # TODO: make conditional on `config.just.enable`
        inherit (pkgs) just;
      });

    shellHook = ''
      # set the root dir
      git_root="$(git rev-parse --show-toplevel)"
      export FLAKEBOX_PROJECT_ROOT_DIR="''${git_root:-$PWD}"
      export PATH="''${git_root}/.config/flakebox/bin/:''${PATH}"
    '';
  };
in
pkgs.mkShell (
  mergeArgs toolchain.shellArgs args
)
