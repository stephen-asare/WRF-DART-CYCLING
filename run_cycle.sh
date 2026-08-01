#!/bin/bash

source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
paramfile="${SCRIPT_DIR}/param.sh"

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found at $paramfile!" >&2
    exit 1
fi
source "$paramfile"

start_date=201507130600
end_date=201507140900
cycle_period=3  # in hours

ccyy_s=${start_date:0:4}
mm_s=${start_date:4:2}
dd_s=${start_date:6:2}
hh_s=${start_date:8:2}
nn_s=${start_date:10:2}

WORK_DIR="$DART_CYCLE_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo
echo "===================================================="
echo "DART cycling driver starting in ${WORK_DIR}"
echo "Start date:       ${start_date}"
echo "End date:         ${end_date}"
echo "Cycle period:     ${cycle_period} h"
echo "NUM_MEMBERS:      ${NUM_MEMBERS}"
echo "===================================================="
echo


############################
# Initial adaptive inflation
############################
inf_flavor=2
inf_initial_from_restart=".false."
inf_sd_initial_from_restart=".false."

# cp ${SYS_OBS_DIR}/${ccyy_s}${mm_s}${dd_s}${hh_s}/input.nml .  # Appropraite to use but not working now
# cp /gpfs/research/chipilskigroup/stephen_asare/wrf_dart_debug_data/base/output/2017042712/input.nml input.nml
cp $DART_DIR/models/wrf/work/input.nml input.nml
sed -i "/  ens_size/c\  ens_size                  = ${NUM_MEMBERS}," input.nml
sed -i "/ num_domains/c\  num_domains               = ${MAX_DOM}, " input.nml  
sed -i "/ assimilation_period_seconds/c\  assimilation_period_seconds               = 10800, " input.nml
sed -i "/  num_output_obs_members/c\  num_output_obs_members   = ${NUM_MEMBERS}," input.nml
sed -i "/  inf_flavor/c\  inf_flavor                  = ${inf_flavor}, 4," input.nml
sed -i "/  inf_initial_from_restart/c\  inf_initial_from_restart    = ${inf_initial_from_restart}, .false.," input.nml
sed -i "/  inf_sd_initial_from_restart/c\  inf_sd_initial_from_restart = ${inf_sd_initial_from_restart}, .false.," input.nml
sed -i "/  layout/c\  layout                  = ${lay_out}," input.nml
sed -i "/  tasks_per_node/c\  tasks_per_node          = ${tasks_per_node}," input.nml
sed -i "/ input_state_file_list/c\   input_state_file_list = 'input_list_d01.txt', 'input_list_d02.txt'," input.nml
sed -i "/ output_state_file_list/c\   output_state_file_list = 'output_list_d01.txt', 'output_list_d02.txt'," input.nml
sed -i "/ input_state_files/c\    input_state_files = 'wrfinput_d01', 'wrfinput_d02'," input.nml
sed -i "/ num_output_state_members/c\    num_output_state_members = ${NUM_MEMBERS}," input.nml
# fill_inflation_restart requires THM instead of T
sed -i "/&model_nml/,/\// s/'T','QTY_POTENTIAL_TEMPERATURE'/'THM','QTY_POTENTIAL_TEMPERATURE'/" input.nml
sed -i '/&assim_tools_nml/a \   distribute_mean = .true.,' input.nml

sed -i "/'PSFC',  'QTY_SURFACE_PRESSURE',     'TYPE_PSFC', 'UPDATE','999'/a \
                             'QCLOUD','QTY_CLOUD_LIQUID_WATER','TYPE_QC','UPDATE','999',\n\
                             'QRAIN','QTY_RAINWATER_MIXING_RATIO','TYPE_QR','UPDATE','999',\n\
                             'QSNOW','QTY_SNOW_MIXING_RATIO','TYPE_QS','UPDATE','999',\n\
                             'QICE','QTY_CLOUD_ICE','TYPE_QI','UPDATE','999',\n\
                             'QGRAUP','QTY_GRAUPEL_MIXING_RATIO','TYPE_QG','UPDATE','999',\n\
                             'QNICE','QTY_ICE_NUMBER_CONCENTRATION','TYPE_QNICE','UPDATE','999',\n\
                             'QNRAIN','QTY_RAIN_NUMBER_CONCENTR','TYPE_QNRAIN','UPDATE','999',\n\
                             'U10','QTY_U_WIND_COMPONENT','TYPE_U10','UPDATE','999',\n\
                             'V10','QTY_V_WIND_COMPONENT','TYPE_V10','UPDATE','999',\n\
                             'T2','QTY_TEMPERATURE','TYPE_T2','UPDATE','999',\n\
                             'Q2','QTY_SPECIFIC_HUMIDITY','TYPE_Q2','UPDATE','999'," input.nml

