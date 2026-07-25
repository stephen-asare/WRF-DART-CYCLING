"""
extract_wrf_obs.py
------------------
Reads filtered observation txt files, matches each observation to the
corresponding 1-minute WRF output file, extracts the model value at the
observation location/level, adds Gaussian noise, and writes the result.

Column layout (1-based, space-delimited):
  1  obs_error (variance)
  2  longitude
  3  latitude
  4  pressure  [hPa]
  5  obs1      (variable value, or zonal wind U)
  6  obs2      (variable value, or meridional wind V)
  7  index     (first digit = variable type)
  8  hour      (offset from REF_TIME in hours)
  9  type_code
  10 qm
  11 subset    (ADPUPA / ADPSFC / SATWND / AIRCFT / SFCSHP)
  12 pc

Index prefix rules:
  1 → temperature
  2 → zonal wind   (obs1=U, obs2=V)
  3 → pressure
  5 → humidity     (obs2==0: specific humidity; obs2==1 or 2: skip)
  7 → skip
  9 → meridional wind (obs1=V, obs2=U)
"""

import os
import glob
import numpy as np
from datetime import datetime, timedelta
from netCDF4 import Dataset

# ── user settings ──────────────────────────────────────────────────────────────

WRF_DIR = os.environ.get("WRF_DIR", "/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/nature_run")
OBS_DIR = os.environ.get("OBS_DIR", "/gpfs/research/scratch/sa24m/tqprof/run2/osse_out/sys_obs/window_2015071300_2015071512/sys_temp_obs")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/sys_obs/window_2015071300_2015071512/sys_obs_wrf_single")

OBS_FILES = sorted([os.path.basename(f) for f in glob.glob(os.path.join(OBS_DIR, "temp_obs.*")) if not f.endswith('.py')])
# print(OBS_FILES)
# Reference time that hour=0 corresponds to
# REF_TIME = datetime(2015, 7, 13, 0, 0, 0)

# Observation types treated as surface (use 2-m / 10-m WRF fields)
SURFACE_TYPES = {"ADPSFC", "SFCSHP"}

# ── helpers ────────────────────────────────────────────────────────────────────

# def hour_to_datetime(hour):
#     """Convert hour offset to an absolute datetime."""
#     return REF_TIME + timedelta(hours=float(hour))

## wrfout is every minute data
#def find_wrf_file(dt):
#    """
#    Return the path to the WRF file matching dt (rounded to nearest minute).
#    Returns None when the file does not exist.
#    """
#    rounded = dt.replace(second=0, microsecond=0)
#    if dt.second >= 30:  
#        rounded += timedelta(minutes=1)
#    fname = "wrfout_d02_" + rounded.strftime("%Y-%m-%d_%H:%M:%S")
#    fpath = os.path.join(WRF_DIR, fname)
#    return fpath if os.path.exists(fpath) else None

## wrfout is hourly data
def find_wrf_file(dt):
    """
    Return the path to the WRF file matching dt (rounded to nearest hour).
    Returns None when the file does not exist.
    """
    # Zero out minutes, seconds, and microseconds to establish the "floor" hour
    rounded = dt.replace(minute=0, second=0, microsecond=0)
    
    # If the original time was 30 minutes or past, round up to the next hour
    if dt.minute >= 30:
        rounded += timedelta(hours=1)
        
    fname = "wrfout_d02_" + rounded.strftime("%Y-%m-%d_%H:%M:%S")
    fpath = os.path.join(WRF_DIR, fname)
    return fpath if os.path.exists(fpath) else None


def get_index_prefix(index_token):
    """Return the integer first digit of the index field."""
    s = index_token.replace(".", "").replace("-", "")
    return int(s[0]) if s else None


def should_skip(index_prefix, obs2_val):
    """Return True for rows that must be skipped."""
    if index_prefix == 7:
        return True
    if index_prefix == 5 and obs2_val in (1.0, 2.0):   # RH or dew point
        return True
    return False


