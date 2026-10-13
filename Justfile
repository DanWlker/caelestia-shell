install:
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DENABLE_MODULES="extras;plugin"  -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DCMAKE_INSTALL_LIBDIR=lib
    cmake --build build --target version
    cmake --build build
    cmake --install build