# Append microphysics bounds to wrf_state_bounds
sed -i "/'QCLOUD','0.0','NULL','CLAMP',/a \
                             'QSNOW','0.0','NULL','CLAMP',\n\
                             'QICE','0.0','NULL','CLAMP',\n\
                             'QGRAUP','0.0','NULL','CLAMP',\n\
                             'QNICE','0.0','NULL','CLAMP',\n\
                             'QNRAIN','0.0','NULL','CLAMP'," input.nml

# Radar microphysics setting
sed -i "/ microphysics_type/c\   microphysics_type           =       3  ," input.nml
sed -i "/'..\/..\/..\/observations\/forward_operators\/obs_def_gts_mod.f90'/a \                             '../../../observations/forward_operators/obs_def_QuikSCAT_mod.f90'," input.nml
sed -i "/ cutoff/c\   cutoff                          = 0.10," input.nml
sed -i "/ adaptive_localization_threshold/c\   adaptive_localization_threshold = 2000," input.nml
sed -i "/ print_every_nth_obs/c\   print_every_nth_obs             = 1000," input.nml
sed -i "/ input_qc_threshold/c\   input_qc_threshold          = 4.0," input.nml

# &location_nml and &model_nml domain metrics
sed -i "/ vert_normalization_pressure/c\   vert_normalization_pressure = 700000.0," input.nml
sed -i "/ vert_normalization_height/c\   vert_normalization_height   = 80000.0," input.nml
sed -i "/ vert_normalization_scale_height/c\   vert_normalization_scale_height = 7.5," input.nml
sed -i "/ nlon/c\   nlon                        = 221," input.nml
sed -i "/ nlat/c\   nlat                        = 122," input.nml
sed -i "/ center_search_half_length/c\   center_search_half_length   = 400000.0," input.nml
sed -i "/ circulation_radius/c\   circulation_radius          = 72000.0," input.nml
sed -i "/ center_spline_grid_scale/c\   center_spline_grid_scale    = 4," input.nml
sed -i "/ vert_localization_coord/c\   vert_localization_coord     = 4," input.nml

sed -i "/ obs_boundary/c\   obs_boundary             = 5.0," input.nml
sed -i "/ increase_bdy_error/c\   increase_bdy_error       = .true.," input.nml
sed -i "/ obsdistbdy/c\   obsdistbdy               = 15.0," input.nml
sed -i "/ sfc_elevation_check/c\   sfc_elevation_check      = .true.," input.nml
sed -i "/ sfc_elevation_tol/c\   sfc_elevation_tol        = 300.0," input.nml
sed -i "/ obs_pressure_top/c\   obs_pressure_top         = 10000.0," input.nml
sed -i "/ obs_height_top/c\   obs_height_top           = 20000.0," input.nml
sed -i "/ aircraft_horiz_int/c\   aircraft_horiz_int       = 60.0," input.nml
sed -i "/ aircraft_pres_int/c\   aircraft_pres_int        = 2500.0," input.nml
sed -i "/ sat_wind_horiz_int/c\   sat_wind_horiz_int       = 90.0," input.nml
sed -i "/ sat_wind_pres_int/c\   sat_wind_pres_int        = 2500.0," input.nml
sed -i "/ overwrite_ncep_satwnd_qc/c\   overwrite_ncep_satwnd_qc = .true.," input.nml
sed -i "/ overwrite_obs_time/c\   overwrite_obs_time       = .true.," input.nml

sed -i '/&closest_member_tool_nml/a \   input_file_name         = '\''filter_ic_new'\'',' input.nml
sed -i '/&utilities_nml/a \   print_debug = .true.,' input.nml
sed -i '/&mpi_utilities_nml/a \   reverse_task_layout = .false.' input.nml
sed -i '/&prep_bufr_nml/a \   obs_window     = -1.,\n   obs_window_sfc = 0.8,' input.nml
sed -i '/&obs_sequence_tool_nml/a \   filename_seq_list    = '\''obs_list'\'',\n   gregorian_cal        = .true.,\n   edit_copies          = .true.,\n   new_copy_index       = 1, 2, 3, 4, 5,\n   synonymous_copy_list = '\'''\'',\n   synonymous_qc_list   = '\'''\'',' input.nml

cat << 'EOF' >> input.nml

&assim_model_nml
   write_binary_restart_files = .true.
   /

&convert_gpsro_bufr_nml
   gpsro_bufr_file     = 'nam.gpsro.bufr',
   gpsro_bufr_filelist = '',
   gpsro_out_file      = 'obs_seq.gpsro',
   gpsro_aux_file      = 'convinfo.txt',
   ray_htop            = 20000.0,
   ray_hbot            =  3000.0
   overwrite_obs_error = .false.,
   convert_to_geopotential_height = .true.,
   obs_window_hr       = 1.5,
   debug = .false.
   /
