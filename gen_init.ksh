#!/bin/ksh
#-----------------------------------------------------
ulimit -s unlimited
export NUM_MEMBERS=30

export RUN_WRFVAR=true            
export RUN_UPDATE_BC=false        
export SINGLE_OBS=false        
export SUBMIT=none
export NUM_PROCS=1 
if [[ $NUM_PROCS -gt 1 ]]; then
   export RUN_CMD="srun $NUM_PROCS"
   #export RUN_CMD="mpiexec -np $NUM_PROCS"
else
   export RUN_CMD="srun "
fi
export CLEAN=false
export NL_FORCE_USE_OLD_DATA=true

# Define experiment name

export REGION=con200         
export EXP_name=gfs
# Define directories for source code and input data 

#export REL_DIR=/glade/scratch/junkyung/MPD_exp/pecan/NR_CNTL_july15_mod_as4_39h_era5_auto_70levs
# Ensemble perturbation dir, working dir.
# export REL_DIR=/gpfs/research/chipilskigroup/junkyung/ICBC/test
export REL_DIR=/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/ens

# WRF real data dir
# export REAL_DIR=/gpfs/research/chipilskigroup/junkyung/ICBC/test/REAL
export REAL_DIR=/gpfs/research/scratch/sa24m/tqprof/run2/osse_out/ens/REAL
#export WRFVAR_DIR=/glade/work/junkyung/fossell/wrfda-derecho (Check!!)
export WRFVAR_DIR=/gpfs/research/chipilskigroup/stephen_asare/models/WRFDA/V4.5.2

# script dir... pwd
export SCRIPTS_DIR='/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/ens'

export DAT_DIR=$REL_DIR
export RUN_DIR=$REL_DIR/perturb_wrf_bc  #jk
#export RUN_DIR=$REL_DIR/ICBC  #jk
export FC_DIR=${RUN_DIR}/fc
export REG_DIR=$DAT_DIR
export OB_DIR=${DAT_DIR}/ob
export RC_DIR=${DAT_DIR}/rc
# export RC_DIR=/gpfs/research/scratch/sa24m/mpd/input/icbc
export BE_DIR=${DAT_DIR}/be

# do not change
export WPB_DIR=/gpfs/home/junkyung_ucar_edu/ICBC/fromdart

# Define experiment time period and dimension

export INITIAL_DATE=2015071412
export   FINAL_DATE=2015071512

export CYCLE_PERIOD=24
export DATE=$INITIAL_DATE
export LBC_FREQ=6

export NL_E_WE=212
export NL_E_SN=160
export NL_DX=15000
export NL_DY=15000
export NL_E_VERT=51
#export NL_ETA_LEVELS=${NL_ETA_LEVELS:-" 1.0000, 0.9980, 0.9940, 0.9870, 0.9750, 0.9590, "\
#                      " 0.9390, 0.9160, 0.8920, 0.8650, 0.8350, 0.8020, 0.7660, "\
#                      " 0.7270, 0.6850, 0.6400, 0.5920, 0.5420, 0.4970, 0.4565, "\
#                      " 0.4205, 0.3877, 0.3582, 0.3317, 0.3078, 0.2863, 0.2670, "\
#                      " 0.2496, 0.2329, 0.2188, 0.2047, 0.1906, 0.1765, 0.1624, "\
#                      " 0.1483, 0.1342, 0.1201, 0.1060, 0.0919, 0.0778, 0.0657, "\
#                      " 0.0568, 0.0486, 0.0409, 0.0337, 0.0271, 0.0209, 0.0151, "\
#                      " 0.0097, 0.0047, 0.0000,"}
#export NL_AUTO_LEVELS_OPT=2
#export NL_DZBOT=20
#export NL_DZSTRETCH_S=1.1
#export NL_DZSTRETCH_U=1.1


export NL_P_TOP_REQUESTED=1500

export NL_I_PARENT_START=1
export NL_J_PARENT_START=1
export NL_TIME_STEP=30
export NL_SMOOTH_OPTION=1
export NL_MP_PHYSICS=8
export NL_RA_LW_PHYSICS=4
export NL_RA_SW_PHYSICS=4
export NL_RADT=10
export NL_SF_SFCLAY_PHYSICS=2
export NL_SF_SURFACE_PHYSICS=2
export NL_NUM_SOIL_LAYERS=4
export NL_NUM_LAND_CAT=20
export NL_BL_PBL_PHYSICS=2
export NL_CU_PHYSICS=1
export NL_W_DAMPING=1
export NL_DIFF_OPT=1
export NL_KM_OPT=4
export NL_HISTORY_INTERVAL=360

