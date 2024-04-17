{
  description = "A flake for building the Infer static analysis tool.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };  # If required
        };

        # src = pkgs.fetchFromGitHub {
        #   owner = "facebook";
        #   repo = "infer";
        #   rev = "main";
        #   sha256 = "sha256-pNVyWWTh4g2CiTOQonKOquzOzFV7k+bj9q1e/26ieG8=";
        #   fetchSubmodules = true;
        # };

        llvmVer = "18.1.3";
        llvmSrc = pkgs.fetchurl {
          url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvmVer}/llvm-project-${llvmVer}.src.tar.xz";
          sha256 = "2929f62d69dec0379e529eb632c40e15191e36f3bd58c2cb2df0413a0dc48651";
        };

        ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;

      in
      {
        packages.infer = pkgs.stdenv.mkDerivation {
          pname = "infer";
          name = "infer";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            autoconf
            automake
            libtool
            which
            python3
            cmake
            pkg-config
            zlib
            ncurses
            openjdk
            clang
            perl536
            ocamlPackages.ocamlbuild
            ocamlPackages.menhir
            ocamlPackages.atdgen
            ocamlPackages.camlzip
            ocamlPackages.ounit
            ocamlPackages.javalib
            ocamlPackages.sawja
            curl
          ];

          buildInputs = with pkgs; [
            ocamlPackages.ocaml
            ocamlPackages.findlib
          ];

          patchPhase = ''
            mkdir -p $TMPDIR/llvm-project
            tar xf ${llvmSrc} -C $TMPDIR/llvm-project --strip-components=1
            mkdir -p facebook-clang-plugins/clang/src/download/
            cp -r $TMPDIR/llvm-project facebook-clang-plugins/clang/src/download
            patchShebangs autogen.sh
            patchShebangs facebook-clang-plugins/clang/src/*.sh
            patchShebangs facebook-clang-plugins/clang/*.sh
          '';

          preConfigure = ''
            opam init --no-setup --disable-sandboxing
            eval $(opam env)
            opam install depext
            opam depext --install --yes conf-m4.1 lwt.5.4.0 ssl.0.5.9
            opam install --yes --deps-only infer
          '';

          configurePhase = ''
            echo "Listing directory contents:"
            ls -la
            ./autogen.sh
            ./configure --disable-clang-analyzers
          '';

          buildPhase = "make -j$NIX_BUILD_CORES";

          installPhase = ''
            mkdir -p $out
            cp -r infer-out/* $out/
          '';

          meta = with pkgs.lib; {
            description = "A static analysis tool for Java, C, C++, and Objective-C";
            homepage = "https://fbinfer.com/";
            license = licenses.mit;
            maintainers = with pkgs.lib.maintainers; [ eelco ];
          };
        };

        defaultPackage = self.packages.${system}.infer;
      }
    );
}
