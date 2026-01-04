#!/bin/bash
# This script runs Ensemble DATA Assimilation (DA) usiing DART and WRF-ARW model.
# It sets up the environment, prepares necessary files, and executes the assimilation process.

source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
echo "Activating conda environment"

conda activate ncar_env
# module restore
module load intel/21
module load openmpi/4.1.0
ml python/3  

RUN_CMD="srun --partition=chipilskigroup_q"

# models directory
MODEL_DIR=/gpfs/research/chipilskigroup/stephen_asare/models
WRFDA_DIR=$MODEL_DIR/WRFDA/V4.5.2
BUILD_DIR=$WRFDA_DIR/var/build
WRF_DIR=$MODEL_DIR/WRF/V4.6.1
WPS_DIR=$MODEL_DIR/WPS/V4.5
DART_DIR=$MODEL_DIR/DART/v11.11.1

# scripts directorys
SCRIPTS_DIR=/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING
NML_DIR=${SCRIPTS_DIR}/NML

# Run directory
RUN_DIR="/gpfs/home/sa24m/scratch/tqprof/run2"     # set this appropriately #%%%#
OBS_DIR=$RUN_DIR/input/obs
RADAR_DIR=$RUN_DIR/input/radar
BE_DIR=$RUN_DIR/input/be
REAL_FC_ERA_DIR=$RUN_DIR/input

## Directories for Peturbed Ensemble Members
ENS_DIR=${RUN_DIR}/ens



# input data Directories:
GEOG_DATA_PATH=/gpfs/research/chipilskigroup/stephen_asare/data/WPS_GEOG
WPS_INPUT_DIR=$RUN_DIR/input/wps_input


# output data durectory:
############################################################
EXP_DIR=$RUN_DIR/osse_out

#wps & real
# WPS_RUN_DIR=$EXP_DIR/wps_fc
# REAL_FC_DIR=$EXP_DIR/real_fc
ICBC_DIR=$EXP_DIR/icbc

WPS_ENS_DIR=$EXP_DIR/wps_ens
ENS_FCST_DIR=$EXP_DIR/ens_fcst
NATURE_DIR=$EXP_DIR/nature_run

# wrf-related
ENS_WRF_DIR=$EXP_DIR/ens_wrf
NATURE_ICBC_DIR=$RUN_DIR/icbc/test/REAL
ANALYSIS_DIR=$RUN_DIR/icbc/test/rc
INITIAL_FC=$EXP_DIR/initial_fc
ENS_ICBC_DIR=$EXP_DIR/ens_icbc
ENSMEAN_DIR=$EXP_DIR/ensmean
ENSMEAN_BG_DIR=$EXP_DIR/ensmean_bg

# analysis proces
DART_D01_DIR=$EXP_DIR/dart_eakf_d01
DART_D02_DIR=$EXP_DIR/dart_eakf_d02
#############################################################

#Time info:                        
INITIAL_DATE=2015071412
FINAL_DATE=2015071512
RADAR_START_DATE=2015071600
CYCLE_PERIOD=6  #forecast range in cycle/en-forecast
CYCLE_RADAR=15  #frequency of radar assimilation (min) 

DE_FCST_RANGE=6
SPINUP_TIME=3
LBC_FREQ=6        #GFS or FNL inteval 
OUTPUT_INTERVAL=15

# Domain:
MAP_PROJ=lambert
REF_LAT=39.0
REF_LON=-101.0
TRUELAT1=32.0
TRUELAT2=46.0
STAND_LON=-101.0
NL_TIME_STEP=60
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
NUM_MEMBERS=30
MAX_ERROR=5
ASSIM_INT_HOURS=6
IC_PERTSCALE=0.25
ADAPTIVE_INFLATION=0 
NUM_VAR_DA=18
VAR_DART=${VAR_DART:-"U,V,PH,THM,MU,QVAPOR,QCLOUD,QRAIN,QICE,QSNOW,QGRAUP,QNICE,QNRAIN,U10,V10,T2,Q2,PSFC"}

extract_vars_a=(U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC)
# RAINC RAINNC GRAUPELNC
extract_vars_b=(U V W PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC REFL_10CM VT_DBZ_WT)
cycle_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK)
increment_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC)
#########################################################################################################


export REMOVE="rm -rf"
export COPY="cp -pfr"
export MOVE="mv -f"
export LINK="ln -fs"
export WGET="/usr/bin/wget"
export LIST="ls"

echo "param.sh done"
