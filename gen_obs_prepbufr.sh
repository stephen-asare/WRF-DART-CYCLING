#!/bin/bash
# ==============================================================================
# Script: gen_obs_prepbufr.sh
# Purpose: Top-level driver to generate synthetic observations using prepbufr
#          locations and metadata.
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

# --- CHECKPOINT SETUP ---
# Create a hidden directory in the window folder to store success markers
CHECKPOINT_DIR="${WINDOW_DIR}/.checkpoints"

echo "=============================================================================="
echo "Generating Synthetic Observations (Prepbufr Locations)"
echo "  Window: ${INITIAL_DATE} to ${FINAL_DATE}"
echo "  Output Directory: ${WINDOW_DIR}"
echo "=============================================================================="

# --- STEP 1: gen_obs.sh ---
if [[ -f "${CHECKPOINT_DIR}/step1_done" ]]; then
    echo "Skipping Step 1: gen_obs.sh (Already completed)"
else
    echo "Step 1: Running gen_obs.sh to extract prepbufr observations..."
    bash "${SCRIPTS_DIR}/gen_obs.sh"
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "ERROR: gen_obs.sh failed!" >&2
        exit $RC
    fi
    mkdir -p "${CHECKPOINT_DIR}"
    touch "${CHECKPOINT_DIR}/step1_done" # Mark success
fi

# --- STEP 2: filter_obs.py ---
if [[ -f "${CHECKPOINT_DIR}/step2_done" ]]; then
    echo "Skipping Step 2: filter_obs.py (Already completed)"
else
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
    touch "${CHECKPOINT_DIR}/step2_done" # Mark success
fi

# --- STEP 3: extract_wrf_obs_earthwind_ObsError2.py ---
if [[ -f "${CHECKPOINT_DIR}/step3_done" ]]; then
    echo "Skipping Step 3: extract_wrf_obs... (Already completed)"
else
    echo "Step 3: Extracting Nature run values using extract_wrf_obs_earthwind_ObsError2.py..."
    export WRF_DIR="${NATURE_DIR2}"
    export OBS_DIR="${WINDOW_DIR}/filtered_obs"
    export OUTPUT_DIR="${WINDOW_DIR}/sys_obs_wrf"
    python3 "${SCRIPT_DIR}/extract_wrf_obs_earthwind_ObsError2.py"
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "ERROR: extract_wrf_obs failed!" >&2
        exit $RC
    fi
    touch "${CHECKPOINT_DIR}/step3_done" # Mark success
fi

# --- STEP 4: make_obs.sh ---
if [[ -f "${CHECKPOINT_DIR}/step4_done" ]]; then
    echo "Skipping Step 4: make_obs.sh"
else
    echo "Step 4: Converting ASCII observations to DART format..."
    bash "${SCRIPTS_DIR}/make_obs.sh" "sys_obs_wrf" "ascii_to_obs"
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "ERROR: make_obs.sh failed!" >&2
        exit $RC
    fi
    touch "${CHECKPOINT_DIR}/step4_done" # Mark success
fi

echo "Successfully completed synthetic observations generation"
exit 0