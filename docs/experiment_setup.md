# Experimental Setup

The experiment simulates and assimilates atmospheric data over a multi-day period using a nested domain setup. 

### Time Configuration
*   **Initial Date:** July 13, 2015, 00:00 UTC
*   **Final Date:** July 15, 2015, 12:00 UTC
*   **Spin-up Time:** 6 hours

### Domain & Grid Specifications
The model utilizes a Lambert Conformal projection centered at 39.0°N, -101.0°W (true latitudes: 32.0° and 46.0°). While parameters for a third domain exist in the configuration, the run is explicitly restricted to two active domains (`MAX_DOM=2`) with 51 vertical levels and a model top of 1500 Pa.

| Attribute | Domain 1 (Parent) | Domain 2 (Nest) |
| :--- | :--- | :--- |
| **Grid Dimensions (W-E x S-N)** | 212 x 160 | 411 x 321 |
| **Grid Spacing** | 15 km | 3 km |
| **Time Step** | 30 seconds | Configured by ratio |
| **Geographic Data** | MODIS 30s | MODIS 30s |

<p align="center">
  <img src="images/img.png" alt="Project Image" width="700">
</p>

### Physics Options
The simulation relies on the following parameterization schemes across both domains:
*   **Microphysics:** Thompson (`mp_physics = 8`)
*   **Radiation (LW/SW):** RRTMG (`ra_lw_physics = 4`, `ra_sw_physics = 4`)
*   **Surface Layer:** Eta similarity (`sf_sfclay_physics = 2`)
*   **Land Surface:** Noah Land Surface Model (`sf_surface_physics = 2`) with 4 soil layers
*   **Planetary Boundary Layer:** Mellor-Yamada-Janjic (MYJ) (`bl_pbl_physics = 2`)
*   **Cumulus:** Kain-Fritsch on Domain 1 (`cu_physics = 1`); explicitly turned off for the 3km Domain 2.

---

## Data Assimilation (DART) Setup

The assimilation cycle employs an either Ensemble Adjustment Kalman Filter (EAKF) or Kernel Density Filter (KDE) driven by DART, interacting with the WRF state. 

*   **Ensemble Size:** 50 members
*   **Assimilation Interval:** 3 hours for standard state variables
*   **Radar Assimilation Frequency:** 15 minutes
*   **Inflation:** Adaptive inflation is enabled (`ADAPTIVE_INFLATION=1`)
*   **Initial Perturbation Scale:** 0.25 
*   **Assimilated Variables for spin up cycle:** `U`, `V`, `PH`, `THM`, `MU`, `QVAPOR`, `QCLOUD`, `QRAIN`, `QICE`, `QSNOW`, `QGRAUP`, `QNICE`, `QNRAIN`, `U10`, `V10`, `T2`, `Q2`, `PSFC`
*   **Assimilated Variables for target cycyle:** `U`, `V`, `THM`, `QVAPOR`

---

## Repository Scripts & Architecture

This repository implements a completely centralized, modernized WRF-DART ensemble data assimilation pipeline. All configuration parameters, scheduler resource allocations, and module environments are driven by a single master parameter file, eliminating redundant scripts and fragile hardcoded replacements.

Below is a summary of the major scripts and their roles within the newly modularized workflow.

### Core Configuration & Environment

* **`param.sh`**
  The **single source of truth** and master configuration file for the entire pipeline. All drivers and submission scripts source this file at runtime. It centrally defines:
  * **Experiment Timing & Variables:** Start/end dates, cycling intervals, assimilated state variables, and ensemble size (`NUM_MEMBERS`).
  * **Directory Setup:** Standardized paths for models, scratch spaces, observations, and outputs.
  * **SLURM / SBATCH Resource Headers:** Complete queue parameters (`-A`, `-p`, `-N`, `-n`, `-t`, `--mem-per-cpu`) customized specifically for each stage (ICBC generation, ensemble perturbations, initial forecasts, cycling forecasts, and DART filter execution).

---

### Data Acquisition

The data download utilities directly reference target directories defined in `param.sh`, ensuring input datasets land directly in the structured paths expected by the workflow:

* **`download_prepbufr.sh`**
  Downloads real observation PrepBUFR data required by the experiment directly to the configured observation directory.

* **`era_api_new_pl.py`**
  Downloads ERA5 pressure-level reanalysis data from the Copernicus Climate Data Store (CDS) into the configured ERA5 directory.

* **`era_api_new_sf.py`**
  Downloads ERA5 single-level and surface fields necessary for generating model initial and boundary conditions.

---

### Initial and Boundary Condition Generation

* **`gen_icbc.sh`**
  The primary driver script responsible for running WPS (`geogrid`, `ungrib`, `metgrid`) and `real.exe` to generate the baseline unperturbed initial condition (`wrfinput`) and lateral boundary condition (`wrfbdy`) files. Auto-submits itself to SLURM using queue configurations sourced from `param.sh`.

