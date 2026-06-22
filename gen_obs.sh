#!/bin/bash

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"
source "$paramfile"

echo "Running gen_obs.sh with per-time ASCII+binary conversion..."

start_date=201507130000
end_date=201507150000
OBS_DIR=/gpfs/research/scratch/sa24m/tqprof/run2/osse_out/prepbufr
CYCLE_PERIOD=3  # in hrs

SYS_OBS_DIR=${SYS_OBS_DIR}/window_${start_date:0:10}_${end_date:0:10}
mkdir -p "${SYS_OBS_DIR}"

# ===================================================
# 1. GENERATE ASCII OBS (temp_obs)
# ===================================================
current_date=$start_date
while [ "$current_date" -le "$end_date" ]; do
    echo ">>> Time: $current_date"

    ccyy_s=$(echo "$current_date" | cut -c 1-4)
    mm_s=$(echo "$current_date" | cut -c 5-6)
    dd_s=$(echo "$current_date" | cut -c 7-8)
    hh_s=$(echo "$current_date" | cut -c 9-10)

    OUTPUT_DIR="${SYS_OBS_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}"
    mkdir -p "${OUTPUT_DIR}/prepout"
    cd "${OUTPUT_DIR}" || exit 1
    
    # Copy and patch prepbufr converter
    cp "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/work/"* "${OUTPUT_DIR}/" || exit 1
    ln -sf "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/exe/"*.x "${OUTPUT_DIR}/" || exit 1
    START_TIME="${ccyy_s}${mm_s}${dd_s}${hh_s}"

    # --- BULLETPROOF PREPBUFR PATCHES ---
    # Using [[:space:]]* so it matches regardless of spaces or tabs in the default script
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_dir[[:space:]]*=.*|set BUFR_dir = ${OUTPUT_DIR}|g" prepbufr.csh || exit 2
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_idir[[:space:]]*=.*|set BUFR_idir = ${OBS_DIR}|g" prepbufr.csh || exit 3
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_odir[[:space:]]*=.*|set BUFR_odir = ${OUTPUT_DIR}/prepout|g" prepbufr.csh || exit 4
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_in[[:space:]]*=.*|set BUFR_in = ${OBS_DIR}/${ccyy_s}${mm_s}${dd_s}.nr/prepbufr.gdas.${ccyy_s}${mm_s}${dd_s}.t${hh_s}z.nr|g" prepbufr.csh || exit 5
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_out[[:space:]]*=.*|set BUFR_out = \${BUFR_odir}/temp_obs.${START_TIME}|g" prepbufr.csh || exit 6
    sed -i "s|^[[:space:]]*set[[:space:]]*files_per_day[[:space:]]*=.*|set files_per_day = 1|g" prepbufr.csh || exit 7
    sed -i "s|^[[:space:]]*set[[:space:]]*daily[[:space:]]*=.*|set daily = no|g" prepbufr.csh || exit 8

    # --- BULLETPROOF NAMELIST PATCHES ---
    sed -i "s|^[[:space:]]*obs_window[[:space:]]*=.*|   obs_window = 1.6|g" input.nml || exit 9
    sed -i "s|^[[:space:]]*obs_window_cw[[:space:]]*=.*|   obs_window_cw = 1.6|g" input.nml || exit 10

    # Only generate ASCII obs if valid time (every 6 hours)
    if (( 10#$hh_s % 6 == 0 )); then
        echo "Generating ASCII obs for $START_TIME..."
        ./prepbufr.csh $ccyy_s $mm_s $dd_s > prepbufr.log 2>&1 || { echo "prepbufr.csh failed for $START_TIME"; exit 11; }
    fi
    cp ${OUTPUT_DIR}/prepout/temp_obs.* "${SYS_OBS_DIR}/" 2>/dev/null
    
    current_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "6h" -f ccyymmddhhnn 2>/dev/null)
done
wait

# # ===================================================
# # 2. AUTOMATED FILE RENAMING (00Z -> 24Z of prev day)
# # ===================================================
# echo "Renaming 00Z files to 24Z of the previous day..."
# cd "${SYS_OBS_DIR}" || exit 12

# for file in temp_obs.*00; do
#     # Skip if wildcard didn't match anything
#     [ -e "$file" ] || continue 
    
#     # Extract the YYYYMMDDHH part
#     datetime="${file##*.}" 
    
#     # Use advance_time to step back 24 hours and format as just YYYYMMDD
#     prev_day=$("$BUILD_DIR/da_advance_time.exe" "${datetime:0:10}00" "-24h" -f ccyymmdd 2>/dev/null)
    
#     if [ -n "$prev_day" ]; then
#         cp "$file" "temp_obs.${prev_day}24"
#         echo "  -> Copied $file to temp_obs.${prev_day}24"
#     fi
# done

# # ===================================================
# # 3. SINGLE call to create_real_obs using all ASCII files
# # ===================================================
# echo "Running create_real_obs on all consolidated ASCII obs..."

# # Calculate total days dynamically so you don't have to change it manually next time
# ccyy_start=${start_date:0:4}
# mm_start=${start_date:4:2}
# dd_start=${start_date:6:2}

# sec_start=$(date -d "${ccyy_start}${mm_start}${dd_start}" +%s)
# sec_end=$(date -d "${end_date:0:8}" +%s)
# # Total days is difference in seconds divided by seconds in a day
# tot_days=$(( (sec_end - sec_start) / 86400 ))

# echo "Processing starting from ${ccyy_start}-${mm_start}-${dd_start} for $tot_days days."

# cp "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/create_real_obs" . || exit 13
# cp "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/input.nml" input.nml || exit 14
# cp input.nml input.nml.bak

# # Strip out old ncepobs_nml section
# sed -i '/&ncepobs_nml/,/\//d' input.nml

# cat >> input.nml << EOF
# &ncepobs_nml
#    year       = ${ccyy_start},
#    month      = ${mm_start},
#    day        = ${dd_start},
#    tot_days   = ${tot_days},
#    max_num    = 800000,
#    select_obs = 0,
#    ObsBase = '${SYS_OBS_DIR}/temp_obs.',
#    include_specific_humidity = .true.,
#    include_relative_humidity = .false.,
#    include_dewpoint = .false.,
#    ADPUPA = .true.,
#    AIRCAR = .true.,
#    AIRCFT = .true.,
#    SATEMP = .false.,
#    SFCSHP = .true.,
#    ADPSFC = .true.,
#    SATWND = .false.,
#    obs_U  = .true.,
#    obs_V  = .true.,
#    obs_T  = .true.,
#    obs_PS = .false.,
#    obs_QV = .false.,
#    daily_file = .false.,
#    obs_time = .true.,
#    lon1   = 0.0,
#    lon2   = 360.0,
#    lat1   = -90.0,
#    lat2   = 90.0 /
# EOF

# ./create_real_obs > create_real_obs_all.log 2>&1
# if [ $? -ne 0 ]; then
#     echo "create_real_obs failed. Check create_real_obs_all.log for details"
#     touch ABORT_RETRO
#     exit 99
# fi

# echo "All observation generation and binary conversion completed."
exit 0