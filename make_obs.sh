#!/bin/bash
# ==============================================================================
# Script: make_obs.sh
# Purpose: Convert intermediate ASCII observation files into DART observation
#          sequence format using the DART create_real_obs utility.
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

OBS_SUBDIR=${1:-"sys_obs_wrf"}
ASCII_SUBDIR=${2:-"ascii_to_obs"}

WINDOW_DIR="${SYS_OBS_DIR}/window_${INITIAL_DATE}_${FINAL_DATE}"
OBS_DIR="${WINDOW_DIR}/${OBS_SUBDIR}"
RUN_DIR="${WINDOW_DIR}/${ASCII_SUBDIR}"

echo "=============================================================================="
echo "Running DART ascii_to_obs converter..."
echo "  Source OBS_DIR: $OBS_DIR"
echo "  Working RUN_DIR: $RUN_DIR"
echo "=============================================================================="

mkdir -p "$RUN_DIR"
rm -rf "${OBS_DIR}/temp_obs"
mkdir -p "${OBS_DIR}/temp_obs"

echo "Concatenating daily observation files..."
cd "${OBS_DIR}" || exit 1
unique_dates=$(ls temp_obs.*.*.wrf 2>/dev/null | cut -d'.' -f2 | cut -c1-8 | sort -u)

if [[ -z "$unique_dates" ]]; then
    echo "WARNING: No observation files found in $OBS_DIR!"
fi

for date_str in $unique_dates; do
    echo " -> Merging files for ${date_str}"
    cat temp_obs.${date_str}* > temp_obs/temp_obs.${date_str}
done

cd "$RUN_DIR" || exit 1

# Link DART binaries
ln -sf "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/create_real_obs" .
ln -sf "${DART_DIR}/models/wrf/work/obs_sequence_tool" .

# Generate input.nml 
start_year=$(echo "$INITIAL_DATE" | cut -c 1-4)
start_month=$(echo "$INITIAL_DATE" | cut -c 5-6 | sed 's/^0//')
start_day=$(echo "$INITIAL_DATE" | cut -c 7-8 | sed 's/^0//')

init_greg=$("$BUILD_DIR/da_advance_time.exe" "$INITIAL_DATE" 0 -g 2>/dev/null)
final_greg=$("$BUILD_DIR/da_advance_time.exe" "$FINAL_DATE" 0 -g 2>/dev/null)

read init_days init_secs <<< "$init_greg"
read final_days final_secs <<< "$final_greg"

diff_hours=$(( (final_days - init_days) * 24 + (final_secs - init_secs) / 3600 ))
tot_days=$(( diff_hours / 24 + 1 ))

echo "Creating input.nml with Start Year: $start_year, Month: $start_month, Day: $start_day, Total Days: $tot_days"

cp "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/input.nml" .

sed -i '/^[[:space:]]*&ncepobs_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
sed -i '/^[[:space:]]*&obs_sequence_tool_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml

cat >> input.nml <<EOF

&ncepobs_nml
   year       = ${start_year},
   month      = ${start_month},
   day        = ${start_day},
   tot_days   = ${tot_days},
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

&obs_sequence_tool_nml
   num_input_files = 2,
   filename_seq    = 'obs_seq20150714', 'obs_seq20150715',
   filename_out    = 'obs_seq_single',
   print_only      = .false.
/
EOF

# Run DART ascii_to_obs converter
./create_real_obs > log.create_real_obs 2>&1
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "ERROR: create_real_obs failed with code $RC!" >&2
    exit $RC
fi

# Run obs_sequence_tool to merge files if they exist
if [[ -f "obs_seq20150714" && -f "obs_seq20150715" ]]; then
    ./obs_sequence_tool > log.obs_sequence_tool 2>&1
    echo "Merged obs sequence files into obs_seq_single."
else
    echo "Single day obs files not found; skipped merging."
fi

echo "Observation conversion complete!"
exit 0
