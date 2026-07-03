#!/usr/bin/env bash
jq -r 'to_entries[] | select(.key | startswith("base")) | "\(.key) \(.value)"' /etc/stylix/palette.json | while read -r name hex; do clean_hex=${hex#\#}; r=$((16#${clean_hex:0:2})); g=$((16#${clean_hex:2:2})); b=$((16#${clean_hex:4:2})); printf "%s: \e[48;2;%d;%d;%dm  \e[0m #%s\n" "$name" "$r" "$g" "$b" "$clean_hex"; done
