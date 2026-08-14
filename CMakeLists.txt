cmake_minimum_required(VERSION 3.16)

project(ImLab VERSION 3.3 LANGUAGES C CXX)

# ImLab was built with Tecgraf's tecmake, which resolves IUP, IM and CD through a shared
# TECTOOLS_HOME tree and a matrix of TEC_UNAME platform names. This replaces that with an
# ordinary CMake build against libraries wherever they actually are: IM and CD from Homebrew,
# IUP from a source tree (the Cocoa port), which is where the macOS work lives.

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

option(IMLAB_ENABLE_FFTW "Use FFTW for the transform operations" ON)

# ---------------------------------------------------------------------------- IUP ----
#
# Not a find_package: IUP has no CMake config, and on macOS this build wants a specific tree --
# the Cocoa port -- rather than whatever might be installed system-wide. Its libraries are built
# as frameworks; IupPlot and IupIm are not, so they are compiled from source below.

set(IUP_ROOT "" CACHE PATH "Root of the IUP source tree to build against")

if(NOT IUP_ROOT)
    foreach(candidate
            "$ENV{IUP}"
            "${CMAKE_CURRENT_SOURCE_DIR}/../../../iupcocoa-scratch/iup"
            "$ENV{HOME}/Projects/iupcocoa-scratch/iup")
        if(candidate AND EXISTS "${candidate}/include/iup.h")
            get_filename_component(IUP_ROOT "${candidate}" ABSOLUTE)
            break()
        endif()
    endforeach()
endif()

if(NOT IUP_ROOT OR NOT EXISTS "${IUP_ROOT}/include/iup.h")
    message(FATAL_ERROR
        "IUP not found. Point -DIUP_ROOT=<path> at an IUP source tree (the one holding "
        "include/iup.h), or set the IUP environment variable.")
endif()

if(APPLE)
    set(IUP_LIB_DIR "${IUP_ROOT}/BUILD-xcode/Release" CACHE PATH "Where the IUP frameworks are")
    if(NOT EXISTS "${IUP_LIB_DIR}/iup.framework")
        message(FATAL_ERROR
            "No IUP frameworks in ${IUP_LIB_DIR}. Build IUP first (its Xcode project), or set "
            "-DIUP_LIB_DIR=<path>.")
    endif()
else()
    set(IUP_LIB_DIR "${IUP_ROOT}/lib" CACHE PATH "Where the IUP libraries are")
endif()

message(STATUS "IUP: ${IUP_ROOT}")
message(STATUS "IUP libraries: ${IUP_LIB_DIR}")

# ------------------------------------------------------------------------- IM / CD ----

find_path(IM_INCLUDE_DIR im.h
    HINTS ENV IM PATH_SUFFIXES include)
find_library(IM_LIBRARY im HINTS ENV IM PATH_SUFFIXES lib)
find_library(IM_PROCESS_LIBRARY im_process HINTS ENV IM PATH_SUFFIXES lib)
find_library(IM_JP2_LIBRARY im_jp2 HINTS ENV IM PATH_SUFFIXES lib)

find_path(CD_INCLUDE_DIR cd.h HINTS ENV CD PATH_SUFFIXES include)
find_library(CD_LIBRARY cd HINTS ENV CD PATH_SUFFIXES lib)

foreach(required IM_INCLUDE_DIR IM_LIBRARY IM_PROCESS_LIBRARY IM_JP2_LIBRARY
                 CD_INCLUDE_DIR CD_LIBRARY)
    if(NOT ${required})
        message(FATAL_ERROR "${required} not found (brew install tecgraf-im tecgraf-cd)")
    endif()
endforeach()

message(STATUS "IM: ${IM_LIBRARY}")
message(STATUS "CD: ${CD_LIBRARY}")

