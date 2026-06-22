#!/bin/bash

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"
source "$paramfile"

echo "Running gen_obs.sh with per-time ASCII+binary conversion..."

start_date=2015071300
end_date=2015071512

SCRIPT_DIR="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/gen_sys_obs2"


SYS_OBS_DIR=${SYS_OBS_DIR}/window_${start_date}_${end_date}
rm -rf "${SYS_OBS_DIR}"
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

    ln -sf "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/exe/"*.x "${OUTPUT_DIR}/" || exit 1
    ln -sf "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/work/advance_time" "${OUTPUT_DIR}/" || exit 1
    cp "${SCRIPT_DIR}/prepbufr.csh" "${OUTPUT_DIR}/" || exit 1

    # change path inside prepbufr.csh
    BUFR_odir=${OUTPUT_DIR}/prepout
    DART_DIR=/gpfs/research/chipilskigroup/stephen_asare/models/DART/v11.21.2
    BUFR_dir=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/prepbufr/bufr_data
    DART_exec_dir=${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/exe
    
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_odir[[:space:]]*=.*|set BUFR_odir = ${BUFR_odir}|g" prepbufr.csh || exit 4
    sed -i "s|^[[:space:]]*set[[:space:]]*DART_DIR[[:space:]]*=.*|set DART_DIR = ${DART_DIR}|g" prepbufr.csh || exit 2
    sed -i "s|^[[:space:]]*set[[:space:]]*BUFR_dir[[:space:]]*=.*|set BUFR_dir = ${BUFR_dir}|g" prepbufr.csh || exit 5
    sed -i "s|^[[:space:]]*set[[:space:]]*DART_exec_dir[[:space:]]*=.*|set DART_exec_dir = ${DART_exec_dir}|g" prepbufr.csh || exit 6

    # Configure namelist
    cp "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/work/input.nml" "${OUTPUT_DIR}/input.nml" || exit 7

    ./prepbufr.csh ${ccyy_s} ${mm_s} ${dd_s} ${hh_s} > prepbufr.log 2>&1 || { echo "prepbufr.csh failed for $current_date"; exit 11; }&

    current_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "24h" -f ccyymmddhh)
done

wait

exit 0