export NL_USE_THETA_M=0
# Define experiment options

#export SCRIPT=$WRFVAR_DIR/var/scripts/RC_ICBDY_ptb/test/d01/da_run_wpb.ksh   #jk
export SCRIPT=$SCRIPTS_DIR/da_run_wpb.ksh   #jk

export NL_EPS=0.01
export NL_NTMAX=200
export NL_CALCULATE_CG_COST_FN=true

# Modifying CV3 length scales and variance
export NL_CV_OPTIONS=3
export NL_AS1="0.063, 0.75, 1.50"
export NL_AS2="0.063, 0.75, 1.50"
export NL_AS3="0.22, 1.00, 1.50"
export NL_AS4="0.05, 0.30, 0.70"
export NL_AS5="0.27, 0.50, 1.50"

#export NL_USE_SOUNDOBS=true      
#export NL_USE_SYNOPOBS=false     
#export NL_USE_METAROBS=false     
#export NL_USE_PILOTOBS=false     
#export NL_USE_SHIPSOBS=false     
#export NL_USE_BUOYOBS=false     
#export NL_USE_GEOAMVOBS=false     
#export NL_USE_AIREPOBS=false     
#export NL_USE_GPSPWOBS=false     
#export NL_USE_SATEMOBS=false     


if $SINGLE_OBS ; then
##----------------------------------------------
##   For Single Obs test  starts
export runplot_psot=2  # 1 -run psot  2- plot psot
export RUN_DIR=$REL_DIR/$REGION/run_psot_cpu${NUM_PROCS}
export FC_DIR=${RUN_DIR}/fc
# 
export NL_NUM_PSEUDO=1
export NL_PSEUDO_VAR="t"         #  Can be    "u   v    t    p     q"
export NL_PSEUDO_X=23.0
export NL_PSEUDO_Y=23.0
export NL_PSEUDO_Z=14.0
export NL_PSEUDO_ERR=1.0       #  Should be "1.0 1.0 1.0  1.0  0.001"
export NL_PSEUDO_VAL=1.0       #  Should be "1.0 1.0 1.0  1.0  0.001"
export NL_CHECK_RH=0                                                   
##----------------------------------------------
export PSEUDO_VAR_SIZE=1
export PSEUDO_VAR_LIST="t"         #  Can be    "u   v    t    p      q"
export PSEUDO_VAL_LIST="1.0"       #  Should be "1.0 1.0 1.0  1.0  0.001"
export PSEUDO_ERR_LIST="1.0"       #  Should be "1.0 1.0 1.0  1.0  0.001"
export PSEUDO_X_LIST="23"          #  Middle of the domain
export PSEUDO_Y_LIST="23"          #  Middle of the domain
export PSEUDO_Z_LIST="14"          #  Middle of the domain
##
if (( $runplot_psot == 1 ));then
   export SCRIPT=$WRFVAR_DIR/var/scripts/da_run_suite.ksh
   echo "DEBUG: Running da_run_suite.ksh for single obs test"
else
   export SCRIPT=$WRFVAR_DIR/var/scripts/da_plot_psot.ksh
   export EXP_DIR=${RUN_DIR}
   $WRFVAR_DIR/var/scripts/da_plot_psot.ksh
   echo "DEBUG: Running da_plot_psot.ksh for single obs test"
   exit 0
fi
#export NL_LEN_SCALING1=0.5    
#export NL_LEN_SCALING2=0.5    
#export NL_LEN_SCALING3=0.5    
#export NL_LEN_SCALING4=0.5    
#export NL_LEN_SCALING5=0.5    

#export NL_LEN_SCALING1=0.25    
#export NL_LEN_SCALING2=0.25    
#export NL_LEN_SCALING3=0.25    
#export NL_LEN_SCALING4=0.25    
#export NL_LEN_SCALING5=0.25    

fi
##----------------------------------------------
##   For Single Obs test  ends
##----------------------------------------------

# $WRFVAR_DIR/var/scripts/da_run_job.ksh
echo "test"
# $WRFVAR_DIR/var/scripts/RC_ICBDY_ptb/test/d01/da_run_job.ksh  #jk old
cd $SCRIPTS_DIR
pwd
echo "DEBUG: Running da_run_job.ksh now"
$SCRIPTS_DIR/da_run_job.ksh
echo "da_run_job.ksh done"
exit 0

































