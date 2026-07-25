#!/bin/bash
# ==============================================================================
# Script: gen_init.sh
# Purpose: Collapsed, modularized entry point for generating perturbed WRF 
#          ensemble initial (IC) and lateral boundary (LBC) conditions.
#          Sourcing param.sh configuration and submitting parallel SLURM jobs
#          with explicit job dependencies to prevent race conditions.
# ==============================================================================

# 1. Source parameters
paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run3/WRF-DART-CYCLING/param.sh"
if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found at $paramfile" >&2
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

echo "Dates and Paths Summary:"
echo "  Initial Date:    $INITIAL_DATE"
echo "  Final Date:      $FINAL_DATE"
echo "  LBC End Date:    $MET_END"
echo "  ICBC Subdir:     $ICBC_SUBDIR"
echo "  Unperturbed IC:  $ICBC_INPUT_FILE"
echo "  Unperturbed LBC: $ICBC_BDY_FILE"

# 3. Sanity check for unperturbed files
if [[ ! -f "$ICBC_INPUT_FILE" ]]; then
    echo "ERROR: Unperturbed IC file does not exist: $ICBC_INPUT_FILE" >&2
    exit 1
fi
if [[ ! -f "$ICBC_BDY_FILE" ]]; then
    echo "ERROR: Unperturbed LBC file does not exist: $ICBC_BDY_FILE" >&2
    exit 1
fi

# 4. Prepare RC directory and symlinks
# REAL_DIR should point to ${RUN_DIR}/osse_out/ens/rc (loaded from param.sh)
mkdir -p "$REAL_DIR/$INITIAL_DATE"

ANALYSIS_DATE=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 0 -W 2>/dev/null)
UNPERT_IC_LINK="$REAL_DIR/$INITIAL_DATE/wrfinput_d01.${ANALYSIS_DATE}"
UNPERT_LBC_LINK="$REAL_DIR/$INITIAL_DATE/wrfbdy_d01"

echo "Linking unperturbed files in RC folder..."
ln -sf "$ICBC_INPUT_FILE" "$UNPERT_IC_LINK"
ln -sf "$ICBC_BDY_FILE" "$UNPERT_LBC_LINK"

# 5. Loop over members to submit jobs
# Base work directory for perturbations (avoiding name collision with global RUN_DIR)
ENS_PERT_WORK_DIR="${ENS_DIR}/perturb_wrf_bc"
mkdir -p "$ENS_PERT_WORK_DIR"

echo "Submitting perturbation jobs for $NUM_MEMBERS members..."

for (( MEM=1; MEM<=NUM_MEMBERS; MEM++ )); do
    # Format member string (e001, e002, etc.)
    CMEM=$(printf "e%03d" $MEM)
    
    # Define file targets
    DA_FIRST_GUESS="$UNPERT_IC_LINK"
    DA_ANALYSIS="$REAL_DIR/$INITIAL_DATE/wrfinput_d01.${INITIAL_DATE}.${CMEM}"
    BDYIN="$UNPERT_LBC_LINK"
    BDYOUT="$REAL_DIR/$INITIAL_DATE/wrfbdy_d01.${CMEM}"
    
    # Member specific work directories
    WRFVAR_RUN_DIR="${ENS_PERT_WORK_DIR}/run/${INITIAL_DATE}/wrfvar_d01/${INITIAL_DATE}.${CMEM}"
    UPDBC_RUN_DIR="${ENS_PERT_WORK_DIR}/run/${INITIAL_DATE}/pert_wrf_bc/${INITIAL_DATE}.${CMEM}"
    
    mkdir -p "$WRFVAR_RUN_DIR"
    mkdir -p "$UPDBC_RUN_DIR"
    
    # Seeds for randomcv
    SEED_ARRAY1=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 0 -f hhddmmyycc)
    SEED_ARRAY2=$(( MEM * 100000 ))
    
    echo "Submitting jobs for member $CMEM..."

    # Submit WRFVAR (IC perturbation) Job
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

# Sourcing parameters to set all NL_ variables and load modules
source "$paramfile"

# Member details
export MEM=${MEM}
export CMEM=${CMEM}
export DATE=${INITIAL_DATE}
export RUN_DIR=${WRFVAR_RUN_DIR}
export WORK_DIR="\${RUN_DIR}/working"

