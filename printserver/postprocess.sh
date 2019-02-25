#!/bin/bash
# vim: set ts=4 sw=4 tw=79 et :
#
# This is a drone.io plugin
#
set -o errexit -o pipefail -o noclobber
  # -o nounset

# load dependencies
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/filepool.sh"

############
# SETTINGS #
############

# verbosity level
if [ -z "$PLUGIN_VERBOSE" ]; then
    PLUGIN_VERBOSE=1
fi

# manually define base dir
if [ -z "$PLUGIN_BASE_DIR" ]; then
    PLUGIN_BASE_DIR="/printserver/data"
fi

# input data directory
if [ -z "$PLUGIN_STORAGE" ]; then
    PLUGIN_STORAGE="cache"
fi
PLUGIN_STORAGE="${PLUGIN_BASE_DIR}/${PLUGIN_STORAGE}"

# output file
if [ -z "$PLUGIN_DESTINATION" ]; then
    PLUGIN_DESTINATION="processed.pdf"
fi
PLUGIN_DESTINATION="${PLUGIN_BASE_DIR}/${PLUGIN_DESTINATION}"

# file pool base name
if [ -z "$PLUGIN_FILE_POOL" ]; then
    PLUGIN_FILE_POOL=SnapScanLossless
fi

# file format of scan
if [ -z "$PLUGIN_FILE_FORMAT" ]; then
    PLUGIN_FILE_FORMAT=tiff
fi

# lang deu is served by package tesseract-ocr-deu
if [ -z "$PLUGIN_SCAN_LANG" ]; then
    PLUGIN_SCAN_LANG=deu
fi

################
# END SETTINGS #
################

# test input parameters
if [ ! -e "$PLUGIN_STORAGE" ]; then
    echo "data dir $PLUGIN_STORAGE does not exist."
    exit 1
fi

MAGICK_TMPDIR="$(mktemp -d magickXXXX)"
cleanup() {
    if ((PLUGIN_VERBOSE)); then
        echo "script $0 finished. cleaning up..."
    fi
    rm -rf "$MAGICK_TMPDIR" # delete this in any way

    if [ ! -e  "$PLUGIN_DESTINATION" ]; then
        exit 1
    fi

    if ((PLUGIN_VERBOSE)); then
        echo "script $0 finished"
    fi
    exit 0
}
trap cleanup EXIT

#
# Post Process Data using ImageMagick
#
# Files are
#  * rotated
#  * dpi value is set
#
# !WARNING! Performance exhaustive function
# on an E-450 cpu ImageMagick takes about 10s for a single file of 97MiB 
#
ScanSnapS1500_PostProcess() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    if ((PLUGIN_VERBOSE)); then
        echo "--- ScanSnapS1500_PostProcess ---"
        local start=$(date +%s.%N)
    fi

    # extend pixelcache in /etc/ImageMagick-6/policy.xml if magick fails
    export MAGICK_TMPDIR && mogrify \
        -limit memory 0 \
        -limit map 0 \
        -compress None \
        -rotate 180 \
        ${storage}/${filepool}*.${image_format}

    if ((PLUGIN_VERBOSE)); then
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}

unscew() {
    local storage=$1
    local filepool=$2
    local image_format=$3

    # intermediate pool
    local temp_pool="unscew"

    if [ $image_format != pnm ]; then
        filepool_convert $storage $filepool $image_format pnm
        image_format=pnm
    fi

    if ((PLUGIN_VERBOSE)); then
        echo "--- unscew_pnm ---"
		filepool_status $storage $filepool $image_format
    fi

    local files=${storage}/${filepool}*.${image_format}
    local pnmInput=$(eval ls -l $files 2>/dev/null | wc -l)
    if ((pnmInput == 0)); then
        echo "no input files found"
        exit 1
    fi

    if ! command -v unpaper > /dev/null; then
        echo "unpaper missing. https://github.com/Flameeyes/unpaper"
        exit 1
    fi

    unpaper \
        $PLUGIN_VERBOSE_DDASH \
        --dpi $SCAN_DPI \
        --sheet-size a4 \
        --no-noise-filter \
        ${storage}/${filepool}%05d.${image_format} \
        ${storage}/${temp_pool}%05d.${image_format}

    local pnmOutput=$(ls -l ${storage}/${temp_pool}*.${image_format} 2>/dev/null| wc -l)
    if ((pnmOutput == 0)); then
        echo "no output produced"
        exit 1
    fi
    if ((pnmInput != pnmOutput)); then
        rm -f ${storage}/${temp_pool}*.${image_format}
        exit 1
    fi
    filepool_move $storage $temp_pool $image_format $filepool

    if ((PLUGIN_VERBOSE)); then
		filepool_status $storage $filepool $image_format
        echo "---"
    fi
}

