import numpy as np
import sys # remove me when done bug testing

# constants
Tfrez = 273.1500
Rv = 461.6
L = 2.50e6
eo = 6.11
Rd = 287.04
RvRd = Rv / Rd
K = 0.2854
g = 9.81

def wrf_to_pres(grid, surface, interplevels):
	'''
	Linearly interpolates a grid to interplevels. This uses the 
	numpy.interp function that requires the function coordinate 
	values to be monotonically increasing, and this function does 
	not check for this. See numpy.interp docs for more information. 
	Grid and surface must be the same shape.
	Parameters
	----------
	grid - 3D array of values to be interpolated onto a vertical surface.  
	surface - 3D array of the verical coordinate values of the surface to be interpolated to. Must be monotonically increasing.
	interplevels - 1D array of vertical coordinate values that are desired to be interpolated to.
	Returns
	-------
	outgrid - numpy.ndarray of values of shape 
			(len( interplevels ), grid.shape[1], grid.shape[2] )
	'''

	# convert the incoming lists to numpy arrays if they aren't already
	grid = np.asarray(grid)
	surface = np.asarray(surface)
	interplevels = np.asarray(interplevels)

	# initialize the output grid
	shape = (interplevels.shape[0], grid.shape[1], grid.shape[2] )
	outgrid = np.empty(shape)
	# reverse interplevels 
	interplevels = interplevels[::-1]

	## loop over each gridpoint and get the vertical column
	for idx, val in np.ndenumerate(grid[0]):
		column = surface[:, idx[0], idx[1]]
		column_grid = grid[:, idx[0], idx[1]]
		# reverse the arrays since pressure is monotonically decreasing
		column = column[::-1]
		column_grid = column_grid[::-1]
		value = np.interp(interplevels, column, column_grid, left = np.nan, right = np.nan)
		# reverse the result as well
		value = value[::-1]
		outgrid[:,idx[0], idx[1]] = value[:]
	return outgrid

def wrf_to_height(grid, surface, zlevels):
    '''
    Linearly interpolates a grid to zlevels. This uses the 
    numpy.interp function that requires the function coordinate 
    values to be monotonically increasing, and this function does 
    not check for this. See numpy.interp docs for more information. 
    Grid and surface must be the same shape.
    Parameters
    ----------
    grid - 3D array of values to be interpolated onto a vertical surface.  
    surface - 3D array of the verical coordinate values of the surface to be interpolated to. Must be monotonically increasing.
    zlevels - 1D array of vertical coordinate values that are desired to be interpolated to.
    Returns
    -------
    outgrid - numpy.ndarray of values of shape 
            (len( interplevels ), grid.shape[1], grid.shape[2] )
    '''

    # convert the incoming lists to numpy arrays if they aren't already
    grid = np.asarray(grid)
    surface = np.asarray(surface)
    interplevels = np.asarray(zlevels)

    # initialize the output grid
    shape = (interplevels.shape[0], grid.shape[1], grid.shape[2] )
    outgrid = np.empty(shape)

    ## loop over each gridpoint and get the vertical column
    for idx, val in np.ndenumerate(grid[0]):
        column = surface[:, idx[0], idx[1]]
        column_grid = grid[:, idx[0], idx[1]]
        value = np.interp(interplevels, column, column_grid, left = np.nan, right = np.nan)
        outgrid[:,idx[0], idx[1]] = value[:]
    return outgrid

def mixrat_to_td(qvap, pres):
	''' Convert from water vapor mixing ratio to dewpoint temperature '''
	''' '''
	''' qvap: Input water vapor mixing ratio (kg/kg)'''
	''' pres: Input pressure (hPa)'''
	''' tdew: Output dewpoint temperature (K)'''
	
	# do a check to see if pres is a 1d array that temp and qvapor have been interpolated from
	qvap = np.asarray(qvap)
	pres = np.asarray(pres)
	if (pres.ndim == 1) and (qvap.ndim == 3):
		plevs = pres
		pres = np.empty_like(qvap)
		for idx, val in enumerate(plevs): 
			pres[idx,:,:] = plevs[idx]

	# calculations
	evap = qvap * pres * RvRd;
	tdew = 1/((1/Tfrez) - (Rv/L)*np.log(evap/eo))
	return tdew

