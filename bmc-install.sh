#!/bin/bash

sudo apt update
sudo apt install -y linux-tools-common linux-tools-`uname -r` htop numactl

ARCH=$(uname -m)

# Check Ubuntu major version
UBUNTU_VERSION=$(lsb_release -rs | cut -d. -f1)
if [ "$UBUNTU_VERSION" -ge 22 ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt -y install gpg curl tar xz-utils make gcc flex bison libssl-dev libelf-dev autoconf automake libtool pkg-config m4 libz3-dev libevent-dev libtinfo5
    
    if [ "$ARCH" = "x86_64" ]; then
        LLVM_VERSION=clang+llvm-9.0.0-x86_64-pc-linux-gnu
    elif [ "$ARCH" = "aarch64" ]; then
        LLVM_VERSION=clang+llvm-9.0.0-aarch64-linux-gnu
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    wget http://releases.llvm.org/9.0.0/$LLVM_VERSION.tar.xz
    tar -xJvf $LLVM_VERSION.tar.xz
    rm $LLVM_VERSION.tar.xz
    mv $LLVM_VERSION clang_9.0.0
    sudo mv clang_9.0.0 /usr/local
    BASHRC="$HOME/.bashrc"
    if ! grep -q "clang_9.0.0" "$BASHRC"; then
        echo 'export PATH=/usr/local/clang_9.0.0/bin:$PATH' >> "$BASHRC"
        echo 'export LD_LIBRARY_PATH=/usr/local/clang_9.0.0/lib:$LD_LIBRARY_PATH' >> "$BASHRC"
    fi
    export PATH=/usr/local/clang_9.0.0/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/clang_9.0.0/lib:$LD_LIBRARY_PATH
    sudo ln -s /usr/lib/$ARCH-linux-gnu/libz3.so.4 /usr/lib/libz3.so.4.8
    sudo ln -s /usr/local/clang_9.0.0/bin/llc /usr/local/clang_9.0.0/bin/llc-9

    sudo DEBIAN_FRONTEND=noninteractive apt -y install gcc-9 g++-9
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 --slave /usr/bin/g++ g++ /usr/bin/g++-9 --slave /usr/bin/gcov gcov /usr/bin/gcov-9
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 --slave /usr/bin/g++ g++ /usr/bin/g++-11 --slave /usr/bin/gcov gcov /usr/bin/gcov-11
    sudo update-alternatives --set gcc /usr/bin/gcc-9
else
    sudo DEBIAN_FRONTEND=noninteractive apt -y install gpg curl tar xz-utils make gcc flex bison libssl-dev libelf-dev clang-9 llvm-9 autoconf automake libtool pkg-config m4 libz3-dev libevent-dev libtinfo5
fi

./kernel-src-download.sh
./kernel-src-prepare.sh
cd bmc
make
cd ..
cd memcached-sr
./autogen.sh
CC=clang-9 CFLAGS='-DREUSEPORT_OPT=1 -Wno-deprecated-declarations' ./configure
make
cd ..

if [ ! -d /sys/fs/bpf ]; then
    sudo mount -t bpf bpffs /sys/fs/bpf/
fi

echo "Please run: source $HOME/.bashrc to update environment variables."
