import numpy as np
from netCDF4 import Dataset


# ============================================================
# NetCDF helpers
# ============================================================

def nc_var_exists(fname, varname):
    with Dataset(fname, "r") as nc:
        return varname in nc.variables


def nc_read_att(fname, varname, attname):
    with Dataset(fname, "r") as nc:
        var = nc.variables[varname]
        return getattr(var, attname, None)


def nc_dim_info(fname, dimname):
    with Dataset(fname, "r") as nc:
        return nc.dimensions[dimname].size


# ============================================================
# Copy / QC index lookup
# ============================================================

def get_copy_index(fname, copystring,
                   context="context", label="CopyString"):
    """
    Return index of requested copy metadata string
    """
    with Dataset(fname, "r") as nc:
        copy_meta = _chararray_to_list(nc.variables["CopyMetaData"][:])

    matches = [i for i, s in enumerate(copy_meta) if s == copystring]

    if not matches:
        raise ValueError(f"No matching {label}: '{copystring}'")

    # MATLAB uses 1-based indexing, Python uses 0-based
    return matches[0]


def get_qc_index(fname, qcstring, label="QCString"):
    """
    Return index of requested QC metadata string
    """
    with Dataset(fname, "r") as nc:
        qc_meta = _chararray_to_list(nc.variables["QCMetaData"][:])

    matches = [i for i, s in enumerate(qc_meta) if s == qcstring]

    if not matches:
        raise ValueError(f"No matching {label}: '{qcstring}'")

    return matches[0]


# ============================================================
# Geographic subsetting
# ============================================================

# def locations_in_region(locs, region):
#     """
#     region = [lon_min lon_max lat_min lat_max z_min z_max]
#     """
#     lon_min, lon_max, lat_min, lat_max, z_min, z_max = region

#     lons = locs[:, 0]
#     lats = locs[:, 1]
#     zs   = locs[:, 2]

#     # Longitude wrap handling (DART-style)
#     if lon_min <= lon_max:
#         lon_mask = (lons >= lon_min) & (lons <= lon_max)
#     else:
#         lon_mask = (lons >= lon_min) | (lons <= lon_max)

#     lat_mask = (lats >= lat_min) & (lats <= lat_max)
#     z_mask   = (zs >= z_min) & (zs <= z_max)

#     return np.where(lon_mask & lat_mask & z_mask)[0]

def locations_in_region(locations, region):
    """
    Returns the indices of the locations in the specified region.

    Parameters
    ----------
    locations : ndarray, shape (N, 3)
        Array of locations [lon, lat, lvl]
    region : array-like, length 4 or 6
        [leftlon, rightlon, minlat, maxlat, (minz, maxz)]

    Returns
    -------
    inds : ndarray
        Indices of locations inside the region
    """

    region = np.asarray(region)

    if len(region) == 6:
        zmin = min(region[4:6])
        zmax = max(region[4:6])
    elif len(region) == 4:
        zmin = -np.inf
        zmax = np.inf
    else:
        raise ValueError("region must be an array of length 4 or 6")

    ymin = min(region[2:4])
    ymax = max(region[2:4])

    xmin = region[0] % 360.0
    xmax = region[1] % 360.0

    lons = locations[:, 0] % 360.0

    # latitude and level logicals
    latlogical = (locations[:, 1] >= ymin) & (locations[:, 1] <= ymax)
    lvllogical = (locations[:, 2] >= zmin) & (locations[:, 2] <= zmax)

    # longitude logical, including wrapping
    if xmin == xmax:
        lonlogical = np.ones_like(latlogical, dtype=bool)
    else:
        if xmin > xmax:
            xmax = xmax + 360.0
            wrap_inds = lons < xmin
            lons = lons.copy()
            lons[wrap_inds] += 360.0

        lonlogical = (lons >= xmin) & (lons <= xmax)

    # combine all conditions
    inds = np.where(lonlogical & latlogical & lvllogical)[0]

    return inds



# ============================================================
# Internal helpers
# ============================================================

def _chararray_to_list(arr):
    """
    Convert NetCDF char arrays to Python string list
    """
    out = []
    for row in arr:
        if isinstance(row, bytes):
            out.append(row.decode("utf-8").strip())
        else:
            out.append("".join(c.decode("utf-8") for c in row).strip())
    return out