ocrmypdf_ocr() {
    local input="$1"
    local output="$2"

    if ((PLUGIN_VERBOSE)); then
        echo "--- ocrmypdf_ocr ---"
        local start=$(date +%s.%N)
        du -h $input
    fi

    if ! command -v ocrmypdf > /dev/null; then
        echo "install ocrmypdf. https://ocrmypdf.readthedocs.io"
        exit 1
    fi

    #--unpaper-args "--dip $SCAN_DPI --sheet-size a4 $PLUGIN_VERBOSE_DDASH" \
    #--mask-barcodes \
    #--pdfa-image-compression jpeg \

    ocrmypdf \
        --remove-background \
        --deskew \
        --clean \
        -l deu \
        --output-type pdfa \
        "$input" \
        "$output"

    if ((PLUGIN_VERBOSE)); then
        du -h $output
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
    fi
}

tesseract_ocr() {
    local input="$1"
    local output="$2"

    if ((PLUGIN_VERBOSE)); then
        echo "--- tesseract_ocr ---"
        echo $input
        du -h $input
    fi
    if ! command -v tesseract > /dev/null; then
        echo "install tesseract from tesseract-ocr"
        exit 1
    fi
    tesseract \
        $input \
        ${output%.*} \
        -l $PLUGIN_SCAN_LANG \
        --psm 3 \
        pdf

    if ((PLUGIN_VERBOSE)); then
        echo ${output%.*}.pdf
        du -h "${output%.*}.pdf"
        echo "---"
    fi
}

# ghostscript is rewriting the pdf and interfers with tesseract output. Only
# use this if tesseract did not run!
convert_ghostscript() {
    local input="$1"
    local output="$2"

    if ((PLUGIN_VERBOSE)); then
        echo "--- convert_ghostscript ---"
        echo $input
        du -h $input
    fi

    if ! command -v gs; then
        exit 1
    fi
    gs \
        -sDEVICE=pdfwrite \
        -dCompatibilityLevel=1.4 \
        -dPDFSETTINGS=/screen \
        -dNOPAUSE \
        -dQUIET \
        -dBATCH \
        -sOutputFile="$output" \
        "$input"

    if ((PLUGIN_VERBOSE)); then
        echo $output
        du -h $output
        echo "---"
    fi
}

# reset branch
if command -v git > /dev/null; then
    (cd $PLUGIN_STORAGE && git reset --hard HEAD)
fi

# Only unscew here if we are in pnm format.
# Otherwise let ocrmypdf do the job.
if [ $PLUGIN_FILE_FORMAT = pnm ]; then
    unscew $PLUGIN_STORAGE $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT
fi

# rotate and set dpi
ScanSnapS1500_PostProcess $PLUGIN_STORAGE $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT

# lossless merge scanned files to tiff file
if [ "$PLUGIN_FILE_FORMAT" != "tiff" ]; then
    filepool_convert "$PLUGIN_STORAGE" $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT tiff
    PLUGIN_FILE_FORMAT=tiff
fi
COMBINED_TIFF="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE combinedXXXX.tiff)"
filepool_mergetiff "$PLUGIN_STORAGE" $PLUGIN_FILE_POOL $COMBINED_TIFF

if command -v ocrmypdf > /dev/null; then
    COMBINED_PDF="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE combinedXXXX.pdf)"
    img2pdf -o $COMBINED_PDF $COMBINED_TIFF

    OCR_PDF="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE ocrmypdfXXXX.pdf)"
    ocrmypdf_ocr $COMBINED_PDF $OCR_PDF

    mv $OCR_PDF $PLUGIN_DESTINATION
    exit 0
fi

exit 0

# old variant disabled. more time consumptive but less resource consuming.
TIFF="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE combinedXXXX.tif)"
process_pnm unpaper $TIFF

PDF_OCR="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE tesseractocrXXXX.pdf)"
tesseract_ocr $TIFF $PDF_OCR
mv $PDF_OCR $PLUGIN_DESTINATION

exit 0

# no ghostscript!
PDF_GS="$(mktemp --dry-run --tmpdir=$PLUGIN_STORAGE ghostXXXX.pdf)"
convert_ghostscript $PDF_OCR $PDF_GS
