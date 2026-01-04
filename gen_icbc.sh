#!/bin/bash
#=====================================================================
# Script Name   : gen_retro_icbc.sh
# Description   : Generate ICBC files for retrospective runs
# Args          : param.sh
# Author        : sa24m
# Date          : June 2024
#=====================================================================
#
# This creates   output/${date}/wrfbdy_d01_{days}_{seconds}_mean
#                output/${date}/wrfinput_d01_{days}_{time_step1}_mean
#                output/${date}/wrfinput_d01_{days}_{time_step2}_mean

########################################################################
echo "gen_retro_icbc.sh is running in $(pwd)"
#======================================================================
#SBATCH --job-name="gen_icbc"
#SBATCH --ntasks=15
#SBATCH -A backfill2
#SBATCH -t 00:20:00
#SBATCH --partition=backfill2
#SBATCH -C "intel,YEAR2013|intel,YEAR2015|intel,YEAR2017|intel,YEAR2018|intel,YEAR2019"
#SBATCH --output=gen_retro_icbc.%j.log # Standard output and error log exclusive
#SBATCH --export=AL
#######################################################################
paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"   # set this appropriately #%%%#
source "$paramfile"

datea=$INITIAL_DATE
datefnl=2015071518
datefnl=$FINAL_DATE # set this appropriately #%%%#