EOF

echo "Linking initial wrfinput files from ${ENS_FCST_DIR}/e001/wrfout_d01_${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00"
ln -sf "${ENS_FCST_DIR}/e001/wrfout_d01_${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00" wrfinput_d01
ln -sf "${ENS_FCST_DIR}/e001/wrfout_d02_${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00" wrfinput_d02

if [ "$ADAPTIVE_INFLATION" -ge 1 ]; then
    echo "Initial adaptive inflation"
    ln -sf "$DART_DIR/models/wrf/work/fill_inflation_restart" .
    
    ./fill_inflation_restart > fill_inflation_restart.log 2>&1 
    if [[ $? -ne 0 ]]; then
        echo "ERROR: fill_inflation_restart failed. Check fill_inflation_restart.log"
        touch ABORT_RETRO
        exit 2
    fi
    echo "Initial adaptive inflation complete."
    echo
fi

#########################
# Create directories & Link Tools
#########################

mkdir -p "${WORK_DIR}/priors" "${WORK_DIR}/posts" "${WORK_DIR}/analysis"

ln -sf "$DART_DIR/models/wrf/work/filter" .
ln -sf "$DART_DIR/models/wrf/work/obs_diag" .
ln -sf "$DART_DIR/models/wrf/work/obs_seq_to_netcdf" .
ln -sf "$DART_DIR/assimilation_code/programs/gen_sampling_err_table/work/sampling_error_correction_table.nc" .
ln -sf "$DART_DIR/models/wrf/work/pert_wrf_bc" .
ln -sf "$DART_DIR/models/wrf/work/obs_sequence_tool" .


### Link initial priors  
IMEM=1
rm -f "${WORK_DIR}/priors"/wrfinput_d0*.e???
echo "Linking initial forecast files from ${ENS_FCST_DIR}/${CMEM}/wrfout_d0${dom}_${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00"
while (( IMEM <= NUM_MEMBERS )); do
    CMEM=$(printf "e%03d" "$IMEM")
    for dom in 1 2; do
        ln -sf "${ENS_FCST_DIR}/${CMEM}/wrfout_d0${dom}_${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00" \
                "${WORK_DIR}/priors/wrfinput_d0${dom}.${CMEM}"
    done
    (( IMEM++ ))
done

####################
# Cycling loop
####################

current_date="$start_date"
# current_date="201507140600"
 
echo
echo "Starting DART cycling from ${start_date} to ${end_date} every ${cycle_period} hours"
echo

while [[ "$current_date" -le "$end_date" ]]; do

    previous_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "-${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)
    forward_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "+${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)

    echo "----------------------------------------------------"
    echo "Previous date: ${previous_date}"
    echo "Current date:  ${current_date}"
    echo "Forward date:  ${forward_date}"
    echo "----------------------------------------------------"

    ccyy_p=${previous_date:0:4}
    mm_p=${previous_date:4:2}
    dd_p=${previous_date:6:2}
    hh_p=${previous_date:8:2}
    nn_p=${previous_date:10:2}

    ccyy_c=${current_date:0:4}
    mm_c=${current_date:4:2}
    dd_c=${current_date:6:2}
    hh_c=${current_date:8:2}
    nn_c=${current_date:10:2}

    ccyy_f=${forward_date:0:4}
    mm_f=${forward_date:4:2}
    dd_f=${forward_date:6:2}
    hh_f=${forward_date:8:2}
    nn_f=${forward_date:10:2}

    OUTPUT_DIR="${WORK_DIR}/output/${ccyy_c}${mm_c}${dd_c}${hh_c}"
    mkdir -p "$OUTPUT_DIR"
    
    # ------------------------------------------------------------------------------
    # DYNAMIC INFLATION LOGIC UPDATE
    # Flip to true and link old files if this is not the first cycle
    # ------------------------------------------------------------------------------
    if [[ "$current_date" != "$start_date" ]]; then
        inf_initial_from_restart=".true."
        inf_sd_initial_from_restart=".true."
        
        for dom in d01 d02; do
            ln -sf "${WORK_DIR}/output/${ccyy_p}${mm_p}${dd_p}${hh_p}/Inflation_input/input_priorinf_mean_${dom}.nc" input_priorinf_mean_${dom}.nc
            ln -sf "${WORK_DIR}/output/${ccyy_p}${mm_p}${dd_p}${hh_p}/Inflation_input/input_priorinf_sd_${dom}.nc" input_priorinf_sd_${dom}.nc
        done
    fi

    sed -i '/^[[:space:]]*&filter_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
    read INIT_DAYS INIT_SECS <  <("$BUILD_DIR/da_advance_time.exe" ${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c} 0 -g)

    echo "INIT_DAYS=${INIT_DAYS} INIT_SECS=${INIT_SECS}"
    read FIRST_DAYS FIRST_SECS < <("$BUILD_DIR/da_advance_time.exe" "${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}" "-90m" -g)
    FIRST_SECS=$((FIRST_SECS + 1))
    read LAST_DAYS  LAST_SECS < <("$BUILD_DIR/da_advance_time.exe" "${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}" "+90m" -g)

