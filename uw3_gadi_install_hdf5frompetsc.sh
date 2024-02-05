#!/bin/bash

usage="
Usage:
  A script to install and run an Underworld software stack.

** To install **
Review script details: modules, paths, repository urls / branches etc.
 $ source <this_script_name>
 $ install_full_stack

** To run **
Add the line
 source /path/gadi.pbs
to your pbs file, make sure to include the absolute path.
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


module purge
module load openmpi/4.1.4 python3/3.11.7 gmsh/4.11.1 cmake

############## need input from user ####################
export GROUP=n69
export USER=tg7098
export USER_HOME=/home/565/tg7098
export ENV_NAME=uw3_boundary_integrals_h5_petsc_env
export INSTALL_NAME=uw3_boundary_integrals_h5_petsc_installs
export PETSC_NAME=petsc-main-lm
export CODES_PATH=/g/data/$GROUP/$USER/codes
########################################################

export ENV_PATH=$CODES_PATH/$ENV_NAME
export INSTALL_PATH=$CODES_PATH/$INSTALL_NAME
export PETSC_PATH=$CODES_PATH/$INSTALL_NAME/$PETSC_NAME
export UW3_PATH=$CODES_PATH/$INSTALL_NAME/uw3
export CDIR=$PWD

PETSC_VERSION="main"
PETSC_GIT="https://gitlab.com/lmoresi/petsc/-/archive/main/petsc-${PETSC_VERSION}.tar.gz"

GIT_COMMAND="git clone --branch boundary_integrals --depth 1 https://github.com/underworldcode/underworld3.git"


install_petsc(){
		unset PYTHONPATH PETSC_DIR PETSC_ARCH

		source $ENV_PATH/bin/activate

		pip install --upgrade pip --no-binary :all:
		pip3 install --no-binary :all: --no-cache-dir mpi4py

		mkdir -p $PETSC_PATH
		mkdir -p $INSTALL_PATH/tmp/src
		
		cd $INSTALL_PATH/tmp/src
		wget ${PETSC_GIT} --no-check-certificate \
		&& tar -zxf petsc-${PETSC_VERSION}.tar.gz
		cd $INSTALL_PATH/tmp/src/petsc-${PETSC_VERSION}

		# install petsc
		./configure --with-debugging=0 --prefix=$PETSC_PATH \
		            --COPTFLAGS="-g -O3" --CXXOPTFLAGS="-g -O3" --FOPTFLAGS="-g -O3" \
		            --with-petsc4py=1               \
		            --with-shared-libraries=1       \
		            --with-cxx-dialect=C++11        \
		            --with-make-np=4                \
		            --download-zlib=1               \
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
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt all \
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt install \
		&& rm -rf $INSTALL_PATH/tmp

		## add bin path to .bashrc file
		#echo "export PYTHONPATH=\"$PETSC_PATH/lib:\$PYTHONPATH\"" >> $USER_HOME/.bashrc
		#echo "export PETSC_DIR=$PETSC_PATH" >> $USER_HOME/.bashrc
		#echo "export PETSC_ARCH=arch-linux-c-opt" >> $USER_HOME/.bashrc
		#source $USER_HOME/.bashrc
		
		export PYTHONPATH=$PETSC_PATH/lib:$PYTHONPATH
		export PETSC_DIR=$PETSC_PATH
		export PETSC_ARCH=arch-linux-c-opt

		cd $CDIR

		CC=mpicc HDF5_MPI="ON" HDF5_DIR=$PETSC_PATH pip3 install --no-cache-dir --no-binary=h5py h5py
}

install_underworld3(){
		source $ENV_PATH/bin/activate
		pip3 install --no-cache-dir pytest
		pip3 install --upgrade --force-reinstall --no-cache-dir typing-extensions

		${GIT_COMMAND} $UW3_PATH \
		&& cd $UW3_PATH \
		&& ./clean.sh \
		&& python3 setup.py develop
	        
		source pypathsetup.sh
		python3 -m pytest -v

		cd $CDIR
}

check_petsc_exists(){
        source $ENV_PATH/bin/activate
        return $(python3 -c "from petsc4py import PETSc")
}

check_underworld3_exists(){
        source $ENV_PATH/bin/activate
        return $(python3 -c "import underworld3")
}

install_full_stack(){
        if ! check_petsc_exists; then
          install_petsc
        fi

        if ! check_underworld3_exists; then
          install_underworld3
        fi
}

install_visz_dependencies(){
		source $ENV_PATH/bin/activate
		pip3 install --no-cache-dir trame trame-vuetify trame-vtk pyvista ipywidgets
		pip3 install --no-cache-dir ipython jupyterlab jupytext
}


if [ ! -d "$ENV_PATH" ]
then
	    echo "Environment not found, creating a new one"
	    mkdir -p $ENV_PATH
	    python3 --version
	    python3 -m venv --system-site-packages $ENV_PATH
else
	    echo "Found Environment"
	    source $ENV_PATH/bin/activate

	  	unset PYTHONPATH PETSC_DIR PETSC_ARCH
	    export PYTHONPATH=$PETSC_PATH/lib:$PYTHONPATH
	    export PETSC_DIR=$PETSC_PATH
	    export PETSC_ARCH=arch-linux-c-opt

		  if check_underworld3_exists; then
		    cd $UW3_PATH
				source pypathsetup.sh
				cd $CDIR
			fi	
fi