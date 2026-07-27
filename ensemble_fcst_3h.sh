#!/bin/bash
# ==============================================================================
# Script: ensemble_fcst_3h.sh
# Purpose: Generate the initial short-range forecast (e.g., 3 hours) for all
#          ensemble members to spin up/start the cycling DA process.
# ==============================================================================
ulimit -s unlimited
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

# Spin-up range is 3 hours by default
FCST_RANGE=${SPINUP_TIME:-3}

# Calculate final date of this short forecast
FINAL_3H_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" "$FCST_RANGE" 2>/dev/null)

echo "=============================================================================="
echo "Starting Short-Range Spin-up Forecasts (Range: ${FCST_RANGE} hours)"
echo "  Start: $INITIAL_DATE"
echo "  End:   $FINAL_3H_DATE"
echo "=============================================================================="

WORK_DIR=${ENS_FCST_DIR}
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

MEM=1
while [[ $MEM -le $NUM_MEMBERS ]]; do
   CMEM=$(printf "e%03d" $MEM)
   MEMBER_DIR="${WORK_DIR}/${CMEM}"
   mkdir -p "$MEMBER_DIR"
   cd "$MEMBER_DIR" || exit 1
   
   echo "Linking perturbed files for member $CMEM..."
   ln -sf "${REAL_DIR}/${INITIAL_DATE}/wrfinput_d01.${INITIAL_DATE}.${CMEM}" ./wrfinput_d01 || exit 1
   ln -sf "${REAL_DIR}/${INITIAL_DATE}/wrfbdy_d01.${CMEM}" ./wrfbdy_d01 || exit 1
   
   echo "Submitting 3h forecast for member $CMEM..."
   cp "$SCRIPTS_DIR/advance_run.sh" ./advance_run.sh
   
   # Note: Since this is a short 3h forecast, we use the cycling resource configs
   sbatch \
       -A "${CYCLE_FCST_SBATCH_ACCOUNT}" \
       -p "${CYCLE_FCST_SBATCH_PARTITION}" \
       -N "${CYCLE_FCST_SBATCH_NODES}" \
       -n "${CYCLE_FCST_SBATCH_TASKS}" \
       -t "${CYCLE_FCST_SBATCH_TIME}" \
       --mem-per-cpu="${CYCLE_FCST_SBATCH_MEM}" \
       -C "${CYCLE_FCST_SBATCH_CONSTRAINT}" \
       --job-name="wrf_3h_${CMEM}" \
       --output="wrf_3h_${CMEM}_%j.log" \
       ./advance_run.sh "$INITIAL_DATE" "$FINAL_3H_DATE" "$FCST_RANGE"
       
   sleep 2
   MEM=$((MEM+1))
done

echo "All 3-hour ensemble forecast jobs submitted!"
exit 0
