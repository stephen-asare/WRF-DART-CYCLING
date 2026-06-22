#!/usr/bin/env ksh
set -e

# --- MET on PATH ---
MET_INSTALL_DIR="/gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1"
PATH="${MET_INSTALL_DIR}/bin:${PATH}"
export MET_INSTALL_DIR PATH
export OMP_NUM_THREADS=4
MODE_DIR=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/mode
WORK_DIR=${MODE_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR

# cd /gpfs/home/sa24m/scratch/tqprof/run1/mode/july15
# cp 
export MET_config=/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/mode/config/MODEConfig_tutorial

export fcst_dir=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/ens_wrf
export obs_dir=/gpfs/research/chipilskigroup/stephen_asare/data/15_july_obs

export MET_out_dir_head=$WORK_DIR/mode_out
mkdir -p ${MET_out_dir_head}

#------ set initial & valid time
export BUILD_DIR=/gpfs/research/chipilskigroup/stephen_asare/models/WRFDA/V4.5.2/var/build
export INITIAL_DATE=2015071421

export DATE=$INITIAL_DATE

export NHOUR=15
#export NHOUR=10
export NUM_MEMBERS=30

# Start hour
HOUR=0
while [[ ${HOUR} -le ${NHOUR} ]]; do
  # Compute valid time
  VAL_DATE="$("${BUILD_DIR}/da_advance_time.exe" "${INITIAL_DATE}" "${HOUR}" 2>/dev/null)"
  print ""
  print "VAL_DATE=${VAL_DATE}"
  print ""

  obs_file="mdbz_${VAL_DATE}_MOSAIC_LD.nc"
  print ""
  obs_path="${obs_dir}/${obs_file}"
  print ""

  MEM=1
  while [[ ${MEM} -le ${NUM_MEMBERS} ]]; do
    # zero-padded member (01, 02, ...)
    print ""
    CMEM=$(printf "%02d" "${MEM}")
    print ""

    # Detect member subdir style: 01/, m01/, e001/
    mem_dir=""
    cand1="${fcst_dir}/${CMEM}"
    cand2="${fcst_dir}/m${CMEM}"
    cand3="${fcst_dir}/e$(printf '%03d' "${MEM}")"
    for cand in "${cand1}" "${cand2}" "${cand3}"; do
      [[ -d "${cand}" ]] && { mem_dir="${cand}"; break; }
    done
    if [[ -z "${mem_dir}" ]]; then
      print "WARN: No member dir for MEM=${MEM} (tried ${cand1} ${cand2} ${cand3}). Skipping."
      MEM=$((MEM+1))
      continue
    fi

    # Forecast filename
    yyyy=${VAL_DATE:0:4}
    mm=${VAL_DATE:4:2}
    dd=${VAL_DATE:6:2}
    HH=${VAL_DATE:8:2}

    # fcst_file="wrfout_d02_2015-07-14_12:00:00"
    fcst_file="wrfout_d02_${yyyy}-${mm}-${dd}_${HH}:00:00"
    print ""
    echo "fcst_file=${fcst_file}"
    print ""
    fcst_path="${mem_dir}/${fcst_file}"

  #   DT="${yyyy}-${mm}-${dd}_${HH}:00:00"

  #   IDX=$(
  #     ncdump -v Times "$fcst_path" \
  #     | awk '/^[[:space:]]*Times =/,/;/' \
  #     | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2}' \
  #     | awk -v d="$DT" 'BEGIN{i=-1} {i++} $0==d{print i; exit}'
  #   )



  # # guard: error if not found
  # if [ -z "$IDX" ]; then
  #   echo "timestamp not found: $DT" >&2
  #   exit 1
  # fi

  # sed -i.bak -E "s/(level[[:space:]]*=[[:space:]]*\"\()([0-9]+)(,.*\)\";)/\1${IDX}\3/" "$MET_config"

    # Existence checks
    [[ -f "${fcst_path}" ]] || { print "SKIP (no fcst): ${fcst_path}"; MEM=$((MEM+1)); continue; }
    [[ -f "${obs_path}"  ]] || { print "SKIP (no obs):  ${obs_path}";  MEM=$((MEM+1)); continue; }

    # Output dir
    MET_out_dir="${MET_out_dir_head}/${INITIAL_DATE}_${VAL_DATE}/e0${CMEM}"
    mkdir -p "${MET_out_dir}"
    met_valid="${yyyy}${mm}${dd}_${HH}0000" 


    echo "met_valid=${met_valid}"
    print "mode ${fcst_path} ${obs_path} ${MET_config} -outdir ${MET_out_dir} -v 2"
    mode  "${fcst_path}" "${obs_path}" "${MET_config}" -outdir "${MET_out_dir}" -v 2
    # rm -f "${clean}" 
    MEM=$((MEM+1))
  done

  HOUR=$((HOUR+1))
done


