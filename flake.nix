{
  description = "Aeryz's Blog — Jekyll (Chirpy) development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Ruby 3.4 matches .github/workflows/pages-deploy.yml.
      toolchain =
        pkgs: with pkgs; [
          ruby_3_4
          bundler

          # Native gem extensions (ffi, http_parser.rb, ...).
          gcc
          gnumake
          pkg-config
          libffi
          zlib

          # `jekyll serve --livereload` and `html-proofer` reach for these.
          curl.out
          git
        ];

      # Keep gems inside the project instead of ~/.gem; matches the `vendor`
      # entry in .gitignore. html-proofer's ethon/ffi dlopen()s libcurl by
      # soname, which the Nix loader cannot resolve without a search path.
      bundlerEnv = pkgs: ''
        export BUNDLE_PATH="$PWD/vendor/bundle"
        export BUNDLE_BIN="$PWD/vendor/bundle/bin"
        export PATH="$BUNDLE_BIN:$PATH"
        export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.curl.out ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      '';

      serve =
        pkgs:
        pkgs.writeShellApplication {
          name = "serve";
          runtimeInputs = toolchain pkgs;
          text = ''
            if [ ! -f _config.yml ]; then
              echo "serve: no _config.yml here — run from the blog repository root." >&2
              exit 1
            fi

            ${bundlerEnv pkgs}

            if ! bundle check >/dev/null 2>&1; then
              echo "> gems missing, installing into ./vendor/bundle"
              bundle install
            fi

            exec bundle exec jekyll serve --livereload "$@"
          '';
        };
    in
    {
      packages = forAllSystems (pkgs: {
        serve = serve pkgs;
      });

      apps = forAllSystems (pkgs: rec {
        serve = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.serve}/bin/serve";
          meta.description = "Serve the blog at http://127.0.0.1:4000 with livereload";
        };
        default = serve;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "aeryz-blog";
          packages = toolchain pkgs;
          shellHook = ''
            ${bundlerEnv pkgs}

            echo "$(ruby -v | cut -d' ' -f1-2) · bundler $(bundler -v | cut -d' ' -f3)"
            echo "  bundle install      install gems into ./vendor/bundle"
            echo "  bash tools/run.sh   serve at http://127.0.0.1:4000"
            echo "  bash tools/test.sh  production build + html-proofer"
          '';
        };
      });
    };
}