cat >> input.nml <<EOF

&filter_nml
   async                    =  0,
   adv_ens_command          = "./advance_model.csh",
   ens_size                 =  ${NUM_MEMBERS},
   obs_sequence_in_name     = "obs_seq.out",
   obs_sequence_out_name    = "obs_seq.final",
   input_state_file_list    = 'input_list_d01.txt', 'input_list_d02.txt',
   output_state_file_list   = 'output_list_d01.txt', 'output_list_d02.txt',
   init_time_days           = ${INIT_DAYS},
   init_time_seconds        = ${INIT_SECS},
   first_obs_days           = ${FIRST_DAYS},
   first_obs_seconds        = ${FIRST_SECS},
   last_obs_days            = ${LAST_DAYS},
   last_obs_seconds         = ${LAST_SECS},
   num_output_state_members = ${NUM_MEMBERS},
   num_output_obs_members   = ${NUM_MEMBERS},
   output_interval          = 1,
   num_groups               = 1,
   output_forward_op_errors = .false.,
   output_timestamps        = .false.,
   trace_execution          = .false.,
   stages_to_write          = 'preassim', 'postassim', 'output',
   output_members           = .true.,
   output_mean              = .true.,
   output_sd                = .true.,
   write_all_stages_at_end  = .false.,
   obs_window_days       = 0,
   obs_window_seconds    = 5400,
   inf_flavor                  = ${inf_flavor},                      0,
   inf_initial_from_restart    = ${inf_initial_from_restart},                .false.,
   inf_sd_initial_from_restart = ${inf_sd_initial_from_restart},                .false.,
   inf_initial                 = 1.0,                   1.12,
   inf_lower_bound             = 1.0,                    1.0,
   inf_upper_bound             = 10000.0,              10000.0,
   inf_damping                 = 0.9,                     1.0,
   inf_sd_initial              = 0.6,                     0.50,
   inf_sd_lower_bound          = 0.6,                     0.10,
   inf_sd_max_change           = 1.05,                    1.05,
/
EOF

    FIRST_YMDHMS=$("$BUILD_DIR/da_advance_time.exe" "${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}" "-90m" -f "ccyy mm dd hh nn ss")
    LAST_YMDHMS=$("$BUILD_DIR/da_advance_time.exe" "${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}"  "+90m" -f "ccyy mm dd hh nn ss")

    FIRST_YMDHMS_COMMA=$(echo "$FIRST_YMDHMS" | awk '{printf "%d, %d, %d, %d, %d, %d,", $1,$2,$3,$4,$5,$6}')
    LAST_YMDHMS_COMMA=$(echo "$LAST_YMDHMS"  | awk '{printf "%d, %d, %d, %d, %d, %d,", $1,$2,$3,$4,$5,$6}')

    sed -i '/^[[:space:]]*&schedule_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
cat >> input.nml <<EOF

&schedule_nml
  calendar             = 'Gregorian',
  first_bin_start      =  ${FIRST_YMDHMS_COMMA},
  first_bin_end        =  ${LAST_YMDHMS_COMMA},
  last_bin_end         =  ${LAST_YMDHMS_COMMA},
  bin_interval_days    = 0,
  bin_interval_seconds = 10800,
  max_num_bins         = 1,
  print_table          = .true.,
/
EOF

    sed -i '/^[[:space:]]*&obs_diag_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
cat >> input.nml <<EOF
 
&obs_diag_nml
   obs_sequence_name     = 'obs_seq.final',
   obs_sequence_list     = '',
   first_bin_center      =  ${ccyy_c}, ${mm_c}, ${dd_c}, ${hh_c}, ${nn_c}, 0,
   last_bin_center       =  ${ccyy_c}, ${mm_c}, ${dd_c}, ${hh_c}, ${nn_c}, 0,
   bin_separation        =     0, 0, 0, 3, 0, 0,
   bin_width             =     0, 0, 0, 3, 0, 0,
   time_to_skip          =     0, 0, 0, 0, 0, 0,
   max_num_bins          = 1,
   Nregions              = 1,
   lonlim1               = 0.0,
   lonlim2               = 360.0,
   latlim1               = -90.0,
   latlim2               = 90.0,
   reg_names             = 'Full Domain',
   create_rank_histogram = .true.,
   verbose               = .true.,
