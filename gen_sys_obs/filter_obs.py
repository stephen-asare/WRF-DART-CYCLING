"""
filter_obs.py
-------------
Reads a fixed-whitespace observation file (e.g. temp_obs.2022062324),
filters rows that satisfy:
  - longitude (col 2) : 108 ~ 137
  - latitude  (col 3) :  10 ~  37
  - pc        (col 12):  1          (all types)
                         1 or 4     (ADPSFC only)
and writes one output file per observation type
(ADPUPA, ADPSFC, SATWND, AIRCFT, SFCSHP).

Column layout (1-based):
  1  : value
  2  : longitude
  3  : latitude
  4  : value
  5  : value
  6  : value
  7  : value
  8  : hour
  9  : value
  10 : value
  11 : observation type
  12 : pc
"""

import os
import glob
import re

BASE_DIR = os.environ["BASE_DIR"]
SEARCH_PATTERN = os.environ["SEARCH_PATTERN"]
OUTPUT_DIR = os.environ["OUTPUT_DIR"]

LON_MIN, LON_MAX = 251.52, 266.82
LAT_MIN, LAT_MAX = 34.85, 43.50
# Allowed pc values per obs type.  All types default to {1};
# ADPSFC additionally accepts pc=4.
PC_ALLOWED = {
    "ADPSFC": {1, 4},
}
PC_DEFAULT = {1}   # used for every type not listed above

OBS_TYPES = ["ADPUPA", "ADPSFC", "SATWND", "SFCSHP"]
# ──────────────────────────────────────────────────────────────────────────────


def parse_line(line):
    """Return a list of string tokens from one data line."""
    return line.split()


def passes_filter(tokens, obs_type):
    """Return True when the row is inside the target region and pc is allowed
    for the given obs_type."""
    try:
        lon  = float(tokens[1])   # column 2  (0-based index 1)
        lat  = float(tokens[2])   # column 3  (0-based index 2)
        pc   = int(tokens[11])    # column 12 (0-based index 11)
    except (IndexError, ValueError):
        return False

    allowed_pc = PC_ALLOWED.get(obs_type, PC_DEFAULT)

    return (LON_MIN <= lon <= LON_MAX and
            LAT_MIN <= lat <= LAT_MAX and
            pc in allowed_pc)


def get_obs_type(tokens):
    """Return the observation-type string (column 11, 0-based index 10)."""
    try:
        return tokens[10]
    except IndexError:
        return None


def reconstruct_line(original_line):
    """
    Return the line with its format preserved.
    If the hour value (column 8, 0-based index 7) is greater than 21,
    subtract 24 from it and rewrite that field in-place.
    """
    # Preserve trailing newline
    nl = "\n" if not original_line.endswith("\n") else ""
    line = original_line.rstrip("\n")

    # tokens = line.split()
    # try:
    #     hour = float(tokens[7])   # column 8 (0-based index 7)
    #     if hour >= 21:
    #         new_hour = hour - 24.0
    #         # Replace only the hour token, keeping original spacing intact
    #         # Find the position of the token in the raw line and replace it
    #         old_token = tokens[7]
    #         # Format the new hour the same way as the original (preserve decimals)
    #         if '.' in old_token:
    #             decimals = len(old_token.split('.')[1])
    #             new_token = f"{new_hour:.{decimals}f}"
    #         else:
    #             new_token = str(int(new_hour))
    #         # Replace only the first occurrence that matches as a standalone token
    #         import re
    #         line = re.sub(r'(?<!\S)' + re.escape(old_token) + r'(?!\S)',
    #                       new_token, line, count=1)
    # except (IndexError, ValueError):
    #     pass

    return line + "\n" + nl


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for INPUT_FILE in sorted(glob.glob(SEARCH_PATTERN)):


        # Collect filtered lines grouped by obs type
        buckets = {obs_type: [] for obs_type in OBS_TYPES}
        skipped = 0
        total   = 0

        with open(INPUT_FILE, "r") as fh:
            for raw_line in fh:
                line = raw_line.rstrip("\n")
                if not line.strip():          # skip blank lines
                    continue
                total += 1
                tokens = parse_line(line)

                obs_type = get_obs_type(tokens)

                if not passes_filter(tokens, obs_type):
                    skipped += 1
                    continue
                if obs_type in buckets:
                    buckets[obs_type].append(reconstruct_line(raw_line))
                else:
                    skipped += 1   # unknown obs type – silently skip

        # Write one output file per obs type
        # os.makedirs(OUTPUT_DIR, exist_ok=True)
        base_name = os.path.basename(INPUT_FILE)   # e.g.  temp_obs.2022062324

        print(f"Input file   : {INPUT_FILE}")
        print(f"Total rows   : {total}")
        print(f"Filtered out : {skipped}")
        print(f"{'Obs type':<10}  {'Rows kept':>10}  Output file")
        print("-" * 60)

        for obs_type in OBS_TYPES:
            rows = buckets[obs_type]
            out_filename = os.path.join(OUTPUT_DIR, f"{base_name}.{obs_type}")
            with open(out_filename, "w") as fh:
                fh.writelines(rows)
            print(f"{obs_type:<10}  {len(rows):>10}  {out_filename}")

        print("\nDone with", base_name, "\n")

if __name__ == "__main__":
    main()
