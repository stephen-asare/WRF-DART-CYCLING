#!/bin/bash

## Run dart cycling aftter initial forecast

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"   # set this appropriately #%%%#
source "$paramfile"

start_date=201507141200
end_date=201507150000
cycle_period=3  # in hrs

ccyy_s=$(echo "$start_date" | cut -c 1-4)
mm_s=$(echo "$start_date" | cut -c 5-6)
dd_s=$(echo "$start_date" | cut -c 7-8)
hh_s=$(echo "$start_date" | cut -c 9-10)
nn_s=$(echo "$start_date" | cut -c 11-12)
## Directories
WORK_DIR=$DART_CYCLE



mkdir -p $WORK_DIR
cd $WORK_DIR 



### Create initial adaptive inflation files
if [ "$ADAPTIVE_INFLATION" = "1" ]; then
# RUN_DIR=$WORK_DIR/run_${ccyy_s}${mm_s}${dd_s}${hh_s}00
# Lazy copy namelist from previos run (obs_gen diretory)
cp $SYS_OBS_DIR/${ccyy_s}${mm_s}${dd_s}/input.nml .
## Insert this at the end of the namelist
cat >> input.nml << EOF
&fill_inflation_restart_nml
   write_prior_inf = .true.
   prior_inf_mean  = 1.00
   prior_inf_sd    = 0.6

   write_post_inf  = .false.
   post_inf_mean   = 1.00
   post_inf_sd     = 0.6

   input_state_files = 'wrfinput_d01'
   single_file       = .false.
   verbose           = .false.
/
EOF
ln -sf $ICBC_DIR/${ccyy_c}${mm_c}${dd_c}${hh_c}/wrfinput_d0*_12_18 .


# Create the home for inflation and future state space diagnostic files
# Should try to check each file here, but shortcutting for prior (most common) and link them all

mkdir -p "${RUN_DIR}"/{Inflation_input,Output}

if [ -e "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf_mean.nc" ]; then
    echo "Linking inflation files from ${OUTPUT_DIR}/${datep}/Inflation_input/ to ${RUN_DIR}/."

    ${LINK} "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf"*.nc "${RUN_DIR}/."
    ${LINK} "${OUTPUT_DIR}/${datep}/Inflation_input/input_postinf"*.nc "${RUN_DIR}/."

else

    echo "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf_mean.nc file does not exist. Stopping"
    touch ABORT_RETRO
    exit 3

fi
fi   # ADAPTIVE_INFLATION file check