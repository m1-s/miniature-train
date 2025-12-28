{ fetchzip, rustPlatform }:
let
  fetchedSrc = fetchzip {
    url = "https://siggsoftware.ch/wordpress/wp-content/uploads/2025/12/srcpd_rust_1.7.0.zip";
    hash = "sha256-YDEik+eXwr8UnNNkJYefmZQO25ut2DQPeEWgxP4I9Ks=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "srcpd-rust";
  version = "1.7.0";
  # Unfortunately, its not included in the repo. This was generated manually.
  cargoLock.lockFile = ./Cargo.lock;
  src = fetchedSrc;
  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';
}