echo "running wps" 
#======================================================================
WORK_DIR=${ICBC_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
ln -sf $WPS_DIR/* .
rm -fv namelist.wps SUCCESS

ccyy_s=$(echo "$datea" | cut -c 1-4)
mm_s=$(echo "$datea" | cut -c 5-6)
dd_s=$(echo "$datea" | cut -c 7-8)
hh_s=$(echo "$datea" | cut -c 9-10)
ccyy_e=$(echo "$datefnl" | cut -c 1-4)
mm_e=$(echo "$datefnl" | cut -c 5-6)
dd_e=$(echo "$datefnl" | cut -c 7-8)
hh_e=$(echo "$datefnl" | cut -c 9-10)

LBC_FREQ_SECOND=`expr 3600 \* ${CYCLE_PERIOD}` 

# create namelist.wps
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
    if [[ ! -f geo_em.d01.nc ]]; then
        run_geogrid=true
    fi
elif [[ $MAX_DOM -eq 2 ]]; then
    if [[ ! -f geo_em.d01.nc || ! -f geo_em.d02.nc ]]; then
        run_geogrid=true
    fi
elif [[ $MAX_DOM -eq 3 ]]; then
    if [[ ! -f geo_em.d01.nc || ! -f geo_em.d02.nc || ! -f geo_em.d03.nc ]]; then
        run_geogrid=true
    fi
else
    echo "Total domains are =$MAX_DOM stopping"
    exit 1
fi
if $run_geogrid; then
    echo "Running geogrid.exe ..."
    ${RUN_CMD} -n 1 ./geogrid.exe > geogrid.log
else
    echo "All geo_em files exist. Skipping geogrid.exe."
fi

echo "geogrid done"

ln -fs ungrib/Variable_Tables/Vtable.ERA-interim.pl Vtable
LOCAL_DATE=$INITIAL_DATE
LAST_DATE=$($BUILD_DIR/da_advance_time.exe ${LOCAL_DATE} -${LBC_FREQ} -f ccyymmddhhnn 3>/dev/null)
echo "LOCAL_DATE = $LOCAL_DATE"
echo "LAST_DATE = $LAST_DATE"

FILES=/gpfs/research/chipilskigroup/stephen_asare/data/ERA5/era5*.grib
echo "FILES = $FILES"

if ls FILE.*.nc 1> /dev/null 2>&1; then
    echo "ungrib files already exist. Skipping ungrib.exe."
else
    echo "No ungrib files found. Running ungrib.exe ..."
    ./link_grib.csh $FILES
    ./ungrib.exe > ungrib.log 2>&1
fi
# Run metgrid:
if ls met_em.d01.*.nc 1> /dev/null 2>&1; then
    echo "met_em files already exist. Skipping metgrid.exe."
else
    echo "No met_em files found. Running metgrid.exe ..."
    ${RUN_CMD}  -n 1 ./metgrid.exe
fi

date	
echo "wps_fc done"

echo "Generating ICBC files ..."
# if ls met_em.d01.*.nc 1> /dev/null 2>&1; then
#     echo "met_em files already exist. Skipping metgrid.exe."
# else
START_DATE=`${BUILD_DIR}/da_advance_time.exe $INITIAL_DATE 0 -w`

datea=$START_DATE
while true; do
    # FINAL_DATE
    END_DATE=`${BUILD_DIR}/da_advance_time.exe $datea $DE_FCST_RANGE -w`
    ln -sf $WRF_DIR/run/* .
    rm namelist.input    

    # ln -sf ${WPS_RUN_DIR}/met_em* .

    #  Run real.exe twice, once to get first time wrfinput_d0? and wrfbdy_d01,
    #  then again to get second time wrfinput_d0? file
    
    ccyy_c=${datea:0:4}; mm_c=${datea:5:2}; dd_c=${datea:8:2}; hh_c=${datea:11:2}
    OUTPUT_DIR=${ccyy_c}${mm_c}${dd_c}${hh_c}
    mkdir -p "$OUTPUT_DIR"
    echo "Cycle dir: $OUTPUT_DIR"

    n=1
    while [ $n -le 2 ]; do
        echo "RUNNING REAL, STEP $n"
        if [ $n -eq 1 ]; then
            date1=$datea
            date2=$END_DATE
            fcst_hours=$DE_FCST_RANGE
        else
            date1=$END_DATE
            date2=$END_DATE
            fcst_hours=0
        fi
        ccyy_s=${date1:0:4}; mm_s=${date1:5:2}; dd_s=${date1:8:2}; hh_s=${date1:11:2}
        ccyy_e=${date2:0:4}; mm_e=${date2:5:2}; dd_e=${date2:8:2}; hh_e=${date2:11:2}

        # create namelist.input
        cat > namelist.input << EOF
        &time_control
        run_days                            = 0,
        run_hours                           = ${fcst_hours},
        run_minutes                         = 0,
        run_seconds                         = 0,
        start_year                          = ${ccyy_s},${ccyy_s},${ccyy_s},
        start_month                         = ${mm_s},${mm_s},${mm_s} 
        start_day                           = ${dd_s},${dd_s},${dd_s}
        start_hour                          = ${hh_s},${hh_s},${hh_s}
        start_minute                        = 00,00,00, 
        start_second                        = 00,00,00,
        end_year                            = ${ccyy_e},${ccyy_e},${ccyy_e} 
        end_month                           = ${mm_e},${mm_e},${mm_e} 
        end_day                             = ${dd_e},${dd_e},${dd_e}
        end_hour                            = ${hh_e},${hh_e},${hh_e}
        end_minute                          = 00,00,00,
        end_second                          = 00,00,00,
        interval_seconds                    = ${LBC_FREQ_SECOND},
        input_from_file                     = .true.,.true.,.true.,
        history_interval                    = 180,60,60
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
        max_dom                             = ${MAX_DOM}
        e_we                                = ${NL_E_WE_1},${NL_E_WE_2},${NL_E_WE_3}
        e_sn                                = ${NL_E_SN_1},${NL_E_SN_2},${NL_E_SN_3}
        e_vert                              = ${NL_E_VERT},${NL_E_VERT},${NL_E_VERT}
        dx                                  = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3}
        dy                                  = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3}
        grid_id                             = 1, 2, 3
        parent_id                           = 1, 1, 2
        i_parent_start                      = 1, ${I_PARENT_START_2}, ${I_PARENT_START_3}
        j_parent_start                      = 1, ${J_PARENT_START_2}, ${J_PARENT_START_3}
        parent_grid_ratio                   = 1, ${PARENT_GRID_RATIO_2}, ${PARENT_GRID_RATIO_3}
        parent_time_step_ratio              = 1, ${PARENT_GRID_RATIO_2}, ${PARENT_GRID_RATIO_3}
        feedback                            = ${FEEDBACK},
        p_top_requested                     = ${NL_P_TOP_REQUESTED},
        num_metgrid_levels                  = ${NL_NUM_METGRID_LEVELS},
        num_metgrid_soil_levels             = 4,
        hypsometric_opt                     = 2,
        smooth_option                       = 0,
        eta_levels                          = ${NL_VERT_LEVELS}
        /

        &physics
        mp_physics                          = ${NL_MP_PHYSICS},${NL_MP_PHYSICS},${NL_MP_PHYSICS},
        ra_lw_physics                       = ${NL_RA_LW}, ${NL_RA_LW},${NL_RA_LW},
        ra_sw_physics                       = ${NL_RA_SW}, ${NL_RA_SW},${NL_RA_SW},
        radt                                = ${NL_RADT1}, ${NL_RADT2},${NL_RADT2},
        sf_sfclay_physics                   = ${NL_SF_SFCLAY_PHYSICS}, ${NL_SF_SFCLAY_PHYSICS},${NL_SF_SFCLAY_PHYSICS},
        sf_surface_physics                  = ${NL_SF_SURFACE_PHYSICS}, ${NL_SF_SURFACE_PHYSICS}, ${NL_SF_SURFACE_PHYSICS},
        bl_pbl_physics                      = ${NL_BL_PBL_PHYSICS},  ${NL_BL_PBL_PHYSICS},${NL_BL_PBL_PHYSICS},
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
        stoch_force_opt                     =$SKEB,
        stoch_vertstruc_opt                 =1,
        tot_backscat_psi                    =1.0E-5
        tot_backscat_t                      =1.0E-6
        nens                                =$NUM_MEMBERS
        perturb_bdy                         =$PERT_BDY
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
        zdamp                               = 5000., 5000.,
        dampcoef                            = 0.15, 0.15, 
        khdif                               = 0, 0,  
        kvdif                               = 0, 0,
        non_hydrostatic                     = .true., .true.,
        moist_adv_opt                       = 1, 1,
        scalar_adv_opt                      = 2, 2,
        use_theta_m                        = 0,
        /
        &bdy_control
        spec_bdy_width                      = 5,
        spec_zone                           = 1,
        relax_zone                          = 4,
        specified                           = .true., .false., 
        nested                              = .false., .true.,
        /
        &grib2
        /
        &namelist_quilt
        nio_tasks_per_group = 0,
        nio_groups = 1,
        /
        &dfi_control
        /
EOF

    srun -n 4 --partition=backfill ./real.exe

    rc=$?
    if (( rc != 0 )); then
        echo "real.exe exited with code $rc"
        exit $rc
    fi
    ## # need to look for something to know when this job is done
    SUCCESS=$(grep -c "real_em: SUCCESS COMPLETE REAL_EM" rsl.error.0000)
    if [ "$SUCCESS" -eq 0 ]; then
        echo "real.exe blown"
        exit -1
    fi
    # [ -f wrfinput_d01 ] && echo "Moving wrfinput_d01 to ${OUTPUT_DIR}" \
    #     && mv wrfinput_d01 "${OUTPUT_DIR}/wrfinput_d01_${hh_s}_${hh_e}"

    # [ -f wrfbdy_d01 ] && echo "Moving wrfbdy_d01 to ${OUTPUT_DIR}" \
    #     && mv wrfbdy_d01 "${OUTPUT_DIR}/wrfbdy_d01_${hh_s}_${hh_e}"
    # ALWAYS move into the fixed cycle dir

    for d in d01 d02 d03; do
    f="wrfinput_${d}"
    f2="wrfbdy_${d}"
    if [ -f "$f" ]; then
        echo "Moving ${f} to ${OUTPUT_DIR}/${f}_${hh_s}_${hh_e}"
        mv -f "$f" "${OUTPUT_DIR}/${f}_${hh_s}_${hh_e}"
        rm -f "$f" rsl.out.* rsl.error.*
    else
        echo "${f} does not exist"
    fi
    done
    if [ -f "$f2" ]; then
        echo "Moving ${f2} to ${OUTPUT_DIR}/${f2}_${hh_s}_${hh_e}"
        mv -f "$f2" "${OUTPUT_DIR}/${f2}_${hh_s}_${hh_e}"
        rm -f "$f2"
    else
        echo "${f2} does not exist"
    fi

    n=$((n+1))
done

# move to next time, or exit if final time is reached
echo "OUTPUT_DIR = $OUTPUT_DIR"
echo "FINAL_DATE = ${FINAL_DATE:0:10}"
if [ "$OUTPUT_DIR" -ge "${FINAL_DATE:0:10}" ]; then
    echo "Reached the final date"
    break
fi

datea=`${BUILD_DIR}/da_advance_time.exe $datea $DE_FCST_RANGE -w`
echo "starting next time: $datea"

done
END_DATE=`${BUILD_DIR}/da_advance_time.exe $FINAL_DATE 0 -w`
ccyy_n=${START_DATE:0:4}; mm_n=${START_DATE:5:2}; dd_n=${START_DATE:8:2}; hh_n=${START_DATE:11:2}
ccyy_f=${END_DATE:0:4}; mm_f=${END_DATE:5:2}; dd_f=${END_DATE:8:2}; hh_f=${END_DATE:11:2}

    cat > namelist.input << EOF
    &time_control
    run_days                            = 0,
    run_hours                           = ${fcst_hours},
    run_minutes                         = 0,
    run_seconds                         = 0,
    start_year                          = ${ccyy_n},${ccyy_n},${ccyy_n},
    start_month                         = ${mm_n},${mm_n},${mm_n},
    start_day                           = ${dd_n},${dd_n},${dd_n}
    start_hour                          = ${hh_n},${hh_n},${hh_n}
    start_minute                        = 00,00,00,
    start_second                        = 00,00,00,
    end_year                            = ${ccyy_f},${ccyy_f},${ccyy_f}
    end_month                           = ${mm_f},${mm_f},${mm_f}
    end_day                             = ${dd_f},${dd_f},${dd_f}
    end_hour                            = ${hh_f},${hh_f},${hh_f}
    end_minute                = 00,00,00,
    end_second                = 00,00,00,
    interval_seconds           = ${LBC_FREQ_SECOND},
    input_from_file            = .true.,.true.,.true.,
    history_interval           = 180,60,60,
    frames_per_outfile         = 1000,1000,1000,
    restart                    = .false.,
    restart_interval            = 2161,
    debug_level                 = 0,
    write_input                 = .false.,
    /

    &domains
    time_step                  = ${NL_TIME_STEP},
    time_step_fract_num         = 0,
    time_step_fract_den         = 1,
    max_dom                     = ${MAX_DOM},
    e_we                        = ${NL_E_WE_1},${NL_E_WE_2},${NL_E_WE_3},
    e_sn                        = ${NL_E_SN_1},${NL_E_SN_2},${NL_E_SN_3},
    e_vert                      = ${NL_E_VERT},${NL_E_VERT},${NL_E_VERT},
    dx                           = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3},
    dy                           = ${NL_DXY_1},${NL_DXY_2},${NL_DXY_3},
    grid_id                      = 1,2,3,
    parent_id                    = 1,1,2,    
    i_parent_start               = 1,${I_PARENT_START_2},${I_PARENT_START_3},
    j_parent_start               = 1,${J_PARENT_START_2},${J_PARENT_START_3},
    parent_grid_ratio            = 1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
    parent_time_step_ratio       = 1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
    feedback                     = ${FEEDBACK},
    p_top_requested              = ${NL_P_TOP_REQUESTED},
    num_metgrid_levels           = ${NL_NUM_METGRID_LEVELS},
    num_metgrid_soil_levels      = 4,
    hypsometric_opt              = 2,
    smooth_option                = 0,
    eta_levels                   = ${NL_VERT_LEVELS},
    /

    &physics
    mp_physics                   = ${NL_MP_PHYSICS},${NL_MP_PHYSICS},${NL_MP_PHYSICS},
    ra_lw_physics                = ${NL_RA_LW},${NL_RA_LW},${NL_RA_LW},
    ra_sw_physics                = ${NL_RA_SW},${NL_RA_SW},${NL_RA_SW},
    radt                         = ${NL_RADT1},${NL_RADT2},${NL_RADT2},
    sf_sfclay_physics            = ${NL_SF_SFCLAY_PHYSICS},${NL_SF_SFCLAY_PHYSICS},${NL_SF_SFCLAY_PHYSICS},
    sf_surface_physics           = ${NL_SF_SURFACE_PHYSICS},${NL_SF_SURFACE_PHYSICS},${NL_SF_SURFACE_PHYSICS},
    bl_pbl_physics               = ${NL_BL_PBL_PHYSICS},${NL_BL_PBL_PHYSICS},${NL_BL_PBL_PHYSICS},
    bldt                         = ${NL_BLDT},
    cu_physics                   = ${NL_CU_PHYSICS1},${NL_CU_PHYSICS2},0, 
    cudt                         = ${NL_CUDT1},${NL_CUDT2},0,
    DO_RADAR_REF                 = 1,
    isfflx                       = 1,
    ifsnow                       = 1,
    icloud                       = 1,
    surface_input_source         = 1,
    num_soil_layers              = 4,
    num_land_cat                 = 20,
    /

    &stoch
    stoch_force_opt              = ${SKEB},
    stoch_vertstruc_opt          = 1,
    tot_backscat_psi             = 1.0E-5,
    tot_backscat_t               = 1.0E-6,
    nens                         = ${NUM_MEMBERS},
    perturb_bdy                  = ${PERT_BDY},
    /

    &fdda
    /

    &dynamics
    w_damping                    = 1,
    diff_opt                     = 1,
    gwd_opt                      = 1,
    km_opt                       = 4,
    diff_6th_opt                 = 0,
    diff_6th_factor              = 0.12,
    base_temp                    = 290.,
    damp_opt                     = 0,
    zdamp                        = 5000.,5000.,5000.,
    dampcoef                     = 0.15,0.15,0.15,
    khdif                        = 0,0,0,
    kvdif                        = 0,0,0,
    non_hydrostatic              = .true.,.true.,.true.,
    moist_adv_opt                = 1,1,1,
    scalar_adv_opt               = 2,2,2,
    use_theta_m                  = 0,
    /

    &bdy_control
    spec_bdy_width               = 5,
    spec_zone                    = 1,
    relax_zone                   = 4,
    specified                    = .true.,.false.,.false.,
    nested                       = .false.,.true.,.true.,
    /

    &grib2
    /

    &namelist_quilt
    nio_tasks_per_group           = 0,
    nio_groups                    = 1,
    /

    &dfi_control
    /
EOF

srun -n 16 ./real.exe
wait 5

OUTPUT=${ccyy_n}${mm_n}${dd_n}${hh_n}_${ccyy_f}${mm_f}${dd_f}${hh_f}
mkdir -p ${OUTPUT}
mv -f wrfinput_d03 ${OUTPUT}/wrfinput_d03
mv -f wrfinput_d01 ${OUTPUT}/wrfinput_d01
mv -f wrfinput_d02 ${OUTPUT}/wrfinput_d02
mv -f wrfbdy_d03 ${OUTPUT}/wrfbdy_d03
mv -f wrfbdy_d02 ${OUTPUT}/wrfbdy_d02
mv -f wrfbdy_d01 ${OUTPUT}/wrfbdy_d01

mv rsl.out.* ${OUTPUT}/.
ln -sf ${OUTPUT}/wrfinput_d03 ${NATURE_ICBC_DIR}/${ccyy_n}${mm_n}${dd_n}${hh_n}/wrfinput_d03

exit 0 
