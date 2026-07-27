#!/bin/bash
# ==============================================================================
# Script: gen_init.sh
# Purpose: Collapsed, modularized entry point for generating perturbed WRF 
#          ensemble initial (IC) and lateral boundary (LBC) conditions.
#          Sourcing param.sh configuration and submitting parallel SLURM jobs
#          with explicit job dependencies to prevent race conditions.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
paramfile="${SCRIPT_DIR}/param.sh"

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found at $paramfile!" >&2
    exit 1
fi
source "$paramfile"

echo "=============================================================================="
echo "Starting WRF-DART Ensemble Initialization"
echo "=============================================================================="

# 2. Derive dynamic dates and directory structure
# Calculate LBC end date based on final date and LBC frequency
MET_END=$("$BUILD_DIR/da_advance_time.exe" "$FINAL_DATE" "$LBC_FREQ" 2>/dev/null)

ccyy_s=${INITIAL_DATE:0:4}
mm_s=${INITIAL_DATE:4:2}
dd_s=${INITIAL_DATE:6:2}
hh_s=${INITIAL_DATE:8:2}

ccyy_e=${MET_END:0:4}
mm_e=${MET_END:4:2}
dd_e=${MET_END:6:2}
hh_e=${MET_END:8:2}

ICBC_SUBDIR="${ccyy_s}${mm_s}${dd_s}${hh_s}_${ccyy_e}${mm_e}${dd_e}${hh_e}"
ICBC_INPUT_FILE="${ICBC_DIR}/${ICBC_SUBDIR}/wrfinput_d01_${hh_s}_${hh_e}"
ICBC_BDY_FILE="${ICBC_DIR}/${ICBC_SUBDIR}/wrfbdy_d01_${hh_s}_${hh_e}"

# 3. Calculate Time Windows for WRFDA Namelist
START_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" "${WINDOW_START}" 2>/dev/null)
END_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" "${WINDOW_END}" 2>/dev/null)

START_YEAR=${START_DATE:0:4}
START_MONTH=${START_DATE:4:2}
START_DAY=${START_DATE:6:2}
START_HOUR=${START_DATE:8:2}

END_YEAR=${END_DATE:0:4}
END_MONTH=${END_DATE:4:2}
END_DAY=${END_DATE:6:2}
END_HOUR=${END_DATE:8:2}

TIME_WINDOW_MIN="${START_YEAR}-${START_MONTH}-${START_DAY}_${START_HOUR}:00:00.0000"
TIME_WINDOW_MAX="${END_YEAR}-${END_MONTH}-${END_DAY}_${END_HOUR}:00:00.0000"

echo "Dates and Paths Summary:"
echo "  Initial Date:    $INITIAL_DATE"
echo "  Final Date:      $FINAL_DATE"
echo "  WRFVAR Window:   $TIME_WINDOW_MIN -> $TIME_WINDOW_MAX"
echo "  LBC End Date:    $MET_END"
echo "  ICBC Subdir:     $ICBC_SUBDIR"
echo "  Unperturbed IC:  $ICBC_INPUT_FILE"
echo "  Unperturbed LBC: $ICBC_BDY_FILE"

# 4. Sanity check for unperturbed files
if [[ ! -f "$ICBC_INPUT_FILE" ]]; then
    echo "ERROR: Unperturbed IC file does not exist: $ICBC_INPUT_FILE" >&2
    exit 1
fi
if [[ ! -f "$ICBC_BDY_FILE" ]]; then
    echo "ERROR: Unperturbed LBC file does not exist: $ICBC_BDY_FILE" >&2
    exit 1
fi

# 5. Prepare RC directory and symlinks
mkdir -p "$REAL_DIR/$INITIAL_DATE"

ANALYSIS_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 0 -W 2>/dev/null)
UNPERT_IC_LINK="$REAL_DIR/$INITIAL_DATE/wrfinput_d01.${ANALYSIS_DATE}"
UNPERT_LBC_LINK="$REAL_DIR/$INITIAL_DATE/wrfbdy_d01"

echo "Linking unperturbed files in RC folder..."
ln -sf "$ICBC_INPUT_FILE" "$UNPERT_IC_LINK"
ln -sf "$ICBC_BDY_FILE" "$UNPERT_LBC_LINK"

# 6. Loop over members to submit jobs
ENS_PERT_WORK_DIR="${ENS_DIR}/perturb_wrf_bc"
mkdir -p "$ENS_PERT_WORK_DIR"

echo "Submitting perturbation jobs for $NUM_MEMBERS members..."