def find_bilinear_weights(lon_obs, lat_obs, XLONG, XLAT):
    """
    Locate the grid cell that contains (lon_obs, lat_obs) on the curvilinear
    WRF grid and compute bilinear interpolation weights.
    """
    nj, ni = XLONG.shape
    dist2 = (XLONG - lon_obs) ** 2 + (XLAT - lat_obs) ** 2
    jn, in_ = np.unravel_index(np.argmin(dist2), dist2.shape)
    best = dict(j0=min(jn, nj - 2), i0=min(max(0, in_ - 1), ni - 2), s=0.5, t=0.5)

    for dj in (-1, 0):
        for di in (-1, 0):
            j0 = jn + dj
            i0 = in_ + di
            if j0 < 0 or i0 < 0 or j0 + 1 >= nj or i0 + 1 >= ni:
                continue

            x00 = XLONG[j0,     i0    ];  y00 = XLAT[j0,     i0    ]
            x10 = XLONG[j0,     i0 + 1];  y10 = XLAT[j0,     i0 + 1]
            x01 = XLONG[j0 + 1, i0    ];  y01 = XLAT[j0 + 1, i0    ]
            x11 = XLONG[j0 + 1, i0 + 1];  y11 = XLAT[j0 + 1, i0 + 1]

            s, t = 0.5, 0.5
            for _ in range(20):
                fx = ((1-s)*(1-t)*x00 + s*(1-t)*x10 + (1-s)*t*x01 + s*t*x11) - lon_obs
                fy = ((1-s)*(1-t)*y00 + s*(1-t)*y10 + (1-s)*t*y01 + s*t*y11) - lat_obs

                dfx_ds = -(1-t)*x00 + (1-t)*x10 - t*x01 + t*x11
                dfx_dt = -(1-s)*x00 - s    *x10 + (1-s)*x01 + s*x11
                dfy_ds = -(1-t)*y00 + (1-t)*y10 - t*y01 + t*y11
                dfy_dt = -(1-s)*y00 - s    *y10 + (1-s)*y01 + s*y11

                det = dfx_ds * dfy_dt - dfx_dt * dfy_ds
                if abs(det) < 1e-14:
                    break
                ds = -(dfy_dt * fx - dfx_dt * fy) / det
                dt = -(-dfy_ds * fx + dfx_ds * fy) / det
                s += ds
                t += dt
                if abs(ds) < 1e-9 and abs(dt) < 1e-9:
                    break

            if -0.02 <= s <= 1.02 and -0.02 <= t <= 1.02:
                best = dict(j0=j0, i0=i0, s=s, t=t)
                break
        else:
            continue
        break

    s = max(0.0, min(1.0, best["s"]))
    t = max(0.0, min(1.0, best["t"]))
    w00 = (1 - s) * (1 - t)
    w10 =      s  * (1 - t)
    w01 = (1 - s) * t
    w11 =      s  * t

    return best["j0"], best["i0"], w00, w10, w01, w11


# ── bilinear application helpers ───────────────────────────────────────────────

def bilinear_2d(field, j0, i0, w00, w10, w01, w11):
    return (w00 * field[j0,     i0    ] + w10 * field[j0,     i0 + 1] +
            w01 * field[j0 + 1, i0    ] + w11 * field[j0 + 1, i0 + 1])


def bilinear_col(field3d, j0, i0, w00, w10, w01, w11):
    return (w00 * field3d[:, j0,     i0    ] + w10 * field3d[:, j0,     i0 + 1] +
            w01 * field3d[:, j0 + 1, i0    ] + w11 * field3d[:, j0 + 1, i0 + 1])


def interp_to_pressure(col_1d, pres_1d, target_pa):
    p_min = float(pres_1d.min())
    p_max = float(pres_1d.max())

    if target_pa < p_min:
        raise ValueError(f"target {target_pa:.1f} Pa is above the model top ({p_min:.1f} Pa) -- skipping.")
    if target_pa > p_max:
        raise ValueError(f"target {target_pa:.1f} Pa is below the model surface ({p_max:.1f} Pa) -- skipping.")

    log_pres   = np.log(pres_1d)
    log_target = np.log(target_pa)
    return float(np.interp(log_target, log_pres[::-1], col_1d[::-1]))


# ── DATA CACHE HELPER ──────────────────────────────────────────────────────────
def get_var(nc, wrf_path, var_name, data_cache):
    """Lazy-loads a WRF variable into memory to avoid redundant disk I/O."""
    if wrf_path not in data_cache:
        data_cache[wrf_path] = {}
        
    if var_name not in data_cache[wrf_path]:
        data_cache[wrf_path][var_name] = nc.variables[var_name][0, ...]
        
    return data_cache[wrf_path][var_name]


