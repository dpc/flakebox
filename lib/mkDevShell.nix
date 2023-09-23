{ pkgs
, flakeboxBin
, config
, share
, docs
}:
let
  defaultToolchain = config.toolchain.default;
  rustfmt = config.toolchain.rustfmt;
  rust-analyzer = config.toolchain.rust-analyzer;

in

{ packages ? [ ]
, toolchain ? defaultToolchain
} @ args:
let
  cleanedArgs = removeAttrs args [
    "toolchain"
  ];
in
pkgs.mkShell (cleanedArgs // {
  packages =
    packages ++ [
      flakeboxBin

      toolchain
      rustfmt
      rust-analyzer

      pkgs.nodePackages.bash-language-server

      # This is required to prevent a mangled bash shell in nix develop
      # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
      (pkgs.hiPrio pkgs.bashInteractive)

    ] ++ config.env.shellPackages ++ (builtins.attrValues {
      # Core & generic
      inherit (pkgs) git coreutils parallel shellcheck;
      # Nix
      inherit (pkgs) nixpkgs-fmt nil;
      # Rust tools
      inherit (pkgs) cargo-watch;
      # Linkers
      inherit (pkgs) lld;
    })
  ;

  shellHook = ''
    # set the share dir
    export FLAKEBOX_SHARE_DIR=${share}
    export FLAKEBOX_DOCS_DIR=${docs}
    export FLAKEBOX_PROJECT_ROOT_DIR="''${PWD}"
    export PATH=${share}/bin/:''${PATH}

    # make sure we have git in the PATH
    export PATH=${pkgs.git}/bin/:''${PATH}

    source ${./mkDevShellHook.sh}
  '';
})  
