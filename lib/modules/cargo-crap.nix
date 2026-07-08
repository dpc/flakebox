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
        description = "Content of the generated .cargo-crap.toml file.";
      };
    };

    just.enable = lib.mkEnableOption "cargo-crap just recipes" // {
      default = true;
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
            cargo crap {{ARGS}}
        '';
      };
    })
  ];
}
