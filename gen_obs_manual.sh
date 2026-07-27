#!/bin/bash
# ==============================================================================
# Script: gen_obs_manual.sh
# Purpose: Top-level driver to generate synthetic observations using manually
#          configured locations and metadata.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
paramfile="${SCRIPT_DIR}/param.sh"

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found at $paramfile!" >&2
    exit 1
fi
source "$paramfile"

SCRIPT_DIR="${SCRIPTS_DIR}/gen_sys_obs"
WINDOW_DIR="${SYS_OBS_DIR}/window_${INITIAL_DATE}_${FINAL_DATE}"

echo "=============================================================================="
echo "Generating Synthetic Observations"
echo "  Window: ${INITIAL_DATE} to ${FINAL_DATE}"
echo "  Output Directory: ${WINDOW_DIR}"
echo "=============================================================================="

echo "Generating manual observation template using sys_temp_obs.py..."
export START_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 6 2>/dev/null)
export END_DATE="${FINAL_DATE}"
export REF_TIME="${INITIAL_DATE}"
export OUTPUT_DIR="${WINDOW_DIR}/sys_temp_obs"
export FREQ_HOURS="${INTERVAL_HOURS}"
python3 "${SCRIPT_DIR}/sys_temp_obs.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: sys_temp_obs.py failed!" >&2
    exit $RC
fi

echo "Extracting Nature run values using extract_wrf_obs_earthwind_ObsError2.py..."
export WRF_DIR="${NATURE_DIR2}"
export OBS_DIR="${WINDOW_DIR}/sys_temp_obs"
export OUTPUT_DIR="${WINDOW_DIR}/sys_obs_wrf_manual"
python3 "${SCRIPT_DIR}/extract_wrf_obs_earthwind_ObsError2.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: extract_wrf_obs failed!" >&2
    exit $RC
fi

echo "Converting ASCII observations to DART format..."
bash "${SCRIPTS_DIR}/make_obs.sh" "sys_obs_wrf_manual" "ascii_to_obs_manual"
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: make_obs.sh failed!" >&2
    exit $RC
fi

echo "Successfully completed synthetic observations generation"
exit 0
