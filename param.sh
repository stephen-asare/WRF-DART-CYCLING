#!/bin/bash
# This script runs Ensemble DATA Assimilation (DA) usiing DART and WRF-ARW model.
# It sets up the environment, prepares necessary files, and executes the assimilation process.

# Centralized module/conda loading function
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda activate ncar_env
source /etc/profile 
module purge 
module load intel/21 openmpi/4.1.0 hdf5/1.10.4 netcdf/4.7.0 python/3 



RUN_CMD="srun --partition=chipilskigroup_q"   # set this appropriately #%%%#

# models directory
MODEL_DIR=/gpfs/research/chipilskigroup/stephen_asare/models   # set this appropriately #%%%#
WRFDA_DIR=$MODEL_DIR/WRFDA/V4.5.2
BUILD_DIR=$WRFDA_DIR/var/build
WRF_DIR=$MODEL_DIR/WRF/V4.6.1
WPS_DIR=$MODEL_DIR/WPS/V4.5
DART_DIR=$MODEL_DIR/DART/v11.21.2

# scripts directorys
SCRIPTS_DIR=/gpfs/home/sa24m/Research/tqprof/scripts/run3/WRF-DART-CYCLING     # set this appropriately #%%%#
# NML_DIR=${SCRIPTS_DIR}/NML

# Run directory
RUN_DIR="/gpfs/home/sa24m/scratch/tqprof/run3"     # set this appropriately #%%%#
RADAR_DIR=$RUN_DIR/input/radar
BE_DIR=$RUN_DIR/input/be
REAL_FC_ERA_DIR=$RUN_DIR/input

## Directories for Peturbed Ensemble Members

# input data Directories:
export ERA5_DATA_DIR="/gpfs/home/sa24m/scratch/tqprof/run3/osse_out/data/ERA5"   # set this appropriately #%%%#
export PREPBUFR_DATA_DIR="/gpfs/home/sa24m/scratch/tqprof/run3/osse_out/prepbufr/bufr_data" # set this appropriately #%%%#
GEOG_DATA_PATH=/gpfs/research/chipilskigroup/stephen_asare/data/WPS_GEOG  # set this appropriately #%%%#
WPS_INPUT_DIR=$RUN_DIR/input/wps_input


# output data durectory:
############################################################
EXP_DIR=$RUN_DIR/osse_out
ENS_DIR=${EXP_DIR}/ens
DART_CYCLE_DIR=$EXP_DIR/dart_cycle

ICBC_DIR=$EXP_DIR/icbc

WPS_ENS_DIR=$EXP_DIR/wps_ens
ENS_FCST_DIR=$EXP_DIR/ens_fcst
NATURE_DIR=$EXP_DIR/nature_run
SYS_OBS_DIR=$EXP_DIR/sys_obs

# wrf-related
ENS_WRF_DIR=$EXP_DIR/ens_wrf
NATURE_ICBC_DIR=$RUN_DIR/icbc/test/REAL
ANALYSIS_DIR=$RUN_DIR/icbc/test/rc
INITIAL_FC=$EXP_DIR/initial_fc
ENS_ICBC_DIR=$EXP_DIR/ens_icbc
ENSMEAN_DIR=$EXP_DIR/ensmean
ENSMEAN_BG_DIR=$EXP_DIR/ensmean_bg

#Time info:                        

phase1_DE_FCST_RANGE=50
INITIAL_DATE=2015071300
FINAL_DATE=2015071512
RADAR_START_DATE=2015071600
CYCLE_PERIOD=6  #forecast range in cycle/en-forecast
CYCLE_RADAR=15  #frequency of radar assimilation (min) 
LBC_FREQ_SECOND=`expr 3600 \* ${CYCLE_PERIOD}`
DE_FCST_RANGE=6
SPINUP_TIME=3
LBC_FREQ=6        #GFS or FNL inteval 
OUTPUT_INTERVAL=180

# Domain:
MAP_PROJ=lambert
REF_LAT=39.0
REF_LON=-101.0
TRUELAT1=32.0
TRUELAT2=46.0
STAND_LON=-101.0
NL_TIME_STEP=30
NL_E_VERT=51 #number of vertical levels needs to be 71
NL_P_TOP_REQUESTED=1500
FEEDBACK=1

