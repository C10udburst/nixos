# The extension set of this feature, shared by its two front-ends: the desktop
# profile (./default.nix) and the browser server (./web.nix). Both resolve the
# same `pkgs.vscode-marketplace` (nix-vscode-extensions, declared once in
# ./default.nix), so the gating below is the single source of truth for what
# either of them gets, and it is exported as two lists:
#
#   vscode          — the desktop editor
#   vscodiumServer  — openvscode-server in the browser
#
# The availability flags are read straight from their leaves. Every one of those
# options already defaults to `parent.enable && …` up to `features.gui`, so the
# cascade is respected without re-ANDing the ancestors here — and a host that
# explicitly enables one leaf on a disabled branch (zeph runs
# `gui.dev.python.enable = true` with `gui.enable = false`) still gets the
# matching extensions.
{
  config,
  lib,
  pkgs,
}: let
  exts = pkgs.vscode-marketplace;

  isProgramming = config.features.gui.dev.programming.enable or false;
  isRust = config.features.gui.dev.programming.rust or false;
  isGo = config.features.gui.dev.programming.go or false;
  isKotlin = config.features.gui.dev.programming.kotlin or false;
  isPython = config.features.gui.dev.python.enable or false;
  isLatex = config.features.gui.dev.documents.latex or false;
  isTypst = config.features.gui.dev.documents.typst or false;
  isArduino = config.features.gui.dev.arduino.enable or false;
  isThreed = config.features.gui.apps.threed.enable or false;
  isLlm = config.features.shell.utils.llm.enable or false;

  # jetbrains.kotlin-server chmods its bundled `server/bin/intellij-server`
  # (chmodSync 0o755) on every launch. The file is already 0555 in the store,
  # but any chmod — even a no-op — returns EROFS on the read-only /nix/store,
  # which crashes the extension before the language server starts. Wrap the
  # single chmodSync call site in the bundled extension.js so EROFS is
  # ignored and any other error still propagates.
  kotlinServerErofsOverlay = final: prev:
    lib.optionalAttrs (prev ? vscode-marketplace) {
      vscode-marketplace =
        prev.vscode-marketplace
        // {
          jetbrains =
            (prev.vscode-marketplace.jetbrains or {})
            // {
              kotlin-server = prev.vscode-marketplace.jetbrains.kotlin-server.overrideAttrs (
                finalAttrs: prevAttrs: {
                  postPatch =
                    (prevAttrs.postPatch or "")
                    + ''
                      f=out/dist/extension.js
                      sed -E -i 's/\(0,([A-Za-z0-9_$.]+)\.chmodSync\)\(([A-Za-z0-9_$]+),493\)/(function(){try{(0,\1.chmodSync)(\2,493)}catch(_e){if(_e.code!=="EROFS")throw _e}})()/g' "$f"
                      if ! grep -q 'EROFS' "$f"; then
                        echo "kotlin-server-erofs-overlay: chmodSync call site not found in $f; upstream bundle changed" >&2
                        exit 1
                      fi
                    '';
                }
              );
            };
        };
    };

  # Core extensions always installed
  coreExtensions = with exts; [
    # Add Gitignore command
    codezombiech.gitignore
    # Github Actions
    github.vscode-github-actions
    # REST client — always useful
    humao.rest-client
    # Markdown
    shd101wyy.markdown-preview-enhanced
    yzhang.markdown-all-in-one
    # Hex Editor
    ms-vscode.hexeditor
    # Shell Formatter
    foxundermoon.shell-format
    # JSON Formatter
    zainchen.json
    # Bracket / UI niceties
    usernamehw.errorlens
    pkief.material-icon-theme
    # Nix
    jnoortheen.nix-ide
  ];

  programmingExtensions = lib.optionals isProgramming (
    with exts;
      [
        wholroyd.jinja
        jock.svg
        slevesque.shader
      ]
      ++ lib.optionals isRust [
        rust-lang.rust-analyzer
      ]
      ++ lib.optionals isGo [
        golang.go
      ]
      ++ lib.optionals isKotlin [
        jetbrains.kotlin-server
      ]
  );

  # Python extensions
  pythonExtensions = lib.optionals isPython (
    with exts; [
      ms-python.python
      ms-python.vscode-pylance
      ms-python.debugpy
      ms-python.black-formatter
      ms-python.isort
      ms-toolsai.jupyter
      ms-toolsai.jupyter-renderers
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow
    ]
  );

  # Everything that runs in either front-end.
  commonExtensions =
    coreExtensions
    ++ programmingExtensions
    ++ pythonExtensions
    ++ lib.optionals isLatex [exts.james-yu.latex-workshop]
    ++ lib.optionals isTypst [exts.myriad-dreamin.tinymist]
    ++ lib.optionals isArduino [
      exts.platformio.platformio-ide
      pkgs.vscode-extensions.ms-vscode.cpptools
    ]
    ++ lib.optionals isThreed [exts.appliedengdesign.vscode-gcode-syntax]
    ++ lib.optionals isLlm [exts.johnny-zhao.pi-agent-studio];

  # The client halves of remote development. They are pointless inside the
  # browser, whose whole purpose is to be the remote, and their marketplace
  # builds demand a VS Code engine newer than openvscode-server ships, so the
  # server would only log them as incompatible.
  remoteExtensions = with exts; [
    # Remote Repositories
    ms-vscode.remote-repositories
    # Remote - SSH
    ms-vscode-remote.remote-ssh
    # GitHub Codespaces
    github.codespaces
  ];

  # The toolchain the extensions shell out to, for the desktop app: a function
  # of the FHS sandbox package set, so the python packages land in its shared
  # site-packages and the extension host can import them.
  sandboxPackages = p:
    with p;
      lib.optionals isRust [
        cargo
        rustc
        rust-analyzer
      ]
      ++ lib.optionals isGo [
        go
        gopls
      ]
      ++ lib.optionals isPython [
        python3
        python3Packages.ipykernel
        black
        isort
      ]
      ++ lib.optionals isTypst [
        typst
        typstyle
      ]
      ++ [
        nixd
        nixfmt
      ];

  # The same toolchain for the server, which only gets a PATH: there the python
  # tooling has to be folded into one interpreter, or ipykernel stays
  # unimportable and the Jupyter extension finds no kernel.
  serverPackages =
    lib.optionals isRust [
      pkgs.cargo
      pkgs.rustc
      pkgs.rust-analyzer
    ]
    ++ lib.optionals isGo [
      pkgs.go
      pkgs.gopls
    ]
    ++ lib.optionals isPython [
      (pkgs.python3.withPackages (ps:
        with ps; [
          ipykernel
          black
          isort
        ]))
    ]
    ++ lib.optionals isTypst [
      pkgs.typst
      pkgs.typstyle
    ]
    ++ [
      pkgs.nixd
      pkgs.nixfmt
    ];
in {
  overlay = kotlinServerErofsOverlay;

  # The desktop editor.
  vscode = {
    extensions = commonExtensions ++ remoteExtensions;
    inherit sandboxPackages;
  };

  # openvscode-server in the browser.
  vscodiumServer = {
    extensions = commonExtensions;
    packages = serverPackages;
  };
}
