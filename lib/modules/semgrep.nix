{ lib, config, pkgs, ... }:
{

  options.semgrep = {
    enable = lib.mkEnableOption "semgrep integration" // {
      default = true;
    };

    pre-commit = {
      enable = lib.mkEnableOption "semgrep git pre-commit hook" // {
        default = true;
      };
    };
  };


  config = lib.mkIf config.semgrep.enable {
    git.pre-commit.hooks = {
      semgrep = ''
        # semgrep is not available on MacOS
        if ! command -v semgrep > /dev/null ; then
          >&2 echo "Skipping semgrep check: not available"
          return 0
        fi
      
        if [ ! -f .config/semgrep.yaml ] ; then
          >&2 echo "Skipping semgrep check: .config/semgrep.yaml doesn't exist"
          return 0
        fi

        if [ ! -s .config/semgrep.yaml ] ; then
          >&2 echo "Skipping semgrep check: .config/semgrep.yaml empty"
          return 0
        fi

        env SEMGREP_ENABLE_VERSION_CHECK=0 \
          semgrep -q --error --config .config/semgrep.yaml
      '';
    };

    shareDir."overlay/.config/semgrep.yaml" = lib.mkIf config.git.commit-template.enable {
      text = ''
        '';
    };

    env.shellPackages = lib.optionals (!pkgs.stdenv.isAarch64 && !pkgs.stdenv.isDarwin) [
      pkgs.semgrep
    ];

    just.rules = {
      semgrep = ''
        # run `semgrep`
        semgrep:
          env SEMGREP_ENABLE_VERSION_CHECK=0 \
            semgrep --error --config .config/semgrep.yaml
      '';
    };
  };
}