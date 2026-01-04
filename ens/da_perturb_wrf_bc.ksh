#!/bin/ksh
#########################################################################
# Script: da_perturb_wrf_bc.ksh
#
# Purpose: Produce a perturbed WRF lateral boundary condition (wrfbdy) file.
#
# Description:
# 1. Run WRF-Var in "randomcv" mode (produces ensemble of perturbed
#    wrfinput_d01 files.
# 2. Loop over 1. and 2. for each time of tendency in wrfbdy file out to
#    forecast length (e.g. 3hourly tendency update in a 72hr forecast).
# 3. Run perturb_wrf_bc to provide perturbed wrfbdy file.
#
#########################################################################

#########################################################################
# Ideally, you should not need to change the code below, but if you 
# think it necessary then please email wrfhelp@ucar.edu with details.
#########################################################################

export REL_DIR=${REL_DIR:-$HOME/trunk}
export WRFVAR_DIR=${WRFVAR_DIR:-$REL_DIR/WRFDA}
#export SCRIPTS_DIR=${SCRIPTS_DIR:-$WRFVAR_DIR/var/scripts}
export SCRIPTS_DIR=${SCRIPTS_DIR:-$WRFVAR_DIR/var/scripts/RC_ICBDY_ptb/july15_mod_as4_39h_era5/d01}
. ${SCRIPTS_DIR}/da_set_defaults.ksh
export RUN_DIR=${RUN_DIR:-$EXP_DIR/perturb_wrf_bc}
export WORK_DIR=$RUN_DIR/working

#------------------------------------------------------------------------------------------

export DATE_SAVE=$DATE
export RC_DIR_SAVE=$RC_DIR
export NL_ANALYSIS_TYPE_SAVE=$NL_ANALYSIS_TYPE
export CYCLING_SAVE=$CYCLING
export RUN_DIR_SAVE=$RUN_DIR

#These are the local values:
export END_DATE=$($BUILD_DIR/da_advance_time.exe $DATE $CYCLE_PERIOD 2>/dev/null)

export NL_ANALYSIS_TYPE="randomcv"
export NL_PUT_RAND_SEED=.TRUE.

export CMEM=e$MEM
if [[ $MEM -lt 100 ]]; then export CMEM=e0$MEM; fi
if [[ $MEM -lt 10 ]]; then export CMEM=e00$MEM; fi

#while [[ $DATE -le $END_DATE ]]; do 

   export RUN_DIR=$RUN_DIR_SAVE/run/$DATE_SAVE/wrfvar_d01/${DATE}.${CMEM}
   mkdir -p $RUN_DIR

   export ANALYSIS_DATE=$($BUILD_DIR/da_advance_time.exe $DATE 0 -W 2>/dev/null)

   export NL_SEED_ARRAY1=$($BUILD_DIR/da_advance_time.exe $DATE 0 -f hhddmmyycc)
   export NL_SEED_ARRAY2=`echo $MEM \* 100000 | bc -l `

   echo "   Run WRF-Var in randomcv mode for date $DATE"
   export DA_FIRST_GUESS=${RC_DIR}/$DATE_SAVE/wrfinput_d01.${ANALYSIS_DATE}
   echo "   DA_FIRST_GUESS=" , $DA_FIRST_GUESS
   export DA_ANALYSIS=${RC_DIR}/$DATE_SAVE/wrfinput_d01.${DATE}.${CMEM}
   echo "   DA_ANALYSIS=" , $DA_ANALYSIS
#cys: need to set NL_ENSDIM_ALPHA=0, so that da_wrfvar.exe can run randomcv correctly
   export NL_ENSDIM_ALPHA=0

   # jk added
   if [[ ! -f $DA_FIRST_GUESS ]]; then
     # cp /glade/scratch/junkyung/MPD_exp/pecan/wrf/era5/70lev/$DATE/wrfinput_d01 $DA_FIRST_GUESS
      #cp /glade/scratch/junkyung/KNU/runwrf/real/$DATE/wrfinput_d01 $DA_FIRST_GUESS
      cp /gpfs/home/sa24m/scratch/tqprof/run2/osse_out/icbc/$DATE/wrfinput_d01_12_18 $DA_FIRST_GUESS
      echo "   Copy wrfinput_d01 from /gpfs/home/sa24m/scratch/tqprof/run2/osse_out/icbc/$DATE to $DA_FIRST_GUESS"
      #cp /glade/scratch/junkyung/KNU/runwrf/real/$DATE_SAVE/wrfbdy_d01  ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01
   fi

 

   # $SCRIPTS_DIR/da_trace.ksh da_run_wrfvar $RUN_DIR

   #date
   #qsub $SCRIPTS_DIR/da_run_wrfvar.ksh > $RUN_DIR/index.html 2>&1
   #date

   #RC=$?
   #if [[ $RC != 0 ]]; then
   #   echo $(date) "${ERR}Failed with error $RC$END"
   #   exit 1
   #fi

   # while [ ! -f ${DA_ANALYSIS} ]; do
   #    echo "   Waiting for da_analysis to finish..."
   #    sleep 10
   # done

   #export NEXT_DATE=$($BUILD_DIR/da_advance_time.exe $DATE $LBC_FREQ 2>/dev/null)
