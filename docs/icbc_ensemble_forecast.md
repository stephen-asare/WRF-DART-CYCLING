# Generating Boundary Conditions
Before moving on to data assimilation, generate your Initial Condition (IC) and Boundary Condition (BC) files.
Edit the parameter file (`param.sh`) to match your device requirements, scheduler requirements, and local directory paths.
Run the generation script:
```
sbatch gen_icbc.sh
```
This should produce directory `2015071300` containing wrfinput and wrfbdy files.

### Generate Perturbed Ensembles
Using the IC and BC files produced for the initial date of the experiment, use randomcv from WRFDA to produce randomly perturbed ensembles.

Edit `gen_init.ksh`:Set `SCRIPTS_DIR` to your current script directory.
Set `REAL_DIR` to the scratch experiment directory.
Update  the initial and final date as well as path to first guess, `wrfbdy` nad `wrfinput` created from `gen_icbc.sh` above.
Execute the script:
```
./gen_init.ksh
```
### Full Experiment Cycle 
Run the full experiment cycle to select your nature run. Update inital and final date to experiment initial and final date.
```
./ensemble_fcst.sh
```
### Generate Synthetic Observations
#### Genrating sysnthetic obsservations using prebufr locations and metadata.
Finally, generate the synthetic observations using the provided Python and Korn shell scripts. 
Run these in the following order:
Update `geb_obs.sh` script, specify `initial_date`, `final_date` and directory to prepubfur files.
Run
```
./gen_obs.sh
```
To extract Rread conventional observation (SFC+UPA) using DART prep_bufr program and generate metadata files. 

Then run:
```
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda activate python311_env
python3 filter_obs.py
```
This reads intermediate text file (e.g. temp_obs.2021081512) and filters rows that satisfy longitude/latitude/pc requirements, and output them by observation types (“ADPUPA", "ADPSFC", "SATWND", "AIRCFT", "SFCSHP”)

Finally, extract variables from Nature run based on the metadata and generate intermediate files containing synthetic observation information
```
python3 extract_wrf_obs_earthwind_ObsError2.py
conda deactivte
```
Convert the intermediate files (temp_obs.2021081512) into a format suitable for DA systems such as DART or JEDI, using DART (ascii_to_obs) program.
```
./make_obs.ksh
```

#### Generating sysnthetic observation, manually specifying observation location and meta data.
First update `sys_temp_obs.py` to manually place observations and obervation meta data.
Update `extract_wrf_obs_earthwind_ObsError2.py` to read temp files from output of `sys_temp_obs.py`
```
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda activate python311_env
python3 sys_temp_obs.py
python3 extract_wrf_obs_earthwind_ObsError2.py
./make_obs.ksh
```
