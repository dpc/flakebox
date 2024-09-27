{
  lib,
  config,
  pkgs,
  ...
}:
{

  options.typos = {
    enable = lib.mkEnableOption "typos integration" // {
      default = true;
    };

    pre-commit = {
      enable = lib.mkEnableOption "typos git pre-commit hook" // {
        default = true;
      };
    };
  };

  config = lib.mkIf config.typos.enable {
    git.pre-commit.hooks = lib.mkIf config.typos.pre-commit.enable {
      typos = ''
        if ! echo "$FLAKEBOX_GIT_LS_TEXT" | typos --file-list - --force-exclude ; then
          >&2 echo "Typos found: Valid new words can be added to '.typos.toml'"
          return 1
        fi
      '';
    };

    env.shellPackages = [
      pkgs.typos
    ];

    just.rules = {
      typos = {
        content = ''
          # check typos
          [no-exit-message]
          typos *PARAMS:
            #!/usr/bin/env bash
            set -eo pipefail

            export FLAKEBOX_GIT_LS
            FLAKEBOX_GIT_LS="$(git ls-files)"
            export FLAKEBOX_GIT_LS_TEXT
            FLAKEBOX_GIT_LS_TEXT="$(echo "$FLAKEBOX_GIT_LS" | grep -v -E "^db/|\.(png|ods|jpg|jpeg|woff2|keystore|wasm|ttf|jar|ico)\$")"


            if ! echo "$FLAKEBOX_GIT_LS_TEXT" | typos {{PARAMS}} --file-list - --force-exclude ; then
              >&2 echo "Typos found: Valid new words can be added to '.typos.toml'"
              return 1
            fi

          # fix all typos
          [no-exit-message]
          typos-fix-all:
            just typos -w
        '';
      };
    };
  };
}