def extract_wrf_value(nc, wrf_path, data_cache, j0, i0, w00, w10, w01, w11,
                      obs_type, index_prefix, obs2_val, pres_hpa):
    """
    Extract the WRF model equivalent of the observation using bilinear
    horizontal interpolation. Uses data_cache to prevent massive I/O loops.
    """
    is_surface = obs_type in SURFACE_TYPES
    target_pa  = float(pres_hpa) * 100.0   # hPa → Pa

    # Temperature (1)
    if index_prefix == 1:
        if is_surface:
            T2  = get_var(nc, wrf_path, "T2", data_cache)
            val = float(bilinear_2d(T2, j0, i0, w00, w10, w01, w11))
            return val, None
        else:
            T_pert = get_var(nc, wrf_path, "T", data_cache)
            P_pert = get_var(nc, wrf_path, "P", data_cache)
            PB     = get_var(nc, wrf_path, "PB", data_cache)
            
            theta_col = bilinear_col(T_pert, j0, i0, w00, w10, w01, w11) + 300.0
            P_col     = (bilinear_col(P_pert, j0, i0, w00, w10, w01, w11)
                       + bilinear_col(PB,     j0, i0, w00, w10, w01, w11))
            temp_col  = theta_col * (P_col / 100000.0) ** (2.0 / 7.0)
            return interp_to_pressure(temp_col, P_col, target_pa), None

    # Pressure (3)
    elif index_prefix == 3:
        if is_surface:
            PSFC = get_var(nc, wrf_path, "PSFC", data_cache)
            val  = float(bilinear_2d(PSFC, j0, i0, w00, w10, w01, w11)) / 100.0
            return val, None
        else:
            P_pert = get_var(nc, wrf_path, "P", data_cache)
            PB     = get_var(nc, wrf_path, "PB", data_cache)
            P_col  = (bilinear_col(P_pert, j0, i0, w00, w10, w01, w11)
                    + bilinear_col(PB,     j0, i0, w00, w10, w01, w11))
            val    = interp_to_pressure(P_col / 100.0, P_col, target_pa)
            return val, None

    # Specific humidity (5)
    elif index_prefix == 5:
        if is_surface:
            Q2  = get_var(nc, wrf_path, "Q2", data_cache)
            val = float(bilinear_2d(Q2, j0, i0, w00, w10, w01, w11))
            return val, None
        else:
            QVAPOR = get_var(nc, wrf_path, "QVAPOR", data_cache)
            P_pert = get_var(nc, wrf_path, "P", data_cache)
            PB     = get_var(nc, wrf_path, "PB", data_cache)
            q_col  = bilinear_col(QVAPOR, j0, i0, w00, w10, w01, w11)
            P_col  = (bilinear_col(P_pert, j0, i0, w00, w10, w01, w11)
                    + bilinear_col(PB,     j0, i0, w00, w10, w01, w11))
            return interp_to_pressure(q_col, P_col, target_pa), None

    # Wind (2, 9)
    elif index_prefix in (2, 9):
        SINA = get_var(nc, wrf_path, "SINALPHA", data_cache)
        COSA = get_var(nc, wrf_path, "COSALPHA", data_cache)
        sina_val = float(bilinear_2d(SINA, j0, i0, w00, w10, w01, w11))
        cosa_val = float(bilinear_2d(COSA, j0, i0, w00, w10, w01, w11))

        if is_surface:
            U10 = get_var(nc, wrf_path, "U10", data_cache)
            V10 = get_var(nc, wrf_path, "V10", data_cache)
            u_grid = float(bilinear_2d(U10, j0, i0, w00, w10, w01, w11))
            v_grid = float(bilinear_2d(V10, j0, i0, w00, w10, w01, w11))
        else:
            U_stag = get_var(nc, wrf_path, "U", data_cache)
            V_stag = get_var(nc, wrf_path, "V", data_cache)
            U_mp   = 0.5 * (U_stag[:, :, :-1] + U_stag[:, :, 1:])
            V_mp   = 0.5 * (V_stag[:, :-1, :] + V_stag[:, 1:, :])

            P_pert = get_var(nc, wrf_path, "P", data_cache)
            PB     = get_var(nc, wrf_path, "PB", data_cache)
            P_col  = (bilinear_col(P_pert, j0, i0, w00, w10, w01, w11)
                    + bilinear_col(PB,     j0, i0, w00, w10, w01, w11))
            u_col  = bilinear_col(U_mp, j0, i0, w00, w10, w01, w11)
            v_col  = bilinear_col(V_mp, j0, i0, w00, w10, w01, w11)
            
            u_grid = interp_to_pressure(u_col, P_col, target_pa)
            v_grid = interp_to_pressure(v_col, P_col, target_pa)

        u_earth = u_grid * cosa_val - v_grid * sina_val
        v_earth = v_grid * cosa_val + u_grid * sina_val

        if index_prefix == 2:
            return u_earth, v_earth
        else:
            return v_earth, u_earth

    return None, None


def format_obs_value(val):
    return f"{val:7.2f}"


def rebuild_line(tokens, obs1_wrf, obs2_wrf):
    new_tokens = list(tokens)
    new_tokens[4] = format_obs_value(obs1_wrf)
    if obs2_wrf is not None:
        new_tokens[5] = format_obs_value(obs2_wrf)
    line = (f"{new_tokens[0]:>5}"
            f"{new_tokens[1]:>9}"
            f"{new_tokens[2]:>9}"
            f"{new_tokens[3]:>12}"
            f"{new_tokens[4]:>7}"
            f"{new_tokens[5]:>7}"
            f"{new_tokens[6]:>9}"
            f"{new_tokens[7]:>7}"
            f"{new_tokens[8]:>4}"
            f"{new_tokens[9]:>2}"
            f"{new_tokens[10]:>7}"
            f"{new_tokens[11]:>2}\n")
    return line


