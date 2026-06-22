#!/bin/ksh

export OBS_DIR=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/sys_obs/window_2015071300_2015071512/sys_obs_wrf_single
export RUN_DIR=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/sys_obs/window_2015071300_2015071512/ascii_to_obs_single
mkdir -p $RUN_DIR
cd $RUN_DIR || exit 1

rm -rf ${OBS_DIR}/temp_obs
mkdir -p ${OBS_DIR}/temp_obs

# ==============================================================================
# NEW: Dynamically find unique dates and concatenate sub-daily files
# ==============================================================================
echo "Concatenating daily observation files..."
cd ${OBS_DIR} || exit 1

unique_dates=$(ls temp_obs.*.*.wrf 2>/dev/null | cut -d'.' -f2 | cut -c1-8 | sort -u)

for date_str in $unique_dates; do
    echo " -> Merging files for ${date_str}"
    cat temp_obs.${date_str}* > temp_obs/temp_obs.${date_str}
done

cd $RUN_DIR || exit 1
# ==============================================================================

ln -sf /gpfs/home/sa24m/stephen_asare/models/DART/v11.21.2/observations/obs_converters/NCEP/ascii_to_obs/work/create_real_obs .
ln -sf /gpfs/home/sa24m/stephen_asare/models/DART/v11.21.2/models/wrf/work/obs_sequence_tool .

cp /gpfs/research/chipilskigroup/stephen_asare/models/DART/v11.21.2/observations/obs_converters/NCEP/ascii_to_obs/work/input.nml .

sed -i '/^[[:space:]]*&ncepobs_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml

cat >> input.nml <<EOF

&ncepobs_nml
   year       = 2015,
   month      = 7,
   day        = 14,
   tot_days   = 2,
   max_num    = 800000,
   select_obs = 0,
   ObsBase = '${OBS_DIR}/temp_obs/temp_obs.',
   include_specific_humidity = .true.,
   include_relative_humidity = .false.,
   include_dewpoint = .false.,
   ADPUPA = .true., 
   AIRCAR = .true., 
   AIRCFT = .true., 
   SATEMP = .true., 
   SFCSHP = .true., 
   ADPSFC = .true., 
   SATWND = .true.,
   obs_U  = .true., 
   obs_V  = .true., 
   obs_T  = .true.,
   obs_PS = .true.,
   obs_QV = .true.,
   daily_file = .true., 
   lon1   =   0.0,
   lon2   = 360.0,
   lat1   = -90.0,
   lat2   =  90.0
  /
EOF

# Run create_real_obs once for the entire 3-day window
echo "Running create_real_obs for the 3-day window..."
./create_real_obs > log.create_real_obs 2>&1

echo "Done. Single observation sequence file generated."

echo "merge all obs files together..."

cat >> input.nml <<EOF

&obs_sequence_tool_nml
   num_input_files = 2,
   filename_seq    = 'obs_seq20150714', 'obs_seq20150715',
   filename_out    = 'obs_seq_single',
   print_only      = .false.
/

EOF

./obs_sequence_tool > log.obs_sequence_tool 2>&1

echo "Done. Single observation sequence file generated."

exit 0
