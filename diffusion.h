#include "mpi.h"

// Julia headers (for initialization and gc commands)
#include "uv.h"
#include "julia.h"

// prototype of the C entry points in our application
int julia_diffusion(size_t nx, size_t ny, size_t nt, double lx, double ly, double lam, double cp_min, double T_amp, double *Cp_d, MPI_Comm comm);
