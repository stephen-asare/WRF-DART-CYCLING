# Assimilating Radar Observation using WRF-DART Cycling
This repository details a sample workflow to perform an Observation System Simulation Experiment on the assimilation of water vapor profiles from the 14th of July 12UTC to the 15 July 12UTC produced by Junkyung et. al 2022. The initial steps describes how to compile the modules and set up enviromental variables and the subsequent instructions details an ensemble cycle assimilation produced in Junkyung et. al 2022. It provides a step by step and a thorough description on the methods, implementations and techniques used. The project is organized into several files for each implementation where for each each implementation theres a driver script  that runs sublevel scripts to complete specific tasks.

# Prerequisites
The project is makes use of the folloWing libraries and modules and the instructions to compile them are below.
### Environmental Modules and Dependency Stack Build Process
1.1 HDF5 (serial build for NetCDF)
```
cd /gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1/external_libs/hdf5
wget https://www.hdfgroup.org/package/hdf5-1-12-2-tar-gz/?wpdmdl=14570 -O hdf5-1.12.2.tar.gz
tar -xzf hdf5-1.12.2.tar.gz
cd hdf5-1.12.2

./configure --prefix=$(pwd)/install --enable-fortran --enable-hl --enable-static=yes \
CC=icc FC=ifort F77=ifort
make -j8
make install
```
### 1.2 NetCDF-C

```bash
cd /gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1/external_libs/netcdf
wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.4.tar.gz
tar -xzf v4.7.4.tar.gz
cd netcdf-c-4.7.4

CPPFLAGS="-I../hdf5/hdf5-1.12.2/install/include" \
LDFLAGS="-L../hdf5/hdf5-1.12.2/install/lib" \
./configure --prefix=$(pwd)/install --disable-dap --enable-static=yes --disable-shared \
CC=icc
make -j8
make install
```

The static library was installed under:

```
liblib/.libs/libnetcdf.a
```

I had to create a **dummy subdirectory** `liblib/.libs/` because MET/UPP build systems expected this layout.

```bash
mkdir -p netcdf-c-4.7.4/liblib/.libs
cp install/lib/libnetcdf.a netcdf-c-4.7.4/liblib/.libs/
```

---

### 1.3 NetCDF-Fortran

```bash
cd /gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1/external_libs/lib
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.5.3.tar.gz
tar -xzf v4.5.3.tar.gz
cd netcdf-fortran-4.5.3

CPPFLAGS="-I../../netcdf/netcdf-c-4.7.4/install/include" \
LDFLAGS="-L../../netcdf/netcdf-c-4.7.4/install/lib" \
./configure --prefix=$(pwd)/install --disable-shared --enable-static=yes CC=icc FC=ifort
make -j8
make install
```

---

### 1.4 Zlib

```bash
cd /gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1/external_libs/zlib
wget https://zlib.net/fossils/zlib-1.2.11.tar.gz
tar -xzf zlib-1.2.11.tar.gz
cd zlib-1.2.11
CC=icc ./configure --static --prefix=$(pwd)/install
make -j8
make install
```

---

### 1.5 libpng

```bash
cd /gpfs/research/chipilskigroup/stephen_asare/models/WPS/V4.6.0/wrf_install
wget https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz
tar -xzf libpng-1.6.37.tar.gz
cd libpng-1.6.37
CC=icc ./configure --prefix=$(pwd)/install --disable-shared --enable-static=yes --with-zlib-prefix=../../MET/v12.1.1/external_libs/zlib/zlib-1.2.11
make -j8
make install
```

---

### 1.6 JasPer

```bash
cd /gpfs/research/chipilskigroup/stephen_asare/models/MET/v12.1.1/external_libs
wget https://github.com/jasper-software/jasper/archive/refs/tags/version-4.2.8.tar.gz -O jasper-4.2.8.tar.gz
tar -xzf jasper-4.2.8.tar.gz
mkdir jasper-4.2.8_build
cd jasper-4.2.8_build
cmake ../jasper-version-4.2.8 -DCMAKE_INSTALL_PREFIX=$(pwd)/install -DJAS_ENABLE_SHARED=OFF -DJAS_ENABLE_DOC=OFF -DJAS_ENABLE_PROGRAMS=OFF
make -j8
make install
```



### The Advanced Research WRF (ARW)
- Compiling the required libraries, modules and software used
  
