#!/usr/bin/env bash

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

# Meanings of exit codes:
# code | meaning    | action of ranger
# -----+------------+-------------------------------------------
# 0    | success    | Display stdout as preview
# 1    | no preview | Display no preview at all
# 2    | plain text | Display the plain content of the file
# 3    | fix width  | Don't reload when width changes
# 4    | fix height | Don't reload when height changes
# 5    | fix both   | Don't ever reload
# 6    | image      | Display the image `$IMAGE_CACHE_PATH` points to as an image preview
# 7    | image      | Display the file directly as an image

# Script arguments
FILE_PATH="${1}"         # Full path of the highlighted file
PV_WIDTH="${2}"          # Width of the preview pane
PV_HEIGHT="${3}"         # Height of the preview pane
IMAGE_CACHE_PATH="${4}"  # Full path that should be used to cache image preview
PV_IMAGE_ENABLED="${5}"  # 'True' if image previews are enabled, 'False' otherwise.

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"

MIMETYPE="$(file --dereference --brief --mime-type -- "${FILE_PATH}")"

# Preview size
DEFAULT_SIZE="1920x1080"

handle_image() {
    local mimetype="${1}"
    case "${mimetype}" in
        ## SVG
        image/svg+xml|image/svg)
            if command -v rsvg-convert &>/dev/null; then
                rsvg-convert --keep-aspect-ratio --width "${DEFAULT_SIZE%x*}" "${FILE_PATH}" -o "${IMAGE_CACHE_PATH}.png" \
                    && mv "${IMAGE_CACHE_PATH}.png" "${IMAGE_CACHE_PATH}" \
                    && exit 6
            fi
            exit 1;;

        ## Image
        image/*)
            # Exit code 7 tells Ranger to display the file directly as an image (using sixel/icat)
            exit 7;;

        ## Video
        video/*)
            # Get video thumbnail
            if command -v ffmpegthumbnailer &>/dev/null; then
                ffmpegthumbnailer -i "${FILE_PATH}" -o "${IMAGE_CACHE_PATH}" -s 0 && exit 6
            elif command -v ffmpeg &>/dev/null; then
                ffmpeg -i "${FILE_PATH}" -map 0:v -map -0:V -c copy "${IMAGE_CACHE_PATH}" && exit 6
            fi
            exit 1;;

        ## PDF
        application/pdf)
            if command -v pdftoppm &>/dev/null; then
                pdftoppm -f 1 -l 1 \
                         -scale-to-x "${DEFAULT_SIZE%x*}" \
                         -scale-to-y -1 \
                         -singlefile \
                         -jpeg \
                         -- "${FILE_PATH}" "${IMAGE_CACHE_PATH%.*}" \
                    && exit 6
            fi
            ;;
    esac
}

handle_extension() {
    case "${FILE_EXTENSION_LOWER}" in
        ## Archive
        a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
        rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip|7z|rar)
            if command -v atool &>/dev/null; then
                atool --list -- "${FILE_PATH}" && exit 5
            elif command -v bsdtar &>/dev/null; then
                bsdtar --list --file "${FILE_PATH}" && exit 5
            fi
            ;;

        ## HTML
        htm|html|xhtml)
            if command -v w3m &>/dev/null; then
                w3m -dump "${FILE_PATH}" && exit 5
            fi
            ;;

        ## Jupyter Notebooks
        ipynb)
            if command -v jupyter &>/dev/null && command -v bat &>/dev/null; then
                jupyter nbconvert --to markdown "${FILE_PATH}" --stdout | env COLORTERM=8bit bat --color=always --style=plain --language=markdown && exit 5
            elif command -v jq &>/dev/null; then
                jq --color-output . "${FILE_PATH}" && exit 5
            fi
            ;;
    esac
}

handle_mime() {
    local mimetype="${1}"
    case "${mimetype}" in
        ## PDF
        application/pdf)
            # Preview as HTML rendered by w3m
            if command -v pdftohtml &>/dev/null && command -v w3m &>/dev/null; then
                pdftohtml -stdout -noframes -i -l 10 -q -- "${FILE_PATH}" | w3m -dump -T text/html && exit 5
            elif command -v pdftotext &>/dev/null; then
                pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | fmt -w "${PV_WIDTH}" && exit 5
            fi
            ;;

        ## JSON
        application/json)
            if command -v jq &>/dev/null; then
                jq --color-output . "${FILE_PATH}" && exit 5
            fi
            ;;

        ## SQLite
        *sqlite3)
            if command -v sqlite3 &>/dev/null; then
                echo "SQLite Database Table Summary:"
                sqlite3 "file:${FILE_PATH}?mode=ro" '.tables' && exit 5
            fi
            ;;

        ## Text
        text/* | */xml)
            if command -v bat &>/dev/null; then
                env COLORTERM=8bit bat --color=always --style=plain -- "${FILE_PATH}" && exit 5
            fi
            exit 2;;

        ## Audio
        audio/*)
            if command -v ffprobe &>/dev/null; then
                ffprobe -hide_banner "${FILE_PATH}" 2>&1 && exit 5
            elif command -v mediainfo &>/dev/null; then
                mediainfo "${FILE_PATH}" && exit 5
            fi
            ;;

        ## ELF files
        application/x-executable | application/x-pie-executable | application/x-sharedlib)
            if command -v readelf &>/dev/null; then
                readelf -WCa "${FILE_PATH}" && exit 5
            fi
            ;;

        application/x-openscad)
            if command -v openscad &>/dev/null; then
                openscad -o "${IMAGE_CACHE_PATH}" --imgsize="${DEFAULT_SIZE%x*},${DEFAULT_SIZE#*x}" --projection=ortho --viewall --colorscheme=Tomorrow --render -- "${FILE_PATH}" && exit 6
            fi
            ;;
    esac
}

handle_fallback() {
    # If the file is binary, use hexyl if available
    if command -v hexyl &>/dev/null && [[ ! "${MIMETYPE}" =~ ^text/ ]]; then
        echo '----- File Type Classification -----'
        file --dereference --brief -- "${FILE_PATH}"
        echo
        echo '----- Hex Dump (hexyl) -----'
        hexyl --border none --color always --length 1024 -- "${FILE_PATH}" && exit 5
    fi

    echo '----- File Type Classification -----'
    file --dereference --brief -- "${FILE_PATH}" && exit 5
}

# Image preview trigger
if [[ "${PV_IMAGE_ENABLED}" == 'True' ]]; then
    handle_image "${MIMETYPE}"
fi

handle_extension
handle_mime "${MIMETYPE}"
handle_fallback

exit 1
