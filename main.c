#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "mpi.h"
#include "cuda.h"
#include "cuda_runtime.h"

// Julia headers (for initialization and gc commands)
#include "uv.h"
#include "julia.h"
#include "diffusion.h"

JULIA_DEFINE_FAST_TLS()

int main(int argc, char *argv[])
{
  // Initialization of libuv and julia
  uv_setup_args(argc, argv);
  libsupport_init();
  jl_parse_opts(&argc, &argv);
  jl_options.image_file = JULIAC_PROGRAM_LIBNAME;  // JULIAC_PROGRAM_LIBNAME defined on command-line for compilation
  julia_init(JL_IMAGE_JULIA_HOME);

  const int NDIMS = 2;
  int ret, nprocs, me, reorder = 0;
  int dims[] = {0,0}, coords[] = {0,0}, periods[] = {0,0};
  MPI_Comm comm=MPI_COMM_NULL;

  // Numerics
  size_t nx     = 64;      // Number of grid points in x dimension
  size_t ny     = 64;      // Number of grid points in y dimension
  size_t nt     = 1000;    // Number of time steps

  // Physics
  double lx     = 10.0;    // Length of domain in x dimension
  double ly     = 10.0;    // Length of domain in y dimension
  double lam    = 1.0;     // Thermal conductivity
  double cp_min = 1.0;     // Minimal heat capacity
  double amp_T  = 100.0;   // Amplitude of Gaussian anomly in temperature field

  double *Cp = (double *)malloc(nx*ny*sizeof(double));  // Heat capacity field
  double *Cp_d;

  // Create Cartesian process topology
  MPI_Init(&argc, &argv);
  MPI_Comm_size(MPI_COMM_WORLD, &nprocs);
  MPI_Dims_create(nprocs, NDIMS, dims);
  MPI_Cart_create(MPI_COMM_WORLD, NDIMS, dims, periods, reorder, &comm);
  MPI_Comm_rank(comm, &me);
  MPI_Cart_coords(comm, me, NDIMS, coords);

  // Initialize the heat capacity field
  for (int ix=0; ix<nx; ix++){
    for (int iy=0; iy<ny; iy++){
      Cp[iy*nx+ix] = cp_min + (coords[1]*ny + iy) / (dims[1]*(ny-2) + 2);
    }
  };

  // Copy the heat capacity field to GPU
  cudaMalloc((void **)&Cp_d, (size_t)nx*ny*sizeof(double));
  cudaMemcpy(Cp_d, Cp, (size_t)nx*ny*sizeof(double), cudaMemcpyHostToDevice);

  // Simulate heat diffusion calling shared library created by compiling Julia code (Diffusion.jl)
  ret = julia_diffusion(nx, ny, nt, lx, ly, lam, cp_min, amp_T, Cp_d, comm);

  // Exit gracefully
  free(Cp);
  cudaFree(Cp_d);
  MPI_Finalize();
  jl_atexit_hook(ret);
  return ret;
}
