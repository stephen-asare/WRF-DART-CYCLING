# Building the Models
This section provides step-by-step instructions for downloading the source code, loading the necessary environment modules, and compiling the atmospheric models required for the experiment.

### Build custom libraries
First we need to build custom PnetCDF, FFTW3, ARPACK-NG, ParMETIS and LAMMPS libraries using RCC system Intel/25, OpenMPI 4.1.0, HDF5 and NetCDF.

Open `rcc_build_stack.sh`, and configure directory for models `MODEL_DIR` (where you want the models to be installed). `rcc_build_stack.sh` will crete the model directory and build the custom libraries.
Run `rcc_build_stack.sh` to build custom libraries.
```bash
nohup ./rcc_build_stack.sh >& compile.log &
```

### Building the Weather Research and Forecasting (WRF) Model
Obtain the WRF-ARW v4.6.1 source code, initialize submodules in the cloning process to ensure all internal dependencies are downloaded. Model directory should be created already from compiling the custom libraries above, simply change directory to that directory
```bash
cd models
mkdir WRF
git clone --branch v4.6.1 --recurse-submodules https://github.com/wrf-model/WRF.git WRF/v4.6.1
cd WRF/v4.6.1
```
Now we configure and compile WRF-ARW v4.6.1 on the FSU RCC HPC environment using the Intel 25 toolchain (ifx/icx), OpenMPI, system NetCDF/HDF5 modules, and the custom PNetCDF installation we just built.

To start, clear active environment modules and load the required compiler, MPI, and library modules.
```bash
module purge
module load intel/25
module load openmpi/4.1.0
module load hdf5/1.10.4
module load netcdf/4.7.0
```
Next, we Export the exact paths for NetCDF, HDF5, and the custom PNetCDF installation along with required feature flags and stack parameters.
```bash
export NETCDF=/opt/rcc/intel/openmpi
export HDF5=/opt/rcc/intel/hdf5-1.10.4
export PNETCDF=/gpfs/home/sa24m/stephen_asare/models_new/NETCDF
export NETCDF4=1
export WRFIO_NETCDF4_FILE_SUPPORT=1
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
export WRF_EM_CORE=1
export WRF_DA_CORE=0
export MP_STACK_SIZE=64000000
export CPPFLAGS="-I$NETCDF/include -I$HDF5/include -I$PNETCDF/include $CPPFLAGS"
export LDFLAGS="-L$NETCDF/lib64 -L$HDF5/lib64 -L$PNETCDF/lib $LDFLAGS"
export LD_LIBRARY_PATH=$NETCDF/lib64:$HDF5/lib64:$PNETCDF/lib:$LD_LIBRARY_PATH
```
To ensure a clean build slate run
```bash
./clean -a
```
Execute the configuration script
```bash
./configure
```
Enter **78** ((dmpar) INTEL (ifx/icx) : oneAPI LLVM) for Compiler Selection and **1** (basic) for Nesting Selection.
Verify that the output summary ends with:
```
*****************************************************************************
This build of WRF will use NETCDF4 with HDF5 compression
*****************************************************************************
```
Compile the em_real dynamical core
```bash
./compile em_real 2>&1 | tee compile.log
```
This may take a while when compilation completes, check the main/ directory for the four required executables.
```bash
ls -l main/*.exe
```
If you see these below, you successfully compiled WRF-ARW
```
wrf.exe 
real.exe
ndown.exe
tc.exe 
``` 
For more on compiling WRF, refer to the official documentation [WRF Compilation tutorials](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/compiling.html) | [WRF Documentation](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php)

---

# Building the WRF Preprocessing System (WPS)
## Purpose
The initial step is to produce the initial and boundary conditions by running the WPS components (`ungrib.exe`, `geogrid.exe`, and `metgrid.exe`). These programs generate the meteorological files required to create the `wrfinput` and `wrfbdy` files initialized at the start date of the experiment.
## Source and Documentation
* NCAR WPS GitHub Repository: https://github.com/wrf-model/WPS
## Download and Compile WPS
Clone the repository into the created directory:
```bash
cd models/
git clone https://github.com/wrf-model/WPS WPS
```
Load the required modules and set environment variables:
```bash
module purge
module load intel/21
```
Export dependent libraries
```
export NETCDF=/gpfs/home/junkyung_ucar_edu/WPSV4.5/NETCDF
export JASPERLIB=/usr/lib64
export JASPERINC=/usr/include/jasper
```
Navigate into the WPS directory and configure:
```bash
cd WPS
./configure
```
You should see the file `configure.wps`.
Select:
```text
17. Linux x86_64, Intel compiler (serial)
```
Compile WPS:
```bash
./compile >& compile.log
ls -ls main/*.exe
```
After successful compilation, the following executables should be present:
```text
geogrid.exe
ungrib.exe
metgrid.exe
```
---