#DOMAIN for NEST
MAX_DOM=2
PARENT_GRID_RATIO_1=1;  PARENT_GRID_RATIO_2=5;   PARENT_GRID_RATIO_3=3
NL_E_WE_1=212;  NL_E_WE_2=411;     NL_E_WE_3=745
NL_E_SN_1=160;  NL_E_SN_2=321;     NL_E_SN_3=655	
I_PARENT_START_1=1;  I_PARENT_START_2=66;   I_PARENT_START_3=82
J_PARENT_START_1=1;  J_PARENT_START_2=51;   J_PARENT_START_3=52
GEOG_DATA_RES_1=modis_30s+30s;  GEOG_DATA_RES_2=modis_30s+30s;   GEOG_DATA_RES_3=modis_30s+30s
NL_DXY_1=15000;  NL_DXY_2=3000;  NL_DXY_3=1000
INPUT_FROM_FILE_1=.true.;  INPUT_FROM_FILE_2=.false.;   INPUT_FROM_FILE_3=.false.

AUTO_LEVELS_OPT=2; DZBOT=20; DZSTRETCH_S=1.08; DZSTRETCH_U=1.1
			   
#physics					   
NL_MP_PHYSICS=8 # 2 for Lin
NL_RA_LW=4
NL_RA_SW=4
NL_RADT1=10; NL_RADT2=10
NL_SF_SFCLAY_PHYSICS=2
NL_SF_SURFACE_PHYSICS=2 # 2 for CWB, 1 for Korea
NL_BL_PBL_PHYSICS=2
NL_BLDT=0
NL_CU_PHYSICS1=1; NL_CU_PHYSICS2=0
NL_CUDT1=5; NL_CUDT2=5
NL_NUM_SOIL_LAYERS=4
NL_NUM_METGRID_LEVELS=38
SKEB=0   ##skeb,0 turn off ;1 turn on
PERT_BDY=0
RUN_MULTI_PHY=false  ##in wrf-ens   

# WRF-VAR
NL_OB_FORMAT=2
NL_NTMAX=80
FORCE_USE_OLD_DATA=T
WINDOW_START=-1h30min
WINDOW_END=1h30min
MAX_ERROR=3.0
CV_OPTIONS1=5
CV_OPTIONS2=7
KIND_VAR=3
NL_ALPHA_CORR_SCALE=100.   
NL_JE_FACTOR=1.33333         
NL_ALPHA_VERTLOC=true

#########################################################################################################
# For Ensembles
NUM_MEMBERS=50
MAX_ERROR=5
ASSIM_INT_HOURS=6
IC_PERTSCALE=0.25
NUM_VAR_DA=18
VAR_DART=${VAR_DART:-"U,V,PH,THM,MU,QVAPOR,QCLOUD,QRAIN,QICE,QSNOW,QGRAUP,QNICE,QNRAIN,U10,V10,T2,Q2,PSFC"}

# Parameters for generating initial ensemble perturbations
export RUN_WRFVAR=true
export RUN_UPDATE_BC=false
export SINGLE_OBS=false
export CLEAN=false
export SUBMIT=none

# Ensemble perturbation specific paths
export REAL_DIR=${RUN_DIR}/osse_out/ens/rc
export WPB_DIR=/gpfs/home/junkyung_ucar_edu/ICBC/fromdart
export ENS_PERT_CYCLE_PERIOD=24

# WRFDA / randomcv perturbation settings
export NL_CV_OPTIONS=3            # CV3 background errors
export NL_PUT_RAND_SEED=.TRUE.
export NL_FORCE_USE_OLD_DATA=true
export NL_SMOOTH_OPTION=1
export NL_NUM_LAND_CAT=20
export NL_W_DAMPING=1
export NL_DIFF_OPT=1
export NL_KM_OPT=4
export NL_USE_THETA_M=0
export NL_EPS=0.01
export NL_CALCULATE_CG_COST_FN=true

