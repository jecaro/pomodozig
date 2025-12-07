{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      });
    in
    {
      overlays.default = (final: prev: {
        pomodozig = prev.stdenv.mkDerivation {
          name = "pomodozig";
          src = self;
          nativeBuildInputs = [ pkgs.zig.hook ];
        };
      });

      packages = forAllSystems (system: {
        pomodozig = nixpkgsFor.${system}.pomodozig;
        default = self.packages.${system}.pomodozig;
      });

      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.zig
              pkgs.zls
            ];
          };
        }
      );
    };
}
