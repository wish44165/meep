# from https://github.com/NanoComp/meep/issues/1853#issuecomment-1826828860

# in a new folder:
mkdir product
mkdir install
cd install

# prepare an environment that for sure uses open mpi and parallel hdf5
xcode-select --install
brew unlink hdf5
brew unlink mpich
# install prerequisites from homebrew
brew install hdf5-mpi fftw gsl libpng autoconf automake libtool swig wget openblas open-mpi
# prepare conda environment
conda create -n pmp -y
conda activate pmp
# install prerequisites from conda
conda install python=3.11 numpy matplotlib scipy autograd jax parameterized ffmpeg nlopt -y

# include dirs for open mpi
INCLUDEADD=$(mpicc --showme:incdirs)
LINKADD=$(mpicc --showme:link)
# must be an absolute path
CURDIR=$(pwd)
PREFIX=$CURDIR/product/
CPPFLAGS="-O3 -I$PREFIX/include -I$(brew --prefix openblas)/include -I$(brew --prefix)/include -I$INCLUDEADD"
LDFLAGS="-L$PREFIX/lib -L$(brew --prefix openblas)/lib -L$(brew --prefix)/lib $LINKADD"
CC="$(brew --prefix)/bin/mpicc"
CXX="$(brew --prefix)/bin/mpic++"

# install mpi4py from pip
CC=$CC CXX=$CXX CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" python -m pip install --no-cache-dir --no-binary=mpi4py mpi4py

# install h5py with open mpi from github
git clone https://github.com/h5py/h5py.git
cd h5py
HDF5_MPI="ON" HDF5_DIR="$(brew --prefix)" CC=$CC CXX=$CXX CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" pip install --no-cache-dir --no-binary=h5py,mpi4py .
cd ..

# check that mpi4py works and h5py can use openmpi
echo "from mpi4py import MPI" > mpitest.py
echo "print('Hello World (from process %d)' % MPI.COMM_WORLD.Get_rank())" >> mpitest.py
echo "import h5https://github.com/NanoComp/meep/issues/1853#issuecomment-1826828860py" >> mpitest.py
echo "rank = MPI.COMM_WORLD.rank" >> mpitest.py
echo "f = h5py.File('parallel_test.hdf5', 'w', driver='mpio', comm=MPI.COMM_WORLD)" >> mpitest.py
echo "dset = f.create_dataset('test', (4,), dtype='i')" >> mpitest.py
echo "dset[rank] = rank" >> mpitest.py
echo "f.close()" >> mpitest.py
mpirun -np 4 python -m mpi4py ./mpitest.py

# install current version of harminv from github
git clone https://github.com/NanoComp/harminv.git
cd harminv
sh autogen.sh CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" PYTHON=python --enable-shared --enable-maintainer-mode --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
cd ..

# install version of libctl from github that allows the without guile option
wget https://gihttps://github.com/NanoComp/meep/issues/1853#issuecomment-1826828860thub.com/NanoComp/libctl/releases/download/v4.5.0/libctl-4.5.0.tar.gz
tar -xzf libctl-4.5.0.tar.gz
cd libctl-4.5.0
./configure CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" PYTHON=python --enable-shared --enable-maintainer-mode --without-guile --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
cd ..

# install current version of mpb from github
git clone https://github.com/NanoComp/mpb.git
cd mpb
sh autogen.sh CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" CC=$CC PYTHON=python --enable-shared --enable-maintainer-mode --without-libctl --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
cd ..

# install current version of h5utils from github
git clone https://github.com/NanoComp/h5utils.git
cd h5utils
sh autogen.sh CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" CC=$CC PYTHON=python --enable-maintainer-mode --enable-parallel --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
cd ..

# install current version of libgdsii from github
git clone https://github.com/HomerReid/libGDSII.git
cd libGDSII
sh autogen.sh CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" PYTHON=python --enable-shared --enable-maintainer-mode --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
cd ..

# install current version of meep from github
git clone https://github.com/NanoComp/meep.git
cd meep
sh autogen.sh CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" CC=$CC CXX=$CXX PYTHON=python --enable-shared --enable-maintainer-mode --with-libctl --without-scheme --with-mpi --prefix=$PREFIX
make -j $(sysctl -n hw.logicalcpu) && make install
make RUNCODE="mpirun -np $(sysctl -n hw.logicalcpu)" check
cd python
make RUNCODE="mpirun -np $(sysctl -n hw.logicalcpu)" check
cd ..
cd ..