# FFTW is optional: without it the Fourier transform operations are simply not offered, which is
# what the USE_FFTW define has always meant here.
if(IMLAB_ENABLE_FFTW)
    find_library(IM_FFTW3_LIBRARY im_fftw3 HINTS ENV IM PATH_SUFFIXES lib)
    find_library(FFTW3_LIBRARY fftw3)
    find_library(FFTW3F_LIBRARY fftw3f)

    if(IM_FFTW3_LIBRARY AND FFTW3_LIBRARY AND FFTW3F_LIBRARY)
        message(STATUS "FFTW: ${FFTW3_LIBRARY}")
    else()
        message(STATUS "FFTW not found, building without the Fourier transform operations")
        set(IMLAB_ENABLE_FFTW OFF)
    endif()
endif()

# ------------------------------------------------- IupPlot and IupIm, from IUP source ----
#
# These two ship as source in the IUP tree rather than as built libraries, so they are compiled
# here. That also keeps this build independent of how the IUP tree happened to be built.

add_library(iup_plot STATIC
    "${IUP_ROOT}/srcplot/iup_plot_ctrl.cpp"
    "${IUP_ROOT}/srcplot/iup_plot_attrib.cpp"
    "${IUP_ROOT}/srcplot/iupPlot.cpp"
    "${IUP_ROOT}/srcplot/iupPlotAxis.cpp"
    "${IUP_ROOT}/srcplot/iupPlotCalc.cpp"
    "${IUP_ROOT}/srcplot/iupPlotData.cpp"
    "${IUP_ROOT}/srcplot/iupPlotDraw.cpp"
    "${IUP_ROOT}/srcplot/iupPlotTick.cpp")

target_include_directories(iup_plot PRIVATE
    "${IUP_ROOT}/include" "${IUP_ROOT}/src" "${IUP_ROOT}/srcplot"
    "${IUP_ROOT}/srccd"          # iup_cdutil.h, the IUP-to-CD helpers IupPlot draws through
    "${CD_INCLUDE_DIR}")

add_library(iup_im STATIC "${IUP_ROOT}/srcim/iup_im.c")
target_include_directories(iup_im PRIVATE
    "${IUP_ROOT}/include" "${IUP_ROOT}/src" "${IM_INCLUDE_DIR}")

foreach(helper iup_plot iup_im)
    if(APPLE)
        target_compile_options(${helper} PRIVATE "-F${IUP_LIB_DIR}")
    endif()
endforeach()

# ---------------------------------------------------------------------- ImLab itself ----

set(IMLAB_SRC_BASE
    src/imlab.cpp
    src/imagefile.cpp
    src/plugin_process.cpp
    src/button_images.cpp
    src/splash.cpp
    src/documentlist.cpp
    src/imagedocument.cpp
    src/counter_preview.cpp)

set(IMLAB_SRC_WINDOWS
    windows/imagewindow.cpp
    windows/mainwindow.cpp
    windows/tridimwindow.cpp
    windows/bitmapwindow.cpp
    windows/histogramwindow.cpp
    windows/matrixwindow.cpp
    windows/resultswindow.cpp
    windows/mainwindow_file.cpp
    windows/mainwindow_image.cpp
    windows/mainwindow_menu.cpp
    windows/mainwindow_view.cpp)

set(IMLAB_SRC_DIALOGS
    dialogs/fullscreen.cpp
    dialogs/dialogs.cpp
    dialogs/saveas.cpp
    dialogs/editattrib.cpp
    dialogs/editpalette.cpp)

# These carry no ImLab dependencies and are meant to be reusable elsewhere
set(IMLAB_SRC_UTIL
    util/im_imagematch.c
    util/im_imageview.c
    util/im_clipboard.c
    util/counter.c
    util/statusbar.c
    util/utl_file.c)

set(IMLAB_SRC_PROCESS
    process/arithmetic.cpp process/color.cpp process/convolve.cpp process/geometric.cpp
    process/histogram.cpp process/threshold.cpp process/transform.cpp process/render.cpp
    process/statistics.cpp process/convolve_rank.cpp process/logic.cpp
    process/morphology_bin.cpp process/morphology_gray.cpp process/tonegamut.cpp
    process/quantize.cpp process/resize.cpp process/effects.cpp process/kernel.cpp
    process/unarithmetic.cpp process/analyze.cpp process/binary.cpp process/remotesens.cpp)

