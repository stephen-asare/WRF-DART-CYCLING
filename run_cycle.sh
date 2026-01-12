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
WORK_DIR=$DART_CYCLE_DIR



mkdir -p $WORK_DIR
cd $WORK_DIR 



### Create initial adaptive inflation files
if [ "$ADAPTIVE_INFLATION" = "1" ]; then
# RUN_DIR=$WORK_DIR/run_${ccyy_s}${mm_s}${dd_s}${hh_s}00
# Lazy copy namelist from previos run (obs_gen diretory)
ln -sf $DART_DIR/models/wrf/work/fill_inflation_restart .

cp ${SYS_OBS_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}/input.nml .
sed -i "/  ens_size/c\  ens_size                  = ${NUM_MEMBERS}," input.nml
## Running fill_inflation_restart requires 'THM' variable instead of 'T'
sed -i "/&model_nml/,/\// s/'T','QTY_POTENTIAL_TEMPERATURE'/'THM','QTY_POTENTIAL_TEMPERATURE'/" input.nml

## Insert this at the end of the namelist
cat >> input.nml << EOF
&fill_inflation_restart_nml
   write_prior_inf = .true.
   prior_inf_mean  = 1.00
   prior_inf_sd    = 0.6

   write_post_inf  = .false.
   post_inf_mean   = 1.00
   post_inf_sd     = 0.6

   input_state_files = 'wrfinput_d01', 'wrfinput_d02'
   single_file       = .false.
   verbose           = .false.
/
EOF
echo "Linking wrfinput_d0* as $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d0*_12_18 "
ln -sf $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d01_12_18 wrfinput_d01
ln -sf $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d02_12_18 wrfinput_d02
./fill_inflation_restart > fill_inflation_restart.log 2>&1
if [ $? -ne 0 ]; then
    echo "fill_inflation_restart failed. Check fill_inflation_restart.log for details"
    touch ABORT_RETRO
    exit 2
fi

# Create the home for inflation and future state space diagnostic files
mkdir -p "${WORK_DIR}"/${ccyy_s}${mm_s}${dd_s}${hh_s}/{Inflation_input,Output} && mv input_priorinf*.nc "${WORK_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}/Inflation_input/" ||  exit 1
mv dart_log* "${WORK_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}/Output/" || exit 2

fi   

## Loop over cycles
current_date=${start_date}
while [ "$current_date" -le "$end_date" ]; do
    echo "Starting DART cycle for $current_date"
    mkdir -p $WORK_DIR/$current_date
    cd $WORK_DIR/$current_date
    ## link files
    ln -sf ${SYS_OBS_DIR}/${current_date}/obs_seq.out ./obs_seq.out