export NL_ANALYSIS_DATE=${ANALYSIS_DATE}.0000
export DA_FIRST_GUESS=${DA_FIRST_GUESS}
export DA_ANALYSIS=${DA_ANALYSIS}
export DA_BACK_ERRORS=\$WRFVAR_DIR/var/run/be.dat.cv3
export NL_ENSDIM_ALPHA=0
export NL_SEED_ARRAY1=${SEED_ARRAY1}
export NL_SEED_ARRAY2=${SEED_ARRAY2}

# Setup working directory
rm -rf "\$WORK_DIR"
mkdir -p "\$WORK_DIR"
cd "\$WORK_DIR"

# Link WRFDA tables and binaries
ln -fs \$WRFVAR_DIR/run/LANDUSE.TBL .
ln -fs \$BUILD_DIR/da_wrfvar.exe .
ln -fs \$WRFVAR_DIR/run/RRTM_DATA_DBL RRTM_DATA
ln -fs \$WRFVAR_DIR/run/VEGPARM.TBL .
ln -fs \$WRFVAR_DIR/run/SOILPARM.TBL .
ln -fs \$WRFVAR_DIR/run/GENPARM.TBL .
ln -fs \$WRFVAR_DIR/var/run/radiance_info radiance_info
ln -fs "\$DA_FIRST_GUESS" fg
ln -fs "\$DA_FIRST_GUESS" wrfinput_d01
ln -fs "\$DA_BACK_ERRORS" be.dat

# Generate namelist.input
. \$WRFVAR_DIR/inc/namelist_script.inc

# Run WRFDA in randomcv mode
srun ./da_wrfvar.exe
RC=\$?

if [[ \$RC -ne 0 ]]; then
   echo "ERROR: da_wrfvar.exe failed, RC=\$RC" >&2
   exit \$RC
fi

# Copy final perturbed analysis to output location
cp wrfvar_output "\$DA_ANALYSIS"

# Archive logs
cp statistics cost_fn grad_fn rsl.out.0000 "\$RUN_DIR" 2>/dev/null || true

# Cleanup if requested
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

    # Submit UPDATE_BC (LBC perturbation) Job with dependency on WRFVAR
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

# Sourcing parameters to load variables and modules
source "$paramfile"

export DATE=${INITIAL_DATE}
export RUN_DIR=${UPDBC_RUN_DIR}
export WORK_DIR="\${RUN_DIR}/working"
export DA_REAL_OUTPUT=${DA_FIRST_GUESS}
export BDYIN=${BDYIN}
export DA_ANALYSIS=${DA_ANALYSIS}
export BDYOUT=${BDYOUT}

# Setup working directory
rm -rf "\$WORK_DIR"
mkdir -p "\$WORK_DIR"
cd "\$WORK_DIR"

cp -f "\$DA_REAL_OUTPUT" real_output
cp -f "\$BDYIN" wrfbdy_d01
ln -sf "\$DA_ANALYSIS" wrfvar_output

# Generate parame.in namelist
echo "&control_param" > parame.in
echo " da_file            = 'wrfvar_output'" >> parame.in
echo " wrf_bdy_file       = 'wrfbdy_d01'" >> parame.in
echo " wrf_input          = 'real_output'" >> parame.in
echo " cycling = .false." >> parame.in
echo " debug   = .true." >> parame.in
echo " update_lateral_bdy = .true." >> parame.in
echo " update_low_bdy = .false. /" >> parame.in

# Run update_bc
ln -fs \$BUILD_DIR/da_update_bc.exe .
srun ./da_update_bc.exe
RC=\$?

if [[ \$RC -ne 0 ]]; then
   echo "ERROR: da_update_bc.exe failed, RC=\$RC" >&2
   exit \$RC
fi

# Copy final perturbed boundary file to output location
cp wrfbdy_d01 "\$BDYOUT"

# Cleanup if requested
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
    echo "  -> submitted updbc job: $UPDBC_JOBID (dependent on $WRFVAR_JOBID)"

    # Small delay between job submissions to avoid scheduler bottleneck
    sleep 0.5
done

echo "=============================================================================="
echo "All perturbation jobs successfully submitted to SLURM!"
echo "=============================================================================="
exit 0
