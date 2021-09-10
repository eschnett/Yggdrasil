using BinaryBuilder, Pkg

name = "OpenMPI"
version = v"4.1.1"
sources = [
    ArchiveSource("https://download.open-mpi.org/release/open-mpi/v$(version.major).$(version.minor)/openmpi-$(version).tar.gz",
                  "d80b9219e80ea1f8bcfe5ad921bd9014285c4948c5965f4156a3831e60776444"),
    DirectorySource("./bundled"),
    # ArchiveSource("https://github.com/eschnett/MPIwrapper/archive/refs/tags/v2.0.0.tar.gz",
    #               "67fdb710d1ca49487593a9c023e94aa8ff0bec56de6005d1a437fca40833def9"),
    ArchiveSource("https://github.com/eschnett/MPIwrapper/archive/944befaecb0d1e7886222911cb96528df72af685.tar.gz",
                  "d4cc2d7e2721f782873c59b1d55dab0fcd2b1b26ef883bfbe52d3e034509272e"),
]

script = raw"""
################################################################################
# Install OpenMPI
################################################################################

# Enter the funzone
cd ${WORKSPACE}/srcdir/openmpi-*

if [[ "${target}" == *-freebsd* ]]; then
    # Help compiler find `complib/cl_types.h`.
    export CPPFLAGS="-I/opt/${target}/${target}/sys-root/include/infiniband"
fi

./configure --prefix=${prefix} \
    --build=${MACHTYPE} \
    --host=${target} \
    --enable-shared=yes \
    --enable-static=no \
    --without-cs-fs \
    --enable-mpi-fortran=usempif08 \
    --with-hwloc=${prefix} \
    --with-cross=${WORKSPACE}/srcdir/${target}

# Build the library
make -j${nproc}

# Install the library
make install

install_license LICENSE

################################################################################
# Install MPIwrapper
################################################################################

cd $WORKSPACE/srcdir/MPIwrapper-*
mkdir build
cd build
suffix=so
if [[ "${target}" == *-apple-* ]]; then
    suffix=dylib
fi
cmake \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_FIND_ROOT_PATH=$prefix \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DBUILD_SHARED_LIBS=ON \
    -DMPI_CXX_COMPILER=c++ \
    -DMPI_Fortran_COMPILER=gfortran \
    -DMPI_CXX_LIB_NAMES='mpi' \
    -DMPI_Fortran_LIB_NAMES='mpi_usempif08;mpi_usempi_ignore_tkr;mpi_mpifh;mpi' \
    -DMPI_mpi_LIBRARY=$prefix/lib/libmpi.$suffix \
    -DMPI_mpi_mpifh_LIBRARY=$prefix/lib/libmpi_mpifh.$suffix \
    -DMPI_mpi_usempi_ignore_tkr_LIBRARY=$prefix/lib/libmpi_usempi_ignore_tkr.$suffix \
    -DMPI_mpi_usempif08_LIBRARY=$prefix/lib/libmpi_usempif08.$suffix \
    -DMPIEXEC_EXECUTABLE=$prefix/bin/mpiexec \
    ..
cmake --build . --config RelWithDebInfo --parallel $nproc
cmake --build . --config RelWithDebInfo --parallel $nproc --target install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line.
platforms = supported_platforms(; experimental=true)
platforms = filter(!Sys.iswindows, platforms)
# Why?
platforms = filter(p -> !(arch(p) == "armv6l" && libc(p) == "glibc"), platforms)
# OpenMPI uses a 32-bit `MPI_Count` on 32-bit platforms, but
# MPIwrapper always uses 64 bits. MPIwrapper cannot handle this
# difference yet.
platforms = filter(p -> nbits(p) == 64, platforms)
# aarch64-apple-darwin-libgfortran5 does not have `MPI_COMPLEX32`,
# which is currently required by MPIwrapper
platforms = filter(p -> !(arch(p) == "aarch64" && Sys.isapple(p)), platforms)
platforms = expand_gfortran_versions(platforms)
    
products = [
    # OpenMPI
    LibraryProduct("libmpi", :libmpi),
    ExecutableProduct("mpiexec", :mpiexec),
    # MPIwrapper
    ExecutableProduct("mpiwrapperexec", :mpiwrapperexec),
]

dependencies = [
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
    Dependency("Hwloc_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"5")
