# Building the Software
This section provides step-by-step instructions for downloading the source code, loading the necessary environment modules, and compiling the atmospheric models required for the experiment.

### Build custom libraries
First we need to build custom PnetCDF, FFTW3, ARPACK-NG, ParMETIS and LAMMPS libraries using RCC system Intel/25, OpenMPI 4.1.0, HDF5 and NetCDF. \
Open `rcc_build_stack.sh`, and configure directory for software `SOFTWARE_DIR` (where you want the models to be installed). The script `rcc_build_stack.sh` will create the model directory and build the custom libraries.
Run `rcc_build_stack.sh` to build custom libraries.
```bash
nohup ./rcc_build_stack.sh >& compile.log &
```
Verify the log file to ensure the libraries successfully completed.

---

### Building the Weather Research and Forecasting (WRF) Model
Obtain the WRF-ARW v4.6.1 source code, initialize submodules in the cloning process to ensure all internal dependencies are downloaded. Model directory should be created already from compiling the custom libraries above, simply change directory to that directory. If you already libraries, PnetCDF, FFTW3, ARPACK-NG, ParMETIS and LAMMPS without using `rcc_build_stack.sh` above, simply create a directory $SOFTWARE_DIR where all the models will be compiled.
```bash
cd $SOFTWARE_DIR
mkdir WRF
git clone --branch v4.6.1 --recurse-submodules https://github.com/wrf-model/WRF.git WRF/v4.6.1
cd WRF/v4.6.1
```
Now we configure and compile WRF-ARW v4.6.1 on the FSU RCC HPC environment using the Intel 25 toolchain (ifx/icx), OpenMPI, system NetCDF/HDF5 modules, and the custom PNetCDF installation we just built.\\
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
```text
*****************************************************************************
This build of WRF will use NETCDF4 with HDF5 compression
*****************************************************************************
```
Compile the em_real dynamical core
```bash
./compile em_real 2>&1 | tee compile.log &
```
This may take a while, when compilation completes, check the main/ directory for the four required executables.
```bash
ls -l main/*.exe
```
If you see these below, you successfully compiled WRF-ARW
```text
wrf.exe 
real.exe
ndown.exe
tc.exe 
``` 
For more on compiling WRF, refer to the official documentation [WRF Compilation tutorials](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/compiling.html) | [WRF Documentation](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php)

---


### Building WRF Data Assimilation (WRFDA)
WRFDA is a critical component of the data assimilation workflow. Using the initial and boundary condition files generated for the experiment start time, we intend to use WRFDA's `randomcv` utility to create randomly perturbed ensemble members. WRFDA is distributed as part of the WRF repository: NCAR WRF GitHub Repository: [WRF-ARW](https://github.com/wrf-model/WRF). \
Download and Compile WRFDA \
Clone the repository:
```bash
cd $SOFTWARE_DIR
mkdir WRFDA
git clone --branch v4.6.1 --recurse-submodules https://github.com/wrf-model/WRF.git WRFDA/v4.6.1
cd WRFDA/v4.6.1
```
Load the required modules:
```bash
module purge
module load intel/25
module load openmpi/4.1.0
module load hdf5/1.10.4
module load netcdf/4.7.0
```
Set the environment variables:
```bash
export NETCDF=/opt/rcc/intel/openmpi
export HDF5=/opt/rcc/intel/hdf5-1.10.4
export PNETCDF=../..//NETCDF
export NETCDF4=1
export WRFIO_NETCDF4_FILE_SUPPORT=1
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
export WRF_EM_CORE=1
export WRF_DA_CORE=1
export MP_STACK_SIZE=64000000
export CPPFLAGS="-I$NETCDF/include -I$HDF5/include -I$PNETCDF/include $CPPFLAGS"
export LDFLAGS="-L$NETCDF/lib64 -L$HDF5/lib64 -L$PNETCDF/lib $LDFLAGS"
export LD_LIBRARY_PATH=$NETCDF/lib64:$HDF5/lib64:$PNETCDF/lib:$LD_LIBRARY_PATH
```
Navigate into the WRFDA directory and configure:
```bash
./configure wrfda
```
You should see the file `configure.wrf`. \
Enter **78** ((`dmpar`) `INTEL` (`ifx/icx`) : `oneAPI LLVM`) for Compiler Selection and **1** (basic) for Nesting Selection.\
Specifically search for the `SCC`, `CCOMP`, and `DM_CC` compiler definitions in configure.wrf and append the bypass flags to them.
```bash
sed -i '/^SCC/ s/icx/icx -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wrf
sed -i '/^CCOMP/ s/icx/icx -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wrf
sed -i '/^DM_CC/ s/mpicc/mpicc -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wrf
```
Compile WRFDA:
```bash
./compile all_wrfvar >& compile.out &
```
After successful compilation, the WRFDA executables we need will be available list them below
```bash
ls -ls var/build/*.exe
```
Check that the following executables are available:
```text
da_advance_time.exe
da_wrfvar.exe
da_update_bc
```
**NB** If you do not see `da_update_bc`, yet `da_advance_time.exe` and `da_wrfvar.exe` is available, do not need to clean the build, just patch the file the NetCDF libraries directly into `LIB_EXTERNAL` in the config file and Fire off the compilation again.
```
sed -i 's|-lwrfio_nf|-lwrfio_nf -L/opt/rcc/intel/openmpi/lib64 -lnetcdff -lnetcdf|g' configure.wrf
./compile all_wrfvar >& compile.out &
```
Once the compilations complete, run `ls -l var/build/*.exe` again, `da_update_bc.exe` and the remaining `gen_be` tools will successfully generate alongside `da_wrfvar.exe`