for (( MEM=1; MEM<=NUM_MEMBERS; MEM++ )); do
    CMEM=$(printf "e%03d" $MEM)
    
    DA_FIRST_GUESS="$UNPERT_IC_LINK"
    DA_ANALYSIS="$REAL_DIR/$INITIAL_DATE/wrfinput_d01.${INITIAL_DATE}.${CMEM}"
    BDYIN="$UNPERT_LBC_LINK"
    BDYOUT="$REAL_DIR/$INITIAL_DATE/wrfbdy_d01.${CMEM}"
    
    WRFVAR_RUN_DIR="${ENS_PERT_WORK_DIR}/run/${INITIAL_DATE}/wrfvar_d01/${INITIAL_DATE}.${CMEM}"
    UPDBC_RUN_DIR="${ENS_PERT_WORK_DIR}/run/${INITIAL_DATE}/pert_wrf_bc/${INITIAL_DATE}.${CMEM}"
    
    mkdir -p "$WRFVAR_RUN_DIR"
    mkdir -p "$UPDBC_RUN_DIR"
    
    SEED_ARRAY1=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 0 -f hhddmmyycc)
    SEED_ARRAY2=$(( MEM * 100000 ))
    
    echo "Submitting jobs for member $CMEM..."

    WRFVAR_JOBID=$(sbatch --parsable <<EOF
#!/bin/bash
#SBATCH --job-name=wrfvar_${CMEM}
#SBATCH -A ${PERT_WRFVAR_SBATCH_ACCOUNT}
#SBATCH --partition=${PERT_WRFVAR_SBATCH_PARTITION}
#SBATCH --time=${PERT_WRFVAR_SBATCH_TIME}
#SBATCH --output=${WRFVAR_RUN_DIR}/run_wrf_var.log
#SBATCH --error=${WRFVAR_RUN_DIR}/run_wrf_var.err
#SBATCH --mem-per-cpu=${PERT_WRFVAR_SBATCH_MEM}
#SBATCH -C "${PERT_WRFVAR_SBATCH_CONSTRAINT}"
#SBATCH --ntasks=${PERT_WRFVAR_SBATCH_TASKS}
#SBATCH --export=ALL

ulimit -s unlimited

source "$paramfile"

export MEM=${MEM}
export CMEM=${CMEM}
export DATE=${INITIAL_DATE}
export RUN_DIR=${WRFVAR_RUN_DIR}
export WORK_DIR="\${RUN_DIR}/working"

export NL_ANALYSIS_DATE=${ANALYSIS_DATE}.0000
export DA_FIRST_GUESS=${DA_FIRST_GUESS}
export DA_ANALYSIS=${DA_ANALYSIS}
export DA_BACK_ERRORS=\$WRFDA_DIR/var/run/be.dat.cv3
export NL_ENSDIM_ALPHA=0
export NL_SEED_ARRAY1=${SEED_ARRAY1}
export NL_SEED_ARRAY2=${SEED_ARRAY2}

# Specific overrides for initial perturbations
export NL_ANALYSIS_TYPE="randomcv"
export NL_PUT_RAND_SEED=".TRUE."

# Date variables required for namelist_script.inc
export NL_START_YEAR=${ccyy_s}
export NL_START_MONTH=${mm_s}
export NL_START_DAY=${dd_s}
export NL_START_HOUR=${hh_s}
export NL_END_YEAR=${ccyy_s}
export NL_END_MONTH=${mm_s}
export NL_END_DAY=${dd_s}
export NL_END_HOUR=${hh_s}
export NL_TIME_WINDOW_MIN="${TIME_WINDOW_MIN}"
export NL_TIME_WINDOW_MAX="${TIME_WINDOW_MAX}"

# Map Domain 1 specific variables from param.sh to generic NL_ variables 
# required by WRFDA's namelist_script.inc
export NL_E_WE=${NL_E_WE_1}
export NL_E_SN=${NL_E_SN_1}
export NL_DX=${NL_DXY_1}
export NL_DY=${NL_DXY_1}
export NL_I_PARENT_START=1
export NL_J_PARENT_START=1
export NL_RA_LW_PHYSICS=${NL_RA_LW}
export NL_RA_SW_PHYSICS=${NL_RA_SW}
export NL_RADT=${NL_RADT1}
export NL_CU_PHYSICS=${NL_CU_PHYSICS1}
export NL_CUDT=${NL_CUDT1}

rm -rf "\$WORK_DIR"
mkdir -p "\$WORK_DIR"
cd "\$WORK_DIR"

ln -fs \$WRFDA_DIR/run/LANDUSE.TBL .
ln -fs \$BUILD_DIR/da_wrfvar.exe .
ln -fs \$WRFDA_DIR/run/RRTM_DATA_DBL RRTM_DATA
ln -fs \$WRFDA_DIR/run/VEGPARM.TBL .
ln -fs \$WRFDA_DIR/run/SOILPARM.TBL .
ln -fs \$WRFDA_DIR/run/GENPARM.TBL .
ln -fs \$WRFDA_DIR/var/run/radiance_info radiance_info
ln -fs "\$DA_FIRST_GUESS" fg
ln -fs "\$DA_FIRST_GUESS" wrfinput_d01
ln -fs "\$DA_BACK_ERRORS" be.dat

# Generate namelist.input
. \$WRFDA_DIR/inc/namelist_script.inc

srun ./da_wrfvar.exe
RC=\$?

if [[ \$RC -ne 0 ]]; then
   echo "ERROR: da_wrfvar.exe failed, RC=\$RC" >&2
   exit \$RC
fi

cp wrfvar_output "\$DA_ANALYSIS"
cp namelist.input "\$RUN_DIR/namelist.input"
cp statistics cost_fn grad_fn rsl.out.0000 "\$RUN_DIR" 2>/dev/null || true

if [[ "\$CLEAN" = "true" ]]; then
   rm -rf "\$WORK_DIR"
fi

exit 0
EOF
)

    if [[ -z "$WRFVAR_JOBID" ]]; then
        echo "ERROR: Failed to submit wrfvar job for member $CMEM" >&2
        exit 1
    fi
    echo "  -> submitted wrfvar job: $WRFVAR_JOBID"

    UPDBC_JOBID=$(sbatch --parsable --dependency=afterok:${WRFVAR_JOBID} <<EOF
#!/bin/bash
#SBATCH --job-name=updbc_${CMEM}
#SBATCH -A ${PERT_UPDBC_SBATCH_ACCOUNT}
#SBATCH --partition=${PERT_UPDBC_SBATCH_PARTITION}
#SBATCH --time=${PERT_UPDBC_SBATCH_TIME}
#SBATCH --output=${UPDBC_RUN_DIR}/run_update_bc.log
#SBATCH --error=${UPDBC_RUN_DIR}/run_update_bc.err
#SBATCH --mem-per-cpu=${PERT_UPDBC_SBATCH_MEM}
#SBATCH --ntasks=${PERT_UPDBC_SBATCH_TASKS}
#SBATCH --export=ALL

ulimit -s unlimited

source "$paramfile"

export DATE=${INITIAL_DATE}
export RUN_DIR=${UPDBC_RUN_DIR}
export WORK_DIR="\${RUN_DIR}/working"
export DA_REAL_OUTPUT=${DA_FIRST_GUESS}
export BDYIN=${BDYIN}
export DA_ANALYSIS=${DA_ANALYSIS}
export BDYOUT=${BDYOUT}

rm -rf "\$WORK_DIR"
mkdir -p "\$WORK_DIR"
cd "\$WORK_DIR"

cp -f "\$DA_REAL_OUTPUT" real_output
cp -f "\$BDYIN" wrfbdy_d01
ln -sf "\$DA_ANALYSIS" wrfvar_output

echo "&control_param" > parame.in
echo " da_file            = 'wrfvar_output'" >> parame.in
echo " wrf_bdy_file       = 'wrfbdy_d01'" >> parame.in
echo " wrf_input          = 'real_output'" >> parame.in
echo " cycling = .false." >> parame.in
echo " debug   = .true." >> parame.in
echo " update_lateral_bdy = .true." >> parame.in
echo " update_low_bdy = .false. /" >> parame.in

ln -fs \$BUILD_DIR/da_update_bc.exe .
srun ./da_update_bc.exe
RC=\$?

if [[ \$RC -ne 0 ]]; then
   echo "ERROR: da_update_bc.exe failed, RC=\$RC" >&2
   exit \$RC
fi

cp wrfbdy_d01 "\$BDYOUT"

if [[ "\$CLEAN" = "true" ]]; then
   rm -rf "\$WORK_DIR"
fi

exit 0
EOF
)

    if [[ -z "$UPDBC_JOBID" ]]; then
        echo "ERROR: Failed to submit updbc job for member $CMEM" >&2
        exit 1
    fi
    echo "  -> submitted updbc job"

    sleep 0.5
done

echo "=============================================================================="
echo "All perturbation jobs successfully submitted to SLURM!"
echo "=============================================================================="
exit 0
