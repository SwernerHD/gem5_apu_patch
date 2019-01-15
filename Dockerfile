FROM ubuntu:16.04
# NOTE: latest (i.e.) 18.04 does not work with roc-1.6.x, only 16.04 
# 	18.04 does work with roc-1.8.x (latest) though

MAINTAINER Sebastian Werner

# Install all necessary libraries 
RUN apt-get update  # needed because there is no pacakge cache in the image 
RUN apt-get upgrade -y
RUN apt-get update
RUN apt-get install -y \
  build-essential \
  git-core \ 
  m4 \ 
  scons \
  zlib1g \ 
  zlib1g-dev \ 
  libprotobuf-dev \
  protobuf-compiler \
  libprotoc-dev \
  libgoogle-perftools-dev \
  swig \
  python-dev \
  python \
  libnuma-dev \
  pkg-config \
  wget \
  g++ \
  g++-multilib \
  gcc-multilib \ 
  findutils \
  libelf1 \
  libpci3 \ 
  file \
  debianutils \
  libunwind-dev \
  libopenmpi-dev \
  libomp-dev \
  vim 

# Packets that can't be located (but appear in Docker installation guide for Ubuntu 18.04)
# https://github.com/RadeonOpenCompute/hcc/wiki#building-hcc-from-source
# hsa-rocr-dev, hsa-ext-rocr-dev, hsakmt-roct-dev, rocm-utils


RUN apt-get clean

#RUN echo "========= Start Installing cmake ========="
RUN apt-get -y install cmake
RUN which cmake 
RUN cmake --version


# ===== rocm ===== #
WORKDIR "/home"
RUN wget http://repo.radeon.com/rocm/archive/apt_1.6.4.tar.bz2
RUN tar -vxjf apt_1.6.4.tar.bz2 
RUN rm apt_1.6.4.tar.bz2
RUN wget -qO - http://repo.radeon.com/rocm/apt/debian/rocm.gpg.key | apt-key add -
RUN sh -c 'echo deb [arch=amd64] file:///home/apt_1.6.4/ xenial main > /etc/apt/sources.list.d/rocm.list'
RUN apt-get update
RUN apt-get install -y rocm-dev

# ==== hcc ==== #
#RUN git clone --recursive -b roc-1.6.x https://github.com/RadeonOpenCompute/hcc.git
#NOTE: this ^^ is supposed to be run according to the wiki, but roc-1.6x hcc does not build, throws different random errors. 
RUN git clone --recursive -b roc-1.6.x https://github.com/RadeonOpenCompute/hcc.git
WORKDIR "/home/hcc"
RUN pwd
RUN ls
RUN mkdir -p build
WORKDIR "/home/hcc/build"
RUN cmake -DCMAKE_BUILD_TYPE=Release ..
RUN echo "========= Start hcc make ========="
RUN make -j20
RUN echo "========= hcc make complete ========="
RUN echo "========= Start hcc make install ========="
RUN make install
RUN echo "========= hcc make install complete ========="
RUN ls


# ==== ROCt ==== #   
RUN apt-get install -y libpci-dev
WORKDIR "/home"
RUN git clone --recursive -b roc-1.6.x https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
WORKDIR "/home/ROCT-Thunk-Interface"
RUN mkdir -p build
WORKDIR  "/home/ROCT-Thunk-Interface/build"
RUN cmake ..
RUN make -j20


# ==== ROCr ==== #
# Get required packages (that haven't been inluded yet), as noted in src/README.md
RUN apt-get install -y \
  libelf-dev \
  libc6-dev-i386
WORKDIR "/home"
RUN git clone --recursive -b roc-1.6.x https://github.com/RadeonOpenCompute/ROCR-Runtime.git
WORKDIR "/home/ROCR-Runtime/src"
RUN mkdir -p build
WORKDIR "/home/ROCR-Runtime/src/build"
RUN cmake -D CMAKE_PREFIX_PATH=/home/ROCT-Thunk-Interface/build ..

RUN cp -a /home/ROCT-Thunk-Interface/include/*.h /home/ROCR-Runtime/src/core/inc/ #ideally you'd want to add this path to cmake, but can't figure out how therefore manually copy header files to prevent include error
RUN make -j20


# ==== HIP ==== #
# That should already be installed along with ROCM, right?! 
RUN apt-get install libelf-dev
WORKDIR "/home"
RUN git clone --recursive -b roc-1.6.x https://github.com/ROCm-Developer-Tools/HIP.git
WORKDIR "/home/HIP"
RUN mkdir -p build
WORKDIR "/home/HIP/build"
RUN cmake -DHSA_PATH=/opt/rocm/hsa/lib -DHCC_HOME=/opt/rocm/hcc/bin -DCMAKE_BUILD_TYPE=Release ..
RUN make -j20
RUN make install
RUN export HIP_PATH=/opt/rocm/hip


# ==== HCC Sample Applications ==== #
#WORKDIR "/home/myhome"
#RUN git clone https://github.com/ROCm-Developer-Tools/HCC-Example-Application.git
#WORKDIR "/home/myhome/HCC-Example-Application"
#RUN mkdir -p build
#WORKDIR "/home/myhome/HCC-Example-Application/build"
#RUN export PATH=$PATH:/opt/rocm/hcc/bin:/opt/rocm/bin
#RUN export LD_LIBRARY_PATH=/opt/rocm/hsa/lib
#RUN CXX=hcc cmake ..
#RUN make -j20


# ==== Compute Proxy Apps ==== #
# mpi.h omp.h no such file or directory solved by apt install libomp-dev and libopenmpi-dev
# snap-hcc amdgpu-target error:  Solution: add -amdgpu-target=gfx803  to line 
# LULESH: LDFLAGS = $(shell $(HCC_CONFIG) --install --ldflags) -lm -amdgpu-target=gfx803

# CLANGLNKFLAGS = $(CLANGLFLAGS) -g -lm -amdgpu-target=gfx803

#RUN git clone https://github.com/AMDComputeLibraries/ComputeApps.git
#RUN WORKDIR "/home/myhome/ComputeApps"


# ==== gem5 ==== # 
# NOTE: in this repositories, the following steps have been taken care of! 
#WORKDIR "/home/myhome/"
#RUN git clone https://gem5.googlesource.com/amd/gem5 -b agutierr/master-gcn3-staging
# DONT FORGET TO CHANGE THE ENV VARS IN APU_SE
#       "/opt/rocm/lib"
#       "/opt/rocm/hcc/lib"
#       "/usr/lib/x86_64-linux-gnu/libunwind.so.8.0.1"
#       "/usr/bin/gcc/"         

#   scons -sQ -j20 ./build/GCN3_X86/gem5.opt
#   
#   ./build/GCN3_X86/gem5.opt  ./configs/example/apu_se.py -c /home/ComputeApps/lulesh-amp/lulesh --num-cpus=32 

#  Note: some syscalls must be ignored in src/arch/X86/linux/system.cc' for this to work
#
#
#




