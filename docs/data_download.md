# Data Download
## Downloading ERA5 Reanalysis
This project uses the 4th generation atmospheric reanalyses from the European Centre for Medium-Range Weather Forecasts (ECMWF) to produce Initial and Lateral Boundary Conditions (IC/BC). You will run the WPS executables (ungrib.exe, geogrid.exe, and metgrid.exe) initialized at the start date of the experiment.Download ECMWF DataIf you have not already downloaded the data, use the provided download.sh and download2.sh scripts, or use the CDS API via Python as shown below.Create a Conda environment and install the CDS API client:

```
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda create -n python311_env python=3.11 -y
conda activate python311_env
conda install cdsapi -y
```
**Important**: Before running the Python scripts below, modify the param file to appropraitely store the downloaded files.
```
python3 era_api_new_pl.py
python3 era_api_new_sf.py
```
Deactivate the environment:
```
conda deactivate
```

## Downloading WPS data
We require a mandatory and optional static data for wrf to run. More information on the static data can be found in [WRF Preprocessing System (WPS) Geographical Input Data Mandatory Fields Downloads]{https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html}

**NB** Create a directory for WPS geographic data and download the all static data into, then configure the `param.sh` to the directory created.

## Downloading Real Observations
We intend on generating synthetic observations from a nature run, but then, we will exatract observation location and meta data from real observations.Additionally, we will use this real observation to match all the ensembles and select an appropraite nature run, which will be the member which closely matches the real observation in terms of evolution of the system.
`download_prepbufr.sh`, is a simple script for downloading NCEP PREPBUFR observation datasets from the NCAR GDEX archive. 

Ran `download_prepbufr.sh` this should create the directory and store the prebufr files. 
```
./download_prepbufr.sh
```
The prebufr files should be downloaded and extracted in set "`
You should find these folders below if the script executed appropraitely.
```
20150713.nr
20150714.nr
20150715.nr
```
For easier assess to the 6 hourly files move all the files into a single subdirectory.
```
cd ${PREPBUFR_DATA_DIR}
mkdir bufr_data
mv 201507*/* bufr_data/
```
