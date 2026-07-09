{
  description = "cme.nvim";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    lib = nixpkgs.lib;
    # i don't manage my nightly neovim installation with nix
    # (shocked gasps from the audience) and i need the flake
    # to NOT reference the stable version if i have a nightly
    nvim-wrapper = pkgs.writeShellScriptBin "nvim" ''
      if [ -x "$HOME/opt/neovim/bin/nvim" ]; then
        exec "$HOME/opt/neovim/bin/nvim" "$@"
      fi
      exec ${lib.getExe pkgs.neovim} "$@"
    '';
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        nvim-wrapper
        pkgs.luajitPackages.busted
        # runner deps
        pkgs.gnumake
        # linter
        pkgs.lua-language-server
        # formatters
        pkgs.stylua
      ];
    };
  };
}
