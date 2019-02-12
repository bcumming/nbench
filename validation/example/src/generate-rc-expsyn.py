import math
import scipy.integrate as integrate
import numpy as np
import xarray

rm =     100;    # total membrane resistance [MΩ]
cm =    0.01;    # total membrane capacitance [nF]
Erev =   -65;    # reversal potential [mV]
syntau = 1.0;    # synapse exponential time constant [ms]
syng0 =  0.1;   # synaptic conductance at time zero [µS] 

# Voltage given by ODE:
#
# cm · dv/dt = - 1/rm · (v - Erev) - syng0 · exp(-t/syntau) · v
#
# Solution is:
#
# v(t) = Erev · exp(-F(t)) · (F(0) + 1/tau · integral(exp(F(u)), u=0..t)
# where:
#     tau = rm · cm
#     F(u) = u/tau - syntau · syng0 · exp(-u/syntau).
#
# But it's empirically better just to use LSODA on the ODE directly.


def membrane_conductance(t, v):
    return 1/rm + syng0*math.exp(-t/syntau)

def dv_dt(t, v):
    return -1/cm * (membrane_conductance(t, v)*v - Erev/rm)

def jacobian(t, v):
    return np.array([[-1/cm * membrane_conductance(t, v)]])

# RC time constant is rm*cm = 1 ms; simulate up to 10 ms.

tend = 10.
nsamp = 1000
ts = np.linspace(0., tend, num=nsamp)

result = integrate.solve_ivp(dv_dt, (0., tend), [Erev], method='LSODA', t_eval=ts, jac=jacobian, atol=1e-10/nsamp, rtol=1e-10/nsamp)

#print(result.y[0])

out = xarray.Dataset({'voltage': (['time'], result.y[0])}, coords={'time': ts})
out.to_netcdf('genout.nc')

