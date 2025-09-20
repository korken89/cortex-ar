{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      fenix,
      ...
    }:
    let
      # forAllSystems follows this guide:
      # https://github.com/Misterio77/nix-starter-configs/issues/64#issuecomment-1941420712
      pkgsFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              fenix.overlays.default
            ];
          };

        in
        {
          inherit system pkgs;

          # Fenix-managed Rust toolchain
          #
          # `nixpkgs` provisioned `rustup` works "good enough" in most cases.
          # However, it relies on downloading toolchains to $HOME/.rustup
          # and patching them on-fly. Executables from such toolchains link
          # against dependencies stored in the nix-store which can be at
          # any point garbage-collected (no appropriate GC-root).
          #
          # `fenix` downloads the toolchain into the `nix-store` instead.
          rustToolchain = pkgs.fenix.fromToolchainFile {
            dir = ./.;
            # rust-toolchain.toml does not contain the hash of the downloaded
            # artifact and thus it has to be provided externally.
            #
            # `nix develop` will yield an expected hash in a case the hash
            # comparison fails.
            sha256 = "sha256-SJwZ8g0zF2WrKDVmHrVG3pD2RGoQeo24MEXnNx5FyuI=";
          };
        };

      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (pkgsFor system));
    in
    {
      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);

      devShells = forAllSystems (
        {
          system,
          pkgs,
          rustToolchain,
          ...
        }:
        {
          default =
            with pkgs;
            pkgs.mkShell {
              packages = [
                git
                rustToolchain
                cargo-binutils
                pkg-config
                cargo-watch
                cargo-bloat
                cargo-expand
              ];

              env = {
                RUSTC_BOOTSTRAP = 1;
              };

              shellHook = ''
                echo "Development shell for cortex-ar."
              '';
            };
        }
      );
    };
}
