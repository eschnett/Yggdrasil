# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder
using Pkg

name = "Dyninst"
version = v"12.3.0"

# Collection of sources required to build hwloc
sources = [
    GitSource("https://github.com/dyninst/dyninst", "334b6856e28fd34a698ad74aa277f1399a814183"),
    DirectorySource("bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/dyninst

rm -f /usr/share/cmake/Modules/Compiler/._*.cmake

# Find newer versions of TBB which are installed in a different directory structure
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/tbb-version.patch"
# Handle missing enum constants
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/df_1_pie.patch"
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/dt_flags_1.patch"
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/em_amdgpu.patch"
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/r_x86_64_rex_gotpcrelx.patch"

cmake -B build -S . \
    -DCMAKE_FIND_ROOT_PATH=${prefix} \
    -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}
    # -DBUILD_SHARED_LIBS=ON
    # -DBUILD_TESTING=OFF
    # -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel ${nproc}
cmake --build build --parallel ${nproc} --target install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
platforms = expand_cxxstring_abis(platforms)

# Binutils and Elfutils require Linux
filter!(Sys.islinux, platforms)

# The products that we will ensure are always built
products = [
    ExecutableProduct("parseThat", :parseThat),
    LibraryProduct("libcommon", :libcommon),
    LibraryProduct("libdynC_API", :libdynC_API),
    LibraryProduct("libdynDwarf", :libdynDwarf),
    LibraryProduct("libdynElf", :libdynElf),
    LibraryProduct("libdyninstAPI", :libdyninstAPI),
    LibraryProduct("libdyninstAPI_RT", :libdyninstAPI_RT),
    LibraryProduct("libinstructionAPI", :libinstructionAPI),
    LibraryProduct("libparseAPI", :libparseAPI),
    LibraryProduct("libparseThat", :libparseThat),
    LibraryProduct("libpatchAPI", :libpatchAPI),
    LibraryProduct("libpcontrol", :libpcontrol),
    LibraryProduct("libstackwalk", :libstackwalk),
    LibraryProduct("libsymLite", :libsymLite),
    LibraryProduct("libsymtabAPI", :libsymtabAPI),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
    # We need at least v2.41 of Binutils_jll to get an `-fPIC` version of `libiberty.a`
    Dependency("Binutils_jll"; compat="2.41"),
    # We require at least v0.186 of Elfutils
    Dependency("Elfutils_jll"; compat="0.189"),
    # We require at least v2019.7 of oneTBB
    Dependency("oneTBB_jll"; compat="2021.8.0"),
    # We require at least v1.70.0 of Boost
    Dependency("boost_jll"; compat="1.79.0"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"7")
