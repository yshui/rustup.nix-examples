{
  description = "Examples for rustup.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    rustup.url = "github:yshui/rustup.nix";

    # unlike oxalica/rust-overlay or nix-community/fenix, rustup.nix doesn't come
    # with toolchain manifests.
    #
    # bringing your own manifests is as simple as adding it as a non-flake input:
    rust-manifest = {
      url = "https://static.rust-lang.org/dist/channel-rust-nightly.toml";
      flake = false;
    };

    # .. if you want to use a pinned version of the rust toolchain, that's also possible.
    # in fact, this is RECOMMENDED for public facing flakes. because the content of un-dated
    # rust toolchain manifest changes everyday, user of your flake will see hash mismatches since
    # the manifest they downloaded will be different from the one used to create flake.lock.
    #
    # if you are writing a public facing flake, use an explicitly dated manifest.
    rust-manifest-pinned = {
      url = "https://static.rust-lang.org/dist/2026-02-04/channel-rust-nightly.toml";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rustup,
      rust-manifest,
    }:
    let
      inherit (nixpkgs) lib;
      forEachSystem = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      packages = forEachSystem (
        system:
        let
          # import nixpkgs with rustup.nix overlay.
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rustup.overlays.default ];
          };

          # create a rust toolchain with the minimal profile. available profiles can be found
          # by looking at the manifest file.
          # usually, there will be `complete`, `default`, and `minimal`.
          #
          # by default, a toolchain targetting the current system is created.
          rustToolchain = (pkgs.rustToolchainFromManifestFile rust-manifest).minimal;

          # .. you can create toolchain for a different target, by overriding it:
          rustToolchain_aarch64 = rustToolchain.override {
            targets = [ "aarch64-unknown-linux-gnu" ];
          };

          # .. you can also customize components beyond just using preset profiles:
          rustToolchain-custom = rustToolchain.override {
            extensions = [
              "rustfmt"
              "rust-src"
              "rust-docs"
              "clippy"
              "miri"

              # don't forget these, as they won't be inclued by default if you override.
              "rustc"
              "cargo"
            ];
          };

          # use the nixpkgs machinary, create a rustPlatform.
          mkRustPlatform =
            pkgs: t:
            pkgs.makeRustPlatform {
              # rustToolchain is all components aggregated, so it has both rustc and cargo.
              rustc = t;
              cargo = t;
            };

          rustPlatform = mkRustPlatform pkgs rustToolchain;

          # you need pkgsCross stdenv if you want to cross compile
          rustPlatform_aarch64 = mkRustPlatform pkgs.pkgsCross.aarch64-multiplatform rustToolchain_aarch64;
        in
        {
          # build rust packages, just like how you would with a native nixpkgs rustPlatform.
          default = rustPlatform.buildRustPackage {
            src = ./.;
            name = "hello";
            cargoLock = {
              lockFile = ./Cargo.lock;
              allowBuiltinFetchGit = true;
            };
          };

          cross-aarch64 = rustPlatform_aarch64.buildRustPackage {
            src = ./.;
            name = "hello";
            cargoLock = {
              lockFile = ./Cargo.lock;
              allowBuiltinFetchGit = true;
            };
          };

          custom-toolchain = rustToolchain-custom;
        }
      );
    };
}
