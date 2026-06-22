# Data Download
## Downloading ERA5 Reanalysis
This project uses the 4th generation atmospheric reanalyses from the European Centre for Medium-Range Weather Forecasts (ECMWF) to produce Initial and Lateral Boundary Conditions (IC/BC). You will run the WPS executables (ungrib.exe, geogrid.exe, and metgrid.exe) initialized at the start date of the experiment.Download ECMWF DataIf you have not already downloaded the data, use the provided download.sh and download2.sh scripts, or use the CDS API via Python as shown below.Create a Conda environment and install the CDS API client:
In `osse` directory in scrath space create sub directory ERA5.

```
mkdir scratch/osse/ERA5
```
```
source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
conda create -n python311_env python=3.11 -y
conda activate python311_env
conda install cdsapi -y
```
**Important**: Before running the Python scripts below, modify `era_api_new_pl.py` and `era_api_new_sf.py` to save the data in the `ERA5` directory created above.
Download the ERA5 data:
```
python era_api_new_pl.py
python era_api_new_sf.py
```
Deactivate the environment:
```
conda deactivate
```

## Downloading WPS data
We require a mandatory and optional static data for wrf to run. More information on the static data can be found in [
WRF Preprocessing System (WPS) Geographical Input Data Mandatory Fields Downloads]{https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html}


## Downloading Real Observations
We intend on generating synthetic observations from a nature run, but then, we will exatract observation location and meta data from real observations.Additionally, we will use this real observation to match all the ensembles and select an appropraite nature run, which will be the member which closely matches the real observation in terms of evolution of the system.
`download_ncep.sh`, is a simple script for downloading NCEP PREPBUFR observation datasets from the NCAR GDEX archive. 
Create a prebufr directory in `scratch/osse/prepbufur
```
mkdir scratch/osse/prepbufr
```
Copy `download_prepbufr.sh` into this newly created folder and run to download data.
```
./download_prepbufr.sh
```
The script downloads the PREPBUFR archives into the current directory.

Extracting the Files

After downloading, extract the archives using:
```
tar -xvzf prepbufr.20150713.nr.tar.gz
tar -xvzf prepbufr.20150714.nr.tar.gz
tar -xvzf prepbufr.20150715.nr.tar.gz
```
You should find these folders below if the script executed appropraitely.
```
20150713.nr
20150714.nr
20150715.nr
```
For easier assess to the 6 hourly files move all the files into a single subdirectory.
```
mkdir bufr_data
mv 201507*/* bufr_data/
```