---

### Building the WRF Preprocessing System (WPS)
WPS components `ungrib.exe`, `geogrid.exe`, and `metgrid.exe` are required to produce the initial and boundary conditions. These programs generate the meteorological files required to create the `wrfinput` and `wrfbdy` files initialized at the start date of the experiment. \
Clone WPS into the $SOFTWARE_DIR directory.
```bash
cd $SOFTWARE_DIR
mkdir WPS && cd WPS
git clone --branch v4.7.0 --single-branch https://github.com/wrf-model/WPS.git v4.7.0
cd v4.7.0
```
You can check the tag to be sure you have the correct version.
```bash
git describe --tags --exact-match
```
This should display
```text
v4.7.0
```
Load the Environment Modules. \
Load the required compiler, MPI, and dependency modules for the build environment:
```bash
module load intel/25 openmpi/4.1.0 hdf5/1.10.4 netcdf/4.7.0
```
Export Dependent Libraries. \
Set the environment variables so the configuration script knows where to look for NetCDF, HDF5, and compression libraries, and specify the new Intel LLVM compiler wrappers (ifx/icx):
```bash
export NETCDF=/opt/rcc/intel/openmpi
export HDF5=/opt/rcc/intel/hdf5-1.10.4
export JASPERLIB=/usr/lib64
export JASPERINC=/usr/include/jasper
export WRF_DIR=../../WRF/v4.6.1
export OMPI_FC=ifx
export OMPI_CC=icx
export OMPI_CXX=icpx
```
Clean the Environment and Patch the Configuration Defaults. \
Ensure the workspace is clean. NB: WPS does not have a built-in option for the newer ifx/icx compilers, so we must change the compilers in WPS's "blueprint" file to replace the old mpicx wrappers with mpicc before running the configuration script.
```bash
./clean -a
sed -i 's/mpicx/mpicc/g' arch/configure.defaults
```
Configure WPS
Run the configuration script to generate configure.wps:
```bash
./configure
```
Choose **19**, Linux x86_64, Intel compiler (dmpar) Note: Option **19** natively hardcodes the older Intel compilers (ifort and icc). However, the Intel/25 module completely dropped those older compilers in favor of the newer oneAPI LLVM compilers (ifx and icx).

