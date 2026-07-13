{ stdenv, rustc }:

stdenv.mkDerivation {
  pname = "flakebox-git-hook-check-timer";
  version = "0.1.0";

  mainSource = ./git-hook-check-timer.rs;
  testSource = ./git-hook-check-timer-tests.rs;
  dontUnpack = true;

  nativeBuildInputs = [ rustc ];

  buildPhase = ''
    runHook preBuild
    cp "$mainSource" git-hook-check-timer.rs
    cp "$testSource" git-hook-check-timer-tests.rs
    rustc --edition 2024 -D warnings git-hook-check-timer.rs \
      -o flakebox-git-hook-check-timer
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    rustc --edition 2024 -D warnings --test git-hook-check-timer.rs \
      -o timer-tests
    ./timer-tests
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 flakebox-git-hook-check-timer \
      "$out/bin/flakebox-git-hook-check-timer"
    runHook postInstall
  '';
}
