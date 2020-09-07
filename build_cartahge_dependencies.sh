#!/bin/sh

# IMPORTANT:
# Always execute this script from /Scripts directory!

CART_DIR_NAME="Carthage"
CART_CHECKOUTS_NAME="Checkouts"
CART_BUILD_NAME="Build"
CART_IOS_NAME="iOS"
CART_TMP_NAME="Build/iOS"

function print_current_dir {
    echo "current path: " ${PWD}
}

# Create directory if does not exist
# $1 - path
function create_framework_output_dir {

    if ! [ -d "$1" -a ! -h "$1" ] 
    then
        #echo "create build directory '$1'"
        mkdir "$1"
    fi
}

# Prepare PATHS and trigger build
# $1 - library directory name is in 'Checkouts'
# $2 - library project name XXX (base name of xcodeproject)
# $3 - scheme 
function preapre_and_build_library {

    LIB_DIR="${PWD}/${CART_CHECKOUTS_NAME}/$1"
    if [ -d "$LIB_DIR" -a ! -h "$LIB_DIR" ] 
    then
        build_library "$1" "$2" "$3" "${LIB_DIR}"
    else
        echo "skip $1/$2.xcodeproj - not found at '${LIB_DIR}'"
    fi
}

# $1 platform build root dir (ex> .../Release-iphoneos/)
function get_universal_framework_output_directory_path {

    LIB_PATH="dummy"

    for filePath in $1/*.*; do
        
        FILENAME_WITH_EXT="$(basename $filePath)"
        FILENAME_NO_EXT="${FILENAME_WITH_EXT%.*}"
        EXT="${filePath##*.}"
        
        if [[ "$EXT" == "framework" ]]
        then
            LIB_PATH="${PWD}/${CART_TMP_NAME}/$FILENAME_WITH_EXT"
        fi
    done
    
    echo "${LIB_PATH}"
}

# $1 platform build root dir (ex> .../Release-iphoneos/ or respectively for simulator)
function get_platform_lib_path {

    LIB_PATH="dummy"

    for filePath in $1/*.*; do
        
        FILENAME_WITH_EXT="$(basename $filePath)"
        FILENAME_NO_EXT="${FILENAME_WITH_EXT%.*}"
        EXT="${filePath##*.}"
        
        if [[ "$EXT" == "framework" ]]
        then
            LIB_PATH="${filePath}/${FILENAME_NO_EXT}"
        fi
    done
    
    echo ${LIB_PATH}
}

# $1 platform build root dir (ex> .../Release-iphoneos/)
function copy_platform_framework_to_output_directory {

    for filePath in $1/*.*; do
        
        FILENAME_WITH_EXT="$(basename $filePath)"
        FILENAME_NO_EXT="${FILENAME_WITH_EXT%.*}"
        EXT="${filePath##*.}"
        #echo "found file: ${FILENAME_NO_EXT} with EXT: ${EXT}"    
        
        if [[ "$EXT" == "framework" ]]
        then

            echo "found framework!"

            UNIVERSAL_DIR_PATH="${PWD}/${CART_TMP_NAME}/$FILENAME_WITH_EXT"
            create_framework_output_dir ${UNIVERSAL_DIR_PATH}

            echo "copy content of ${filePath}/ to ${UNIVERSAL_DIR_PATH}/"
            SOURCE_PATH="${filePath}"

            cp -R ${SOURCE_PATH}/* ${UNIVERSAL_DIR_PATH}/
            rm ${UNIVERSAL_DIR_PATH}/$FILENAME_NO_EXT
            
        fi
        
        if [[ "$EXT" == "dSYM" ]]
        then
        
            echo "found dSYM!"
            cp -R "${filePath}" "${PWD}/${CART_TMP_NAME}/${FILENAME}"
        fi
        
    done
}

# Build library and create universal framework
# $1 - library dir name
# $2 - library project name
# $3 - scheme name
# $4 - library root path (where .xcproject is located)
function build_library {

    # PWD == /Carthage/   (Carthage root where Build and Checkout directoreis reside)
    
    DERIVED_DATA_PATH="$4/build"
    PROJECT_PATH="$4/$2.xcodeproj"
    echo "start build: $1/$2 - scheme: $3 at $4"
    
    echo "build for iPHONE"
    xcodebuild -project "${PROJECT_PATH}" \
    -scheme "$3" \
    -configuration Release \
    -arch arm64 -arch armv7 -arch armv7s only_active_arch=no defines_module=yes \
    -sdk "iphoneos" \
    -derivedDataPath "${DERIVED_DATA_PATH}"
    
    echo "build for Simulator"
    xcodebuild -project "${PROJECT_PATH}" \
    -scheme "$3" \
    -configuration Release \
    -arch x86_64 -arch i386 \
    -sdk "iphonesimulator" \
    -derivedDataPath "${DERIVED_DATA_PATH}"
    
    LIB_IPHONE_SRC_PATH="$4/build/Build/Products/Release-iphoneos"
    OUTPUT_DIR=$(get_universal_framework_output_directory_path $LIB_IPHONE_SRC_PATH)
    echo "Output dir should be: ${OUTPUT_DIR}"
    
    echo "iphone path: ${LIB_IPHONE_SRC_PATH}"
    LIB_IPHONE_PATH=$(get_platform_lib_path $LIB_IPHONE_SRC_PATH)
    copy_platform_framework_to_output_directory $LIB_IPHONE_SRC_PATH
    
    LIB_SIMU_SRC_PATH="$4/build/Build/Products/Release-iphonesimulator"
    echo "simulator path: ${LIB_SIMU_SRC_PATH}"
    LIB_SIMU_PATH=$(get_platform_lib_path $LIB_SIMU_SRC_PATH)
    copy_platform_framework_to_output_directory $LIB_SIMU_SRC_PATH
    
    echo "lip iphone (${LIB_IPHONE_PATH}) and simulator (${LIB_SIMU_PATH})"    
    echo "start lipo"
    
    FILENAME_WITH_EXT="$(basename $LIB_IPHONE_PATH)"
    FILENAME_NO_EXT="${FILENAME_WITH_EXT%.*}"
    lipo "${LIB_IPHONE_PATH}" "${LIB_SIMU_PATH}" -create -output "${OUTPUT_DIR}/$FILENAME_NO_EXT"
    
    rm -R ${LIB_IPHONE_SRC_PATH}
    rm -R ${LIB_SIMU_SRC_PATH}
}

function create_directory_structure {

    CART_BUILD_DIR="${PWD}/${CART_BUILD_NAME}"

    # Remove Build directory if exists
    if [ -d "$CART_BUILD_DIR" -a ! -h "$CART_BUILD_DIR" ]
    then
       echo "Build directdory '${CART_BUILD_DIR}' exists - delete"
       #echo "remove dir: ${PWD}/${CART_BUILD_NAME}"
       #rm -rf ${PWD}/${CART_BUILD_NAME}
    else
       echo "Build directory '${CART_BUILD_DIR}' does not exist -> next step"
    fi

    # Create Build directory if does not exist
    if ! [ -d "$CART_BUILD_DIR" -a ! -h "$CART_BUILD_DIR" ] 
    then
        echo "create build directory '${CART_BUILD_DIR}'"
        mkdir "$CART_BUILD_NAME"
    fi

    CART_BUILD_IOS_DIR="${PWD}/${CART_BUILD_NAME}/${CART_IOS_NAME}"

    # Create iOS directory if does not exist
    if ! [ -d "$CART_BUILD_IOS_DIR" -a ! -h "$CART_BUILD_IOS_DIR" ] 
    then
        echo "create iOS platform directory '${CART_BUILD_IOS_DIR}'"
        mkdir "$CART_BUILD_IOS_DIR"
    fi

    # Create tmp directory for build output
    TMP_DIR="${PWD}/${CART_TMP_NAME}"
    if ! [ -d "$TMP_DIR" -a ! -h "$TMP_DIR" ] 
    then
        echo "create TMP directory '${TMP_DIR}'"
        mkdir "$TMP_DIR"
    fi
}

cd ..
cd Carthage

print_current_dir
create_directory_structure

preapre_and_build_library "FileProvider" "FilesProvider" "FilesProvider iOS"
preapre_and_build_library "GzipSwift" "Gzip" "Gzip iOS"
preapre_and_build_library "HanekeSwift" "Haneke" "Haneke-iOS"
preapre_and_build_library "OHHTTPStubs" "OHHTTPStubs" "OHHTTPStubs iOS Framework"
preapre_and_build_library "PromiseKit" "PromiseKit" "PromiseKit"
preapre_and_build_library "Reachability.swift" "Reachability" "Reachability"
preapre_and_build_library "SwiftKeychainWrapper" "SwiftKeychainWrapper" "SwiftKeychainWrapper"
preapre_and_build_library "Toast-Swift" "Toast-Swift" "ToastSwiftFramework"
preapre_and_build_library "TPKeyboardAvoiding" "TPKeyboardAvoidingSample" "TPKeyboardAvoidingKit"
preapre_and_build_library "TransitionButton" "TransitionButton" "TransitionButton"
preapre_and_build_library "XCGLogger" "XCGLogger" "XCGLogger (iOS)"
preapre_and_build_library "XCGLogger" "XCGLogger" "ObjcExceptionBridging (iOS)"
preapre_and_build_library "Zip" "Zip" "Zip"




