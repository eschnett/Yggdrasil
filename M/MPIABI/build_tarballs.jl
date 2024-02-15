using BinaryBuilder, Pkg
using Base.BinaryPlatforms
const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "platforms", "mpi.jl"))

name = "MPIABI"
version = v"4.2.0"

sources = [
    GitSource("https://github.com/mpiwg-abi/header_and_stub_library", "8d187fc938c59f54e0435718dc16e45812904c2c"),
]

script = raw"""
cd header_and_stub_library
cmake -Bbuild -DCMAKE_FIND_ROOT_PATH=${prefix} -DCMAKE_INSTALL_PREFIX=${prefix} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}
cmake --build build --parallel ${nproc}
cmake --install build
"""

augment_platform_block = """
    using Base.BinaryPlatforms
    $(MPI.augment)
    augment_platform!(platform::Platform) = augment_mpi!(platform)
"""

platforms = supported_platforms()

# Add `mpi+mpiabi` platform tag
for p in platforms
    p["mpi"] = "MPIABI"
end

products = [
    LibraryProduct("libmpi_abi", :libmpi),
]

dependencies = [
    Dependency(PackageSpec(name="MPIPreferences", uuid="3da0fdf6-3ccc-4f1b-acd9-58baa6c99267");
               compat="0.1", top_level=true),
]

# Build the tarballs.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               augment_platform_block, julia_compat="1.6")