# Building WRF Data Assimilation (WRFDA)
## Purpose
WRFDA is a critical component of the data assimilation workflow. Using the initial and boundary condition files generated for the experiment start time, WRFDA's `randomcv` utility is used to create 40 randomly perturbed ensemble members.
## Source and Documentation
WRFDA is distributed as part of the WRF repository:
* NCAR WRF GitHub Repository: https://github.com/wrf-model/WRF
## Download and Compile WRFDA
Clone the repository:
```bash
git clone --recurse-submodules https://github.com/wrf-model/WRF WRFDA
```
Load the required modules:
```bash
module load intel/21
module load openmpi/4.1.0
module load hdf5/1.10.4
module load netcdf/4.7.0
```
Set the environment variables:
```bash
export WRF_EM_CORE=1
export WRF_DA_CORE=1
export MP_STACK_SIZE=64000000

export NETCDF=/gpfs/home/junkyung_ucar_edu/Build_WRF/NETCDF
export HDF5=/gpfs/home/junkyung_ucar_edu/Build_WRF/HDF5
```
Navigate into the WRFDA directory and configure:
```bash
cd WRFDA
./configure wrfda
```
You should see the file `configure.wrf`.
Select:
```text
15. Intel (dmpar)
```
Compile WRFDA:
```bash
./compile all_wrfvar >& compile.out
ls -ls var/build/*.exe
```
After successful compilation, the WRFDA executables will be available in:
```text
var/build/
```