def wrf_height(ph, phb):
	# calculates geopotential height via geopotential
	return (ph + phb) / g

def unstagger_we(grid):
	# unstaggers wrf height grids, must be 3d array
	# for unstaggering west-east (such as uwind)
	gridout = ( grid[:, :, :-1] + grid[:, :, 1:] ) / 2.
	return gridout

def unstagger_ns(grid):
	# unstaggers wrf height grids, must be 3d array
	# for unstaggering north-south (such as vwind)
	gridout = ( grid[:, :-1, :] + grid[:, 1:, :] ) / 2.
	return gridout

def unstagger_bt(grid):
	# unstaggers wrf height grids, must be 3d array
	# for unstaggering bottom-top (such as wwind, or geopotential height)
	gridout = ( grid[:-1, :, :] + grid[1:, :, :] ) / 2.
	return gridout

def wrf_temp(theta, pres):
	# calculates the temperature given potential temperature (theta in K) and pressure (in hPa)
	return theta * (1000 / pres)**-K

def wrf_theta(temp,pres):
	# calculates the potential temperature given temperature (in K) and pressure (in hPa)
	return temp * (1000 / pres)**K

def c_to_f(temp):
	# converts celsius to fahrenheit
	return temp * (9./5.) + 32

def f_to_c(temp):
	# converts fahrenheit to celsius
	return (temp - 32.) * (5./9.)

def calc_windir(u, v):
	# calculates the meteorological wind direction given the u and v components
	return ( np.arctan2(u, v) * (180 / np.pi) ) + 180

def calc_rh(temp, qvap, pres):
	# converts relative humidity given
	# temp - in K
	# pres - in hPa
	# qvapor - in kg/kg

	# do a check to see if pres is a 1d array that temp and qvapor have been interpolated from
	qvap = np.asarray(qvap)
	pres = np.asarray(pres)
	if (pres.ndim == 1) and (qvap.ndim == 3):
		plevs = pres
		pres = np.empty_like(qvap)
		for idx, val in enumerate(plevs):
			pres[idx,:,:] = plevs[idx]

	# first calculate es
	term1 = -7.90298 * ((373.15 / temp) - 1)
	term2 = 5.02808 * np.log10(373.15 / temp)
	term3 = (-1.3816E-7) * (10**(11.344*(1-(temp/373.15)))-1)
	term4 = (8.1328E-3) * (10**(-3.49149*((373.15/temp) - 1))-1)
	term5 = np.log10(1013.25)
	es = 10**(term1 + term2 + term3 + term4 + term5)
	ws = (621.97 * (es / (pres - es))) / 1000.
	rh = (qvap / ws) * 100
	return rh

def calc_thetav(qvapor,theta):
	'''
	Calculates virtual potential temperature
	---
	Inputs:
	qvapor: water vapor mixing ratio, kg/kg
	theta: potential temperature, K
	---
	Outputs:
	thetav: virtual potential temperature, K
	'''
	thetav = (1 + (0.61 * qvapor)) * theta
	return thetav

def calc_pvu(u, v, f, theta, pres, mapfac_m, dx):
	'''
	Calculates the potential vorticity in PVUs
	---
	Inputs:
	u: 3d array u-component of the wind, m/s
	v: 3d array of v-component of the wind, m/s
	f: 3d array of coriolis sine latitude values, s^-1
	theta: 3d array of potential temperature, K
	pres: 3d array of pressure, mb
	mapfac_m: 2d of map scale factor on mass grid
	dx: horizontal grid spacing, m
	---
	Outputs:
	pvu: 3d array of potential vorticity values in PVU (K * m/2 * kg^-1 * s^-1)*10^6
	'''
	assert u.shape == v.shape == theta.shape == pres.shape

	# convert pres to Pa
	pres = pres * 100
	dx = dx * mapfac_m
	dy = dx

	dVp,dVy,dVx = np.gradient(v)
	dUp,dUy,dUx = np.gradient(u)
	dTp,dTy,dTx = np.gradient(theta)
	dp,dPy,dPx = np.gradient(pres)
	PV = -g * (-dVp/dp * dTx/dx + dUp/dp * dTy/dy + (dVx/dx - dUy/dy + f) * dTp/dp)
	pvu = PV * pow(10, 6)
	return pvu