* **`gen_init.sh`**
  The **consolidated ensemble initialization engine** that replaces legacy multi-script chains. It creates member subdirectories, generates random initial condition perturbations using WRFDA's `randomcv` utility, and orchestrates SLURM job dependency tracking (`afterok`) to safely trigger corresponding lateral boundary condition perturbations (`da_update_bc`) without race conditions.

---

### Observation Processing & Drivers

Observation generation is decoupled into two automated, top-level drivers that orchestrate Python extraction tools by passing environment variables sourced from `param.sh`:

* **`gen_obs_prepbufr.sh`**
  Top-level orchestration driver for creating synthetic observations based on **PrepBUFR locations and metadata**. Automatically executes ASCII extraction (`gen_obs.sh`), quality control filtering, Nature Run observation-space extraction, and sequence formatting.

* **`gen_obs_manual.sh`**
  Top-level orchestration driver for creating synthetic observations at **manually configured stations and networks**. Coordinates manual network setup (`sys_temp_obs.py`), Nature Run extraction, and sequence formatting.

* **`make_obs.sh`**
  Modernized shell utility that invokes DART's `create_real_obs` program to convert intermediate ASCII observation files into official DART observation sequence files (`obs_seq.in`), dynamically inheriting date windows and directory paths from `param.sh`.

* **Python Observation Processing Toolchain:**
  * **`filter_obs.py`**: Applies spatial quality control procedures to filter observations according to boundary domains and variable rules.
  * **`sys_temp_obs.py`**: Configures artificial station layouts and timestamps for customized observing system simulation experiments (OSSEs).
  * **`extract_wrf_obs_earthwind_ObsError2.py`**: Interpolates WRF Nature Run grid fields to observation coordinates, applies observational error statistics, and converts variables into DART-compatible state quantities.

---

### Ensemble Forecasting & Data Assimilation Cycling

To eliminate script modification during execution, forecast routines are decoupled into reusable execution modules and purpose-specific launchers:

* **`advance_run.sh`**
  The core, reusable model forecast driver. Instead of editing files on the fly, it accepts the simulation start date, end date, and forecast duration (`DE_FCST_RANGE`) dynamically as command-line arguments.

* **`ensemble_fcst_full.sh`**
  Executes long-range free forecasts (e.g., 50-hour runs) across all ensemble members using centralized long-job SLURM settings. Used to generate the free-run ensemble and establish the Nature Run (truth state) for synthetic observation generation.

* **`ensemble_fcst_3h.sh`**
  Executes short-range (e.g., 3-hour) forecasts across ensemble members using dedicated spin-up SLURM queue parameters. Used to advance initial state members to the starting timestamp of the cycling period.

* **`run_cycle.sh`**
  The primary data assimilation cycling driver. Managing the iterative EAKF assimilation loop, it automates:
  1. Setting up short-term ensemble forecast windows via `advance_run.sh` using cycling queue configurations.
  2. Executing DART (`filter`) across compute nodes to adjust ensemble member states against observation sequence files.
  3. Updating boundary tendencies and progressing simulation timestamps to the next assimilation cycle.

---

### Repository Workflow & Entry Points

For an end-to-end OSSE experiment, the simplified execution sequence is structured as follows:

```text
param.sh (Master Config, Module Loader & SLURM Queue Settings)
   ↓
gen_icbc3.sh (WPS & Real.exe — Base IC/BC Generation)
   ↓
gen_init.sh (Consolidated WRFDA randomcv IC & Update LBC Perturbation Engine)
   ↓
[Phase 1: Free-Run & Synthetic Observation Generation]
   ├──→ ensemble_fcst_full.sh (Long Free-Run Forecast to establish Nature Run/Truth State)
   │       └──→ advance_run.sh [passed duration argument dynamically]
   │
   ├──→ gen_obs_prepbufr.sh (Top-Level PrepBUFR Synthetic Obs Driver)
   │       ├──→ gen_obs.sh / prepbufr.csh (DART prep_bufr ASCII extraction)
   │       ├──→ filter_obs.py (Spatial/Quality domain filtering)
   │       ├──→ extract_wrf_obs_earthwind_ObsError2.py (Nature Run extraction & observation error assignment)
   │       └──→ make_obs.sh (Dynamic DART observation sequence conversion)
   │
   └──→ gen_obs_manual.sh (Top-Level Manual Synthetic Obs Driver)
           ├──→ sys_temp_obs.py (Manual location & station network generator)
           ├──→ extract_wrf_obs_earthwind_ObsError2.py (Nature Run extraction & observation error assignment)
           └──→ make_obs.sh (Dynamic DART observation sequence conversion)
   ↓
[Phase 2: Data Assimilation Cycling]
   ├──→ ensemble_fcst_3h.sh (Initial Short-Range Spin-Up Forecast)
   │       └──→ advance_run.sh [passed duration argument dynamically]
   │
   └──→ run_cycle.sh (Iterative EAKF Assimilation Cycling Engine)
           ├──→ DART Filter Execution 
           └──→ advance_run.sh (Next-cycle ensemble background advancement)
```
