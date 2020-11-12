import MPI
using CUDA

precompile(Tuple{typeof(Diffusion.julia_diffusion), UInt64, UInt64, UInt64, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble, CuPtr{Cdouble}, MPI.MPI_Comm})
