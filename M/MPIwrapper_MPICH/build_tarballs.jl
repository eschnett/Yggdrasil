# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "MPIwrapper_MPICH"
version = v"2.0.0"

# Collection of sources required to complete build
sources = [
    # ArchiveSource("https://github.com/eschnett/MPItrampoline/archive/refs/tags/v1.1.0.tar.gz",
    #               "67fdb710d1ca49487593a9c023e94aa8ff0bec56de6005d1a437fca40833def9"),
    ArchiveSource("https://github.com/eschnett/MPIwrapper/archive/2ab9f22d99cfb027f32a6a6a232311fa548e74aa.tar.gz",
                  "f24c0435e851d4135cc492f0cf1919e1852849c16661106a5b4837873cb54e8c"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd MPIwrapper-*
mkdir build
cd build
cmake \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_FIND_ROOT_PATH=$prefix \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DBUILD_SHARED_LIBS=ON \
    -DMPI_C_COMPILER=cc \
    -DMPI_CXX_COMPILER=c++ \
    -DMPI_Fortran_COMPILER=gfortran \
    -DMPI_CXX_LIB_NAMES='mpicxx;mpi;pmpi' \
    -DMPI_Fortran_LIB_NAMES='mpifort;mpi;pmpi' \
    -DMPI_mpi_LIBRARY=$prefix/lib/libmpi.dylib \
    -DMPI_mpicxx_LIBRARY=$prefix/lib/libmpicxx.dylib \
    -DMPI_mpifort_LIBRARY=$prefix/lib/libmpifort.dylib \
    -DMPI_pmpi_LIBRARY=$prefix/lib/libpmpi.dylib \
    -DMPIEXEC_EXECUTABLE=$prefix/bin/mpiexec \
    ..
cmake --build . --config RelWithDebInfo --parallel $nproc
cmake --build . --config RelWithDebInfo --parallel $nproc --target install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
# This package provides a plugin `libmpiwrapper.so` that has a
# well-defined ABI. It is not necessary to take C++ or Fortran ABIs
# into account.

# The products that we will ensure are always built
products = [
    ExecutableProduct("mpiwrapperexec", :mpiwrapperexec),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
    #TODO Dependency(PackageSpec(name="MPICH_jll")),
    Dependency(PackageSpec(name="MPICH_jll",
                           uuid="7cb0a576-ebde-5e09-9194-50597f1243b4",
                           path="$(ENV["HOME"])/.julia/dev/MPICH_jll")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
