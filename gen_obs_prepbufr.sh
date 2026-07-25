#!/bin/bash
# ==============================================================================
# Script: gen_obs_prepbufr.sh
# Purpose: Top-level driver to generate synthetic observations using prepbufr
#          locations and metadata.
# ==============================================================================

# 1. Source parameters
paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run3/WRF-DART-CYCLING/param.sh"
if [[ ! -f "$paramfile" ]]; then
    paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"
fi

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found!" >&2
    exit 1
fi
source "$paramfile"

SCRIPT_DIR="${SCRIPTS_DIR}/gen_sys_obs"
WINDOW_DIR="${SYS_OBS_DIR}/window_${INITIAL_DATE}_${FINAL_DATE}"

echo "=============================================================================="
echo "Generating Synthetic Observations (Prepbufr Locations)"
echo "  Window: ${INITIAL_DATE} to ${FINAL_DATE}"
echo "  Output Directory: ${WINDOW_DIR}"
echo "=============================================================================="

# Step 1: Extract conventional observation locations using prep_bufr
echo "Step 1: Running gen_obs.sh to extract prepbufr observations..."
bash "${SCRIPTS_DIR}/gen_obs.sh"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: gen_obs.sh failed!" >&2
    exit $RC
fi

# Step 2: Filter observations based on spatial bounds
echo "Step 2: Filtering observations using filter_obs.py..."
export BASE_DIR="${WINDOW_DIR}"
export SEARCH_PATTERN="${WINDOW_DIR}/*/prepout/temp_obs.*"
export OUTPUT_DIR="${WINDOW_DIR}/filtered_obs"
python3 "${SCRIPT_DIR}/filter_obs.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: filter_obs.py failed!" >&2
    exit $RC
fi

# Step 3: Extract Nature run values at filtered locations
echo "Step 3: Extracting Nature run values using extract_wrf_obs_earthwind_ObsError2.py..."
# For the Nature run, we use nature run forecast files
export WRF_DIR="${NATURE_DIR}"
export OBS_DIR="${WINDOW_DIR}/filtered_obs"
export OUTPUT_DIR="${WINDOW_DIR}/sys_obs_wrf_single"
python3 "${SCRIPT_DIR}/extract_wrf_obs_earthwind_ObsError2.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: extract_wrf_obs failed!" >&2
    exit $RC
fi

# Step 4: Convert intermediate text files into DART observation sequence format
echo "Step 4: Converting ASCII observations to DART format..."
bash "${SCRIPTS_DIR}/make_obs.sh" "sys_obs_wrf_single" "ascii_to_obs_single"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: make_obs.sh failed!" >&2
    exit $RC
fi

echo "Successfully completed synthetic observations generation (Prepbufr Locations)!"
exit 0
