module Diffusion

import MPI
using ImplicitGlobalGrid
using CUDA
using Plots

@views d_xa(A) = A[2:end  , :     ] .- A[1:end-1, :     ];
@views d_xi(A) = A[2:end  ,2:end-1] .- A[1:end-1,2:end-1];
@views d_ya(A) = A[ :     ,2:end  ] .- A[ :     ,1:end-1];
@views d_yi(A) = A[2:end-1,2:end  ] .- A[2:end-1,1:end-1];
@views  inn(A) = A[2:end-1,2:end-1]

@views function diffusion2D(nx, ny, nt, lx, ly, lam, cp_min, amp_T, Cp, comm)
    # Numerics
    me, dims = init_global_grid(nx, ny, 1; init_MPI=false, comm=comm, reorder=0)  # Initialize the implicit global grid
    dx       = lx/(nx_g()-1)                                                      # Space step in dimension x
    dy       = ly/(ny_g()-1)                                                      # ...        in dimension y

    # Array initializations
    T     = CUDA.zeros(Float64, nx,   ny, )
    dTedt = CUDA.zeros(Float64, nx-2, ny-2)
    qx    = CUDA.zeros(Float64, nx-1, ny-2)
    qy    = CUDA.zeros(Float64, nx-2, ny-1)

    # Initialize temperature with a Gaussian anomaly of amplitude amp_T
    T    .= CuArray([amp_T*exp(-((x_g(ix,dx,T)-lx/2)/2)^2-((y_g(iy,dy,T)-ly/2)/2)^2) for ix=1:size(T,1), iy=1:size(T,2)])

    # Preparation of visualisation
    gr()
    ENV["GKSwstype"]="nul"
    anim     = Animation();
    nx_v     = (nx-2)*dims[1]
    ny_v     = (ny-2)*dims[2]
    T_v      = zeros(nx_v, ny_v)
    T_nohalo = zeros(nx-2, ny-2)

    # Time loop
    nframes = 50
    dt = min(dx,dy)^2*cp_min/lam/4.1                            # Time step for the 2D Heat diffusion
    for it = 1:nt
        qx    .= -lam.*d_xi(T)./dx                              # Fourier's law of heat conduction: q_x   = -λ δT/δx
        qy    .= -lam.*d_yi(T)./dy                              # ...                               q_y   = -λ δT/δy
        dTedt .= 1.0./inn(Cp).*(-d_xa(qx)./dx .- d_ya(qy)./dy)  # Conservation of energy:           δT/δt = 1/cₚ (-δq_x/δx - δq_y/dy)
        T[2:end-1,2:end-1] .= inn(T) .+ dt.*dTedt               # Update of temperature             T_new = T_old + δT/δt
        update_halo!(T)                                         # Update the halo of T
        if mod(it, nt/nframes) == 1
            T_nohalo .= T[2:end-1,2:end-1]                      # Copy data to CPU removing the halo.
            gather!(T_nohalo, T_v)                              # Gather the global temperature field on process 0.
            if (me==0)                                          # Visualize it on process 0.
                println("Time step $it: maximum temperature is $(maximum(T_v))")
                heatmap(T_v, aspect_ratio=1); frame(anim)
            end
        end
    end

    # Postprocessing
    if (me==0) gif(anim, "diffusion2D.gif", fps = 15) end       # Create an animated gif on process 0.
    finalize_global_grid(;finalize_MPI=false)
end

Base.@ccallable function julia_diffusion(nx::Csize_t, ny::Csize_t, nt::Csize_t, lx::Cdouble, ly::Cdouble, lam::Cdouble, cp_min::Cdouble, amp_T::Cdouble, Cp_c::CuPtr{Cdouble}, comm_c::MPI.MPI_Comm)::Cint
    try
        comm = MPI.Comm_dup(MPI.Comm(comm_c))
        Cp   = unsafe_wrap(CuArray, Cp_c, (Int64(nx), Int64(ny)))
        diffusion2D(nx, ny, nt, lx, ly, lam, cp_min, amp_T, Cp, comm)
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

end # module
