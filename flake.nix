{
  description = "Irodori-TTS: uv and ROCm wheel runtime for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        # sentencepiece 0.1.99 has prebuilt wheels for Python 3.11.
        packages = with pkgs; [ uv python311 git ffmpeg-headless pkg-config ];

        # PyTorch's ROCm wheels include HIP/rocBLAS/MIOpen. Supply their
        # system dependencies without mixing in a different ROCm version.
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
          stdenv.cc.cc.lib zlib zstd xz bzip2
          libsndfile ffmpeg-headless numactl libdrm elfutils
        ]);
        UV_PYTHON = "${pkgs.python311}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";

        shellHook = ''
          export UV_CACHE_DIR="$PWD/.cache/uv"
          export HF_HOME="$PWD/.cache/huggingface"
          export PYTHONUNBUFFERED=1
        '';
      };
    };
}
