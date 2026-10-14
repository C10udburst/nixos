{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.scripts.documents;

  glmocr = pkgs.python3Packages.buildPythonApplication {
    pname = "glmocr";
    version = "unstable";
    format = "pyproject";

    src = inputs.glmocr-src;

    postPatch = ''
      substituteInPlace glmocr/config.yaml \
        --replace-fail 'enabled: true # Set to true to use MaaS mode' 'enabled: false # Disabled: self-hosted mode' \
        --replace-fail 'api_host: 127.0.0.1' 'api_host: llm'
    '';

    build-system = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    dependencies = with pkgs.python3Packages; [
      pillow
      numpy
      requests
      pydantic
      pyyaml
      portalocker
      python-dotenv
      tqdm
      pymupdf
      opencv4
      torch
      torchvision
      transformers
      sentencepiece
      accelerate
      pypdfium2
    ];

    doCheck = false;
  };
in {
  config = lib.mkMerge [
    {
      flake-file.inputs = {
        glmocr-src = {
          url = "github:zai-org/GLM-OCR";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = [
        glmocr
      ];
    })
  ];
}