def calc_iwp(temp, pres, qice, qsnow, qgraup, Z, HGT):
	'''
	Calculates the Ice Water Path in kg/m2
	---
	Inputs:
	Need to calculate air density and integrated mixing ratios of all ice hydrometeors
	temp: 3d array of temperature, K
	pres: 3d array of pressure, hPa
	qice: 3d array of ice mixing ratio, kg/kg
	qsnow: 3d array of snow mixing ratio, kg/kkg
	qgraup: 3d array of graupel mixing ratio, kg/kg
	Z: 3d array of height, m
	HGT: 2d array of terrain height
	---
	Outputs:
	iwp: 2d array of ice water path, kg/m2
	'''

	# first calculate 3d density
	rho = pres / (Rd * temp)

	# now calculate IWP
	nlevs = rho.shape[0] # number of vertical levels to integrate through
	iwp = np.zeros_like(qgraup[0,:,:])
	for lev in range(0,nlevs):
		
		# sum up the mixing ratios
		qsum = qice[lev,:,:] + qsnow[lev,:,:] + qgraup[lev,:,:]
	
		# calculate the dz at each point
		if lev == 0:
			dz = Z[0,:,:] - HGT[:,:]	
		else:
			dz = Z[lev,:,:] - Z[lev-1,:,:]

		# increment iwp 
		iwp = iwp + (qsum * dz * rho[lev,:,:])

	return iwp

def calc_lwp(temp, pres, qrain, qcloud, Z, HGT):
	'''
	Calculates the Liquid Water Path in kg/m2
	---
	Inputs:
	Need to calculate air density and integrated mixing ratios of all liquid water hydrometeors
	temp: 3d array of temperature, K
	pres: 3d array of pressure, hPa
	qrain: 3d array of rain water mixing ratio, kg/kg
	qcloud: 3d array of cloud water mixing ratio, kg/kkg
	Z: 3d array of height, m
	HGT: 2d array of terrain height
	---
	Outputs:
	lwp: 2d array of ice water path, kg/m2
	'''

	# first calculate 3d density
	rho = pres / (Rd * temp)

	# now calculate LWP
	nlevs = rho.shape[0] # number of vertical levels to integrate through
	lwp = np.zeros_like(qrain[0,:,:])
	for lev in range(0,nlevs):
		
		# sum up the mixing ratios
		qsum = qrain[lev,:,:] + qcloud[lev,:,:]
	
		# calculate the dz at each point
		if lev == 0:
			dz = Z[0,:,:] - HGT[:,:]	
		else:
			dz = Z[lev,:,:] - Z[lev-1,:,:]

		# increment iwp 
		lwp = lwp + (qsum * dz * rho[lev,:,:])

	return lwp


