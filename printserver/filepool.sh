#!/bin/bash
# vim: set ts=4 sw=4 tw=0 et :

# number of pool entity
filepool_getNumber() {
    local file="$1"

    n=$(echo ${file##*/} | sed 's/[a-z]\+\([0-9]\+\).[a-z]\+/\1/i')
    n=$((10#$n))
    n=$(printf '%05d' $n)

    echo $n
}

# numer of files in the specified pool
filepool_getSize() {
    local filepool=$1
    local image_format=$2

    local files=${filepool}*.${image_format}
    echo $(($(eval ls -l $files 2>/dev/null | wc -l)))
}

# disk usage of pool
filepool_status() {
    local filepool=$1
    local image_format=$2

    local numfiles=$(filepool_getSize "$filepool" $image_format)
    local size=$(du -kc ${filepool}*.${image_format} | tail -n1 | cut -f1)
    local size_human=$(du -hc ${filepool}*.${image_format} | tail -n1 | cut -f1)

    echo -n "filepool_status: "
    echo -n "$numfiles file(s) "
    echo -n "${size}K ($size_human) "
    echo -n "${filepool}*.${image_format}"
    echo .

    if ((numfiles == 0)); then
        echo "Error! No files in pool!"
        exit 1
    fi
}

# use img2pdf to get a pdf file
# https://gitlab.mister-muffin.de/josch/img2pdf
filepool_merge_pdf() {
    local filepool=$1
    local image_format=$2
    local outputfile=$3

    if ((VERBOSE)); then
        echo "--- filepool_merge_pdf ---"
        local start=$(date +%s.%N)
    fi

    # img2pdf can only handle jpeg, png, tiff file pools
    if [ "$image_format" != "jpeg" -a "$image_format" != "png" -a "$image_format" != "tiff" ]; then
        local outputdir="$(dirname $outputfile)"
        local merge_dir=$(mktemp -d --tmpdir="$outputdir" mergepdfpoolXXXX)
        local filepool_merge="${merge_dir}/file"
        local image_format_merge=png
        filepool_convert $filepool $image_format $filepool_merge $image_format_merge
        img2pdf ${filepool_merge}*.${image_format_merge} -o $outputfile
        rm -rf $merge_dir
    else
        img2pdf ${filepool}*.${image_format} -o $outputfile
    fi

    if ((VERBOSE)); then
        stat $outputfile
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- end filepool_merge_pdf: ${diff}s ---"
    fi
}


filepool_convert() {
    local filepool=$1
    local image_format=$2
    local filepool_dest=$3
    local image_format_dest=$4

    if ((VERBOSE)); then
        echo "--- filepool_convert ---"
        local start=$(date +%s.%N)
    fi

    if command -v pamtotiff; then
        echo "New version of netpbm detected."
        echo "See http://netpbm.sourceforge.net/doc/pamtotiff.html"
        pamtotiff
    fi

    local magick_tmpdir="$(mktemp --tmpdir -d magickXXXX)"
    trap "rm -rf $magick_tmpdir" EXIT

    local n=
    local output=
    local file=
    for file in ${filepool}*.${image_format}; do
        n=$(filepool_getNumber $file)
        output="${filepool_dest}${n}.${image_format_dest}"

        echo "input: $file"
        echo "output: $output"

        # use package netpbm http://netpbm.sourceforge.net/
        if [ "$image_format" = "pnm" -a "$image_format_dest" = "tiff" ]; then
            pnmtotiff "$file" > "$output"
            continue
        fi
        if [ "$image_format" = "tiff" -a "$image_format_dest" = "pnm" ]; then
            tifftopnm "$file" > "$output"
            continue
        fi
        if [ "$image_format" = "pnm" -a "$image_format_dest" = "png" ]; then
            pnmtopng -compression 0 "$file" > "$output"
            continue
        fi

        export magick_tmpdir && convert \
            -limit memory 0 \
            -limit map 0 \
            "$file" \
            -compress None \
            "$output"
    done

    if ((VERBOSE)); then
        filepool_status $filepool_dest $image_format_dest
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- end filepool_convert: ${diff}s ---"
    fi
}

# Rotate a filepool by 180 degrees
#
# Note: If acting on pnm files, performance can be increased
#
# Uses ntepbm as default and imagemagick as fall-back.
filepool_rotate180() {
    local filepool=$1
    local image_format=$2

    if ((PLUGIN_VERBOSE)); then
        echo "--- filepool_rotate180 ---"
        local start=$(date +%s.%N)
    fi

    for file in ${filepool}*.${image_format}; do
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
        filepool_status ${filepool} $image_format
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}

filepool_move() {
    local filepool=$1
    local image_format=$2
    local filepool_dest=$3

    local n
    for file in ${filepool}*.${image_format}; do
        n=$(filepool_getNumber $file)
        mv -f "$file" "${filepool_dest}${n}.${image_format}"
    done
}

# merge multiple tiff files into one
filepool_merge_tiff() {
    local filepool=$1
    local outputfile=$2

    if ((VERBOSE)); then
        echo "--- filepool_merge_tiff ---"
        local start=$(date +%s.%N)
    fi

    # WARNING for unhandled usage of tiff filepools on large files
    local size=$(du -kc ${filepool}*.tiff | tail -n1 | cut -f1)
    if [ $size -gt $((2 * 1024 * 1024)) ]; then
        echo "Error: tiffs can only contain up to 2GB of data."
        exit 1
    fi

    tiffcp ${filepool}*.tiff $outputfile

    if ((VERBOSE)); then
        du -h $outputfile
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}
