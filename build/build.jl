using PackageCompiler, Libdl

PackageCompiler.create_sysimage(Symbol[:Diffusion];
                                project=joinpath(@__DIR__, ".."),
                                precompile_execution_file=[joinpath(@__DIR__, "generate_precompile.jl")],
                                precompile_statements_file=[joinpath(@__DIR__, "additional_precompile.jl")],
                                sysimage_path=joinpath(@__DIR__, "..", "libdiffusion.$(Libdl.dlext)"),
                                incremental=false,
                                filter_stdlibs=true)
