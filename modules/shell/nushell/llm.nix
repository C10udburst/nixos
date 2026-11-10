{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.nushell;
in {
  options.features.shell.nushell.llm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.shell.nushell.enable && true;
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "mimo-v2.6-flash-mopd";
    };
  };

  config = lib.mkIf cfg.llm.enable {
    home-manager.users.cloudburst = {
      programs.nushell.extraConfig = ''
        def get-llm-oneliner [prompt: string] {
          let pwd = ($env.PWD)
          let user = ($env.USER)
          let host_info = (sys host)
          let hostname = ($host_info.hostname)
          let os = ($host_info.long_os_version)
          let dir_contents = (ls -a | take 20 | to md)
          let jobs = (job list | to md)

          let system_prompt = $"
            You are a terminal assistant that outputs valid Nushell code. Respond ONLY with a single-line shell command.
            Current directory contents: ($dir_contents)
            Current directory: ($pwd)
            User: ($user)@($hostname)
            OS: ($os)
            Jobs: ($jobs)

            Respond ONLY with a single-line shell command.
            Do not include markdown blocks, backticks, explanations, or formatting.
            Remember not to use bash, zsh, or any other shell syntax. Use only **Nushell** syntax.
            Just the raw command.
          "

          let body = {
            model: "${cfg.llm.model}"
            messages: [
              { role: "system", content: $system_prompt }
              { role: "user", content: $prompt }
            ]
          }

          let response = (
            http post --content-type application/json
              "http://llm:8080/v1/chat/completions"
              $body
          )

          return ($response.choices.0.message.content | str trim)
        }

        $env.config = ($env.config)
        $env.config.keybindings = ($env.config.keybindings)

        $env.config.keybindings = ($env.config.keybindings | append {
          name: llm_oneliner
          modifier: control
          keycode: char_a
          mode: [emacs, vi_insert, vi_normal]
          event: [{
            send: ExecuteHostCommand
            cmd: "
              let current_prompt = (commandline | str trim)
              if ($current_prompt | is-not-empty) {
                let response = (get-llm-oneliner $current_prompt)
                if ($response | is-not-empty) {
                  commandline edit --replace $response
                }
              }
            "
          }]
        })
      '';
    };
  };
}
