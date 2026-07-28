#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
paramfile="${SCRIPT_DIR}/param.sh"

if [[ ! -f "$paramfile" ]]; then
    echo "ERROR: param.sh not found at $paramfile!" >&2
    exit 1
fi
source "$paramfile"

if [[ -z "$SLURM_JOB_ID" ]]; then
    echo "Submitting gen_icbc3.sh to SLURM using parameters from param.sh..."
    sbatch \
        -A "${ICBC_SBATCH_ACCOUNT}" \
        -p "${ICBC_SBATCH_PARTITION}" \
        -n "${ICBC_SBATCH_TASKS}" \
        -t "${ICBC_SBATCH_TIME}" \
        -C "${ICBC_SBATCH_CONSTRAINT}" \
        --job-name="gen_icbc" \
        --output="gen_retro_icbc.%j.log" \
        --export=ALL \
        "$0" "$@"
    exit 0
fi

datea=$INITIAL_DATE
datefnl=$FINAL_DATE

echo "running wps"
WORK_DIR=${ICBC_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
ln -sf $WPS_DIR/* .
rm -fv namelist.wps SUCCESS

# -------------------------------------------------------------------
# FIX 1: WPS must start from phase1_INITIAL_DATE to capture spin-up 
#        and extend through Phase 2's FINAL_DATE + LBC_FREQ
# -------------------------------------------------------------------
START_WRF="$(${BUILD_DIR}/da_advance_time.exe $INITIAL_DATE 0 -w)"
MET_END="$(${BUILD_DIR}/da_advance_time.exe $FINAL_DATE $LBC_FREQ -w)"   

ccyy_s=${START_WRF:0:4}
mm_s=${START_WRF:5:2}
dd_s=${START_WRF:8:2}
hh_s=${START_WRF:11:2}

ccyy_e=${MET_END:0:4}
mm_e=${MET_END:5:2}
dd_e=${MET_END:8:2}
hh_e=${MET_END:11:2}

LBC_FREQ_SECOND=`expr 3600 \* ${CYCLE_PERIOD}`

cat > namelist.wps << EOF
&share
 wrf_core = 'ARW',
 max_dom = ${MAX_DOM},
 start_date = '${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00','${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00','${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00',
 end_date   = '${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00','${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00','${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00',
 interval_seconds = ${LBC_FREQ_SECOND},
 io_form_geogrid = 2,
 debug_level = 0,
 active_grid = .true., .true.,
/

&geogrid
 parent_id         =   1,1,2
 parent_grid_ratio =   1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
 i_parent_start    =   1,${I_PARENT_START_2},${I_PARENT_START_3},
 j_parent_start    =   1,${J_PARENT_START_2},${J_PARENT_START_3},
 e_we              =   ${NL_E_WE_1}, ${NL_E_WE_2}, ${NL_E_WE_3},
 e_sn              =   ${NL_E_SN_1}, ${NL_E_SN_2}, ${NL_E_SN_3},
 geog_data_res     = '${GEOG_DATA_RES_1}','${GEOG_DATA_RES_2}','${GEOG_DATA_RES_3}',
 dx = ${NL_DXY_1},
 dy = ${NL_DXY_1},
 map_proj = '${MAP_PROJ}',
 ref_lat   =  ${REF_LAT},
 ref_lon   =  ${REF_LON},
 truelat1  =  ${TRUELAT1},
 truelat2  =  ${TRUELAT2},
 stand_lon =  ${STAND_LON},
 geog_data_path = '${GEOG_DATA_PATH}'
/

&ungrib
 out_format = 'WPS',
 prefix = 'FILE',
/

&metgrid
 fg_name = 'FILE'
 io_form_metgrid = 2,
/

&mod_levs
 press_pa = 201300 , 200100 , 100000 ,
             95000 ,  90000 ,
             85000 ,  80000 ,
             75000 ,  70000 ,
             65000 ,  60000 ,
             55000 ,  50000 ,
             45000 ,  40000 ,
             35000 ,  30000 ,
             25000 ,  20000 ,
             15000 ,  10000 ,
              5000 ,   1000
/
EOF

run_geogrid=false
if [[ $MAX_DOM -eq 1 ]]; then
    [[ ! -f geo_em.d01.nc ]] && run_geogrid=true
elif [[ $MAX_DOM -eq 2 ]]; then
    [[ ! -f geo_em.d01.nc || ! -f geo_em.d02.nc ]] && run_geogrid=true
elif [[ $MAX_DOM -eq 3 ]]; then
    [[ ! -f geo_em.d01.nc || ! -f geo_em.d02.nc || ! -f geo_em.d03.nc ]] && run_geogrid=true
else
    echo "Total domains are =$MAX_DOM stopping"
    exit 1
fi

if $run_geogrid; then
    echo "Running geogrid.exe ..."
    echo "Check geogrid log file in $WORK_DIR/geogrid.log"
    ${RUN_CMD} -n 1 ./geogrid.exe > geogrid.log
    if [ $? -ne 0 ]; then
        echo "Error: geogrid.exe failed. Please check $WORK_DIR/geogrid.log"
        exit 1
    fi
else
    echo "All geo_em files exist. Skipping geogrid.exe."
fi
echo "geogrid done"

ln -fs ungrib/Variable_Tables/Vtable.ERA-interim.pl Vtable

FILES=${ERA5_DATA_DIR}/era5*.grib
echo "FILES = $FILES"

if ls FILE.*.nc 1> /dev/null 2>&1; then
    echo "ungrib files already exist. Skipping ungrib.exe."
else
    echo "No ungrib files found. Running ungrib.exe ..."
    ./link_grib.csh $FILES
    echo "Check ungrib log file in $WORK_DIR/ungrib.log"
    ./ungrib.exe > ungrib.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: ungrib.exe failed. Please check $WORK_DIR/ungrib.log"
        exit 1
    fi
fi

# Check for the absolute last file required by metgrid
need_last="${MET_END}"
missing=0
for dom in $(seq 1 $MAX_DOM); do
    d=$(printf "d%02d" $dom)
    [[ -f "met_em.${d}.${need_last}.nc" ]] || { echo "MISSING met_em.${d}.${need_last}.nc"; missing=1; }
done

if ls met_em.d01.*.nc 1> /dev/null 2>&1; then
    echo "met_em files already exist. Skipping metgrid.exe."
else
    echo "No met_em files found. Running metgrid.exe ..."
    echo "Check metgrid log file in $WORK_DIR/metgrid.log"
    ${RUN_CMD} -n 1 ./metgrid.exe > metgrid.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: metgrid.exe failed. Please check $WORK_DIR/metgrid.log"
        exit 1
    fi
fi

date
echo "wps_fc done"
echo ""

ln -sf $WRF_DIR/run/* .
rm -f namelist.input
ln -sf ${WORK_DIR}/met_em.d0*.nc .

fcst_hours=$phase1_DE_FCST_RANGE

OUTPUT_DIR=${ccyy_s}${mm_s}${dd_s}${hh_s}_${ccyy_e}${mm_e}${dd_e}${hh_e}
mkdir -p "$OUTPUT_DIR"
echo "Cycle dir: $OUTPUT_DIR"
echo "Cycle window: $INITIAL_DATE --> $FINAL_DATE"

cat > namelist.input << EOF
&time_control
 run_days                            = 0,
 run_hours                           = ${fcst_hours},
 run_minutes                         = 0,
 run_seconds                         = 0,
 start_year                          = ${ccyy_s},${ccyy_s},${ccyy_s},
 start_month                         = ${mm_s},${mm_s},${mm_s},
 start_day                           = ${dd_s},${dd_s},${dd_s},
 start_hour                          = ${hh_s},${hh_s},${hh_s},
 start_minute                        = 00,00,00,
 start_second                        = 00,00,00,
 end_year                            = ${ccyy_e},${ccyy_e},${ccyy_e},
 end_month                           = ${mm_e},${mm_e},${mm_e},
 end_day                             = ${dd_e},${dd_e},${dd_e},
 end_hour                            = ${hh_e},${hh_e},${hh_e},
 end_minute                          = 00,00,00,
 end_second                          = 00,00,00,
 interval_seconds                    = ${LBC_FREQ_SECOND},
 input_from_file                     = .true.,.true.,.true.,
 history_interval                    = 180,60,60,
 frames_per_outfile                  = 1000,1000,1000,
 restart                             = .false.,
 restart_interval                    = 2161,
 debug_level                         = 0,
 write_input                         = .false.,
/

&domains
 time_step                           = ${NL_TIME_STEP},
 time_step_fract_num                 = 0,
 time_step_fract_den                 = 1,
 max_dom                             = ${MAX_DOM},
 e_we                                = ${NL_E_WE_1},${NL_E_WE_2},${NL_E_WE_3},
 e_sn                                = ${NL_E_SN_1},${NL_E_SN_2},${NL_E_SN_3},
 e_vert                              = ${NL_E_VERT},${NL_E_VERT},${NL_E_VERT},
 dx                                  = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3},
 dy                                  = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3},
 grid_id                             = 1,2,3,
 parent_id                           = 1,1,2,
 i_parent_start                      = 1,${I_PARENT_START_2},${I_PARENT_START_3},
 j_parent_start                      = 1,${J_PARENT_START_2},${J_PARENT_START_3},
 parent_grid_ratio                   = 1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
 parent_time_step_ratio              = 1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
 feedback                            = ${FEEDBACK},
 p_top_requested                     = ${NL_P_TOP_REQUESTED},
 num_metgrid_levels                  = ${NL_NUM_METGRID_LEVELS},
 num_metgrid_soil_levels             = 4,
 hypsometric_opt                     = 2,
 smooth_option                       = 0,
 eta_levels                          = ${NL_VERT_LEVELS},
/

&physics
 mp_physics                          = ${NL_MP_PHYSICS},${NL_MP_PHYSICS},${NL_MP_PHYSICS},
 ra_lw_physics                       = ${NL_RA_LW},${NL_RA_LW},${NL_RA_LW},
 ra_sw_physics                       = ${NL_RA_SW},${NL_RA_SW},${NL_RA_SW},
 radt                                = ${NL_RADT1},${NL_RADT2},${NL_RADT2},
 sf_sfclay_physics                   = ${NL_SF_SFCLAY_PHYSICS},${NL_SF_SFCLAY_PHYSICS},${NL_SF_SFCLAY_PHYSICS},
 sf_surface_physics                  = ${NL_SF_SURFACE_PHYSICS},${NL_SF_SURFACE_PHYSICS},${NL_SF_SURFACE_PHYSICS},
 bl_pbl_physics                      = ${NL_BL_PBL_PHYSICS},${NL_BL_PBL_PHYSICS},${NL_BL_PBL_PHYSICS},
 bldt                                = ${NL_BLDT},
 cu_physics                          = ${NL_CU_PHYSICS1},${NL_CU_PHYSICS2},0,
 cudt                                = ${NL_CUDT1},${NL_CUDT2},0,
 DO_RADAR_REF                        = 1,
 isfflx                              = 1,
 ifsnow                              = 1,
 icloud                              = 1,
 surface_input_source                = 1,
 num_soil_layers                     = 4,
 NUM_LAND_CAT                        = 20,
/

&stoch
 stoch_force_opt                     = ${SKEB},
 stoch_vertstruc_opt                 = 1,
 tot_backscat_psi                    = 1.0E-5,
 tot_backscat_t                      = 1.0E-6,
 nens                                = ${NUM_MEMBERS},
 perturb_bdy                         = ${PERT_BDY},
/

&fdda
/

&dynamics
 w_damping                           = 1,
 diff_opt                            = 1,
 gwd_opt                             = 1,
 km_opt                              = 4,
 diff_6th_opt                        = 0,
 diff_6th_factor                     = 0.12,
 base_temp                           = 290.,
 damp_opt                            = 0,
 zdamp                               = 5000., 5000., 5000.,
 dampcoef                            = 0.15, 0.15, 0.15,
 khdif                               = 0, 0, 0,
 kvdif                               = 0, 0, 0,
 non_hydrostatic                     = .true., .true., .true.,
 moist_adv_opt                       = 1, 1, 1,
 scalar_adv_opt                      = 2, 2, 2,
 use_theta_m                         = 0,
/

&bdy_control
 spec_bdy_width                      = 5,
 spec_zone                           = 1,
 relax_zone                          = 4,
 specified                           = .true., .false., .false.,
 nested                              = .false., .true., .true.,
/

&grib2
/

&namelist_quilt
 nio_tasks_per_group                 = 0,
 nio_groups                          = 1,
/

&dfi_control
/
EOF

echo "Running real.exe"
echo "INITIAL_DATE = ${INITIAL_DATE}"
echo "FINAL_DATE = ${FINAL_DATE}"
echo "Check real log file in $WORK_DIR/real.log"
srun ./real.exe > real.log 2>&1
rc=$?
if (( rc != 0 )); then
    echo "Error: real.exe failed. Please check $WORK_DIR/real.log"
    exit $rc
fi

SUCCESS=$(grep -c "real_em: SUCCESS COMPLETE REAL_EM" rsl.error.0000)
if [ "$SUCCESS" -eq 0 ]; then
    echo "real.exe blown"
    exit 1
fi

for dom in $(seq 1 $MAX_DOM); do
    d=$(printf "d%02d" $dom)
    f="wrfinput_${d}"
    if [ -f "$f" ]; then
        echo "Moving ${f} to ${OUTPUT_DIR}/${f}_${hh_s}_${hh_e}"
        mv -f "$f" "${OUTPUT_DIR}/${f}_${hh_s}_${hh_e}"
    fi
done

if [ -f "wrfbdy_d01" ]; then
    echo "Moving wrfbdy_d01 to ${OUTPUT_DIR}/wrfbdy_d01_${hh_s}_${hh_e}"
    mv -f "wrfbdy_d01" "${OUTPUT_DIR}/wrfbdy_d01_${hh_s}_${hh_e}"
else
    echo "ERROR: wrfbdy_d01 was not created for Phase 1 cycle ${datea} -> ${END_DATE}"
    exit 2
fi

mv rsl.out.* "${OUTPUT_DIR}/"
mv rsl.error.* "${OUTPUT_DIR}/"

exit 0
