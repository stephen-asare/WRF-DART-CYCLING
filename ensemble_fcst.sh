#!/bin/bash

#--------------------------------------------------------------------------------------------------------
# This is a sample script to run the ensemble forecast
# This script generate the ensemble forecast. The full forecast is used for genrating nature run 
# and the first three hours is assimilated using the cyking ssytem.
#--------------------------------------------------------------------------------------------------------
paramfile="/gpfs/home/sa24m/Research/tqprof/scripts/run2/WRF-DART-CYCLING/param.sh"   # set this appropriately #%%%#
source "$paramfile"

WORK_DIR=${ENS_WRF_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
# NUM_MEMBERS=2 # DEBUG
MEM=1

DATE=$INITIAL_DATE

while [[ $MEM -le $NUM_MEMBERS ]]; do 
   if [[ $MEM -lt 100 ]]; then export CMEM=e0$MEM; fi
   if [[ $MEM -lt 10 ]]; then export CMEM=e00$MEM; fi
   mkdir -p ${WORK_DIR}/$CMEM
   cd ${WORK_DIR}/$CMEM
   echo "linking wrfinput for ensemble member $MEM from ${ENS_DIR}/rc/$DATE/wrfinput_d01.${DATE}.${CMEM}"
   ln -sf $ENS_DIR/rc/$DATE/wrfinput_d01.${DATE}.${CMEM} ./wrfinput_d01 || exit 1
   ln -sf $ICBC_DIR/wrfbdy_d01 ./wrfbdy_d01 || exit 1
   echo "Forecast for ensemble member $MEM"
   cp $SCRIPTS_DIR/advance_run.sh ./advance_run.sh
   sbatch ./advance_run.sh $INITIAL_DATE $FINAL_DATE 2>&1 &
   sleep 2
   MEM=$((MEM+1))   
   done
wait
echo "Ensemble forecast done"
exit 0 