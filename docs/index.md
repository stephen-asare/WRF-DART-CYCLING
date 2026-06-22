# Introduction and Experiment Overview

This documentation details the methods, implementations, and techniques required to execute the WRF-DART Cycling workflow. It provides a comprehensive guide for performing an Observation System Simulation Experiment (OSSE) using advanced data assimilation.

---

## Experiment Summary

* **Objective:** Assimilation of water vapor profiles (or synthetic/real NCEP BUFR observations).
* **Timeframe:** July 14, 12:00 UTC to July 15, 12:00 UTC.
* **Reference Literature:** Reproduces the ensemble cycle assimilation methodology described by Junkyung et al., 2022.
* **Ensemble Size:** Utilizes `randomcv` from WRFDA to generate 40 randomly perturbed ensemble members.

---

## Technical Prerequisites

The project is organized into several files where a primary driver script executes sub-level scripts to complete specific tasks. Required technical competencies and environments include:

* **Scripting:** Proficiency in Shell scripting (bash/ksh) and Python for driver execution and data acquisition.
* **Compilers:** Access to Intel Compilers to compile WPS, WRF, and WRFDA from source.
* **Environment Management:** A Conda environment configured to install and run the ERA5 API client.
* **Job Scheduling:** Configuration of parameter files (e.g., `param.sh`) to align with device and scheduler requirements.

---

## Data Sources

The workflow dynamically downscales global reanalysis data to generate Initial and Lateral Boundary Conditions (IC/BCs).

* **Atmospheric Reanalysis:** 4th generation atmospheric reanalyses (ERA5) produced by the European Centre for Medium-Range Weather Forecasts (ECMWF).
* **Data Acquisition:** Automated retrieval using the provided Python scripts (`download_era_5_pl.py` and `download_era_5_sf.py`).

---

## Hardware & Storage Requirements

Executing a 40-member WRF-DART ensemble cycle is computationally demanding. Baseline recommendations include:

* **Storage Space:** At least **2 to 5 Terabytes (TB)** of high-speed scratch storage. WRF input, boundary, and output files for 40 ensemble members over multiple cycles will consume storage rapidly.
* **Compute (CPU):** A high-performance cluster with at least **128 to 256 cores** for parallel processing (MPI) during the ensemble forecasts and DART assimilation steps.
* **Memory (RAM):** A minimum of **4 to 8 GB of RAM per core**, depending on your domain's grid spacing and vertical levels. 

> **Note:** These are baseline estimates. Actual resource consumption will scale heavily based on specific `namelist.input` configurations, domain resolution, and the frequency of cycling intervals.

