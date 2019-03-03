#!/bin/bash
# vim: set ts=4 sw=4 tw=0 et :

# number of pool entity
filepool_getNumber() {
    local file="$1"

    echo ${file##*/} | sed 's/[a-z]\+\([0-9]\+\).[a-z]\+/\1/i'
}

# numer of files in the specified pool
filepool_getSize() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    local files=${storage}/${filepool}*.${image_format}

    echo $(($(eval ls -l $files 2>/dev/null | wc -l)))
}

# disk usage of pool
filepool_status() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    du -hc ${storage}/${filepool}*.${image_format}
}

filepool_convert() {
    local storage=$1
    local filepool=$2
    local image_format=$3
    local image_format_dest=$4

    if ((VERBOSE)); then
        echo "--- filepool_convert ---"
        local start=$(date +%s.%N)
    fi

    local magick_tmpdir="$(mktemp -d magickXXXX)"
    trap "rm -rf $magick_tmpdir" EXIT

    local n
    local output
    local files=${storage}/${filepool}*.${image_format}
    for file in $(eval ls $files); do
        n=$(filepool_getNumber $file)
        output="${storage}/${filepool}$n.${image_format_dest}"

        # use package netpbm http://netpbm.sourceforge.net/
        if [ "$image_format" = "pnm" -a "$image_format_dest" = "tiff" ]; then
            if command -v pamtotiff; then
                echo "new version of netpbm detected.\n" \
                     "See http://netpbm.sourceforge.net/doc/pamtotiff.html"
                pamtotiff
            fi
            pnmtotiff "$file" > "$output"
            continue
        fi
        if [ "$image_format" = "tiff" -a "$image_format_dest" = "pnm" ]; then
            tifftopnm "$file" > "$output"
            continue
        fi

        export magick_tmpdir && convert \
            -limit memory 0 \
            -limit map 0 \
            "$file" \
            -compress None \
            "$output"
    done
    rm -f ${storage}/${filepool}*.${image_format}

    if ((VERBOSE)); then
        filepool_status $storage $filepool $image_format_dest
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}

# Rotate a filepool by 180 degrees
#
# Note: If acting on pnm files, performance can be increased
#
# Uses ntepbm as default and imagemagick as fall-back.
filepool_rotate180() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    if ((PLUGIN_VERBOSE)); then
        echo "--- filepool_rotate180 ---"
        local start=$(date +%s.%N)
    fi

    local files=${storage}/${filepool}*.${image_format}
    for file in $(eval ls $files); do
        # try to rotate pnm file
        if [ "$image_format" = "pnm" ]; then
            if pnmflip -rotate180 "$file" > "${file}.tmp"; then
                if [ -e "${file}.tmp" ]; then
                    rm "$file"
                    mv "${file}.tmp" "$file"
                fi
                continue
            fi
        fi

        # extend pixelcache in /etc/ImageMagick-6/policy.xml if magick fails
        export MAGICK_TMPDIR && mogrify \
            -limit memory 0 \
            -limit map 0 \
            -compress None \
            -rotate 180 \
            $file
    done

    if ((PLUGIN_VERBOSE)); then
        filepool_status $storage $filepool $image_format
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}

filepool_move() {
    local storage=$1
    local filepool=$2
    local image_format=$3
    local filepool_dest=$4

    local n
    for file in ${storage}/${filepool}*.${image_format}; do
        n=$(filepool_getNumber $file)
        mv -f "$file" "${storage}/${filepool_dest}$n.${image_format}"
    done
}

filepool_push() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    if ! command -v git 2>/dev/null; then
        echo "$0: git not found."
        exit 1
    fi

    for file in ${storage}/${filepool}*.${image_format}; do
        git add -f $file
        git commit -m "add $file"
        git push --quiet &
    done
}

# merge multiple tiff files into one
filepool_mergetiff() {
    local storage=$1
    local filepool=$2
    local outputfile=$3

    local image_format="tiff"
    local files=${storage}/${filepool}*.${image_format}

    if ((VERBOSE)); then
        echo "--- filepool_mergetiff ---"
        local start=$(date +%s.%N)
    fi

    eval tiffcp $files $outputfile

    if ((VERBOSE)); then
        du -h $outputfile
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}