# Building the Data Assimilation Research Testbed (DART)
**Purpose:** DART is the primary ensemble data assimilation system used to assimilate observations (such as radar or water vapor profiles) into the WRF model state. It interfaces directly with WRF to update the state variables using ensemble Kalman filter techniques.
**Source & Documentation:** [NCAR DART GitHub Repository](https://github.com/NCAR/DART) | [DART Documentation](https://docs.dart.ucar.edu/)
```
cd ../DART
```
Clone the repository:
```bash
git clone --branch v11.21.2 --single-branch https://github.com/NCAR/DART.git v11.21.2
```
Load required modules:
```
module load python/3
module load matlab/2022b
module load precompiled
module load intel/21
module load hdf5/1.10.4
module load mvapich/2.3.5
module load netcdf/4.7.0
```
Update the Makefile Template:Before building, you must update the NetCDF paths in the mkmf.template file specific to your system.Open `build_templates/mkmf.template` and locate the NetCDF definitions.
Change from:
```
NETCDF = /opt/local
LIBS = -L$(NETCDF)/lib -lnetcdff -lnetcdf
```
Change to:
```
NETCDF = /opt/rcc/intel
LIBS = -L$(NETCDF)/lib64 -lnetcdff -lnetcdf
```
Build DART:
```
cd models/wrf/work
./quickbuild.csh
```
Once finished, ensure the filter executable has been generated in your `models/wrf/work directory.`

Now we want to build other DART tools we will require for the experiments `advance_time`, `create_real_obs`, `obs_sequence_tool`, `cword.x`, `grabbufr.x`, `prepbufr_03Z.x` and `prepbufr.x`
```
cd "${DART_DIR}/observations/obs_converters/NCEP/ascii_to_obs/work/
./quickbuild.sh
ls
```
You should see create `create_real_obs` in the directory.
```
cd ${DART_DIR}/models/wrf/work
./quickbuild.sh
ls
```
This should create `advance_time`, `obs_sequence_tool`, `update_wrf_bc`, `obs_seq_to_netcdf`, `pert_wrf_bc` `obs_diag`, `create_obs_sequence` and the other tools we will require.

Lastly
```
cd "${DART_DIR}/observations/obs_converters/NCEP/prep_bufr/
./install.sh
ls exe/
```
This should display `cword.x`, `grabbufr.x`, `prepbufr_03Z.x` and `prepbufr.x`



<!-- # Compiling METplus
**NB** Installing MET can be skipped for now since its not used in the current experiment.
Create new directory to install package: 
```
mkdir models/MET/v12.1.1
```
Download the compile_MET_all.sh script and tar_files.tgz file and place both of these files in the new directory. 
```
wget https://raw.githubusercontent.com/dtcenter/MET/main_v12.1/internal/scripts/installation/compile_MET_all.sh
wget https://dtcenter.ucar.edu/dfiles/code/METplus/MET/installation/tar_files.tgz
```
The tar files will need to be extracted in the MET installation directory:
```
tar -zxf tar_files.tgz
chmod 775 compile_MET_all.sh
```
Now change directories to the one that was created from expanding the tar files:
```
cd tar_files
```
Identify and download the latest MET release as a tar file 
```
wget https://github.com/dtcenter/MET/archive/refs/tags/v12.1.1.tar.gz
```
Create Environmental variable description
```
touch install_met_env.rcc
```
Copy everything below and paste in newly created file and save
```
module load intel/21

# Find the directory this script is called from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Required
# Directory that is the root of the compile
export TEST_BASE=${DIR}

# Required
# Format is compiler_version (e.g. gnu_8.3.0)
# Compiler options = gnu, intel, ics, ips, PrgEnv-intel, or pgi
# Version is used for gnu in compilation of BUFRLIB and HDF5
export COMPILER=intel/21

# Set the values for the compilers
export FC=ifort
export F77=ifort
export F90=ifort
export CC=icc
export CXX=icpc

# Required
# Root directory for creating/untaring met source code - usually same as TEST_BASE
export MET_SUBDIR=${TEST_BASE}

# Required
# The name of the met tarbal usually downloaded with version from dtcenter.org and includes a version
#  example - v11.1.0.tar.gz
export MET_TARBALL=v12.1.1.tar.gz

# Required
# Specify if machine useds modules for loading software
export USE_MODULES=True

# Root directory of your python install, containing the bin, include, lib, and share directories
# export MET_PYTHON=`python3-config --prefix`
export MET_PYTHON="/gpfs/research/software/python/anaconda38"

# Python ldflags created using python3-config
# export MET_PYTHON_LD=`python3-config --ldflags --embed`
export MET_PYTHON_LD="-L/gpfs/research/software/python/anaconda38/lib -lpython3.8 -lpthread -ldl -lutil -lm -lcrypt"

# Python cflags created using python3-config
# export MET_PYTHON_CC=`python3-config --cflags`
export MET_PYTHON_CC="-I/gpfs/research/software/python/anaconda38/include/python3.8"

# Use MAKE_ARGS to sped up the compilation of the external libaries and/or MET
# MAKE_ARGS can be set "-j #" where # is replaced with the number of
# cores to use (as an integer) or to simply "-j" to use all available cores.
# Recommend setting to "-j 5" as some users have experienced problems with
# higher values or no # specified.
export MAKE_ARGS="-j 5"

# If users have already installed these libraries and would like to make use of
# them, uncomment out the export statements. If those pre-existing libraries are
# in the external_libs directory, no further edits are needed; however, users
# that have the pre-existing libraries not in the external_libs directory will
# need to update the paths to the appropriate location.
#export EXTERNAL_LIBS=${TEST_BASE}/external_libs
#export MET_PROJ=${EXTERNAL_LIBS}
#export TIFF_INCLUDE_DIR=${EXTERNAL_LIBS}/include
#export TIFF_LIB_DIR=${EXTERNAL_LIBS}/lib
#export SQLITE_INCLUDE_DIR=${EXTERNAL_LIBS}/include
#export SQLITE_LIB_DIR=${EXTERNAL_LIBS}/lib
#export MET_GSL=${EXTERNAL_LIBS}
#export MET_BUFRLIB=${EXTERNAL_LIBS}/lib
#export BUFRLIB_NAME=-lbufr_4
#export LIB_JASPER=${EXTERNAL_LIBS}/lib
#export LIB_LIBPNG=${EXTERNAL_LIBS}/lib
#export LIB_Z=${EXTERNAL_LIBS}/lib
#export MET_GRIB2CLIB=${EXTERNAL_LIBS}/lib
#export MET_GRIB2CINC=${EXTERNAL_LIBS}/include
#export GRIB2CLIB_NAME=-lg2c
#export MET_HDF5=${EXTERNAL_LIBS}
#export MET_NETCDF=${EXTERNAL_LIBS}
#export MET_ECKIT==${EXTERNAL_LIBS}
#export MET_ATLAS==${EXTERNAL_LIBS}

# The optional libraries ecKit and atlas offer support for unstructured
# grids. The optional libraries HDF4, HDFEOS, FREETYPE, and CAIRO are
# used for the following, not widely used tools, MODIS-Regrid,
# lidar2nc, and MODE Graphics. To enable building of these libraries,
# set the compile flags for the library (e.g. COMPILE_ECKIT, COMPILE_ATLAS,
# COMPILE_HDF, COMPILE_HDFEOS) to any value in the environment config
# file. If these libraries have already been installed and don't need
# to be reinstalled, please supply values for the following environment
# variables in the input environment configuration file
# (install_met_env.<machine_name>): MET_ECKIT, MET_ATLAS, MET_HDF,
# MET_HDFEOS, MET_FREETYPEINC, MET_FREETYPELIB, MET_CAIROINC,
# MET_CAIROLIB.

```
Load modules
```
Module restore (normally already  saved all modules I use)
Compile 
./compile_MET_all.sh install_met_env.rcc
```
Check if compiled successfully
```
ls
```
```
MET-12.1.1  bin  compile_MET_all.sh  external_libs  install_met_env.hera  share  tar_files
```
To confirm that MET was installed successfully, run the following command from the installation directory to check for errors in the test file:
```
grep -i error MET-12.1.0/met.make_test.log
```
If no errors are returned, the installation was successful
Add to environmental variable
```
echo 'export MET_INSTALL_DIR="/gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1"' >> ~/.bashrc
echo 'export PATH="$MET_INSTALL_DIR/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
 -->