# CV3 scaling factors (AS1-AS5) to control ensemble spread
export NL_AS1="0.25, 1.00, 1.5"
export NL_AS2="0.25, 1.00, 1.50"
export NL_AS3="0.25, 1.00, 1.50"
export NL_AS4="0.25, 1.00, 1.50"
export NL_AS5="0.25, 1.00, 1.50"

extract_vars_a=(U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC)
# RAINC RAINNC GRAUPELNC
extract_vars_b=(U V W PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC REFL_10CM VT_DBZ_WT)
cycle_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK)
increment_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC)

# ==============================================================================
# SLURM / SBATCH Configuration Settings
# ==============================================================================
# 1. ICBC Generation Job Settings (gen_icbc3.sh)
export ICBC_SBATCH_ACCOUNT="backfill2"
export ICBC_SBATCH_PARTITION="backfill2"
export ICBC_SBATCH_TASKS=15
export ICBC_SBATCH_TIME="00:50:00"
export ICBC_SBATCH_CONSTRAINT="intel,YEAR2013|intel,YEAR2015|intel,YEAR2017|intel,YEAR2018|intel,YEAR2019"

# 2. Ensemble Initialization - WRFDA / randomcv Job Settings (gen_init.sh)
export PERT_WRFVAR_SBATCH_ACCOUNT="backfill2"
export PERT_WRFVAR_SBATCH_PARTITION="backfill2"
export PERT_WRFVAR_SBATCH_TASKS=5
export PERT_WRFVAR_SBATCH_TIME="00:30:00"
export PERT_WRFVAR_SBATCH_MEM="8000M"
export PERT_WRFVAR_SBATCH_CONSTRAINT="intel,YEAR2013|intel,YEAR2015|intel,YEAR2017|intel,YEAR2018|intel,YEAR2019"

# 3. Ensemble Initialization - Update BC Job Settings (gen_init.sh)
export PERT_UPDBC_SBATCH_ACCOUNT="backfill2"
export PERT_UPDBC_SBATCH_PARTITION="backfill2"
export PERT_UPDBC_SBATCH_TASKS=5
export PERT_UPDBC_SBATCH_TIME="00:30:00"
export PERT_UPDBC_SBATCH_MEM="8000M"

# 4a. Initial Ensemble Forecast Job Settings (ensemble_fcst.sh)
export ENS_FCST_SBATCH_ACCOUNT="chipilskigroup_q"
export ENS_FCST_SBATCH_PARTITION="chipilskigroup_q"
export ENS_FCST_SBATCH_NODES=15
export ENS_FCST_SBATCH_TASKS=75
export ENS_FCST_SBATCH_TIME="3:55:00"
export ENS_FCST_SBATCH_MEM="4000M"
export ENS_FCST_SBATCH_CONSTRAINT="intel,YEAR2018|intel,YEAR2019"

# 4b. Cycling Forecast Job Settings (run_cycle.sh)
export CYCLE_FCST_SBATCH_ACCOUNT="backfill2"
export CYCLE_FCST_SBATCH_PARTITION="backfill2"
export CYCLE_FCST_SBATCH_NODES=5
export CYCLE_FCST_SBATCH_TASKS=30
export CYCLE_FCST_SBATCH_TIME="00:30:00"
export CYCLE_FCST_SBATCH_MEM="8000M"
export CYCLE_FCST_SBATCH_CONSTRAINT="intel,YEAR2015|intel,YEAR2017|intel,YEAR2018|intel,YEAR2019"

# 5. DART Filter Job Settings 
export FILTER_SBATCH_ACCOUNT="chipilskigroup_q"
export FILTER_SBATCH_PARTITION="chipilskigroup_q"
export FILTER_SBATCH_NODES=15
export FILTER_SBATCH_TASKS=75
export FILTER_SBATCH_TIME="22:55:00"
export FILTER_SBATCH_CONSTRAINT="intel,YEAR2018|intel,YEAR2019"

## DART 
ADAPTIVE_INFLATION=2
tasks_per_node=15  
lay_out=1                                        

#########################################################################################################


export REMOVE="rm -rf"
export COPY="cp -pfr"
export MOVE="mv -f"
export LINK="ln -fs"
export WGET="/usr/bin/wget"
export LIST="ls"

echo "param.sh done"
