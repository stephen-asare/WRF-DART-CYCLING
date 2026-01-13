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

## Create directories for Prior and Post files
mkdir -p ${WORK_DIR}/priors
mkdir -p ${WORK_DIR}/posts

IMEM=1
while (( IMEM <= ${NUM_MEMBERS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi 
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi 
echo "Linking prior member ${ENS_WRF_DIR}/${CMEM}/wrfout_d0*_${ccyy_s}-${mm_s}-${dd_s}_15:00:00 ${WORK_DIR}/priors/wrfinput_d0*.$CMEM"
for dom in 1 2; do
    ln -sf "${ENS_WRF_DIR}/${CMEM}/wrfout_d0${dom}_${ccyy_s}-${mm_s}-${dd_s}_15:00:00" \
           "${WORK_DIR}/priors/wrfinput_d0${dom}.${CMEM}"
done
let IMEM=$IMEM+1
done

ls $WORK_DIR/priors/wrfinput_d01* > input_list_d01.txt
ls $WORK_DIR/priors/wrfinput_d02* > input_list_d02.txt

cp input_list_d01.txt output_list_d01.txt
cp input_list_d02.txt output_list_d02.txt

sed -i 's/priors/posts/g' output_list_d01.txt
sed -i 's/priors/posts/g' output_list_d02.txt

# prepare executable file
ln -sf $DART_DIR/models/wrf/work/filter .
ln -sf $DART_DIR/assimilation_code/programs/gen_sampling_err_table/work/sampling_error_correction_table.nc .
ln -sf $DART_DIR/models/wrf/work/pert_wrf_bc .

cp ${NML_DIR}/input.nml.d02 input.nml

cat > script.sed << EOF
  /ens_size/c\
  ens_size = ${NUM_MEMBERS},
  /num_output_obs_members/c\
      num_output_obs_members = ${NUM_MEMBERS},
  /inf_flavor/c\
      inf_flavor = ${inf_flavor}, 4
  /inf_initial_from_restart/c\
      inf_initial_from_restart = ${inf_initial_from_restart}, .false.,
  /inf_sd_initial_from_restart/c\
      inf_sd_initial_from_restart = ${inf_sd_initial_from_restart}, .false.,
  /layout/c\
      layout = ${lay_out},
  /tasks_per_node/c\
      tasks_per_node = ${tasks_per_node},
  /first_bin_center/c\
      first_bin_center = ${year},${month},${day},${hour}, 0, 0
  /last_bin_center/c\
      last_bin_center = ${year1},${month1},${day1},${hour1}, 0, 0
EOF

sed -f script.sed $NML_DIR/input.nml.d02 > input.nml
# sed -f script.sed /gpfs/research/scratch/sa24m/base/rundir/input.nml > input.nml

# exit 0
## Loop over cycles
# current_date=${start_date}
# while [ "$current_date" -le "$end_date" ]; do
#     previous_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "-${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)
#     echo "Previous date: $previous_date" 
#     echo "Starting DART cycle for $current_date" 
#     ccyy_p=$(echo "$previous_date" | cut -c 1-4) 
#     mm_p=$(echo "$previous_date" | cut -c 5-6) 
#     dd_p=$(echo "$previous_date" | cut -c 7-8) 
#     hh_p=$(echo "$previous_date" | cut -c 9-10) 
#     nn_p=$(echo "$previous_date" | cut -c 11-12) 

#     ccyy_s=$(echo "$current_date" | cut -c 1-4)
#     mm_s=$(echo "$current_date" | cut -c 5-6)
#     dd_s=$(echo "$current_date" | cut -c 7-8)
#     hh_s=$(echo "$current_date" | cut -c 9-10)
#     nn_s=$(echo "$current_date" | cut -c 11-12)

#     dtg="${ccyy_s}${mm_s}${dd_s}${hh_s}"
#     mkdir -p $WORK_DIR/${dtg}
#     cd $WORK_DIR/${dtg}

#     ## link observation files
#     ln -sf ${SYS_OBS_DIR}/obs_seq${dtg} .

#     # link prior files

