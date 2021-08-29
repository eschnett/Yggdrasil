# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "MPItrampoline"
version = v"1.1.0"

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://github.com/eschnett/MPItrampoline/archive/refs/tags/v1.1.0.tar.gz",
                  "67fdb710d1ca49487593a9c023e94aa8ff0bec56de6005d1a437fca40833def9"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd MPItrampoline-*
mkdir build
cd build
cmake \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_FIND_ROOT_PATH=$prefix \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DBUILD_SHARED_LIBS=ON \
    ..
cmake --build . --config RelWithDebInfo --parallel $nproc
cmake --build . --config RelWithDebInfo --parallel $nproc --target install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
# Apple: Dynamically loaded libraries (`dlopen`) are not handled correctly.
# Windows: Does not have `dlopen`.
# musl: Does not define `RTLD_DEEPBIND` for `dlopen`.
platforms = filter(p -> !(Sys.isapple(p) || Sys.iswindows(p) || libc(p) == "musl"), platforms)
platforms = expand_gfortran_versions(platforms)
# libgfortran3 does not support `!GCC$ ATTRIBUTES NO_ARG_CHECK`. (We
# could in principle build without Fortran support there.)
platforms = filter(p -> libgfortran_version(p) ≠ v"3", platforms)

# TODO: on 32-bit systems, Fortran `MPI_Status` has the wrong size

# The products that we will ensure are always built
products = [
    ExecutableProduct("mpicc", :mpicc),
    ExecutableProduct("mpicxx", :mpicxx),
    ExecutableProduct("mpifc", :mpifc),
    ExecutableProduct("mpifort", :mpifort),
    ExecutableProduct("mpiexec", :mpiexec),

    # We need to call this library `:libmpi` in Julia so that Julia's
    # `MPI.jl` will find it
    LibraryProduct("libmpi", :libmpi),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
