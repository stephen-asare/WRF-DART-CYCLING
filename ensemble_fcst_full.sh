#!/bin/bash
# ==============================================================================
# Script: ensemble_fcst_full.sh
# Purpose: Generate the full experiment cycle free-run ensemble forecast
#          (e.g., 50 hours) for all members. This is used for generating
#          synthetic observations.
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

echo "=============================================================================="
echo "Starting Full Cycle Ensemble Forecasts (Range: ${phase1_DE_FCST_RANGE:-50} hours)"
echo "=============================================================================="

# Use ENS_WRF_DIR as the working folder for members
WORK_DIR=${ENS_WRF_DIR}
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

MEM=1
# while [[ $MEM -le $NUM_MEMBERS ]]; do  ## use only 1 since we want to just select ensemble member 1 as nature run to generate observations.
while [ $MEM -eq 1 ]; do
   CMEM=$(printf "e%03d" $MEM)
   MEMBER_DIR="${WORK_DIR}/${CMEM}"
   mkdir -p "$MEMBER_DIR"
   cd "$MEMBER_DIR" || exit 1
   
   echo "Linking perturbed files for member $CMEM..."
   ln -sf "${REAL_DIR}/${INITIAL_DATE}/wrfinput_d01.${INITIAL_DATE}.${CMEM}" ./wrfinput_d01 || exit 1
   ln -sf "${REAL_DIR}/${INITIAL_DATE}/wrfbdy_d01.${CMEM}" ./wrfbdy_d01 || exit 1
   
   echo "Submitting full forecast for member $CMEM..."
   cp "$SCRIPTS_DIR/advance_run.sh" ./advance_run.sh
   
   sbatch \
       -A "${ENS_FCST_SBATCH_ACCOUNT}" \
       -p "${ENS_FCST_SBATCH_PARTITION}" \
       -N "${ENS_FCST_SBATCH_NODES}" \
       -n "${ENS_FCST_SBATCH_TASKS}" \
       -t "${ENS_FCST_SBATCH_TIME}" \
       --mem-per-cpu="${ENS_FCST_SBATCH_MEM}" \
       -C "${ENS_FCST_SBATCH_CONSTRAINT}" \
       --job-name="wrf_full_${CMEM}" \
       --output="wrf_full_${CMEM}_%j.log" \
       ./advance_run.sh "$INITIAL_DATE" "$FINAL_DATE" "${phase1_DE_FCST_RANGE:-50}"
       
   sleep 2
   MEM=$((MEM+1))
done

echo "All full cycle ensemble forecast jobs submitted!"
exit 0
