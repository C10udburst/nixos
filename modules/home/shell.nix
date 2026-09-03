{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings.shell;
in {
  options.homeSettings.shell = {
    enable = lib.mkEnableOption "Enable shell aliases";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf config.homeSettings.shell-undo.enable {
        home.packages = [inputs.shell-undo.packages.${pkgs.system}.default];

        programs.bash.initExtra = ''
          source ${inputs.shell-undo.packages.${pkgs.system}.default}/share/undo/undo.bash

          _undo_preexec() {
              [[ -n ''${_undo_at_prompt-} ]] || return 0
              _undo_at_prompt=
              local cmd=$BASH_COMMAND
              case $cmd in
                  undo | 'undo '* | distrobox | 'distrobox '* | distrobox-* | podman | 'podman '* | docker | 'docker '* | flatpak | 'flatpak '*) return 0 ;;
              esac

              local id=''${EPOCHREALTIME/./}
              local dir=$UNDO_DATA_DIR/sessions/$id
              mkdir -p "$dir/data" 2>/dev/null || return 0
              printf '%s\n' "$cmd" >| "$dir/cmd"
              printf '%s\n' "$$" >| "$dir/pid"

              _undo_session=$dir
              export UNDO_SESSION=$dir
              if [[ ":''${LD_PRELOAD-}:" != *":$UNDO_LIB:"* ]]; then
                  _undo_saved_preload=''${LD_PRELOAD-__undo_unset__}
                  local _undo_keep="" _undo_p
                  local -a _undo_parts
                  IFS=: read -ra _undo_parts <<<"''${LD_PRELOAD-}"
                  for _undo_p in "''${_undo_parts[@]}"; do
                      [[ -z "$_undo_p" || "$_undo_p" == *libundo.so ]] && continue
                      _undo_keep="''${_undo_keep:+$_undo_keep:}$_undo_p"
                  done
                  export LD_PRELOAD="$UNDO_LIB''${_undo_keep:+:$_undo_keep}"
              fi
          }

          _undo_precmd() {
              _undo_at_prompt=1
              [[ -n ''${_undo_session-} ]] || return 0
              unset UNDO_SESSION

              if [[ -n ''${LD_PRELOAD-} ]]; then
                  local _undo_keep="" _undo_p
                  local -a _undo_parts
                  IFS=: read -ra _undo_parts <<<"''${LD_PRELOAD-}"
                  for _undo_p in "''${_undo_parts[@]}"; do
                      [[ -z "$_undo_p" || "$_undo_p" == *libundo.so ]] && continue
                      _undo_keep="''${_undo_keep:+$_undo_keep:}$_undo_p"
                  done
                  if [[ -n "$_undo_keep" ]]; then
                      export LD_PRELOAD="$_undo_keep"
                  else
                      unset LD_PRELOAD
                  fi
              fi
              unset _undo_saved_preload

              if [[ -s $_undo_session/degraded ]]; then
                  printf 'undo: %s\n' "$(<"$_undo_session/degraded")" >&2
              fi

              [[ -d $_undo_session ]] && : >| "$_undo_session/done" 2>/dev/null
              unset _undo_session

              if command -v undo >/dev/null 2>&1; then
                  command undo gc --auto 2>/dev/null
                  return 0
              fi
              local d
              for d in "$UNDO_DATA_DIR"/sessions/*/; do
                  [[ -d $d ]] || continue
                  [[ -s $d/journal ]] || rm -rf -- "$d"
              done
              local -a all=("$UNDO_DATA_DIR"/sessions/*/)
              local n=''${#all[@]} i
              if [[ -d ''${all[0]-} ]] && ((n > UNDO_KEEP)); then
                  for ((i = 0; i < n - UNDO_KEEP; i++)); do
                      rm -rf -- "''${all[i]}"
                  done
              fi
          }
        '';
        programs.zsh.initContent = ''
          source ${inputs.shell-undo.packages.${pkgs.system}.default}/share/undo/undo.zsh

          _undo_preexec() {
              local cmd=''${1##[[:space:]]#}
              [[ $cmd == (undo|distrobox|distrobox-*|podman|docker|flatpak)(|' '*) ]] && return 0

              local id=''${EPOCHREALTIME/./}
              local dir=$UNDO_DATA_DIR/sessions/$id
              command mkdir -p -- $dir/data 2>/dev/null || return 0
              print -r -- $1 >| $dir/cmd
              print -r -- $$ >| $dir/pid

              typeset -g _undo_session=$dir
              export UNDO_SESSION=$dir
              if [[ ":''${LD_PRELOAD-}:" != *":$UNDO_LIB:"* ]]; then
                  typeset -g _undo_saved_preload=''${LD_PRELOAD-__undo_unset__}
                  local -a _undo_pre
                  _undo_pre=(''${(s.:.)LD_PRELOAD})
                  _undo_pre=(''${_undo_pre:#*libundo.so})
                  export LD_PRELOAD=''${(j.:.)''${(@)_undo_pre}}
                  export LD_PRELOAD=$UNDO_LIB''${LD_PRELOAD:+:$LD_PRELOAD}
              fi
          }

          _undo_precmd() {
              [[ -n ''${_undo_session-} ]] || return 0
              unset UNDO_SESSION

              if [[ -n ''${LD_PRELOAD-} ]]; then
                  local -a _undo_pre
                  _undo_pre=(''${(s.:.)LD_PRELOAD})
                  _undo_pre=(''${_undo_pre:#*libundo.so})
                  if (( ''${#_undo_pre} )); then
                      export LD_PRELOAD=''${(j.:.)''${(@)_undo_pre}}
                  else
                      unset LD_PRELOAD
                  fi
              fi
              unset _undo_saved_preload

              [[ -s $_undo_session/degraded ]] &&
                  print -ru2 -- "undo: $(<$_undo_session/degraded)"

              [[ -d $_undo_session ]] && : >| $_undo_session/done 2>/dev/null
              unset _undo_session

              if (( $+commands[undo] )); then
                  command undo gc --auto 2>/dev/null
              else
                  local -a sessions
                  sessions=($UNDO_DATA_DIR/sessions/*(N/On))
                  local d
                  local -i n=0
                  for d in $sessions; do
                      if [[ ! -s $d/journal ]] || (( ++n > UNDO_KEEP )); then
                          command rm -rf -- $d
                      fi
                  done
              fi
          }
        '';
      })
      {
        home.shellAliases =
          {
            ".." = "cd ..";
            "..." = "cd ../..";
            py = "python3";
            dc = "cd";
            cls = "printf '\033[2J\033[3J\033[1;1H'";
            ll = "eza -la --sort name --group-directories-first --git --smart-group -h --extended --icons -M";
            l = "eza --icons --git --group-directories-first";
            tree = "eza --icons --git --group-directories-first -T -L 2";
            t = "eza --icons --git --group-directories-first -T -L 2";
            # "top-10" = "history | awk '{CMD[\$2]++;count++;}END { for (a in CMD)print CMD[a] \" \" CMD[a]/count*100 \"% \" a;}' | grep -v \"./\" | column -c3 -s \" \" -t | sort -nr | nl |  head -n10";
            # "top-n" = "history | awk '{CMD[\$2]++;count++;}END { for (a in CMD)print CMD[a] \" \" CMD[a]/count*100 \"% \" a;}' | grep -v \"./\" | column -c3 -s \" \" -t | sort -nr | nl |  head -n ";
            # lsport = "sudo lsof -i -P -n | grep --color=never LISTEN";
            pubip = "dig +short myip.opendns.com @resolver1.opendns.com";
            # localip = "ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'";
            # ips = "ifconfig -a | grep -o 'inet6\\? \\(addr:\\)\\?\\s\\?\\(\\(\\([0-9]\\+\\.\\)\\{3\\}[0-9]\\+\\)\\|[a-fA-F0-9:]\\+\\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'";
            # pause = "printf \"Press any key to continue...\"; read -s -n 1; printf \"\\n\"";
            "cd.." = "cd ..";
            "-" = "cd -";
          }
          // (lib.listToAttrs (
            map (i: {
              name = "..${toString i}";
              value = "cd " + (lib.concatStringsSep "/" (map (x: "..") (lib.range 1 i)));
            }) (lib.range 2 10)
          ));
      }
    ]
  );
}