Patch Compiler Warnings and Linker Paths \
Because we are using newer LLVM compilers, several strict C standards and library structures need to be patched in the generated configure.wps file.
Suppress strict C compiler errors that would otherwise halt the compilation of older WPS C-routines:
```bash
sed -i 's/^SCC.*/& -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wps
sed -i 's/^CCOMP.*/& -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wps
sed -i 's/^DM_CC.*/& -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion/' configure.wps
```
Fix the NetCDF library path (modern NetCDF installs into lib64 instead of lib):
```bash
sed -i 's|-L$(NETCDF)/lib|-L$(NETCDF)/lib64|g' configure.wps
```
Explicitly link the NetCDF-Fortran (-lnetcdff) library, as well as its underlying dependencies (parallel HDF5 and Zlib) to avoid undefined reference to H5P... errors:
```bash
sed -i 's|-lnetcdf|-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lm -lz|g' configure.wps
```
Prevent Environment Interference and Compile.  \
The openmpi module exports an environment variable named MPI_LIB as a raw directory path (/opt/rcc/intel/openmpi/lib64). Because the Makefile imports environment variables, the linker mistakenly reads this raw path as a file, causing a ld: read in flex scanner failed error. We must unset it.
```bash
unset MPI_LIB
```
Finally, execute the compilation script and log the output:
```bash
./compile 2>&1 | tee compile_wps.log
```
Check for `geogrid.exe`, `metgrid.exe` and `ungrib.exe`.
```bash
ls -ls *.exe
```

### Building the Data Assimilation Research Testbed (DART)
**Purpose:** DART is the primary ensemble data assimilation system used to assimilate observations (such as radar or water vapor profiles) into the WRF model state. It interfaces directly with WRF to update the state variables using ensemble Kalman filter techniques.
**Source & Documentation:** [NCAR DART GitHub Repository](https://github.com/NCAR/DART) | [DART Documentation](https://docs.dart.ucar.edu/)
```bash
cd $SOFTWARE_DIR
mkdir DART && cd DART
```
Clone the repository:
```bash
git clone --branch v11.21.2 --single-branch https://github.com/NCAR/DART.git v11.21.2
cd v11.21.2
```
Load required modules:
```bash
module load intel/25 
module load precompiled
module load hdf5/1.10.4
module load netcdf/4.7.0
module load mvapich/2.3.7
module load matlab/2022b
module load python/3
```
Change directory to `build_templates`. \
Copy the ifx template to the default name DART looks for:
```Bash
cp mkmf.template.ifx.linux mkmf.template
```
Now Update the Makefile Template. \
Use you favorite editor to open the `mkmf.template` file. Update the NetCDF paths in the mkmf.template file specific to RCC system. \
Change from:
```bash
# NETCDF = /opt/local
LIBS = -L$(NETCDF)/lib -lnetcdff -lnetcdf
```
Change to:
```bash
NETCDF = /opt/rcc/intel
LIBS = -L$(NETCDF)/lib64 -lnetcdff -lnetcdf
```
Build DART:
```bash
cd $SOFTWARE_DIR/DART/v11.21.2/models/wrf/work
./quickbuild.csh
```
Once finished, this should create `filter`, `advance_time`, `obs_sequence_tool`, `update_wrf_bc`, `obs_seq_to_netcdf`, `pert_wrf_bc` `obs_diag` and `create_obs_sequence` in the directory.

Now we want to build other DART tools we will require for the experiments `create_real_obs`, `cword.x`, `grabbufr.x`, `prepbufr_03Z.x` and `prepbufr.x`
```bash
cd "$SOFTWARE_DIR/DART/v11.21.2/observations/obs_converters/NCEP/ascii_to_obs/work/"
./quickbuild.sh
ls
```
You should see create `create_real_obs` and `prepbufr_to_obs` in the directory. \
Lastly, we build the observation pre-processing tools for bufr files
```bash
cd $SOFTWARE_DIR/DART/v11.21.2/observations/obs_converters/NCEP/prep_bufr/
```
Replace `icc` and `ifort`with icx and ifx along with flags.
```bash
sed -i 's/cc=icx/cc="icx -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion"/g' install.sh
sed -i 's/ff=ifort/ff=ifx/g' install.sh
```
Execute installation.
```bash
CCOMP=intel FCOMP=intel ./install.sh
```
```bash
ls exe/
```
This should display `cword.x`, `grabbufr.x`, `prepbufr_03Z.x` and `prepbufr.x`

---


<!-- 
# Compiling METplus
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
``` -->

