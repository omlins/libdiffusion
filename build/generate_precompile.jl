using Diffusion
import MPI
using CUDA

MPI.Init()
nx = ny                        = Csize_t(8)
nt                             = Csize_t(100)
lx = ly = lam = cp_min = amp_T = Cdouble(42.0)
Cp_d                           = pointer(CUDA.ones(Cdouble, nx, ny))
comm                           = MPI.COMM_WORLD.val

Diffusion.julia_diffusion(nx, ny, nt, lx, ly, lam, cp_min, amp_T, Cp_d, comm)

MPI.Finalize()
