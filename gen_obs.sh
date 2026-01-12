#!/bin/bash

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"
source "$paramfile"

echo "Running gen_obs.sh with per-time ASCII+binary conversion..."

start_date=201507141200
end_date=201507150000
OBS_DIR=/gpfs/research/scratch/sa24m/tqprof/run1/prepbufr
CYCLE_PERIOD=3  # in hrs

while [ "$start_date" -le "$end_date" ]; do
    echo ">>> Time: $start_date"

    ccyy_s=$(echo "$start_date" | cut -c 1-4)
    mm_s=$(echo "$start_date" | cut -c 5-6)
    dd_s=$(echo "$start_date" | cut -c 7-8)
    hh_s=$(echo "$start_date" | cut -c 9-10)

    OUTPUT_DIR="${SYS_OBS_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}"
    mkdir -p "${OUTPUT_DIR}/prepout"
    cd "${OUTPUT_DIR}" || exit 1

    # Copy and patch prepbufr converter
    cp "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/work/"* . || exit 1
    START_TIME="${ccyy_s}${mm_s}${dd_s}${hh_s}"

    sed -i "/^ *set ref_time *=/c\ set ref_time=${START_TIME}" prepbufr.csh || exit 2
    sed -i "/^ *set obs_time *=/c\ set obs_time=${START_TIME}" prepbufr.csh || exit 3
    sed -i "/^ *set BUFR_dir *=/c\ set BUFR_dir=${OUTPUT_DIR}" prepbufr.csh || exit 4
    sed -i "/^ *set BUFR_in *=/c\  set BUFR_in=${OBS_DIR}/${ccyy_s}${mm_s}${dd_s}.nr/prepbufr.gdas.${ccyy_s}${mm_s}${dd_s}.t${hh_s}z.nr" prepbufr.csh || exit 5
    sed -i '/set BUFR_out *=.*oyear.*omn.*ody.*24/c\ set BUFR_out = ${BUFR_odir}/temp_obs.'${START_TIME} prepbufr.csh

    sed -i "/^ *obs_window *=/c\ obs_window=1.6" input.nml || exit 6
    sed -i "/^ *obs_window_cw *=/c\ obs_window_cw=1.6" input.nml || exit 7

    # Only generate ASCII obs if valid time
    if (( hh_s % 6 == 0 )); then
        echo "Generating ASCII obs..."
        # ./prepbufr.csh > prepbufr.log 2>&1 || { echo "prepbufr.csh failed"; exit 10; }

        # Convert ASCII to binary
        echo "Running create_real_obs for $START_TIME"

        cp "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/create_real_obs" . || exit 11
        echo "coping from ${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/input.nml"
        cp "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/input.nml" input.nml || exit 12
        cp input.nml input.nml.bak
        sed -i '/&ncepobs_nml/,/\//d' input.nml
        
        cat >> input.nml << EOF
&ncepobs_nml
   year       = ${ccyy_s},
   month      = ${mm_s},
   day        = ${dd_s},
   tot_days   = 0,
   max_num    = 800000,
   select_obs = 0,
   ObsBase = '${OUTPUT_DIR}/prepout/temp_obs.${START_TIME}',
   include_specific_humidity = .true.,
   include_relative_humidity = .false.,
   include_dewpoint = .false.,
   ADPUPA = .true.,
   AIRCAR = .true.,
   AIRCFT = .true.,
   SATEMP = .false.,
   SFCSHP = .true.,
   ADPSFC = .true.,
   SATWND = .false.,
   obs_U  = .true.,
   obs_V  = .true.,
   obs_T  = .true.,
   obs_PS = .false.,
   obs_QV = .false.,
   daily_file = .true.,
   obs_time = .false.,
   lon1   = 0.0,
   lon2   = 360.0,
   lat1   = -90.0,
   lat2   = 90.0 /
EOF

        ./create_real_obs > create_real_obs_${START_TIME}.log 2>&1
        if [ $? -ne 0 ]; then
            echo "create_real_obs failed for $START_TIME. See log."
            touch ABORT_RETRO
            exit 13
        fi
    fi

    start_date=$("$BUILD_DIR/da_advance_time.exe" "$start_date" "${CYCLE_PERIOD}h" -f ccyymmddhhnn 2>/dev/null)
done

exit 0
