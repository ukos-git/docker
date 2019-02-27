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
if [ -z "$PLUGIN_INPUT_DIR" ]; then
    PLUGIN_INPUT_DIR="scan"
fi
PLUGIN_INPUT_DIR="${PLUGIN_BASE_DIR}/${PLUGIN_INPUT_DIR}"

# output data directory
if [ -z "$PLUGIN_OUTPUT_DIR" ]; then
    PLUGIN_OUTPUT_DIR="build"
fi
PLUGIN_OUTPUT_DIR="${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}"

# output file
if [ -z "$PLUGIN_DESTINATION" ]; then
    PLUGIN_DESTINATION="processed.pdf"
fi
PLUGIN_DESTINATION="${PLUGIN_OUTPUT_DIR}/${PLUGIN_DESTINATION}"

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

if [ -z "$PLUGIN_SCAN_DPI" ]; then
    PLUGIN_SCAN_DPI=600
fi

################
# END SETTINGS #
################

# test input parameters
if [ ! -e "$PLUGIN_INPUT_DIR" ]; then
    echo "data dir $PLUGIN_INPUT_DIR does not exist."
    exit 1
fi

if [ ! -e "$PLUGIN_OUTPUT_DIR" ]; then
    echo "creating output data dir $PLUGIN_OUTPUT_DIR."
    mkdir -p "$PLUGIN_OUTPUT_DIR"
fi

MAGICK_TMPDIR="$(mktemp -d magickXXXX)"
cleanup() {
    if ((PLUGIN_VERBOSE)); then
        echo "cleaning up..."
    fi
    rm -rf "$MAGICK_TMPDIR" # delete this in any way

    if [ ! -e  "$PLUGIN_DESTINATION" ]; then
        exit 1
    fi

    if ((PLUGIN_VERBOSE)); then
        echo "script $0 finished successfully."
        echo "file is at $PLUGIN_DESTINATION."
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
		filepool_status $storage $filepool $image_format
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
    fi

    if ((PLUGIN_VERBOSE)); then
        echo "--- unscew ---"
        local start=$(date +%s.%N)
		filepool_status $storage $filepool pnm
    fi

    local pnmInput=$(ls -l ${storage}/${filepool}*.pnm 2>/dev/null | wc -l)
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
        --dpi $PLUGIN_SCAN_DPI \
        --sheet-size a4 \
        --no-noise-filter \
        ${storage}/${filepool}%05d.pnm \
        ${storage}/${temp_pool}%05d.pnm

    local pnmOutput=$(ls -l ${storage}/${temp_pool}*.pnm 2>/dev/null| wc -l)
    if ((pnmOutput == 0)); then
        echo "no output produced"
        exit 1
    fi
    if ((pnmInput != pnmOutput)); then
        rm -f ${storage}/${temp_pool}*.${image_format}
        exit 1
    fi
    filepool_move $storage $temp_pool pnm $filepool

    if [ $image_format != pnm ]; then
        filepool_convert $storage $filepool pnm $image_format
    fi

    if ((PLUGIN_VERBOSE)); then
		filepool_status $storage $filepool $image_format
        local end=$(date +%s.%N)
        local diff=$(echo "$end - $start" | bc)
        echo "--- total time: $diff ---"
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


    local unpaperargs=
    if [ $PLUGIN_FILE_FORMAT != pnm ]; then
        unpaperargs='--unpaper-args "--dpi $PLUGIN_SCAN_DPI --sheet-size a4 $PLUGIN_VERBOSE_DDASH"'
        echo adding unpaper arguments:
        echo "$(eval $unpaperargs)"
    fi

    ocrmypdf \
        --remove-background \
        --mask-barcodes \
        --clean \
        --image-dpi $PLUGIN_SCAN_DPI \
        --deskew \
        $(eval $unpaperargs) \
        --jbig2-lossy \
        --optimize 3 \
        --output-type pdfa \
        --pdfa-image-compression jpeg \
        -l deu \
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

filepool_status  $PLUGIN_INPUT_DIR $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT
echo "beginning postprocess."

# rotate and set dpi
ScanSnapS1500_PostProcess $PLUGIN_INPUT_DIR $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT

if [ $PLUGIN_FILE_FORMAT = pnm ]; then
    unscew $PLUGIN_INPUT_DIR $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT
fi

# lossless merge scanned files to tiff file
if [ "$PLUGIN_FILE_FORMAT" != "tiff" ]; then
    filepool_convert "$PLUGIN_INPUT_DIR" $PLUGIN_FILE_POOL $PLUGIN_FILE_FORMAT tiff
    PLUGIN_FILE_FORMAT=tiff
fi
COMBINED_TIFF="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR combinedXXXX.tiff)"
filepool_mergetiff "$PLUGIN_INPUT_DIR" $PLUGIN_FILE_POOL $COMBINED_TIFF

if command -v ocrmypdf > /dev/null; then
    COMBINED_PDF="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR combinedXXXX.pdf)"
    img2pdf -o $COMBINED_PDF $COMBINED_TIFF

    OCR_PDF="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR ocrmypdfXXXX.pdf)"
    ocrmypdf_ocr $COMBINED_PDF $OCR_PDF

    mv $OCR_PDF $PLUGIN_DESTINATION
    exit 0
fi

exit 0

# old variant disabled. more time consumptive but less resource consuming.
TIFF="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR combinedXXXX.tif)"
process_pnm unpaper $TIFF

PDF_OCR="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR tesseractocrXXXX.pdf)"
tesseract_ocr $TIFF $PDF_OCR
mv $PDF_OCR $PLUGIN_DESTINATION

exit 0

# no ghostscript!
PDF_GS="$(mktemp --dry-run --tmpdir=$PLUGIN_OUTPUT_DIR ghostXXXX.pdf)"
convert_ghostscript $PDF_OCR $PDF_GS
