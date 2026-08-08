#!/bin/bash
# ==============================================================================
# RCC HPC External Libraries Compilation Script
# Author: Stephen Asare
# Institution: Florida State University - Dept. of Scientific Computing
# Description: Custom HPC stack compilation for external libraries needed for WRF-ARW / DART and other models.
# Date: August 2026
#
# Libraries Built: PnetCDF, FFTW3, ARPACK-NG, ParMETIS, LAMMPS
# Toolchain: Intel 25 / OpenMPI 4.1.0 / hdf5/1.10.4 / netcdf/4.7.0
# ==============================================================================

set -e

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
module purge
module load intel/25
module load openmpi/4.1.0
module load hdf5/1.10.4
module load netcdf/4.7.0

echo "Setting installation paths"
echo ""
export MODEL_DIR="/gpfs/home/sa24m/stephen_asare/models"     #set this when appropriately.
export PREFIX=$MODEL_DIR/NETCDF
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# Force standard MPI wrappers to ensure Intel underlying compilers are used
export CC=mpicc
export CXX=mpicxx
export FC=mpifort
export F77=mpifort

# Create build workspace
mkdir -p $MODEL_DIR/NETCDF
mkdir -p $MODEL_DIR/builds
echo "NETCDF Path: $PREFIX"
echo "Build Path: $MODEL_DIR/builds"

cd $MODEL_DIR/builds

# ==============================================================================
# PNETCDF (v1.15.0) 
# ==============================================================================
echo "Building PnetCDF"
wget https://parallel-netcdf.github.io/Release/pnetcdf-1.15.0.tar.gz
tar -xzf pnetcdf-1.15.0.tar.gz
cd pnetcdf-1.15.0

export MPICC=mpicc
export MPICXX=mpicxx
export MPIFC=mpifort
export MPIF77=mpifort

export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
export FCFLAGS="-fPIC"
export FFLAGS="-fPIC"

./configure --prefix=$PREFIX --disable-shared --enable-fortran
make -j 16
make install
cd ..

# ==============================================================================
# FFTW3 (v3.3.10)
# ==============================================================================
echo "Building FFTW3"
wget http://www.fftw.org/fftw-3.3.10.tar.gz
tar -xzf fftw-3.3.10.tar.gz
cd fftw-3.3.10

# Build 1: Double Precision (libfftw3_mpi.so)
./configure --prefix=$PREFIX --enable-mpi --enable-shared
make -j 16
make install

# Clean environment before switching precision
make clean

# Build 2: Single Precision (libfftw3f_mpi.so)
./configure --prefix=$PREFIX --enable-mpi --enable-shared --enable-float
make -j 16
make install
cd ..

# ==============================================================================
# ARPACK-NG (v3.9.1)
# ==============================================================================
echo "Building ARPACK-NG"
wget https://github.com/opencollab/arpack-ng/archive/refs/tags/3.9.1.tar.gz -O arpack-ng-3.9.1.tar.gz
tar -xzf arpack-ng-3.9.1.tar.gz
cd arpack-ng-3.9.1

# Generate configure script from raw source
sh bootstrap

# Configure to build both libarpack.so and libparpack.so
./configure --prefix=$PREFIX --enable-mpi --enable-shared
make -j 16
make install
cd ..

# ==============================================================================
# PARMETIS (v4.0.3)
# ==============================================================================
echo "Building ParMETIS"
wget https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/parmetis/4.0.3-4/parmetis_4.0.3.orig.tar.gz -O parmetis-4.0.3.tar.gz
tar -xzf parmetis-4.0.3.tar.gz
cd parmetis-4.0.3

# ParMETIS uses a custom wrapper around CMake
make config shared=1 prefix=$PREFIX cc=mpicc cxx=mpicxx
make -j 16
make install
cd ..

# ==============================================================================
# 6. LAMMPS (stable_2Aug2023_update3)
# ==============================================================================
echo "Building LAMMPS..."
wget https://github.com/lammps/lammps/archive/refs/tags/stable_2Aug2023_update3.tar.gz -O lammps.tar.gz
tar -xzf lammps.tar.gz
cd lammps-stable_2Aug2023_update3

mkdir build
cd build

# CMake configuration for shared library with Intel MPI
cmake ../cmake \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DBUILD_SHARED_LIBS=ON \
    -DPKG_MPI=ON \
    -DCMAKE_C_COMPILER=mpicc \
    -DCMAKE_CXX_COMPILER=mpicxx \
    -DCMAKE_Fortran_COMPILER=mpifort

make -j 16
make install
cd ../..

echo "=============================================================================="
echo "Compilation Complete.
echo "$PREFIX"
echo "=============================================================================="