def wrf_pblh_single(theta, qvapor, pressure, height):
#def calc_pbl(thetav, pressure, height, nlevs, nsites, ntimes):
	''' 
	Calculates the height of the PBL at a single in meters
	Uses method from Coniglio et al. 2013
	Checks profile of ThetaV and looks for height where it begins to increase 
	---
	Inputs: 
	theta: potential temperature profile, K
	pressure: pressure profile, Pa
	qvapor: water vapor mixing ratio, kg/kg
	height: height profile, m
	---
	Outputs:
	pbld: depth of the PBL at that gridpoint, m
	'''

	average_through = 1000 # mb to average thetav through to compare to profile
	STARTAT = 85000 # which pressure level to start looking at? Normally the surface (just put something like 110000 for surface)

	# subsect the arrays to elements only above the STARTAT pressure level
	for idx, pres in enumerate(pressure):
		if pres < STARTAT:
			startid = idx
			break
	theta = theta[startid:]
	qvapor = qvapor[startid:]
	pressure = pressure[startid:]
	height = height[startid:]
	
	# calculate thetav in K
	thetav = calc_thetav(qvapor,theta)

	# get number of vertical levels
	nlevs = np.shape(thetav)[0]

	# first up, average thetav over lowest 25mb
	to_stop = pressure[0] - average_through
	pbl_depth = np.zeros_like(to_stop)
	
	# calculate how many points to average
	for i in range(0,nlevs): # loop through vertical levels
		if pressure[i] < to_stop:
			to_average = i
			break

	# average this number of points
	total = 0
	for i in range(0,to_average):
		total = total + thetav[i]
	thetav_avg = total / to_average
	thetav_avg = thetav_avg + 2 # GIVE IT SOME LEEWAY TO CHECK, NOT THE MOST ACCURATE ASSUMPTION

	# find the level, starting from the point above lowest 25mb
	# define PBL height as first level greater than lowest 25mb average
	level=np.nan # initialize level
	for i in range(to_average,nlevs):
		if thetav[i] >= thetav_avg and thetav[i+1] >= thetav_avg and thetav[i+2] >= thetav_avg:
			level = i
			# check if pbl exists, ie if thetav is already increasing in lowest 25mb
			if i == to_average:
				level = np.nan
			break

	# linear interpolation to find final PBL depth, via Congilio et. al 2013? 
	if np.isfinite(level):
		slope_hght = (height[level] - height[level-1]) / (thetav[level] - thetav[level-1])
		slope_pres = (pressure[level] - pressure[level-1]) / (thetav[level] - thetav[level-1])
		pbld_hght = height[level-1] + (slope_hght * (thetav_avg - thetav[level-1]))
		pbld_pres = pressure[level-1] + (slope_pres * (thetav_avg - thetav[level-1]))
	else:
		pbld_hght = np.nan
		pbld_pres = np.nan

	return pbld_hght, pbld_pres



def wrf_latlong_to_ij(file, long, lat):
	''' 
	Finds the closest grid point in the wrfout file to the given lat and long  
	---
	Inputs: 
	file: wrf output file in netcdf format
	lat: latitude of point
	long: longitude of point
	---
	Outputs:
	i_grid: i grid point corresponding to closest point
	j_grid: j grid point corresponding to closest point
	'''
	from mpl_toolkits.basemap import Basemap
	from netCDF4 import Dataset

	# note, this takes about three seconds to run
	nc = Dataset(file, 'r')

	# get grid sizes
	x_dim = len(nc.dimensions['west_east'])
	y_dim = len(nc.dimensions['south_north'])
	z_dim = len(nc.dimensions['bottom_top'])

	# Get the grid spacing
	dx = float(nc.DX)
	dy = float(nc.DY)
	width_meters = dx * (x_dim - 1)
	height_meters = dy * (y_dim - 1)

	# read in lats to make basemap
	cen_lat = float(nc.CEN_LAT)
	cen_lon = float(nc.CEN_LON)
	truelat1 = float(nc.TRUELAT1)
	truelat2 = float(nc.TRUELAT2)
	standlon = float(nc.STAND_LON)

	# Draw the base map behind it with the lats and
	# lons calculated earlier
	m = Basemap(resolution='i',projection='lcc',\
		width=width_meters,height=height_meters,\
		lat_0=cen_lat,lon_0=cen_lon,lat_1=truelat1,\
		lat_2=truelat2)

	# make a map for the given lat/longs in the wrf file and also get the location on the map where our point is
	x_maps,y_maps = m(nc.variables['XLONG'][0],nc.variables['XLAT'][0])
	x_here,y_here = m(long,lat)

	# find the x,y location on the map closest to our point
	distance = (x_maps - x_here)**2 + (y_maps - y_here)**2
	closest = np.where(distance == distance.min())

	i_grid = closest[1][0]
	j_grid = closest[0][0]

	return (i_grid, j_grid) 
