#!/bin/bash
# ==============================================================================
# Script: download_prepbufr.sh
# Purpose: Download prepbufr files into the directory specified in param.sh.
# ==============================================================================

# Source parameters
paramfile="$(pwd)/param.sh"

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found in $(pwd)!" >&2
    exit 1
fi

source "$paramfile"

# Check that the target directory is configured
if [[ -z "$PREPBUFR_DATA_DIR" ]]; then
    echo "ERROR: PREPBUFR_DATA_DIR is not set in param.sh!" >&2
    exit 1
fi

echo "=============================================================================="
echo "Downloading Prepbufr Observations..."
echo "  Target Directory: $PREPBUFR_DATA_DIR"
echo "=============================================================================="

mkdir -p "$PREPBUFR_DATA_DIR"
cd "$PREPBUFR_DATA_DIR" || exit 1

opts="-N"
cert_opt=""

# download the file(s)
wget $cert_opt $opts https://osdf-director.osg-htc.org/ncar/gdex/d337000/tarfiles/2015/prepbufr.20150714.nr.tar.gz
wget $cert_opt $opts https://osdf-director.osg-htc.org/ncar/gdex/d337000/tarfiles/2015/prepbufr.20150715.nr.tar.gz
wget $cert_opt $opts https://osdf-director.osg-htc.org/ncar/gdex/d337000/tarfiles/2015/prepbufr.20150716.nr.tar.gz

echo "Prepbufr files downloaded successfully!"

echo "Extracting PrepBUFR archives..."

for file in prepbufr.*.tar.gz; do
    if [[ -f "$file" ]]; then
        echo "Extracting $file..."
        tar -xzf "$file"
    fi
done

echo "PrepBUFR archives extracted successfully!"
exit 0
