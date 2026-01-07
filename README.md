# Assimilating Radar Observation using WRF-DART Cycling
This repository details a sample workflow to perform an Observation System Simulation Experiment on the assimilation of water vapor profiles from the 14th of July 12UTC to the 15 July 12UTC produced by Junkyung et. al 2022. The initial steps describes how to compile the modules and set up enviromental variables and the subsequent instructions details an ensemble cycle assimilation produced in Junkyung et. al 2022. It provides a step by step and a thorough description on the methods, implementations and techniques used. The project is organized into several files for each implementation where for each each implementation theres a driver script  that runs sublevel scripts to complete specific tasks.

## Dynamically downcalling ERA5 reaanalysis to produce Initial and Lateral boundary conditions.
The project makes use of the 4th generation atmospheric reanalyses produced by the European Center for Medium Range and Weather Forecasting. The initial steps is therefore to produce the initial boundary conditions by running WPS (ungrib.exe, geogrid.exe and metgrid.exe) to produce the wrfinput and wrfbdy files initialized at the start date of the experiment. If required you ay need to download the the data as below;
Use the script `download.sh` and `download2.sh` to download ECMWF data.
Configure file 'wrapper_EaKF.ksh` to specify environmental variables and experiment configuration.Downscele the downloaded European Centre for Medium-Range Weather Forecasts (ECMWF) fifth-generation climate reanalysis (ERA5) using WPS preproceessing tools by setting it in wrapper_EaKf.ksh eg. export **RUN_GEOGRID=true**, export **RUN_WPS=true**, **RUN_REAL_FC=true** (ungrib.exe, geogrid.exe, metgrid.exe). Its advisable to perform every step on at a time.

Begin with **RUN_WPS=true** to run `geogrid.exe` which process static geographic data and generate grid definitions for WRF model domains, this also runs `ungrib.exe` which decodes GRIB (GRidded Information in Binary) format meteorological data files and converting them into WPS intermediate format. This intermediate format is then consumed by `metgrid.exe` for interpolation to model grids.



### Prepare experiment directory
You may need approximately 5TB of space to run the full scale project. If you have limited space, best practices will be to reduce the ensemble memebrs together with removing temprory files after each run.

#### Configure the param file and generate boundary conditions
Edit the paramenter file to meet device and scheduler requirements, along with directory paths the run `gen_icbc.sh` to generate **IC** and **BC** files. 
```
./gen_icbc.sh
```
### Generate Perturbed Ensembles
Using the produced IC and BC file for the initial date of the experiment, I will use randomcv from WRFDA to produced 40 randomly perturbed ensembles. 

