#!/bin/bash

## Run dart cycling aftter initial forecast

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"   # set this appropriately #%%%#
source "$paramfile"

start_date=201507141200
end_date=201507141300
cycle_period=6  # in hrs

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
echo "Linking wrfinput from $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d0*_12_18 "
ln -sf $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d01_12_18 wrfinput_d01
ln -sf $ICBC_DIR/${ccyy_s}${mm_s}${dd_s}${hh_s}/wrfinput_d02_12_18 wrfinput_d02
./fill_inflation_restart > fill_inflation_restart.log 2>&1
if [ $? -ne 0 ]; then
    echo "fill_inflation_restart failed. Check fill_inflation_restart.log for details"
    touch ABORT_RETRO
    exit 2
fi

# Create the home for inflation and future state space diagnostic files
# mkdir -p "${WORK_DIR}"/{Inflation_input,Output} && mv input_priorinf*.nc "${WORK_DIR}/Inflation_input/" ||  exit 1
# mv dart_log* "${WORK_DIR}/Output/" || exit 2

fi   

## Create directories for Prior and Post files
mkdir -p ${WORK_DIR}/priors
mkdir -p ${WORK_DIR}/posts
mkdir analysis



inf_flavor=0
inf_initial_from_restart=".false."
inf_sd_initial_from_restart=".false."


# prepare executable file
ln -sf $DART_DIR/models/wrf/work/filter .
ln -sf $DART_DIR/assimilation_code/programs/gen_sampling_err_table/work/sampling_error_correction_table.nc .
ln -sf $DART_DIR/models/wrf/work/pert_wrf_bc .

# cp ${NML_DIR}/input.nml.d02 input.nml

cp /gpfs/research/chipilskigroup/stephen_asare/wrf_dart_debug_data/base/output/2017042712/input.nml input.nml

# Loop over cycles
current_date=${start_date}
echo " "
echo "Starting DART cycling from $start_date to $end_date every $cycle_period hours"
while [ "$current_date" -le "$end_date" ]; do
    previous_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "-${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)
    forward_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "1h" -f ccyymmddhhnn 2>/dev/null)
    echo "Previous date: $previous_date" 
    echo "Current date: $current_date" 
    echo "Forward date: $forward_date" 
    echo " "
    ccyy_p=$(echo "$previous_date" | cut -c 1-4) 
    mm_p=$(echo "$previous_date" | cut -c 5-6) 
    dd_p=$(echo "$previous_date" | cut -c 7-8) 
    hh_p=$(echo "$previous_date" | cut -c 9-10) 
    nn_p=$(echo "$previous_date" | cut -c 11-12) 

    ccyy_c=$(echo "$current_date" | cut -c 1-4)
    mm_c=$(echo "$current_date" | cut -c 5-6)
    dd_c=$(echo "$current_date" | cut -c 7-8)
    hh_c=$(echo "$current_date" | cut -c 9-10)
    nn_c=$(echo "$current_date" | cut -c 11-12)
    OUTPUT_DIR=$WORK_DIR/output/${ccyy_c}${mm_c}${dd_c}${hh_c}
    mkdir -p $OUTPUT_DIR

    ccyy_f=$(echo "$forward_date" | cut -c 1-4)
    mm_f=$(echo "$forward_date" | cut -c 5-6)
    dd_f=$(echo "$forward_date" | cut -c 7-8)
    hh_f=$(echo "$forward_date" | cut -c 9-10)
    nn_f=$(echo "$forward_date" | cut -c 11-12)
    # echo "ccyy_c: $ccyy_c mm_c: $mm_c dd_c: $dd_c hh_c: $hh_c nn_c: $nn_c"
    # echo "ccyy_f: $ccyy_f mm_f: $mm_f dd_f: $dd_f hh_f: $hh_f nn_f: $nn_f"
    # echo "ccyy_p: $ccyy_p mm_p: $mm_p dd_p: $dd_p hh_p: $hh_p nn_p: $nn_p"

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
      first_bin_center = ${ccyy_c},${mm_c},${dd_c},${hh_c}, 0, 0
  /last_bin_center/c\
      last_bin_center = ${ccyy_f},${mm_f},${dd_f},${hh_f}, 0, 0
EOF

# sed -f script.sed $NML_DIR/input.nml.d02 > input.nml

# cp input.nml input.nml.bak   # backup

# tmpfile=$(mktemp)

# # Write your new blocks, then the original file
# cat > "$tmpfile" << 'EOF'
# &probit_transform_nml
# /
# &algorithm_info_nml
#    qceff_table_filename = ''
# /
# EOF

# cat input.nml >> "$tmpfile"

# mv "$tmpfile" input.nml

cd $WORK_DIR



echo "Running DART filter for cycle at ${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c} ..."