#   export NEXT_DATE=$($BUILD_DIR/da_advance_time.exe $DATE $CYCLE_PERIOD 2>/dev/null)
#   export DATE=$NEXT_DATE

#done

#jk  # update bdy

echo "   Run pert_wrf_bc to create perturbed wrfbdy file for member $MEM"
export RUN_DIR=$RUN_DIR_SAVE/run/$DATE_SAVE/pert_wrf_bc/${DATE_SAVE}.${CMEM}
echo "   RUN_DIR=" , $RUN_DIR
mkdir -p $RUN_DIR
cd $RUN_DIR

   # jk added
   if [[ ! -f ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01 ]]; then
 #     cp /glade/scratch/junkyung/MPD_exp/pecan/wrf/era5/70lev/$DATE_SAVE/wrfbdy_d01  ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01 
      #cp /glade/scratch/junkyung/KNU/runwrf/real/$DATE/wrfbdy_d01  ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01
      cp ${REAL_DIR}/$DATE/wrfbdy_d01 ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01
   fi

export DATE=$DATE_SAVE

            #export DA_REAL_OUTPUT=$RC_DIR/$DATE/wrfinput_d01.${DATE}.${CMEM}
            #export BDYIN=$RC_DIR/${DATE}/wrfbdy_d01.${CMEM}
            export DA_REAL_OUTPUT=$DA_FIRST_GUESS
            export BDYIN=${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01

            export DA_ANALYSIS=${RC_DIR_SAVE}/${DATE_SAVE}/wrfinput_d01.${DATE}.${CMEM}
            #export BDYOUT=$FC_DIR/${DATE}.${CMEM}/wrfbdy_d01
            export BDYOUT=${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01.${CMEM}
            #mkdir -p $FC_DIR/${DATE}.${CMEM}  #jk

            $SCRIPTS_DIR/da_trace.sh da_run_update_bc $RUN_DIR
            date
            #qsub -V $SCRIPTS_DIR/da_run_update_bc.ksh > $RUN_DIR/index.html 2>&1 &
            sbatch $SCRIPTS_DIR/da_run_update_bc.ksh > $RUN_DIR/index.html 2>&1 &
            date
            RC=$?
            if [[ $? != 0 ]]; then
               echo $(date) "${ERR}update_bc failed with error $RC$END"
               echo update_bc > FAIL
               break 2
            fi

#while [ ! -f $BDYOUT ]; do
#   sleep 100
#done

#while [[ $DATE -lt $END_DATE ]]; do

   #export NEXT_DATE=$($BUILD_DIR/da_advance_time.exe $DATE $LBC_FREQ 2>/dev/null)
#   export NEXT_DATE=$($BUILD_DIR/da_advance_time.exe $DATE $CYCLE_PERIOD 2>/dev/null)
#   if [[ ! -f wrfbdy_this ]]; then
#      cp ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01 wrfbdy_this
#   fi
#   ln -fs ${RC_DIR}/${DATE_SAVE}/wrfinput_d01.${DATE}.${CMEM} wrfinput_this
#   ln -fs ${RC_DIR}/${DATE_SAVE}/wrfinput_d01.${NEXT_DATE}.${CMEM} wrfinput_next
#  # ln -fs ${RC_DIR}/${NEXT_DATE}/wrfinput_d01.${NEXT_DATE}.${CMEM} wrfinput_next
#   ln -fs ${WPB_DIR}/input.nml .
#   ln -fs ${WPB_DIR}/pert_wrf_bc pert_wrf_bc.exe
#   . $WRFVAR_DIR/inc/namelist_script.inc 
##   ./pert_wrf_bc.exe > pert_wrf_bc.out.${CMEM} 2>&1
#   date
#   qsub $SCRIPTS_DIR/da_pert_wrf_bc.ksh > pert_wrf_bc.out.${CMEM} 2>&1
#   date
#   export DATE=$NEXT_DATE
#done

#while [ ! -f pert_wrf_bc.out2.${CMEM} ]; do
#   sleep 200
#done

#mv wrfbdy_this ${RC_DIR_SAVE}/${DATE_SAVE}/wrfbdy_d01.${CMEM}
##mv ${RC_DIR}/${DATE_SAVE}/wrfinput_d01.${CMEM} ${RC_DIR_SAVE}/${DATE_SAVE}

#export END_DATE=$END_DATE_SAVE
export RC_DIR=$RC_DIR_SAVE
#export NL_ANALYSIS_TYPE=$NL_ANALYSIS_TYPE_SAVE
export RUN_DIR=$RUN_DIR_SAVE
echo "perturb_wrf_bc done for member"
exit 0

