{
  description = "cme.nvim";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        pkgs.neovim
        # runner deps
        pkgs.just
        pkgs.nushell
        # linter
        pkgs.lua-language-server
        # formatters
        pkgs.alejandra
        pkgs.stylua
      ];
    };

    formatter.${system} = pkgs.alejandra;
  };
}