ln -sf ${SYS_OBS_DIR}/obs_seq${ccyy_c}${mm_c}${dd_c}${hh_c} ./obs_seq.out 
# Link prior files
IMEM=1
while (( IMEM <= ${NUM_MEMBERS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi 
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi 

for dom in 1 2; do
    ln -sf "${ENS_WRF_DIR}/${CMEM}/wrfout_d0${dom}_${ccyy_c}-${mm_c}-${dd_c}_${hh_c}:00:00" \
           "${WORK_DIR}/priors/wrfinput_d0${dom}.${CMEM}"
done
let IMEM=$IMEM+1
done

ls $WORK_DIR/priors/wrfinput_d01* > input_list_d01.txt
echo "$WORK_DIR/priors/wrfinput_d01.*"
ls $WORK_DIR/priors/wrfinput_d02* > input_list_d02.txt

cp input_list_d01.txt output_list_d01.txt
cp input_list_d02.txt output_list_d02.txt

sed -i 's/priors/posts/g' output_list_d01.txt
sed -i 's/priors/posts/g' output_list_d02.txt

cat > run_filter << EOF
#!/bin/sh
#SBATCH --job-name=run_filter
#SBATCH -A chipilskigroup_q
#SBATCH --ntasks=64
#SBATCH --nodes=10
#SBATCH -t 01:30:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --output=output_%j.log
#SBATCH --export=ALL

ulimit -s unlimited
module load intel/21
module load openmpi/4.1.0
ml python/3

cd ${WORK_DIR}
srun  ${WORK_DIR}/filter
EOF
chmod +x run_filter
sbatch run_filter
wait

echo "filter done for cycle at ${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}."
datea=${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}
echo ""
echo "Listing contents of dir before archiving at $(date)"
ls -l *.nc dart_log* filter_* input.nml obs_seq* Output/inf_ic*
mkdir -p "${OUTPUT_DIR}/${datea}/"{Inflation_input,WRFIN,PRIORS,logs}

for FILE in postassim_mean.nc preassim_mean.nc postassim_sd.nc preassim_sd.nc \
            obs_seq.final analysis_increment.nc output_mean.nc output_sd.nc; do
    if [ -e "$FILE" ] && [ -s "$FILE" ]; then
        ${MOVE} "$FILE" "${OUTPUT_DIR}/${datea}/."
        if [ ! $? -eq 0 ]; then
            echo "Failed moving ${WORK_DIR}/${FILE} exiting"
            touch BOMBED
            exit
        fi
    else
        echo "${OUTPUT_DIR}/${FILE} does not exist and should. ls and exit"
        ls -l
        touch BOMBED
        exit
    fi
done


if [ "$ADAPTIVE_INFLATION" = "1" ]; then
    old_file=(input_postinf_mean.nc  input_postinf_sd.nc  input_priorinf_mean.nc  input_priorinf_sd.nc)
    new_file=(output_postinf_mean.nc output_postinf_sd.nc output_priorinf_mean.nc output_priorinf_sd.nc)
    i=0
    nfiles=${#new_file[@]}
    while [ "$i" -lt "$nfiles" ]; do
        if [ -e "${new_file[$i]}" ] && [ -s "${new_file[$i]}" ]; then
            ${MOVE} "${new_file[$i]}" "${OUTPUT_DIR}/${datea}/Inflation_input/${old_file[$i]}"
            if [ ! $? -eq 0 ]; then
                echo "Failed moving ${WORK_DIR}/Output/${new_file[$i]}"
                touch BOMBED
                exit
            fi
        fi
        i=$((i + 1))
    done
    echo "Past the inflation file moves"
fi   # Adaptive_inflation file moves

echo "Ready to integrate ensemble members"
n=1
while [ "$n" -le "${NUM_MEMBERS}" ]; do


current_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)
done
wait


exit 0
# sed -f script.sed /gpfs/research/scratch/sa24m/base/rundir/input.nml > input.nml

# exit 0
# # Loop over cycles
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

# export year=`echo   $DATE | cut -c1-4`
# export month=`echo  $DATE | cut -c5-6`
# export day=`echo    $DATE | cut -c7-8`
# export hour=`echo   $DATE | cut -c9-10` 
# export minute=`echo   $DATE | cut -c11-12`

# export year1=`echo  $FWD_DATE | cut -c1-4`
# export month1=`echo $FWD_DATE | cut -c5-6`
# export day1=`echo   $FWD_DATE | cut -c7-8`
# export hour1=`echo  $FWD_DATE | cut -c9-10` 
# export minute1=`echo  $FWD_DATE | cut -c11-12`

# export year2=`echo  $PREV_DATE | cut -c1-4`
# export month2=`echo $PREV_DATE | cut -c5-6`
# export day2=`echo   $PREV_DATE | cut -c7-8`
# export hour2=`echo  $PREV_DATE | cut -c9-10` 
# export minute2=`echo  $PREV_DATE | cut -c11-12`