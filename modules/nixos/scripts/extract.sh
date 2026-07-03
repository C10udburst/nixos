#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz|asar>"
  echo "       $(basename "$0") <file1.ext> [file2.ext] [file3.ext] ..."
  exit 1
fi

for n in "$@"; do
  if [ -f "$n" ]; then
    case "${n%,}" in
      *.cbt | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tbz2 | *.tgz | *.txz | *.tar)
        tar xvf "$n"
        ;;
      *.lzma) unlzma ./"$n" ;;
      *.bz2) bunzip2 ./"$n" ;;
      *.cbr | *.rar) unrar x -ad ./"$n" ;;
      *.gz) gunzip ./"$n" ;;
      *.cbz | *.epub | *.zip) unzip ./"$n" ;;
      *.z) uncompress ./"$n" ;;
      *.7z | *.arj | *.cab | *.cb7 | *.chm | *.deb | *.dmg | *.iso | *.lzh | *.msi | *.pkg | *.rpm | *.udf | *.wim | *.xar)
        7z x ./"$n"
        ;;
      *.xz) unxz ./"$n" ;;
      *.exe) cabextract ./"$n" ;;
      *.cpio) cpio -id <./"$n" ;;
      *.cba | *.ace) unace x ./"$n" ;;
      *.asar) pnpx asar extract "$n" . ;;
      *)
        echo "extract: '$n' - unknown archive method"
        printf "Try using binwalk? [y/n] "
        read -r yn
        echo ""
        if [[ ! $yn =~ ^[YyTt]$ ]]; then
          exit 1
        fi
        binwalk -e "$n"
        ;;
    esac
  else
    echo "extract: '$n' - file does not exist"
    exit 1
  fi
done
