{ pkgs, flakeboxLib }:
pkgs.runCommand "ast-grep-rules"
  {
    nativeBuildInputs = [ pkgs.ast-grep ];
    src = pkgs.lib.sources.cleanSourceWith {
      src = ../.;
      filter = flakeboxLib.source.filters.all [
        pkgs.lib.sources.cleanSourceFilter
        (flakeboxLib.source.filters.excludeDirectoriesNamed [ "specs" ])
      ];
    };
  }
  ''
    cp -r "$src" source
    chmod -R u+w source
    cd source

    # Promote the behavioral rules to CI errors while retaining the comparison
    # orientation rule as an interactive style hint.
    ast-grep scan --error --hint=prefer-less-than-comparisons
    ast-grep test

    touch "$out"
  ''
