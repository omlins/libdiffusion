import Diffusion  # Requires to do Pkg.activate(".) in the project's top level folder.

import MPI
using CUDA

MPI.Init()
comm = MPI.COMM_WORLD

# Numerics
nx     = 128;     # Number of grid points in x dimension
ny     = 128;     # Number of grid points in y dimension
nt     = 1000;    # Number of time steps

# Physics
lx     = 10.0;    # Length of domain in x dimension
ly     = 10.0;    # Length of domain in y dimension
lam    = 1.0;     # Thermal conductivity
cp_min = 1.0;     # Minimal heat capacity
amp_T  = 100.0;   # Amplitude of Gaussian anomly in temperature field

Cp = zeros(Float64, nx, ny) # Heat capacity field

for ix = 1:nx
    for iy = 1:ny
        Cp[ix,iy] = cp_min + iy/ny;
    end
end

# Copy field Cp to GPU
Cp_d = CuArray(Cp)

# Simulate heat diffusion calling directly the diffusion routine.
Diffusion.diffusion2D(nx, ny, nt, lx, ly, lam, cp_min, amp_T, Cp_d, comm)

# Simulate heat diffusion calling the C interface of the diffusion routine.
Diffusion.julia_diffusion(Csize_t(nx), Csize_t(ny), Csize_t(nt), Cdouble(lx), Cdouble(ly), Cdouble(lam), Cdouble(cp_min), Cdouble(amp_T), pointer(Cp_d), comm.val)

MPI.Finalize()