list(TRANSFORM IMLAB_SRC_WINDOWS PREPEND src/)
list(TRANSFORM IMLAB_SRC_DIALOGS PREPEND src/)
list(TRANSFORM IMLAB_SRC_UTIL PREPEND src/)
list(TRANSFORM IMLAB_SRC_PROCESS PREPEND src/)

set(IMLAB_SOURCES
    ${IMLAB_SRC_BASE} ${IMLAB_SRC_WINDOWS} ${IMLAB_SRC_DIALOGS}
    ${IMLAB_SRC_UTIL} ${IMLAB_SRC_PROCESS})

# src/plugin_capture.cpp and src/dialogs/imagecapture.cpp are DirectShow video capture, and are
# Windows-only in the original build too.
if(WIN32)
    list(APPEND IMLAB_SOURCES src/plugin_capture.cpp src/dialogs/imagecapture.cpp src/imlab.rc)
endif()

add_executable(imlab ${IMLAB_SOURCES})

target_include_directories(imlab PRIVATE
    src src/windows src/dialogs src/util src/process
    "${IM_INCLUDE_DIR}" "${CD_INCLUDE_DIR}" "${IUP_ROOT}/include")

target_link_libraries(imlab PRIVATE
    iup_plot iup_im
    ${IM_PROCESS_LIBRARY} ${IM_JP2_LIBRARY} ${IM_LIBRARY}
    ${CD_LIBRARY})

if(IMLAB_ENABLE_FFTW)
    target_compile_definitions(imlab PRIVATE USE_FFTW)
    target_link_libraries(imlab PRIVATE ${IM_FFTW3_LIBRARY} ${FFTW3F_LIBRARY} ${FFTW3_LIBRARY})
endif()

if(WIN32)
    target_compile_definitions(imlab PRIVATE USE_VIDEOCAPTURE USE_AVI)
endif()

find_package(OpenGL REQUIRED)
target_link_libraries(imlab PRIVATE OpenGL::GL)

if(APPLE)
    # IUP is built as frameworks here. iupim and iup_plot are the two that are not, and are
    # compiled above; iupcd bridges IUP canvases to CD; iupgl backs the 3D view.
    target_link_options(imlab PRIVATE "-F${IUP_LIB_DIR}")
    target_link_libraries(imlab PRIVATE
        "-framework iup" "-framework iupcontrols" "-framework iupimglib"
        "-framework iupcd" "-framework iupgl" "-framework Cocoa")

    # so the frameworks are found at run time without DYLD_FRAMEWORK_PATH
    set_target_properties(imlab PROPERTIES
        BUILD_RPATH "${IUP_LIB_DIR}"
        INSTALL_RPATH "${IUP_LIB_DIR}")
else()
    target_link_directories(imlab PRIVATE "${IUP_LIB_DIR}")
    target_link_libraries(imlab PRIVATE iupcontrols iupimglib iupcd iupgl iup)
endif()

# --------------------------------------------------------------------------- assets ----
#
# ImLab looks for its images beside the executable, or one directory above (see
# load_image_imlab_logo in src/splash.cpp), so put them where it will actually look.

add_custom_command(TARGET imlab POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/etc" "$<TARGET_FILE_DIR:imlab>"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/krn" "$<TARGET_FILE_DIR:imlab>/krn"
    COMMENT "Copying ImLab images and convolution kernels beside the executable")

install(TARGETS imlab RUNTIME DESTINATION bin)
install(DIRECTORY etc/ DESTINATION bin FILES_MATCHING PATTERN "*.png")
install(DIRECTORY krn/ DESTINATION bin/krn)

message(STATUS "")
message(STATUS "ImLab ${PROJECT_VERSION}")
message(STATUS "  FFTW transforms: ${IMLAB_ENABLE_FFTW}")
message(STATUS "")
