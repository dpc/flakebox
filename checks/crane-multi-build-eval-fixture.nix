{
  craneMultiBuildPath,
  scenario,
}:
let
  mergeArgs =
    left: right:
    left
    // right
    // {
      buildInputs = (left.buildInputs or [ ]) ++ (right.buildInputs or [ ]);
      nativeBuildInputs = (left.nativeBuildInputs or [ ]) ++ (right.nativeBuildInputs or [ ]);
      packages = (left.packages or [ ]) ++ (right.packages or [ ]);
      env = (left.env or { }) // (right.env or { });
    };

  mkCraneLib = args: cargoProfile: {
    inherit args cargoProfile;
    overrideArgs = newArgs: mkCraneLib (mergeArgs args newArgs) cargoProfile;
    mapWithProfiles =
      outputsFn: profiles:
      builtins.listToAttrs (
        map (profile: {
          name = profile;
          value = outputsFn (mkCraneLib args profile);
        }) profiles
      );
  };

  baseCraneLib = mkCraneLib { } "release";
  dependencyContext = {
    packages = {
      buildInputs = { };
      nativeBuildInputs = { };
      depsBuildBuild = { };
    };
  };
  unsupportedContext = cellKind: {
    packages.depsBuildBuild = { };
    unavailablePackages.buildInputs = "this ${cellKind} cell has no truthful target Nixpkgs package universe";
  };
  toolchain = {
    craneLib = baseCraneLib;
    inherit dependencyContext;
  };

  craneMultiBuild = import craneMultiBuildPath {
    craneMkLib = _: throw "unused craneMkLib";
    mkStdToolchains = _: throw "unused mkStdToolchains";
    lib = {
      genAttrs =
        names: valueFor:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = valueFor name;
          }) names
        );
      mapAttrs = builtins.mapAttrs;
    };
    pkgs = { };
  };

  profiles = [
    "dev"
    "release"
  ];
  outputsFn = craneLib: {
    probe = craneLib.args.marker;
  };

  scopeOutputs =
    (craneMultiBuild {
      inherit profiles;
      toolchains = {
        default = toolchain;
        cross = toolchain;
      };
      argsFor =
        { toolchainName, ... }:
        builtins.trace "argsFor invocation: ${toolchainName}" {
          marker = toolchainName;
        };
    })
      outputsFn;

  failureCell =
    if scenario == "custom" then
      "custom"
    else if scenario == "wasm" then
      "wasm32-unknown"
    else
      "aarch64-android";
  failureContext =
    if scenario == "custom" then
      null
    else if scenario == "wasm" then
      unsupportedContext "wasm32-unknown-unknown"
    else
      unsupportedContext "Android";
  failureToolchain =
    builtins.removeAttrs toolchain [ "dependencyContext" ]
    // (
      if failureContext == null then
        { }
      else
        {
          dependencyContext = failureContext;
        }
    );
  failureOutputs =
    (craneMultiBuild {
      inherit profiles;
      toolchains = {
        default = toolchain;
        ${failureCell} = failureToolchain;
      };
      argsFor = { packages, ... }: {
        marker = packages.buildInputs.openssl;
      };
    })
      outputsFn;
in
if scenario == "scope" then
  builtins.deepSeq scopeOutputs true
else
  builtins.seq failureOutputs.${failureCell}.dev.probe true
