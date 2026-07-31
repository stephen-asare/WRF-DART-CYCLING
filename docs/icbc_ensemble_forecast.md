# Generating Boundary Conditions

First, lets create a separate conda enviroment and build some ncar utilities required.
```
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda create -n ncar_env -c conda-forge \
    python=3.13 \
    numpy \
    netcdf-fortran \
    esmf \
    tempest-remap \
    nco \
    ncl \
    pybufrkit 
```
Select yes(y) if prompted.

Before moving on to data assimilation, generate your Initial Condition (IC) and Boundary Condition (BC) files.
Edit the parameter file (`param.sh`) to match your device requirements, scheduler requirements, and local directory paths.
Run the generation script:
```
./gen_icbc.sh
```
This should produce directory `2015071300` containing wrfinput and wrfbdy files.

### Generate Perturbed Ensembles
Using the IC and BC files produced for the initial date of the experiment, use randomcv from WRFDA to produce randomly perturbed ensembles.

Execute the script:
```
./gen_init.sh
```
### Full Experiment Cycle 
Run the full experiment cycle to select your nature run. Update inital and final date to experiment initial and final date.
```
./ensemble_fcst_full.sh
```
### Generate Synthetic Observations
#### Genrating sysnthetic obsservations using prebufr locations and metadata.
Finally, generate the synthetic observations using the provided scripts. There are two diffrent observations we want to generate, first is to generate observation using prepbufr locations and metadata from real observations. The next we manually simulate observations at specific locations and metadata using `sys_temp_obs.py`.
Run these in the following order:

```
./gen_obs_prepbufr.sh
```
To extract Rread conventional observation (SFC+UPA) using DART prep_bufr program and generate metadata files and then filter them based on longitude/latitude/pc requirements. Then extract variables from Nature run based on the metadata and generate intermediate files containing synthetic observation information.

Next generate to manually place observation at specific locations and metadata using `sys_temp_obs.py`, first configure `sys_temp_obs.py` to your desired observation locations and metadata. Since our goal is to to simulate observations within the boundary layers, we set pres < 800hpa to 99.99 (this is an indicator for filtering observations which are not useful) for now. Find this block in `extract_wrf_obs_earthwind_ObsError2.py`.
```
if pres_hpa < 800.0:
    tokens[0] = "99.99"
    obs_err_var = float(tokens[0])
```
and uncomment it out.
Then run:
```
./gen_obs_manual.sh
```
This repeat the entire process of gen_obs_prepbufr.sh but only using your own specified locations and meta data.

### inital 3Hr Forecast
Run a 3hr forecast for all the ensembles. Alternatively, you can use the 3hr forecast from the full experiment cycle if you run the ful cycle experiment for all members.
```
./ensemble_fcst_6h.sh
```

### Begin cycling sequence
Lastly run the cycling script to run the ensemble forecast and data assimilation cycle. If you ran the full experiment cycle previously, then you can simply configure `run_cycle.sh` to start from the first 3hr forecast of all the members, if not configure `run_cycle.sh` to start from the output of `ensemble_fcst_6h.sh`.

```
tmux new -s dart_cycle
./run_cycle.sh >& run_cycle.log &
```
Press Ctrl+B, let go, and then press D. This detaches you from the session. You can safely exit the session while the program runs.
To check on it later:
Log back into the cluster and type
```
tmux new -s dart_cycle
```
