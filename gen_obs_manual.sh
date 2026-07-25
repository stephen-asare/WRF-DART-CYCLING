#!/bin/bash
# ==============================================================================
# Script: gen_obs_manual.sh
# Purpose: Top-level driver to generate synthetic observations using manually
#          configured locations and metadata.
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
echo "Generating Synthetic Observations (Manually Configured Locations)"
echo "  Window: ${INITIAL_DATE} to ${FINAL_DATE}"
echo "  Output Directory: ${WINDOW_DIR}"
echo "=============================================================================="

# Step 1: Create the manual observation locations and metadata
echo "Step 1: Generating manual observation template using sys_temp_obs.py..."
# Set dates in YYYYMMDDHH format (sys_temp_obs.py requires 10-char format)
# Calculate START_DATE to match the start of the window, e.g. 6 hours after INITIAL_DATE to match GFS/FNL
export START_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 6 2>/dev/null)
export END_DATE="${FINAL_DATE}"
export REF_TIME="${INITIAL_DATE}"
export OUTPUT_DIR="${WINDOW_DIR}/sys_temp_obs"
python3 "${SCRIPT_DIR}/sys_temp_obs.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: sys_temp_obs.py failed!" >&2
    exit $RC
fi

# Step 2: Extract Nature run values at the manually defined locations
echo "Step 2: Extracting Nature run values using extract_wrf_obs_earthwind_ObsError2.py..."
export WRF_DIR="${NATURE_DIR}"
export OBS_DIR="${WINDOW_DIR}/sys_temp_obs"
export OUTPUT_DIR="${WINDOW_DIR}/sys_obs_wrf_single"
python3 "${SCRIPT_DIR}/extract_wrf_obs_earthwind_ObsError2.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: extract_wrf_obs failed!" >&2
    exit $RC
fi

# Step 3: Convert intermediate text files into DART observation sequence format
echo "Step 3: Converting ASCII observations to DART format..."
bash "${SCRIPTS_DIR}/make_obs.sh" "sys_obs_wrf_single" "ascii_to_obs_single"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: make_obs.sh failed!" >&2
    exit $RC
fi

echo "Successfully completed synthetic observations generation (Manual Locations)!"
exit 0
