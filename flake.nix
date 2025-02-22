{
  description = "A very basic flake";
  inputs = {
    arbeitszeitapp.url = "github:arbeitszeit/arbeitszeitapp";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  };

  outputs = { self, nixpkgs, arbeitszeitapp }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f system (mkPkgs system));
      mkPkgs = system: import nixpkgs { inherit system; };
    in {
      nixosModules = {
        default = import modules/default.nix {
          overlay = arbeitszeitapp.overlays.default;
        };
      };
      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.python3Packages.black pkgs.nixfmt ];
        };
      });
      checks = forAllSystems (system: pkgs:
        let
          makeSimpleTest = testFile:
            pkgs.nixosTest {
              nodes.machine = { config, ... }: {
                imports = [ self.nixosModules.default ];
                services.arbeitszeitapp.enable = true;
                services.arbeitszeitapp.hostName = "localhost";
                services.arbeitszeitapp.enableHttps = false;
                services.arbeitszeitapp.emailEncryptionType = null;
                services.arbeitszeitapp.emailConfigurationFile =
                  pkgs.writeText "mailconfig.json" (builtins.toJSON {
                    MAIL_SERVER = "mail.server.example";
                    MAIL_PORT = "465";
                    MAIL_USERNAME = "mail@mail.server.example";
                    MAIL_PASSWORD = "secret password";
                    MAIL_DEFAULT_SENDER = "sender@mail.server.example";
                  });
              };
              testScript = builtins.readFile testFile;
            };
        in { launchWebserver = makeSimpleTest tests/launchWebserver.py; });
    };
}
