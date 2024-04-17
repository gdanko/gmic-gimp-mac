#/bin/bash

PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(arch)
PORTS_PREFIX="/opt/local"
SLASHED_PORTS_PREFIX=$PORTS_PREFIX/
PACKAGE_NAME=gmic-gimp
PLUGIN_ROOT=$PWD/$PACKAGE_NAME/lib/gimp/2.0/plug-ins
PLUGIN_VERSION=""
CURRENT_PWD=$(pwd)

function log {
    LEVEL=$(echo $1 | tr '[:lower:]' '[:upper:]')
    MESSAGE=$2
    echo "[$LEVEL] $MESSAGE"
    if [ $LEVEL = "ERROR" ]; then
        exit 1
    fi
}

function package_is_installed {
    local PACKAGE_NAME=$1
    RESPONSE=$($PORTS_PREFIX/bin/port installed $PACKAGE_NAME 2>/dev/null)
    if [[ ! "$RESPONSE" =~ "The following ports are currently installed" ]]; then
        echo false
    else
        echo true
    fi
}

function file_exists {
    if [ ! -f "$1" ]; then
        echo The required file \"$1\" does not exist. Cannot continue.
        exit 1
    fi
}

function prepare {
    if [ "$(package_is_installed $PACKAGE_NAME)" = false ]; then
        log error "The package $PACKAGE_NAME is not installed. Cannot continue."
    fi

    PLUGIN_VERSION=$($PORTS_PREFIX/bin/port info $PACKAGE_NAME | head -n 1 | awk '{print $2}' | sed 's/^@//')

    if [ -d $PLUGIN_ROOT ]; then
        log error "The directory $PLUGIN_ROOT already exists. Cannot continue."
    fi
    mkdir -p $PLUGIN_ROOT
    cd $PLUGIN_ROOT
}

function copy_dependencies {
    local FILEPATH=""

    for FILEPATH in $(otool -L $1 | grep "\t$SLASHED_PORTS_PREFIX" | sed "s|${SLASHED_PORTS_PREFIX}||" | awk '{print $1}'); do
        local OLDPATH="$PORTS_PREFIX/$FILEPATH"
        if [ ! -f $OLDPATH ]; then
            echo "Required file $OLDPATH does not exist. Aborting."
            exit 1
        fi
        local DIRNAME=$(dirname $OLDPATH | sed "s|${PORTS_PREFIX}\/||")
        local BASENAME=$(basename $OLDPATH)
        mkdir -p $DIRNAME
        if [ ! -f $(pwd)/$FILEPATH ]; then
            echo Copying $OLDPATH to $DIRNAME/$BASENAME
            cp $OLDPATH $DIRNAME
            chmod 755 $DIRNAME/$BASENAME
            copy_dependencies $DIRNAME/$BASENAME
        fi
    done
}

function calculate_rpath {
    CURRENT_BITS=$(echo $(pwd) | grep -o "/[^/]*" | wc -l)
    DESIRED_BITS=$(echo $1 | grep -o "/[^/]*" | wc -l)
    DISTANCE=$(($DESIRED_BITS-$CURRENT_BITS-1))
    CALCULATED_RPATH="@executable_path"
    for ((i = $DISTANCE; i > 0; i--)); do
        CALCULATED_RPATH="$CALCULATED_RPATH/.."
    done
    echo $CALCULATED_RPATH
}

function copy_and_process_dependencies {
    SOURCE=$1
    DESTINATION_DIR=$2
    file_exists $SOURCE
    if [ -z $DESTINATION_DIR ]; then
        DESTINATION_DIR=$(dirname $SOURCE | sed "s|${SLASHED_PORTS_PREFIX}||")
    fi
    BASENAME=$(basename $SOURCE)
    if [ ! -d $DESTINATION_DIR ]; then
        mkdir -p $DESTINATION_DIR
    fi

    echo Copying $SOURCE to $DESTINATION_DIR/$BASENAME
    cp $SOURCE $DESTINATION_DIR
    chmod 755 $DESTINATION_DIR/$BASENAME
    echo Finding dependencies for $DESTINATION_DIR/$BASENAME

    for FILEPATH in $(otool -L $DESTINATION_DIR/$BASENAME | grep "\t$SLASHED_PORTS_PREFIX" | awk '{print $1}'); do
        DEPENDENCY_BASENAME=$(basename $FILEPATH)
        DEPENDENCY_DIRNAME=$(dirname $FILEPATH | sed "s|${SLASHED_PORTS_PREFIX}||" )
        if [ ! -d $DEPENDENCY_DIRNAME ]; then
            mkdir -p $DEPENDENCY_DIRNAME
        fi

        if [ ! -f $DEPENDENCY_DIRNAME/$DEPENDENCY_BASENAME ]; then
            copy_and_process_dependencies $FILEPATH
        fi
    done
}

function update_rpaths {
    FILENAME=$1
    RPATH=$(calculate_rpath $FILENAME)
    if [ $DEBUG = true ]; then
        echo install_name_tool -add_rpath $RPATH $FILENAME
    fi
    install_name_tool -add_rpath $RPATH $FILENAME
    for FILEPATH in $(otool -L $FILENAME | grep "\t$SLASHED_PORTS_PREFIX" | sed "s|${SLASHED_PORTS_PREFIX}||" | awk '{print $1}'); do
        if [ $DEBUG = true ]; then
            echo install_name_tool -change $PORTS_PREFIX/$FILEPATH @rpath/$FILEPATH $FILENAME
        fi
        install_name_tool -change $PORTS_PREFIX/$FILEPATH @rpath/$FILEPATH $FILENAME
    done
}

function process_binary {
    BINARY=$PORTS_PREFIX/lib/gimp/2.0/plug-ins/gmic_gimp_qt/gmic_gimp_qt
    file_exists $BINARY
    copy_and_process_dependencies $BINARY $(pwd)
    update_rpaths $(basename $BINARY)
}

function process_platforms {
    echo Copying the qt5 platforms libraries
    PLATFORMS_DIR=$PORTS_PREFIX/libexec/qt5/plugins/platforms
    if [ ! -d $PLATFORMS_DIR ]; then
        echo The qt5 platforms directory "$PLATFORMS_DIR" cannot be found.
        exit 1
    fi

    FILES=$(find $PLATFORMS_DIR -perm +111 -type f | xargs file | grep ' Mach-O '| awk -F ':' '{print $1}')
    for FILE in $FILES; do
        copy_and_process_dependencies $FILE
    done
}

function process_libraries {
    for DIRECTORY in $(ls -d */); do
        echo Looking for files in $(pwd)/${DIRECTORY%/}
        FILES=$(find $(pwd)/${DIRECTORY%/} -perm +111 -type f | xargs file | grep ' Mach-O '| awk -F ':' '{print $1}')
        for FILE in $FILES; do
            echo Updating $FILE
            update_rpaths $FILE
        done
    done
}

function compress {
    ARCHIVE_NAME=$PACKAGE_NAME-$PLUGIN_VERSION-$PLATFORM-$ARCH.tgz
    cd $CURRENT_PWD
    pushd $PACKAGE_NAME
    tar czvf $CURRENT_PWD/$ARCHIVE_NAME *
    popd
}

DEBUG=true
prepare
process_binary
process_platforms
process_libraries
compress
