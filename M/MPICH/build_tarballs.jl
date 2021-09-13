using BinaryBuilder, Pkg

name = "MPICH"
version = v"3.4.2"

sources = [
    ArchiveSource("https://www.mpich.org/static/downloads/$(version)/mpich-$(version).tar.gz",
                  "5c19bea8b84e8d74cca5f047e82b147ff3fba096144270e3911ad623d6c587bf"),
]

script = raw"""
# Enter the funzone
cd ${WORKSPACE}/srcdir/mpich*

EXTRA_FLAGS=()
if [[ "${target}" != i686-linux-gnu ]] || [[ "${target}" != x86_64-linux-* ]]; then
    # Define some obscure undocumented variables needed for cross compilation of
    # the Fortran bindings.  See for example
    # * https://stackoverflow.com/q/56759636/2442087
    # * https://github.com/pmodels/mpich/blob/d10400d7a8238dc3c8464184238202ecacfb53c7/doc/installguide/cfile
    export CROSS_F77_SIZEOF_INTEGER=4
    export CROSS_F77_SIZEOF_REAL=4
    export CROSS_F77_SIZEOF_DOUBLE_PRECISION=8
    export CROSS_F77_FALSE_VALUE=0
    export CROSS_F77_TRUE_VALUE=1

    if [[ ${nbits} == 32 ]]; then
        export CROSS_F90_ADDRESS_KIND=4
        export CROSS_F90_OFFSET_KIND=4
    else
        export CROSS_F90_ADDRESS_KIND=8
        export CROSS_F90_OFFSET_KIND=8
    fi
    export CROSS_F90_INTEGER_KIND=4
    export CROSS_F90_INTEGER_MODEL=9
    export CROSS_F90_REAL_MODEL=6,37
    export CROSS_F90_DOUBLE_MODEL=15,307
    export CROSS_F90_ALL_INTEGER_MODELS=2,1,4,2,9,4,18,8,
    export CROSS_F90_INTEGER_MODEL_MAP={2,1,1},{4,2,2},{9,4,4},{18,8,8},

    if [[ "${target}" == i686-linux-musl ]]; then
        # Our `i686-linux-musl` platform is a bit rotten: it can run C programs,
        # but not C++ or Fortran.  `configure` runs a C program to determine
        # whether it's cross-compiling or not, but when it comes to running
        # Fortran programs, it fails.  In addition, `configure` ignores the
        # above exported variables if it believes it's doing a native build.
        # Small hack: edit `configure` script to force `cross_compiling` to be
        # always "yes".
        sed -i 's/cross_compiling=no/cross_compiling=yes/g' configure
        EXTRA_FLAGS+=(ac_cv_sizeof_bool="1")
    fi
fi

if [[ "${target}" == aarch64-apple-* ]]; then
    export FFLAGS=-fallow-argument-mismatch
fi

if [[ "${target}" == *-apple-* ]]; then
    # MPICH uses the link options `-flat_namespace` on Darwin. This
    # conflicts with MPItrampoline, which requires the option
    # `-twolevel_namespace`.
    EXTRA_FLAGS+=(--enable-two-level-namespace)
fi


./configure \
    --prefix=${prefix} \
    --docdir=/tmp \
    --build=${MACHTYPE} \
    --host=${target} \
    --disable-dependency-tracking \
    --enable-shared=yes \
    --enable-static=no \
    --with-device=ch3 \
    --with-hwloc-prefix=${prefix}
    "${EXTRA_FLAGS[@]}"

# Remove empty `-l` flags from libtool
# (Why are they there? They should not be.)
# Run the command several times to handle multiple (overlapping) occurrences.
sed -i 's/"-l /"/g;s/ -l / /g;s/-l"/"/g' libtool
sed -i 's/"-l /"/g;s/ -l / /g;s/-l"/"/g' libtool
sed -i 's/"-l /"/g;s/ -l / /g;s/-l"/"/g' libtool

# Build the library
make -j${nproc}

# Install the library
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line.
platforms = supported_platforms(; experimental=true)
platforms = filter(!Sys.iswindows, platforms)
platforms = expand_gfortran_versions(platforms)

products = [
    # MPICH
    LibraryProduct("libmpicxx", :libmpicxx),
    LibraryProduct("libmpifort", :libmpifort),
    LibraryProduct("libmpi", :libmpi),
    ExecutableProduct("mpiexec", :mpiexec),
]

dependencies = [
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
    Dependency("Hwloc_jll"),
]

# Build the tarballs.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