/
EOF

    sed -i '/^[[:space:]]*&quality_control_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
cat >> input.nml <<EOF

&quality_control_nml
   input_qc_threshold       = -1,
   outlier_threshold        = -1,
   enable_special_outlier_code = .false.
/
EOF
    
    # ------------------------------------------------------------------------------
    # APPEND PERT_WRF_BC_NML FOR BOUNDARY UPDATE
    # ------------------------------------------------------------------------------
    sed -i '/^[[:space:]]*&pert_wrf_bc_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
cat >> input.nml <<EOF

&pert_wrf_bc_nml
   ens_size             = 1,
   netcdf_file_prefix   = 'wrfbdy_d01',
   update_bc            = .true.,
/
EOF

    sed -i '/^[[:space:]]*&obs_kind_nml[[:space:]]*$/,/^[[:space:]]*\/[[:space:]]*$/d' input.nml
cycle="${ccyy_c}${mm_c}${dd_c}${hh_c}"

if [ "$cycle" = "2015071409" ] || [ "$cycle" = "2015071412" ]; then
    ASSIM_OBS_TYPE="'RADIOSONDE_U_WIND_COMPONENT','RADIOSONDE_V_WIND_COMPONENT','RADIOSONDE_TEMPERATURE','RADIOSONDE_SPECIFIC_HUMIDITY'"
    EVAL_OBS_TYPE=""

else
    ASSIM_OBS_TYPE="'RADIOSONDE_TEMPERATURE','RADIOSONDE_U_WIND_COMPONENT','RADIOSONDE_V_WIND_COMPONENT','RADIOSONDE_SPECIFIC_HUMIDITY','RADIOSONDE_SURFACE_ALTIMETER','ACARS_U_WIND_COMPONENT','ACARS_V_WIND_COMPONENT','ACARS_TEMPERATURE','ACARS_DEWPOINT','SAT_U_WIND_COMPONENT','SAT_V_WIND_COMPONENT','GPSRO_REFRACTIVITY','PROFILER_U_WIND_COMPONENT','PROFILER_V_WIND_COMPONENT','METAR_U_10_METER_WIND','METAR_V_10_METER_WIND','METAR_TEMPERATURE_2_METER','METAR_DEWPOINT_2_METER','METAR_ALTIMETER', 'METAR_SPECIFIC_HUMIDITY_2_METER','MARINE_SFC_U_WIND_COMPONENT','MARINE_SFC_V_WIND_COMPONENT','MARINE_SFC_TEMPERATURE','MARINE_SFC_ALTIMETER','MARINE_SFC_DEWPOINT','LAND_SFC_TEMPERATURE','LAND_SFC_U_WIND_COMPONENT','LAND_SFC_V_WIND_COMPONENT','LAND_SFC_ALTIMETER','LAND_SFC_SPECIFIC_HUMIDITY'"
    EVAL_OBS_TYPE="'LAND_SFC_DEWPOINT'"
fi

cat >> input.nml <<EOF

&obs_kind_nml
   assimilate_these_obs_types = ${ASSIM_OBS_TYPE}
   evaluate_these_obs_types   = ${EVAL_OBS_TYPE}
/
EOF

# ------------------------------------------------------------------------------
# QCEFF helper
# ------------------------------------------------------------------------------
QCEFF_BASENAME="qceff_table.csv"

write_qceff_table() {
  local outfile="$1"
  if [ "$cycle" = "2015071409" ] || [ "$cycle" = "2015071412" ]; then
    local dist_type="KDE_DISTRIBUTION"
    local f_kind="KDE_FILTER"
  else
    local dist_type="NORMAL_DISTRIBUTION"
    local f_kind="EAKF"
  fi
  local obs_err_dist="NORMAL_DISTRIBUTION" 
  local b_below=".false."
  local b_above=".false."
  local l_bound="-888888.0"
  local u_bound="888888.0"
  local b_str="${b_below},${b_above},${l_bound},${u_bound}"

  cat > "${outfile}" <<EOF
QCEFF table version: 1,obs_error_info,,,,probit_inflation,,,,,probit_state,,,,,probit_extended_state,,,,,obs_inc_info,,,,
QTY_NAME,bounded_below,bounded_above,lower_bound,upper_bound,dist_type,bounded_below,bounded_above,lower_bound,upper_bound,dist_type,bounded_below,bounded_above,lower_bound,upper_bound,dist_type,bounded_below,bounded_above,lower_bound,upper_bound,filter_kind,bounded_below,bounded_above,lower_bound,upper_bound
EOF

  local quantities=(
    "QTY_U_WIND_COMPONENT" "QTY_V_WIND_COMPONENT" "QTY_VERTICAL_VELOCITY"
    "QTY_POTENTIAL_TEMPERATURE" "QTY_GEOPOTENTIAL_HEIGHT" "QTY_PRESSURE"
    "QTY_VAPOR_MIXING_RATIO" "QTY_CLOUD_LIQUID_WATER" "QTY_RAINWATER_MIXING_RATIO"
    "QTY_SNOW_MIXING_RATIO" "QTY_CLOUD_ICE" "QTY_GRAUPEL_MIXING_RATIO"
    "QTY_ICE_NUMBER_CONCENTRATION" "QTY_RAIN_NUMBER_CONCENTR" "QTY_TEMPERATURE"
    "QTY_SPECIFIC_HUMIDITY"
  )

  for qty in "${quantities[@]}"; do
    echo "${qty},${b_str},${obs_err_dist},${b_str},${dist_type},${b_str},${dist_type},${b_str},${f_kind},${b_str}" >> "${outfile}"
  done
}

