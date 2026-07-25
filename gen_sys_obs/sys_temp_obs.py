import os
from datetime import datetime, timedelta

# ── TIME & DATE SETTINGS ──────────────────────────────────────────────────────
start_date_str = os.environ.get("START_DATE", "2015071406")
end_date_str = os.environ.get("END_DATE", "2015071500")
ref_time_str = os.environ.get("REF_TIME", "2015071400")

START_DATE = datetime.strptime(start_date_str, "%Y%m%d%H")
END_DATE   = datetime.strptime(end_date_str, "%Y%m%d%H")
FREQ_HOURS = int(os.environ.get("FREQ_HOURS", "3"))
REF_TIME   = datetime.strptime(ref_time_str, "%Y%m%d%H")

OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/gpfs/home/sa24m/scratch/tqprof/run2/osse_out/sys_obs/window_2015071300_2015071512/sys_temp_obs")
OUTPUT_PREFIX = "temp_obs."

# ── VARIABLE DEFINITIONS ──────────────────────────────────────────────────────
VAR_MAP = {
    "ADPUPA": {
        "T": ("1000368.", "120", "2", "1"),
        "Q": ("5000368.", "120", "2", "1"),
        "P": ("3000368.", "120", "2", "1"),
        "U": ("2000368.", "220", "2", "1"),
        "V": ("9000368.", "220", "2", "1"),
    },
    "ADPSFC": {
        "T": ("1229116.", "187", "9", "4"),
        "Q": ("5229116.", "187", "9", "4"),
        "P": ("3229116.", "187", "2", "1"),
        "U": ("2229116.", "287", "9", "4"),
        "V": ("9229116.", "287", "9", "4"),
    }
}

# ── STATION NETWORK ───────────────────────────────────────────────────────────
STATIONS = [    
    # {
    #     "description": "Fixed Surface Station",
    #     "subset": "ADPSFC",
    #     "lon": 260.0300,
    #     "lat": 37.7600,
    #     "pressures_hpa": [1013.25],
    #     "vars": {"T": 1.5, "Q": 0.3, "U": 2.0, "V": 2.0, "P": 1.0}
    # },
    {
        "description": "Radiosonde Profiler - Location A",
        "subset": "ADPUPA",
        "lon": 260.0300,
        "lat": 37.7600,
        "pressures_hpa": [910],
        "vars": {"T": 1.0, "Q": 0.04, "U": 1.5, "V": 1.5}
    }
]

# ── GENERATION LOGIC ──────────────────────────────────────────────────────────

def generate_files():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    current_time = START_DATE
    total_files = 0
    total_obs = 0

    print(f"Starting generation from {START_DATE} to {END_DATE} (every {FREQ_HOURS}h)")
    print("-" * 60)

    while current_time <= END_DATE:
        date_str = current_time.strftime("%Y%m%d%H")
        hour_offset = (current_time - REF_TIME).total_seconds() / 3600.0
        
        # Buffer to hold lines for each subset (e.g., "ADPSFC": [line1, line2], "ADPUPA": [line1, line2])
        subset_buffers = {}
        
        for station in STATIONS:
            lon = station["lon"]
            lat = station["lat"]
            subset = station["subset"]
            
            if subset not in subset_buffers:
                subset_buffers[subset] = []
            
            for p_hpa in station["pressures_hpa"]:
                for var_name, err_var in station["vars"].items():
                    idx_token, type_code, qm, pc = VAR_MAP[subset][var_name]

                    line = (f"{err_var:>5.2f} {lon:>9.4f} {lat:>8.4f} {p_hpa:>10.5E} "
                            f"{0.0:>7.2f} {0.0:>7.2f} {idx_token:>9} {hour_offset:>7.3f} "
                            f"{type_code:>3} {qm:>1} {subset:>7} {pc:>1}\n")
                    subset_buffers[subset].append(line)
        
        # Write the buffered lines into their respective subset files
        for subset, lines in subset_buffers.items():
            filename = f"{OUTPUT_PREFIX}{date_str}.{subset}"
            filepath = os.path.join(OUTPUT_DIR, filename)
            
            with open(filepath, "w") as f:
                f.writelines(lines)
                
            obs_in_file = len(lines)
            total_obs += obs_in_file
            total_files += 1
            print(f"Generated {filename:<25} | Hour Offset: {hour_offset:>5.1f} | Obs: {obs_in_file}")
            
        current_time += timedelta(hours=FREQ_HOURS)

    print("-" * 60)
    print(f"Done. Generated {total_files} files containing {total_obs} total observations.")
    print(f"Output saved to: {os.path.abspath(OUTPUT_DIR)}")

if __name__ == "__main__":
    generate_files()