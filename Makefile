OS := $(shell uname)
DLEXT := $(shell julia -e 'using Libdl; print(Libdl.dlext)')

JULIA := julia
JULIA_DIR := $(shell $(JULIA) -e 'print(dirname(Sys.BINDIR))')
MAIN := main

ifeq ($(OS), WINNT)
  MAIN := $(MAIN).exe
endif

ifeq ($(OS), Darwin)
  WLARGS := -Wl,-rpath,"$(JULIA_DIR)/lib" -Wl,-rpath,"@executable_path -Wl,-rpath,"$(JULIA_DIR)/lib/julia"
else
  WLARGS := -Wl,-rpath,"$(JULIA_DIR)/lib:$$ORIGIN" -Wl,-rpath,"$(JULIA_DIR)/lib/julia:$$ORIGIN"
endif

CC=$(JULIA_MPICC)
CFLAGS+=-O2 -fPIE -I$(JULIA_DIR)/include/julia  # Add here CUDA include flag if needed (automatic with Cray wrapper)
LDFLAGS+=-L$(JULIA_DIR)/lib -L. -ljulia -lm $(WLARGS)  # Add here CUDA link flag if needed (automatic with Cray wrapper)

.DEFAULT_GOAL := main

libdiffusion.$(DLEXT): build/build.jl src/Diffusion.jl build/generate_precompile.jl build/additional_precompile.jl
	JULIA_CUDA_USE_BINARYBUILDER=false JULIA_MPI_BINARY=system $(JULIA) --startup-file=no --project=. -e 'using Pkg; Pkg.add(url="https://github.com/eth-cscs/ImplicitGlobalGrid.jl")' # Note: unregistered packages need to be added before instantiation.
	JULIA_CUDA_USE_BINARYBUILDER=false JULIA_MPI_BINARY=system $(JULIA) --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) --startup-file=no --project=build -e 'using Pkg; Pkg.instantiate()'
	JULIA_CUDA_USE_BINARYBUILDER=false $(JULIA_MPIEXEC) $(JULIA_MPIEXEC_ARGS) $(JULIA) --startup-file=no --project=build $<

main.o: main.c
	$(CC) $^ -c -o $@ $(CFLAGS) -DJULIAC_PROGRAM_LIBNAME=\"libdiffusion.$(DLEXT)\"

$(MAIN): main.o libdiffusion.$(DLEXT)
	$(CC) -o $@ $< $(LDFLAGS) -ldiffusion

.PHONY: clean
clean:
	$(RM) *~ *.o *.$(DLEXT) main
