from pathlib import Path
import os
import cdsapi

def get_output_dir():
    val = os.environ.get("ERA5_DATA_DIR")
    if val:
        return val

    param_file = Path.cwd() / "param.sh"

    if param_file.exists():
        with param_file.open() as f:
            for line in f:
                if "export ERA5_DATA_DIR=" in line:
                    value = line.split("=", 1)[1]
                    value = value.split("#", 1)[0].strip()   
                    return value.strip('"').strip("'")

    raise FileNotFoundError(f"param.sh not found in {Path.cwd()}")

output_dir = Path(get_output_dir())
output_dir.mkdir(parents=True, exist_ok=True)

dataset = "reanalysis-era5-pressure-levels"
request = {
    "product_type": ["reanalysis"],
    "variable": [
        "geopotential",
        "relative_humidity",
        "specific_humidity",
        "temperature",
        "u_component_of_wind",
        "v_component_of_wind"
    ],
    "year": ["2015"],
    "month": ["07"],
    "day": ["13","14","15"],
    "time": ["00:00", "03:00", "06:00", "09:00", "12:00", "15:00", "18:00", "21:00"],
    "pressure_level": [
        "1", "2", "3",
        "5", "7", "10",
        "20", "30", "50",
        "70", "100", "125",
        "150", "175", "200",
        "225", "250", "300",
        "350", "400", "450",
        "500", "550", "600",
        "650", "700", "750",
        "775", "800", "825",
        "850", "875", "900",
        "925", "950", "975",
        "1000"
    ],
    "data_format": "grib",
    "download_format": "unarchived",
    "area": [80, -170, -80, 170]
}

client = cdsapi.Client()
outfile = os.path.join(output_dir, "era5_pl_20150713_20150715.grib")
client.retrieve(dataset, request).download(outfile)