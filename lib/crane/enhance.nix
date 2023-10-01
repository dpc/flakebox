{ pkgs
, mergeArgs
, ...
}:
let lib = pkgs.lib; in craneLib:
craneLib.overrideScope' (self: prev: {
  cargoProfile = "release";
  args = {
    # https://github.com/ipetkov/crane/issues/76#issuecomment-1296025495
    installCargoArtifactsMode = "use-zstd";
    doCheck = false;

    # without this any buildInputs and nativeBuildInputs can cause cargo's ./target invalidations
    strictDeps = true;
  };

  argsDepsOnly = { };

  mkCargoDerivation = args: prev.mkCargoDerivation (
    { CARGO_PROFILE = self.cargoProfile; }
    // (mergeArgs self.args args)
  );

  # functions that don't lower to `mkCargoDerivation` or lower too late it requires `args.src`
  buildDepsOnly = args: prev.buildDepsOnly (
    { CARGO_PROFILE = self.cargoProfile; }
    // (mergeArgs (mergeArgs self.args self.argsDepsOnly) args)
  );

  crateNameFromCargoToml = args: prev.crateNameFromCargoToml (mergeArgs self.args args);
  mkDummySrc = args: prev.mkDummySrc (mergeArgs self.args args);
  buildPackage = args: prev.buildPackage (
    let mergedArgs = mergeArgs self.args args; in (mergedArgs // {
      # implicit deps building is breaking caching somehow, so we need to do it ourselves here
      cargoArtifacts = mergedArgs.cargoArtifacts or (
        self.buildDepsOnly (mergedArgs // {
          installCargoArtifactsMode = mergedArgs.installCargoArtifactsMode or "use-zstd";
          # NB: we intentionally don't run any caller-provided hooks here since they might fail
          # if they require any files that have been omitted by the source dummification.
          # However, we still _do_ want to run the installation hook with the actual artifacts
          installPhase = "prepareAndInstallCargoArtifactsDir";
        }));
    })
  );
  buildTrunkPackage = args: prev.buildTrunkPackage (mergeArgs self.args args);
  # causes issues
  vendorCargoDeps = args: prev.vendorCargoDeps (mergeArgs self.args args);

  buildWorkspaceDepsOnly = origArgs:
    let
      args = builtins.removeAttrs origArgs [ "pname" ];
      pname = if builtins.hasAttr "pname" origArgs then "${origArgs.pname}-workspace" else if builtins.hasAttr "pname" self.args then "${self.args.pname}-workspace" else null;
    in
    self.buildDepsOnly
      ((lib.optionalAttrs (pname != null) {
        inherit pname;
      }) // (mergeArgs
        {
          buildPhaseCargoCommand = "cargoWithProfile doc --workspace --locked ; cargoWithProfile check --workspace --all-targets --locked ; cargoWithProfile build --locked --workspace --all-targets";
        }
        args));

  buildWorkspace = origArgs:
    let
      args = builtins.removeAttrs origArgs [ "pname" ];
      pname = if builtins.hasAttr "pname" origArgs then "${origArgs.pname}-workspace" else if builtins.hasAttr "pname" self.args then "${self.args.pname}-workspace" else null;
    in
    self.mkCargoDerivation (
      ((lib.optionalAttrs (pname != null) {
        inherit pname;
      }) // (mergeArgs
        {
          buildPhaseCargoCommand = "cargoWithProfile doc --workspace --locked ; cargoWithProfile check --workspace --all-targets --locked ; cargoWithProfile build --locked --workspace --all-targets";
          doCheck = false;
        }
        args))
    );

  buildCommand = origArgs: self.mkCargoDerivation (
    let
      args = builtins.removeAttrs origArgs [ "cmd" "buildPhaseCargoCommand" ];
    in
    ({
      pname = if builtins.hasAttr "pname" origArgs then "${origArgs.pname}-cmd" else if builtins.hasAttr "pname" self.args then "${self.args.pname}-cmd" else null;
      buildPhaseCargoCommand = origArgs.cmd;
      doCheck = false;
    } // args)
  );


  # Compile a group of packages together
  #
  # This unifies their cargo features and avoids building common dependencies multiple
  # times, but will produce a derivation with all listed packages.
  buildPackageGroup = { pname ? null, packages, mainProgram ? null, ... }@origArgs:
    let
      args = builtins.removeAttrs origArgs [ "mainProgram" "pname" "packages" ];
      pname = if builtins.hasAttr "pname" origArgs then "${origArgs.pname}-group" else if builtins.hasAttr "pname" self.args then "${self.args.pname}-group" else null;
      # "--package x --package y" args passed to cargo
      pkgsArgs = lib.strings.concatStringsSep " " (builtins.map (name: "--package ${name}") packages);

      deps = self.buildDepsOnly (mergeArgs args (
        (lib.optionalAttrs (pname != null) {
          inherit pname;
        }) // {
          buildPhaseCargoCommand = "cargoWithProfile build ${pkgsArgs}";
        }
      ));
    in
    self.buildPackage (args // (lib.optionalAttrs (pname != null) {
      inherit pname;
    }) // {
      cargoArtifacts = deps;
      meta = { inherit mainProgram; };
      cargoExtraArgs = "${pkgsArgs}";
    });


  overrideArgs = f: self.overrideScope' (self: prev: { args = mergeArgs (prev.args) (f prev.args); });
  overrideArgs' = f: self.overrideScope' (self: prev: { args = mergeArgs (prev.args) (f self prev.args); });
  overrideArgsDepsOnly = f: self.overrideScope' (self: prev: { argsDepsOnly = mergeArgs (prev.argsDepsOnly) (f prev.argsDepsOnly); });
  overrideArgsDepsOnly' = f: self.overrideScope' (self: prev: { argsDepsOnly = mergeArgs (prev.argsDepsOnly) (f self prev.argsDepsOnly); });
  overrideProfile = cargoProfile: self.overrideScope' (self: prev: { inherit cargoProfile; });
  mapWithProfiles = f: profiles: builtins.listToAttrs (builtins.map (cargoProfile: { name = cargoProfile; value = f (self.overrideProfile cargoProfile); }) profiles);
})