write_qceff_table "${QCEFF_BASENAME}"
sed -i "s|^[[:space:]]*qceff_table_filename[[:space:]]*=.*|   qceff_table_filename = '${QCEFF_BASENAME}',|" input.nml

    cd "$WORK_DIR"
    echo "Running DART filter for cycle at ${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c} ..."
    date
    if [ "$cycle" = "2015071409" ] || [ "$cycle" = "2015071412" ]; then
        ln -sf "/gpfs/research/scratch/sa24m/tqprof/run3/osse_out/sys_obs/window_2015071300_2015071512/ascii_to_obs_manual/obs_seq_single" obs_seq.out || exit 1  ## Update appropraitely
    else
        ln -sf "/gpfs/research/scratch/sa24m/tqprof/run3/osse_out/sys_obs/window_2015071300_2015071512/ascii_to_obs/obs_seq_single" obs_seq.out || exit 1  ## Update appropraitely
    fi
    #################################
    # Link priors if not first cycle
    #################################
    if [[ "$current_date" != "$start_date" ]]; then
        # CLEAR GHOST FILES
        rm -f "${WORK_DIR}/priors/wrfinput_d0"*
        
        IMEM=1
        while (( IMEM <= NUM_MEMBERS )); do
            CMEM=$(printf "e%03d" "$IMEM")
            for dom in 1 2; do
                ln -sf "${WORK_DIR}/output/${ccyy_p}${mm_p}${dd_p}${hh_p}/WRFIN/${CMEM}/wrfout_d0${dom}_${ccyy_c}-${mm_c}-${dd_c}_${hh_c}:00:00" \
                    "${WORK_DIR}/priors/wrfinput_d0${dom}.${CMEM}"
            done
            (( IMEM++ ))
        done
    fi

    ls "${WORK_DIR}"/priors/wrfinput_d01* > input_list_d01.txt
    ls "${WORK_DIR}"/priors/wrfinput_d02* > input_list_d02.txt

    cp input_list_d01.txt output_list_d01.txt
    cp input_list_d02.txt output_list_d02.txt

    sed -i 's/priors/posts/g' output_list_d01.txt
    sed -i 's/priors/posts/g' output_list_d02.txt

    #########################
    # Submit filter job and wait
    #########################

    cat > run_filter << EOF
#!/bin/bash
#SBATCH --job-name=run_filter_${ccyy_c}${mm_c}${dd_c}${hh_c}
#SBATCH -A chipilskigroup_q
#SBATCH -t 22:55:00
#SBATCH --nodes=15
#SBATCH --partition=chipilskigroup_q
#SBATCH -n 75
#SBATCH -C "intel,YEAR2018|intel,YEAR2019"
#SBATCH --output=run_filter_${dd_c}${hh_c}_%j.log
#SBATCH --export=ALL

source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh

ulimit -s unlimited
module load intel/21
module load python/3

unset DISPLAY

cd "${WORK_DIR}"

srun "${WORK_DIR}/filter"

echo ""
echo "Computing obs_epoch"

