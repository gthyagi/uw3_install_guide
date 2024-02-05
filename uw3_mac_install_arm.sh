#!/bin/zsh

usage="
Usage:
  A script to install and run an Underworld software stack.
  Change the directories accordingly when line comment says '# user_input'
  It is very important to use openmpi version-4.1.6 and python version-3.11.
  Manual installation of openmpi is highly recommended. Do not use homebrew one.

** To install **
Review script details: modules, paths, repository urls / branches etc.
 $ source <this_script_name>
 $ install_full_stack

** To run **
source this file to open the environment
"

while getopts ':h' option; do
  case "$option" in
    h) echo "$usage"
       # safe script exit for sourced script
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
    \?) # incorrect options
       echo "Error: Incorrect options"
       echo "$usage"
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
  esac
done

############## need input from user ####################
export USER_HOME="/Users/tgol0006" 
export ENV_PATH=$USER_HOME/uw_folder 
export ENV_NAME="uw3_boundary_integrals_env" 
export PKG_PATH=$USER_HOME/manual_install_pkg/uw3_boundary_integrals_installs 
export PETSC_INSTALL=$PKG_PATH/petsc_main_lm 
########################################################

export VIR_ENV=$ENV_PATH/$ENV_NAME
export CDIR=$PWD

PYVER="3.11"
GIT_COMMAND="git clone --branch boundary_integrals --depth 1 https://github.com/underworldcode/underworld3.git"

PETSC_VERSION="main"
PETSC_COMMAND="https://gitlab.com/lmoresi/petsc/-/archive/main/petsc-${PETSC_VERSION}.tar.gz"

OMPI_MAJOR_VERSION="v4.1"
OMPI_VERSION="4.1.6"
OMPI_CONFIGURE_OPTIONS="--prefix=$PKG_PATH/openmpi-${OMPI_VERSION}"
OMPI_MAKE_OPTIONS="-j4"
OMPI_COMMAND="https://download.open-mpi.org/release/open-mpi/${OMPI_MAJOR_VERSION}/openmpi-${OMPI_VERSION}.tar.gz"

install_openmpi(){
		mkdir -p $PKG_PATH/tmp/src

		cd $PKG_PATH/tmp/src
		wget ${OMPI_COMMAND} --no-check-certificate \
		&& tar -zxf openmpi-${OMPI_VERSION}.tar.gz
		cd $PKG_PATH/tmp/src/openmpi-${OMPI_VERSION}
		./configure ${OMPI_CONFIGURE_OPTIONS} \
		&&  make ${OMPI_MAKE_OPTIONS} \
		&&  make install \
		&&  rm -rf $PKG_PATH/tmp

		# add bin path to .zshrc file
		echo "export PATH=\"$PKG_PATH/openmpi-${OMPI_VERSION}/bin:\$PATH\"" >> $USER_HOME/.zshrc
		source $USER_HOME/.zshrc

		cd $CDIR
}

install_petsc(){
		unset PYTHONPATH PETSC_DIR PETSC_ARCH

		source $VIR_ENV/bin/activate
		pip3 install --upgrade pip
		pip3 install --no-cache-dir cython numpy mpi4py gmsh

		mkdir -p $PETSC_INSTALL
		mkdir -p $PKG_PATH/tmp/src
		
		cd $PKG_PATH/tmp/src
		wget ${PETSC_COMMAND} --no-check-certificate \
		&& tar -zxf petsc-${PETSC_VERSION}.tar.gz
		cd $PKG_PATH/tmp/src/petsc-${PETSC_VERSION}

		# install petsc
		./configure --with-debugging=0 --prefix=$PETSC_INSTALL \
		            --COPTFLAGS="-g -O3" --CXXOPTFLAGS="-g -O3" --FOPTFLAGS="-g -O3" \
		            --with-petsc4py=1               \
		            --with-shared-libraries=1       \
		            --with-cxx-dialect=C++11        \
		            --with-make-np=4                \
		            --download-zlib=1               \
		            --download-cmake=1			    \
		            --download-hdf5=1               \
		            --download-mumps=1              \
		            --download-parmetis=1           \
		            --download-metis=1              \
		            --download-superlu=1            \
		            --download-hypre=1              \
		            --download-scalapack=1          \
		            --download-superlu_dist=1       \
		            --download-pragmatic=1          \
		            --download-ctetgen              \
		            --download-eigen                \
		            --download-superlu=1            \
		            --download-triangle             \
		            --useThreads=0                  \
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt all \
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt install \
		&& rm -rf $PKG_PATH/tmp

		# # add bin path to .zshrc file
		# echo "export PYTHONPATH=\"$PETSC_INSTALL/lib:\$PYTHONPATH\"" >> $USER_HOME/.zshrc 
		# echo "export PETSC_DIR=$PETSC_INSTALL" >> $USER_HOME/.zshrc
		# echo "export PETSC_ARCH=arch-darwin-c-opt" >> $USER_HOME/.zshrc
		# source $USER_HOME/.zshrc

		export PYTHONPATH=$PETSC_INSTALL/lib:$PYTHONPATH
		export PETSC_DIR=$PETSC_INSTALL
		export PETSC_ARCH=arch-darwin-c-opt

		cd $CDIR

		source $VIR_ENV/bin/activate
		CC=mpicc HDF5_MPI="ON" HDF5_DIR=$PETSC_DIR pip3 install --no-cache-dir --no-binary=h5py h5py
}

install_underworld3(){
		source $VIR_ENV/bin/activate
		pip3 install --no-cache-dir pytest

		${GIT_COMMAND} $PKG_PATH/uw3_folder \
		&& cd $PKG_PATH/uw3_folder \
		&& ./clean.sh \
		&& python setup.py develop \
		&& pytest -v

		cd $CDIR
}

install_visz_dependencies(){
		source $VIR_ENV/bin/activate
	    pip3 install --no-cache-dir trame trame-vuetify trame-vtk pyvista ipywidgets
	    pip3 install --no-cache-dir ipython jupyterlab jupytext
}

check_openmpi_exists(){
        return $(bash -c "mpirun -np 1 hostname")
}

check_petsc_exists(){
        source $VIR_ENV/bin/activate
        return $(python${PYVER} -c "from petsc4py import PETSc")
}

check_underworld3_exists(){
        source $VIR_ENV/bin/activate
        return $(python${PYVER} -c "import underworld3")
}


install_full_stack(){

		if ! check_openmpi_exists; then
          install_openmpi
        fi

        if ! check_petsc_exists; then
          install_petsc
        fi

        if ! check_underworld3_exists; then
          install_underworld3
        fi

        install_visz_dependencies
}

if [ ! -d "$VIR_ENV" ]
then
	    echo "Environment not found, creating a new one"
	    mkdir -p $VIR_ENV
	    python${PYVER} --version
	    python${PYVER} -m venv --system-site-packages $VIR_ENV
else
	    echo "Found Environment"
	    source $VIR_ENV/bin/activate

    	unset PYTHONPATH PETSC_DIR PETSC_ARCH
        export PYTHONPATH=$PETSC_INSTALL/lib:$PYTHONPATH
		export PETSC_DIR=$PETSC_INSTALL
		export PETSC_ARCH=arch-darwin-c-opt
fi