# ── main ───────────────────────────────────────────────────────────────────────

def process_file(obs_filepath):
    base      = os.path.basename(obs_filepath)
    out_path  = os.path.join(OUTPUT_DIR, base + ".wrf")
    obs_type  = base.split(".")[-1]

    # Dynamically parse the base date from the filename (e.g. temp_obs.2015071406.ADPSFC)
    date_str   = base.split(".")[1]
    file_year  = int(date_str[0:4])
    file_month = int(date_str[4:6])
    file_day   = int(date_str[6:8])
    file_ref_time = datetime(file_year, file_month, file_day, 0, 0, 0)

    wrf_cache  = {}
    grid_cache = {}
    data_cache = {}

    out_lines   = []
    n_total     = 0
    n_matched   = 0
    n_skipped      = 0
    n_no_wrf       = 0
    n_out_of_range = 0

    with open(obs_filepath, "r") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")
            if not line.strip():
                continue
            n_total += 1
            tokens = line.split()
            if len(tokens) < 12:
                n_skipped += 1
                continue

            obs_err_var = float(tokens[0])
            lon_obs  = float(tokens[1])
            lat_obs  = float(tokens[2])
            pres_hpa = float(tokens[3])
            obs2_val = float(tokens[5])
            index_token = tokens[6]
            hour_val = float(tokens[7])


            if pres_hpa < 800.0:
                tokens[0] = "99.99"
                obs_err_var = float(tokens[0])
                
            index_prefix = get_index_prefix(index_token)
            if index_prefix is None or should_skip(index_prefix, obs2_val):
                n_skipped += 1
                continue

            # obs_dt   = hour_to_datetime(hour_val)
            obs_dt   = file_ref_time + timedelta(hours=hour_val)
            wrf_path = find_wrf_file(obs_dt)
            if wrf_path is None:
                n_no_wrf += 1
                continue

            if wrf_path not in wrf_cache:
                wrf_cache[wrf_path]  = Dataset(wrf_path, "r")
                nc0 = wrf_cache[wrf_path]
                XLONG = nc0.variables["XLONG"][0, :, :]
                XLAT  = nc0.variables["XLAT"][0, :, :]
                grid_cache[wrf_path] = (XLONG, XLAT)

            nc = wrf_cache[wrf_path]
            XLONG, XLAT = grid_cache[wrf_path]

            j0, i0, w00, w10, w01, w11 = find_bilinear_weights(lon_obs, lat_obs, XLONG, XLAT)

            try:
                obs1_wrf, obs2_wrf = extract_wrf_value(
                    nc, wrf_path, data_cache, j0, i0, w00, w10, w01, w11,
                    obs_type, index_prefix, obs2_val, pres_hpa
                )
            except ValueError:
                n_out_of_range += 1
                continue
            except Exception as e:
                print(f"  WARNING: extraction failed ({e}) – skipping line")
                n_skipped += 1
                continue

            if obs1_wrf is None:
                n_skipped += 1
                continue

            # ── add random error ──────────────────────────────────────
            obs_err_std = np.sqrt(max(0.0, obs_err_var))
            
            obs1_wrf += np.random.normal(0.0, obs_err_std)
            if obs2_wrf is not None:
                obs2_wrf += np.random.normal(0.0, obs_err_std)

            # ── physics bounds check ──────────────────────────────────
            # Prevent specific humidity (q) from dropping below zero
            if index_prefix == 5:
                obs1_wrf = max(0.0, obs1_wrf)

            out_lines.append(rebuild_line(tokens, obs1_wrf, obs2_wrf))
            n_matched += 1

    data_cache.clear()
    for nc in wrf_cache.values():
        nc.close()

    with open(out_path, "w") as fh:
        fh.writelines(out_lines)

    print(f"{obs_type:<10}  total={n_total:6d}  matched={n_matched:6d}  "
          f"skipped={n_skipped:5d}  out_of_range={n_out_of_range:5d}  "
          f"no_wrf={n_no_wrf:5d}  --> {out_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"WRF directory : {WRF_DIR}")
    # print(f"Reference time: {REF_TIME} UTC")
    print(f"{'Obs type':<10}  {'Total':>8}  {'Matched':>8}  "
          f"{'Skipped':>7}  {'No WRF':>7}  Output")
    print("-" * 80)
    for obs_file in OBS_FILES:
        obs_path = os.path.join(OBS_DIR, obs_file)
        if not os.path.exists(obs_path):
            print(f"  [MISSING] {obs_path}")
            continue
        process_file(obs_path)
    print("\nDone.")


if __name__ == "__main__":
    main()
