{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) types;
  cargoCrapPackage =
    if pkgs ? cargo-crap then pkgs.cargo-crap else pkgs.callPackage ../pkgs/cargo-crap.nix { };
  preCommitArgs = lib.escapeShellArgs config.cargo-crap.pre-commit.args;
in
{
  options.cargo-crap = {
    enable = lib.mkEnableOption "cargo-crap integration" // {
      default = true;
    };

    package = lib.mkOption {
      type = types.package;
      default = cargoCrapPackage;
      defaultText = lib.literalExpression "pkgs.cargo-crap or flakebox's packaged cargo-crap";
      description = "cargo-crap package to add to flakebox development shells.";
    };

    config = {
      enable = lib.mkEnableOption "generation of .cargo-crap.toml" // {
        default = true;
      };

      content = lib.mkOption {
        type = types.lines;
        description = "Full content of the generated .cargo-crap.toml file. Setting this option replaces the default TOML.";
      };
    };

    just.enable = lib.mkEnableOption "cargo-crap just recipes" // {
      default = true;
    };

    pre-commit = {
      enable = lib.mkEnableOption "cargo-crap git pre-commit gate" // {
        default = false;
      };

      args = lib.mkOption {
        type = types.listOf types.str;
        default = [
          "--workspace"
          "--fail-above"
        ];
        description = ''
          Arguments passed to `cargo-crap` by the opt-in pre-commit gate.

          The default runs an absolute CRAP-score gate using the threshold from
          `.cargo-crap.toml`. Add arguments such as `--lcov lcov.info`,
          `--threshold N`, or `--baseline path/to/baseline.json` here for
          project-specific gates.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.cargo-crap.enable {
      env.shellPackages = [ config.cargo-crap.package ];

      cargo-crap.config.content = lib.mkDefault ''
        # Shared cargo-crap defaults for local runs and CI gates.
        # CLI arguments take precedence over this file.
        default-excludes = ["benches/**", "examples/**", "tests/**"]
        epsilon = 0.01
        missing = "pessimistic"
        sort = "crap"
        threshold = 500
      '';
    })

    (lib.mkIf (config.cargo-crap.enable && config.cargo-crap.config.enable) {
      rootDir.".cargo-crap.toml" = {
        text = config.cargo-crap.config.content;
      };
    })

    (lib.mkIf (config.cargo-crap.enable && config.cargo-crap.just.enable) {
      just.rules.cargo-crap = {
        content = ''
          # run cargo-crap on the workspace
          crap *ARGS="--workspace":
            #!/usr/bin/env bash
            set -euo pipefail
            if [ ! -f Cargo.toml ]; then
              cd {{invocation_directory()}}
            fi
            cargo-crap {{ARGS}}
        '';
      };
    })

    (lib.mkIf (config.cargo-crap.enable && config.cargo-crap.pre-commit.enable) {
      git.pre-commit.hooks = {
        cargo_crap = ''
          flakebox-in-each-cargo-workspace cargo-crap ${preCommitArgs}
        '';
      };
    })
  ];
}
