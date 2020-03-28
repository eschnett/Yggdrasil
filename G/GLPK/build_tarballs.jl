using BinaryBuilder, Pkg

name = "GLPK"
version = v"4.64"

# Collection of sources required to build GLPKBuilder
sources = [
    ArchiveSource("http://ftpmirror.gnu.org/gnu/glpk/glpk-$(version.major).$(version.minor).tar.gz",
                  "539267f40ea3e09c3b76a31c8747f559e8a097ec0cda8f1a3778eec3e4c3cc24"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/glpk-*
export LDFLAGS="-L${prefix}/lib"
if [ $target = "x86_64-w64-mingw32" ] || [ $target = "i686-w64-mingw32" ]; then
    export CPPFLAGS="-I${prefix}/include -D__WOE__=1";
else
    export CPPFLAGS="-I${prefix}/include";
fi
./configure --prefix=$prefix --host=${target} --with-gmp
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libglpk", :libglpk)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("GMP_jll")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
