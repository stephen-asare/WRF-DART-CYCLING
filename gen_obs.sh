#!/bin/bash

paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"   # set this appropriately #%%%#
source "$paramfile"

echo "Running gen_obs.sh"

# WORK_DIR=${SYS_OBS_DIR}
# if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
# cd $WORK_DIR
# start_date=($(echo $INITIAL_DATE 0h -g | ${BUILD_DIR}/advance_time)) || exit 1
# end_date=($(echo $FINAL_DATE 0h -g | ${BUILD_DIR}/advance_time)) || exit 1
# echo "start_date: $start_date"
# echo "end_date: $end_date"
# exit 0
start_date=201507141200
end_date=201507150000
OBS_DIR=/gpfs/research/scratch/sa24m/tqprof/run1/prepbufr
CYCLE_PERIOD=3  # in hrs
while [ "$start_date" -le "$end_date" ]; do
    echo "Generating synthetic observations for time: $start_date"

    ccyy_s=$(echo "$start_date" | cut -c 1-4)
    mm_s=$(echo "$start_date" | cut -c 5-6)
    dd_s=$(echo "$start_date" | cut -c 7-8)
    hh_s=$(echo "$start_date" | cut -c 9-10)
    nn_s=$(echo "$start_date" | cut -c 11-12)

    OUTPUT_DIR="${SYS_OBS_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}"
    mkdir -p "${OUTPUT_DIR}"
    cd "${OUTPUT_DIR}" || exit 1
    mkdir -p ${OUTPUT_DIR}/prepout

    cp "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/work/"* . || exit 1
    START_TIME="${ccyy_s}${mm_s}${dd_s}${hh_s}"

    sed -i "/^ *set ref_time *=/c\ set ref_time=${START_TIME}" prepbufr.csh || exit 2
    sed -i "/^ *set obs_time *=/c\ set obs_time=${START_TIME}" prepbufr.csh || exit 3
    sed -i "/^ *set BUFR_dir *=/c\ set BUFR_dir=${OUTPUT_DIR}" prepbufr.csh || exit 4
    sed -i "/^ *set BUFR_in *=/c\  set BUFR_in=${OBS_DIR}/${ccyy_s}${mm_s}${dd_s}.nr/prepbufr.gdas.${ccyy_s}${mm_s}${dd_s}.t${hh_s}z.nr" prepbufr.csh || exit 5
    sed -i '/set BUFR_out *=.*oyear.*omn.*ody.*24/c\ set BUFR_out = ${BUFR_odir}/temp_obs.${dtg}24' prepbufr.csh
    sed -i "/^ *obs_window *=/c\ obs_window=1.6" input.nml || exit 6
    sed -i "/^ *obs_window_cw *=/c\ obs_window_cw=1.6" input.nml || exit 7


    # ./prepbufr.csh &> prepbufr.log &
    # Only run obs generation at 00/06/12/18
    if (( hh_s % 6 == 0 )); then
        ./prepbufr.csh &> prepbufr.log &
    fi


    start_date=$("$BUILD_DIR/da_advance_time.exe" "$start_date" "${CYCLE_PERIOD}h" -f ccyymmddhhnn 2>/dev/null)
done

    echo "-------------------------------------------------------------"
    # echo "New start date: $start_date"
wait
exit 0
## 