"${WORK_DIR}/obs_seq_to_netcdf" > obs_seq_to_netcdf.log 2>&1
"${WORK_DIR}/obs_diag" > obs_diag.log 2>&1
EOF

    chmod +x run_filter

    FILTER_JOBID=$(sbatch --parsable run_filter)
    
    if [[ -z "$FILTER_JOBID" ]]; then
        echo "ERROR: Filter job failed to submit"
        exit 1
    fi

    echo "Filter job ${FILTER_JOBID} submitted. Waiting for completion..."

    while :; do
        still_in_queue=$(squeue -h -j "${FILTER_JOBID}" -o "%i" 2>/dev/null | wc -l)
        if (( still_in_queue == 0 )); then
            echo "Filter job ${FILTER_JOBID} has left the queue."
            break
        fi
        sleep 5
    done

    # echo "Submitted run_filter job on chipilskigroup_q and waiting for completion..."

    # FILTER_JOBID=$(sbatch --parsable --wait run_filter) || {
    #     echo "ERROR: Filter job failed"
    #     exit 1
    # }

    echo "Filter completed for cycle at ${ccyy_c}${mm_c}${dd_c}${hh_c}${nn_c}."
    
    mkdir -p "${OUTPUT_DIR}/Inflation_input" \
             "${OUTPUT_DIR}/WRFIN" \
             "${OUTPUT_DIR}/PRIORS" \
             "${OUTPUT_DIR}/logs"

    ###############################
    # Analysis increment and archiving
    ###############################

    num_vars=${#increment_vars_a[@]}
    extract_str=""
    for (( i=0; i<num_vars; i++ )); do
        extract_str+="${increment_vars_a[i]},"
    done
    extract_str="${extract_str%,}"

    for dom in d01 d02; do
        echo "Processing ${dom} analysis increment"
        
        # CLEAR STATIC DATA FILES BEFORE CREATION
        rm -f static_data_${dom}.nc

        ncdiff -F -O -v "${extract_str}" \
            postassim_mean_${dom}.nc \
            preassim_mean_${dom}.nc \
            analysis_increment_${dom}.nc || {
                echo "ERROR: ncdiff failed for ${dom}"
                exit 1
            }

        ncks -F -O -x -v "${extract_str}" \
            postassim_mean_${dom}.nc \
            static_data_${dom}.nc || {
                echo "ERROR: ncks extract failed for ${dom}"
                exit 1
            }

        ncks -A static_data_${dom}.nc analysis_increment_${dom}.nc || {
            echo "ERROR: ncks append failed for ${dom}"
            exit 1
        }
    done

    for dom in d01 d02; do
        for FILE in \
            postassim_mean_${dom}.nc preassim_mean_${dom}.nc \
            postassim_sd_${dom}.nc preassim_sd_${dom}.nc \
            analysis_increment_${dom}.nc output_mean_${dom}.nc \
            output_sd_${dom}.nc; do

            if [[ -e "$FILE" && -s "$FILE" ]]; then
                mv "$FILE" "${OUTPUT_DIR}/." || exit 1
            else
                echo "ERROR: Missing expected file: ${FILE}"
                exit 1
            fi
        done
    done

    for FILE in obs_seq.final; do
        if [[ -e "$FILE" && -s "$FILE" ]]; then
            mv "$FILE" "${OUTPUT_DIR}/." 2>/dev/null
        else
            echo "ERROR: Missing ${FILE}"
            exit 1
        fi
    done
    
    mv obs_epoch*.nc "${OUTPUT_DIR}/." 2>/dev/null
    mv obs_diag_output.nc "${OUTPUT_DIR}/." 2>/dev/null
    mv *.log  "${OUTPUT_DIR}/"

    ##############################
    # Adaptive inflation file moves
    ##############################

    if [ "$ADAPTIVE_INFLATION" -ge 1 ]; then
        for dom in d01 d02; do
            old_file=( input_postinf_mean_${dom}.nc input_postinf_sd_${dom}.nc input_priorinf_mean_${dom}.nc input_priorinf_sd_${dom}.nc )
            new_file=( output_postinf_mean_${dom}.nc output_postinf_sd_${dom}.nc output_priorinf_mean_${dom}.nc output_priorinf_sd_${dom}.nc )

            i=0
            nfiles=${#new_file[@]}
            while (( i < nfiles )); do
                if [[ -e "${new_file[$i]}" && -s "${new_file[$i]}" ]]; then
                    mv "${new_file[$i]}" "${OUTPUT_DIR}/Inflation_input/${old_file[$i]}"
                fi
                (( i++ ))
            done
        done
    fi

    echo "Cleaning up prior files..."
    cd "$WORK_DIR" || exit 1
    shopt -s nullglob
    mv postassim_member_*.nc preassim_member_*.nc output/${ccyy_c}${mm_c}${dd_c}${hh_c}/

    #################################
    # Ensemble forecasts on backfill
    #################################
    echo "Ready to integrate ensemble members"

    MEM=1
    declare -a FORECAST_JOBIDS=()
    while (( MEM <= NUM_MEMBERS )); do
        CMEM=$(printf "e%03d" "$MEM")
        mem_dir="${WORK_DIR}/${CMEM}"
        rm -rf "$mem_dir"/*
        mkdir -p "$mem_dir"
        cd "$mem_dir"

        echo "Linking wrfinput/wrfbdy for ensemble member ${MEM} (${CMEM})"

        for dom in 1 2; do
            FILE_DATE=${ccyy_c}-${mm_c}-${dd_c}_${hh_c}:${nn_c}:00
            FILE_DATE_P=${ccyy_p}-${mm_p}-${dd_p}_${hh_p}:${nn_p}:00
            
            if [[ ${current_date} == "${start_date}" ]]; then
                cp ${ENS_FCST_DIR}/$CMEM/wrfout_d0${dom}_${FILE_DATE} ${WORK_DIR}/analysis/wrfvar_output_d0${dom}.${CMEM} || exit 1
            else
                ln -sf ${WORK_DIR}/output/${ccyy_p}${mm_p}${dd_p}${hh_p}/WRFIN/${CMEM}/wrfout_d0${dom}_${FILE_DATE} ${WORK_DIR}/analysis/wrfvar_output_d0${dom}.${CMEM} || exit 1
            fi
            
            ncks -A -v ${VAR_DART} ${WORK_DIR}/posts/wrfinput_d0${dom}.${CMEM} ${WORK_DIR}/analysis/wrfvar_output_d0${dom}.${CMEM} || exit 1
            ln -sf "${WORK_DIR}/analysis/wrfvar_output_d0${dom}.${CMEM}" "${mem_dir}/wrfinput_d0${dom}"
        done
        
        # ------------------------------------------------------------------------------
        # UPDATE BOUNDARIES USING PERT_WRF_BC
        # ------------------------------------------------------------------------------
        cp ${ENS_DIR}/rc/2015071300/wrfbdy_d01.${CMEM} ./wrfbdy_d01 || exit 1
        chmod u+w ./wrfbdy_d01
        
        echo "Running pert_wrf_bc to update boundaries for ${CMEM}..."
        ln -sf "${WORK_DIR}/input.nml" .
        "${WORK_DIR}/pert_wrf_bc" > pert_wrf_bc.log 2>&1
        
        cp ./wrfbdy_d01 "${WORK_DIR}/analysis/wrfbdy_d01.${CMEM}"

        cp "${SCRIPTS_DIR}/advance_run.sh" advance_run.sh || exit 1
        sed -i "s/^[[:space:]]*DE_FCST_RANGE=.*/DE_FCST_RANGE=${cycle_period}/" advance_run.sh
        chmod +x ./advance_run.sh

        start_time="${ccyy_c}${mm_c}${dd_c}${hh_c}"
        end_time="${ccyy_f}${mm_f}${dd_f}${hh_f}"
        
        jid=$(sbatch \
            --parsable \
            --requeue \
            --mem-per-cpu="${CYCLE_FCST_SBATCH_MEM}" \
            --job-name="wrf_${CMEM}_${ccyy_c}${mm_c}${dd_c}${hh_c}" \
            --output="wrf_${CMEM}_${ccyy_c}${mm_c}${dd_c}${hh_c}_%j.log" \
            advance_run.sh "${start_time}" "${end_time}")

        if [[ -z "$jid" ]]; then
            echo "ERROR: sbatch failed for member ${CMEM}" >&2
            exit 1
        fi
        FORECAST_JOBIDS+=("$jid")

        (( MEM++ ))
    done
    
    FINAL_JOB=$(sbatch --dependency=afterok:$(IFS=:; echo "${FORECAST_JOBIDS[*]}") --wrap="true")
    cd "$WORK_DIR"

    echo "Waiting for ${#FORECAST_JOBIDS[@]} forecast jobs to complete..."

    while :; do
        still_in_queue=$(squeue -h -j "$(IFS=,; echo "${FORECAST_JOBIDS[*]}")" -o "%i" 2>/dev/null | wc -l)
        if (( still_in_queue == 0 )); then
            echo "All forecast jobs have left the queue."
            break
        fi
        sleep 5
    done 

    MEM=1
    while (( MEM <= NUM_MEMBERS )); do
        CMEM=$(printf "e%03d" "$MEM")
        mkdir -p "${OUTPUT_DIR}/WRFIN/${CMEM}"
        mkdir -p "${OUTPUT_DIR}/logs/${CMEM}"
        
        for dom in 1 2; do
            mv "${WORK_DIR}/${CMEM}/wrfout_d0${dom}_${ccyy_f}-${mm_f}-${dd_f}_${hh_f}:00:00" "${OUTPUT_DIR}/WRFIN/${CMEM}/" || exit 1
        done
        mv ${WORK_DIR}/${CMEM}/rsl* ${OUTPUT_DIR}/logs/${CMEM}/
        (( MEM++ ))
    done
    
    echo "All ensemble forecasts completed successfully for this cycle."
    current_date=$("$BUILD_DIR/da_advance_time.exe" "$current_date" "${cycle_period}h" -f ccyymmddhhnn 2>/dev/null)
done
echo "Cycling loop completed successfully."
exit 0