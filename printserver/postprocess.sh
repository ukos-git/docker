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
VERBOSE=$PLUGIN_VERBOSE

# debug level
if [ -z "$PLUGIN_DEBUG" ]; then
    PLUGIN_DEBUG=0
fi
DEBUG=$PLUGIN_DEBUG

# manually define base dir
if [ -z "$PLUGIN_BASE_DIR" ]; then
    PLUGIN_BASE_DIR="/printserver/data"
fi

# input data directory
if [ -z "$PLUGIN_INPUT_DIR" ]; then
    PLUGIN_INPUT_DIR="scan"
fi

# output data directory
if [ -z "$PLUGIN_OUTPUT_DIR" ]; then
    PLUGIN_OUTPUT_DIR="build"
fi

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
if [ ! -e "${PLUGIN_BASE_DIR}/${PLUGIN_INPUT_DIR}" ]; then
    echo "Error: Input directory $PLUGIN_INPUT_DIR does not exist."
    exit 1
fi

if [ -e "${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}" ]; then
    echo "Initializing output dir at ${PLUGIN_OUTPUT_DIR}..."
    rm -rf "${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}"
fi
mkdir -p "${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}"

INPUT_POOL="${PLUGIN_BASE_DIR}/${PLUGIN_INPUT_DIR}/${PLUGIN_FILE_POOL}"

# no-gray-filter for colored images
UNPAPER_ARGS="--no-grayfilter --dpi $PLUGIN_SCAN_DPI $PLUGIN_VERBOSE_DDASH"
        
MAGICK_TMPDIR="$(mktemp -d magickXXXX)"
trap "rm -rf $MAGICK_TMPDIR" EXIT

cleanup() {
    if ((PLUGIN_VERBOSE)); then
        echo "cleaning up..."
    fi

    if [ ! -e  "${PLUGIN_BASE_DIR}/${PLUGIN_DESTINATION}" ]; then
        exit 1
    fi

    if ((PLUGIN_VERBOSE)); then
        echo "script $0 finished successfully."
        echo "file is at ${PLUGIN_BASE_DIR}/${PLUGIN_DESTINATION}."
    fi
    exit 0
}
trap cleanup EXIT

# uses unpaper to descew files one by one
descew() {
    local filepool=$1
    local image_format=$2

    if ! command -v unpaper > /dev/null; then
        echo "unpaper missing."
        echo "see https://github.com/Flameeyes/unpaper"
        exit 1
    fi

    # intermediate pools
    local pnm_pool="$(mktemp_dir pnmpoolXXXX)/file"
    local unpaper_pool="$(mktemp_dir unpaperpoolXXXX)/file"

    if ((PLUGIN_VERBOSE)); then
        echo "--- descew ---"
        local start=$(date +%s.%N)
    fi
    filepool_status $filepool $image_format

    if [ $image_format != pnm ]; then
        filepool_convert "$filepool" $image_format "$pnm_pool" pnm
    else
        filepool_move $filepool pnm $pnm_pool
    fi
    filepool_status $pnm_pool pnm

    local pnmInput=$(filepool_getSize $pnm_pool $image_format)

    for file in ${pnm_pool}*.pnm; do
        n=$(filepool_getNumber $file)
        output="${unpaper_pool}${n}.pnm"
        unpaper $UNPAPER_ARGS $file $output
    done
    filepool_status $unpaper_pool pnm

    local pnmOutput=$(filepool_getSize $unpaper_pool pnm)
    if ((pnmInput != pnmOutput)); then
        echo "Error in unpaper processing. No output produced"
        exit 1
    fi

    if [ $image_format != pnm ]; then
        filepool_convert $unpaper_pool pnm $filepool $image_format
    else
        filepool_move $unpaper_pool pnm $filepool
    fi
    filepool_status "$filepool" $image_format

    if ((!DEBUG)); then
        rm -rf $(dirname $pnm_pool)
        rm -rf $(dirname $unpaper_pool)
    fi

    if ((PLUGIN_VERBOSE)); then
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

    local unpaperargs="--clean --deskew --clean-final"
    if [ "$PLUGIN_FILE_FORMAT" != "pnm" ]; then
        unpaperargs="$unpaperargs --unpaper-args '$UNPAPER_ARGS'"
        echo "adding unpaper arguments: $unpaperargs"
        eval echo $unpaperargs
    fi

    eval ocrmypdf \
        --remove-background \
        --mask-barcodes \
        ${unpaperargs} \
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

# wrapper for mktemp
# @see mktemp_dir
mktemp_file() {
    local basename=$1

    if ((DEBUG));then
        mktemp --dry-run \
               --tmpdir="${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}" \
               "$basename"
    else
        mktemp --dry-run --tmpdir "$basename"
    fi
}

# wrapper for mktemp
# stores output in output dir if in debug mode and in system temp dir on
# default.
# @see mktemp_file
mktemp_dir() {
    local basename=$1

    if ((DEBUG));then
        mktemp -d --tmpdir="${PLUGIN_BASE_DIR}/${PLUGIN_OUTPUT_DIR}" "$basename"
    else
        mktemp -d --tmpdir "$basename"
    fi
}

echo "Beginning postprocess of scanned images..."

filepool_status "$INPUT_POOL" "$PLUGIN_FILE_FORMAT"
filepool_rotate180 "$INPUT_POOL" "$PLUGIN_FILE_FORMAT"

if [ $PLUGIN_FILE_FORMAT = pnm ]; then
    descew "$INPUT_POOL" "$PLUGIN_FILE_FORMAT"
fi

if command -v ocrmypdf > /dev/null; then
    COMBINED="$(mktemp_file combinedXXXX.pdf)"
    filepool_merge_pdf "$INPUT_POOL" "$PLUGIN_FILE_FORMAT" "$COMBINED"
    OCR_PDF="$(mktemp_file ocrmypdfXXXX.pdf)"
    ocrmypdf_ocr $COMBINED $OCR_PDF
else
    filepool_status "$INPUT_POOL" "$PLUGIN_FILE_FORMAT"
    COMBINED="$(mktemp_file combinedXXXX.tiff)"
    filepool_mergetiff $INPUT_POOL "$PLUGIN_FILE_FORMAT" "$COMBINED"
    OCR_PDF="$(mktemp_file tesseractocrXXXX.pdf)"
    tesseract_ocr $COMBINED $OCR_PDF
fi
mv $OCR_PDF ${PLUGIN_BASE_DIR}/${PLUGIN_DESTINATION}

exit 0 # no ghostscript!
PDF_GS="$(mktemp_file ghostXXXX.pdf)"
convert_ghostscript $PDF_OCR $PDF_GS
