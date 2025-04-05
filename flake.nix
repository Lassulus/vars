{
  description = "testing vars without depending on clan";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
    in {
      nixosModules.default = { imports = [ ./options.nix ]; };
      nixosModules.backend-on-machine = { imports = [ ./backends/on-machine.nix ]; };
      # TODO fix tests
      checks = forAllSystems (system: let
        tests = {
          testing = inputs.nixpkgs.lib.nixos.runTest {
            hostPkgs = inputs.nixpkgs.legacyPackages.${system};
            imports = [
              ./options.nix
              ./testing.nix
            ];
          };
        };
      in tests);
    };
}
