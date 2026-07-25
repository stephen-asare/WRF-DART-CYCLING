import cdsapi
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

output_dir = get_output_dir()
output_dir.mkdir(parents=True, exist_ok=True)

dataset = "reanalysis-era5-single-levels"
request = {
    "product_type": ["reanalysis"],
    "variable": [
        "10m_u_component_of_wind",
        "10m_v_component_of_wind",
        "2m_dewpoint_temperature",
        "2m_temperature",
        "mean_sea_level_pressure",
        "sea_surface_temperature",
        "surface_pressure",
        "total_precipitation",
        "skin_temperature",
        "surface_latent_heat_flux",
        "top_net_solar_radiation_clear_sky",
        "soil_temperature_level_1",
        "soil_temperature_level_2",
        "soil_temperature_level_3",
        "soil_temperature_level_4",
        "soil_type",
        "volumetric_soil_water_layer_1",
        "volumetric_soil_water_layer_2",
        "volumetric_soil_water_layer_3",
        "volumetric_soil_water_layer_4",
        "geopotential",
        "land_sea_mask",
        "sea_ice_cover",
        "leaf_area_index_high_vegetation",
        "snow_depth"
    ],
    "year": ["2015"],
    "month": ["07"],
    "day": ["13","14","15"],
    "time": ["00:00", "03:00", "06:00", "09:00", "12:00", "15:00", "18:00", "21:00"],
    "data_format": "grib",
    "download_format": "unarchived",
    "area": [70, -160,-50, 160]
}

client = cdsapi.Client()
outfile = os.path.join(output_dir, "era5_sf_20150713_20150715.grib")
client.retrieve(dataset, request).download(outfile)
