# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg
using Base.BinaryPlatforms
const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "platforms", "mpi.jl"))

name = "ADIOS2"
version = v"2.9.0"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/ornladios/ADIOS2.git", "aac4a45fdd05fda62a80b1f5a4d174faade32f3c"),
    DirectorySource("./bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd ADIOS2
# Don't define clock_gettime on macOS
atomic_patch -p1 ${WORKSPACE}/srcdir/patches/clock_gettime.patch

mkdir build
cd build

archopts=()

if grep -q MSMPI_VER ${prefix}/include/mpi.h; then
    # Microsoft MPI
    # # Hide static libraries
    # rm ${prefix}/lib/msmpi*.lib
    # # Make shared libraries visible
    # ln -s msmpi.dll ${libdir}/libmsmpi.dll
    # export FCFLAGS="$FCFLAGS -I${prefix}/src -I${prefix}/include -fno-range-check"
    # export LIBS="-L${libdir} -lmsmpi"
    # archopts="-DMPI_GUESS_LIBRARY_NAME=MSMPI -DMPI_C_LIBRARIES=msmpi -DMPI_CXX_LIBRARIES=msmpi -DMPI_Fortran_LIBRARIES=msmpi -DADIOS2_USE_SST=OFF -DADIOS2_USE_Table=OFF"
    archopts+=(-DMPI_C_ADDITIONAL_INCLUDE_DIRS= -DMPI_C_LIBRARIES=$libdir/msmpi.dll
               -DMPI_CXX_ADDITIONAL_INCLUDE_DIRS= -DMPI_CXX_LIBRARIES=$libdir/msmpi.dll
               -DMPI_Fortran_ADDITIONAL_INCLUDE_DIRS= -DMPI_Fortran_LIBRARIES=$libdir/msmpi.dll)
fi

if [[ "$target" == *-mingw* ]]; then
    # Windows: Some options do not build
    archopts+=(-DADIOS2_USE_DataMan=OFF -DADIOS2_USE_SST=OFF -DADIOS2_USE_Table=OFF)
else
    archopts+=(-DADIOS2_USE_DataMan=ON -DADIOS2_USE_SST=ON -DADIOS2_USE_Table=ON)
fi

if grep -q MPICH_NAME $prefix/include/mpi.h && ls /usr/include/*/sys/queue.hh >/dev/null 2>&1; then
    # This feature only works with MPICH
    archopts+=(-DADIOS2_HAVE_MPI_CLIENT_SERVER_EXITCODE=0 -DADIOS2_HAVE_MPI_CLIENT_SERVER_EXITCODE__TRYRUN_OUTPUT=)
else
    archopts+=(-DADIOS2_HAVE_MPI_CLIENT_SERVER_EXITCODE=1 -DADIOS2_HAVE_MPI_CLIENT_SERVER_EXITCODE__TRYRUN_OUTPUT=)
fi

# Fortran is not supported with Clang
cmake \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_FIND_ROOT_PATH=$prefix \
    -DBUILD_TESTING=OFF \
    -DADIOS2_BUILD_EXAMPLES=OFF \
    -DADIOS2_HAVE_ZFP_CUDA=OFF \
    -DADIOS2_USE_Blosc2=ON \
    -DADIOS2_USE_CUDA=OFF \
    -DADIOS2_USE_Fortran=OFF \
    -DADIOS2_USE_MPI=ON \
    -DADIOS2_USE_PNG=ON \
    -DADIOS2_USE_SZ=ON \
    -DADIOS2_USE_ZeroMQ=ON \
    -DMPI_HOME=$prefix \
    ${archopts[@]} \
    -DADIOS2_INSTALL_GENERATE_CONFIG=OFF \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    ..
cmake --build . --config RelWithDebInfo --parallel $nproc
cmake --build . --config RelWithDebInfo --parallel $nproc --target install
install_license ../Copyright.txt ../LICENSE
"""

augment_platform_block = """
    using Base.BinaryPlatforms
    $(MPI.augment)
    augment_platform!(platform::Platform) = augment_mpi!(platform)
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
# 32-bit architectures are not supported; see
# <https://github.com/ornladios/ADIOS2/issues/2704>
platforms = filter(p -> nbits(p) ≠ 32, platforms)
platforms = expand_cxxstring_abis(platforms)
# Windows doesn't build with libcxx="cxx03"
platforms = expand_gfortran_versions(platforms)

platforms, platform_dependencies = MPI.augment_platforms(platforms)

# Avoid platforms where the MPI implementation isn't supported
# OpenMPI
platforms = filter(p -> !(p["mpi"] == "openmpi" && arch(p) == "armv6l" && libc(p) == "glibc"), platforms)
# MPItrampoline
platforms = filter(p -> !(p["mpi"] == "mpitrampoline" && libc(p) == "musl"), platforms)
platforms = filter(p -> !(p["mpi"] == "mpitrampoline" && Sys.isfreebsd(p)), platforms)

# The products that we will ensure are always built
products = [
    # ExecutableProduct("adios_deactivate_bp", :adios_deactivate_bp),
    # ExecutableProduct("adios_iotest", :adios_iotest),
    # ExecutableProduct("adios_reorganize", :adios_reorganize),
    # ExecutableProduct("adios_reorganize_mpi", :adios_reorganize_mpi),
    # ExecutableProduct("bp4dbg", :bp4dbg),
    ExecutableProduct("bpls", :bpls),
    # ExecutableProduct("sst_conn_tool", :sst_conn_tool),

    LibraryProduct("libadios2_c", :libadios2_c),
    LibraryProduct("libadios2_c_mpi", :libadios2_c_mpi),
    LibraryProduct("libadios2_core", :libadios2_core),
    LibraryProduct("libadios2_core_mpi", :libadios2_core_mpi),
    LibraryProduct("libadios2_cxx11", :libadios2_cxx11),
    LibraryProduct("libadios2_cxx11_mpi", :libadios2_cxx11_mpi),

    # Missing on Apple:
    # LibraryProduct("libadios2_taustubs", :libadios2_taustubs),

    # Missing on Windows:
    # LibraryProduct("libadios2_atl", :libadios2_atl),
    # LibraryProduct("libadios2_dill", :libadios2_dill),
    # LibraryProduct("libadios2_evpath", :libadios2_evpath),
    # LibraryProduct("libadios2_ffs", :libadios2_ffs),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="Blosc2_jll")),
    Dependency(PackageSpec(name="Bzip2_jll"); compat="1.0.8"),
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae"), v"0.5.2"),
    # We cannot use HDF5 because we need an HDF5 configuration with MPI support
    # Dependency(PackageSpec(name="HDF5_jll")),
    Dependency(PackageSpec(name="SZ_jll")),
    Dependency(PackageSpec(name="ZeroMQ_jll")),
    Dependency(PackageSpec(name="libpng_jll")),
    Dependency(PackageSpec(name="zfp_jll")),
]
append!(dependencies, platform_dependencies)

# Build the tarballs, and possibly a `build.jl` as well.
# GCC 4 is too old for Windows; it doesn't have <regex.h>
# GCC 5 is too old for FreeBSD; it doesn't have `std::to_string`
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               augment_platform_block, julia_compat="1.6", preferred_gcc_version=v"6")
