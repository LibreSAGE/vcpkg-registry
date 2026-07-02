# dxvk is a Vulkan-based D3D8/9/10/11 translation layer built with the Meson
# build system. See https://github.com/LibreSAGE/dxvk.
#
# The GitHub release tarball does not contain dxvk's git submodules, so we fetch
# and stage the ones that are required to build:
#   * subprojects/dxbc-spirv     - DXBC -> SPIR-V compiler (required, no fallback)
#   * subprojects/libdisplay-info - EDID/DisplayID parsing (required dependency)
#   * include/native/directx     - MinGW DirectX headers for the native build
# The Vulkan and SPIR-V headers (normally the include/vulkan and include/spirv
# submodules) are provided instead by the vulkan-headers and spirv-headers
# dependencies, which Meson picks up through its header-check fallback.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO LibreSAGE/dxvk
    REF "v${VERSION}"
    SHA512 dc29ede4d7079b7ecbab0bea4456acf0bb6717cf8fcdfdbe2456b773c1322bc083fd6cc3194a44807b10eb6f3620be3d0e0468f38ba7294f314090316776cac4
    HEAD_REF master
)

# --- Stage required submodules (pinned to the commits referenced by v3.0) ---
vcpkg_from_github(
    OUT_SOURCE_PATH DXBC_SPIRV_SOURCE
    REPO doitsujin/dxbc-spirv
    REF aa18e0b062ae9485c9188db12ff77122f51fc4d3
    SHA512 6d18684de52dfe486dc0d6099dbd9d408278535fcf3c376671686b8d137d1bb54dee7e400b59810be9cf3cf65fad2fd262d92240529fd80aa19489c7c8b5a1c4
)
vcpkg_from_github(
    OUT_SOURCE_PATH LIBDISPLAY_INFO_SOURCE
    REPO doitsujin/libdisplay-info
    REF 275e6459c7ab1ddd4b125f28d0440716e4888078
    SHA512 4816510f1d92d3e4ca266d29a9fbe583e9ef65af44ee2050e0b575661c1ff0ebcfb84cc499c4fdc594e0fde7261f946ca8748207b29af920605174f45ced260e
)
vcpkg_from_github(
    OUT_SOURCE_PATH DIRECTX_HEADERS_SOURCE
    REPO Joshua-Ashton/mingw-directx-headers
    REF 9df86f2341616ef1888ae59919feaa6d4fad693d
    SHA512 5563b842d2c6f97c2a1abfd2d5066c15f1e4f310324310a61f98ed62731f90a0fd16d419858bb1ef8351a1d911e3de3d8ff861af0e69dac373f25b2f3d76a179
)
# dxbc-spirv #includes the SPIR-V headers through a hard-coded relative path
# (submodules/spirv_headers/...), so it needs its own nested submodule staged
# in place rather than relying on the spirv-headers include directory.
vcpkg_from_github(
    OUT_SOURCE_PATH SPIRV_HEADERS_SOURCE
    REPO KhronosGroup/SPIRV-Headers
    REF c8ad050fcb29e42a2f57d9f59e97488f465c436d
    SHA512 f6a9beccd5f98325f65cbd78412fb409cf5f1476dbced3641fec5728a9c6fad4183dbbc01d8a501bc82a8b5cf5dd5131ae1f46cfcd92e792c32a569e31d083ea
)

foreach(staging IN ITEMS
    "${DXBC_SPIRV_SOURCE}=subprojects/dxbc-spirv"
    "${LIBDISPLAY_INFO_SOURCE}=subprojects/libdisplay-info"
    "${DIRECTX_HEADERS_SOURCE}=include/native/directx"
    "${SPIRV_HEADERS_SOURCE}=subprojects/dxbc-spirv/submodules/spirv_headers"
)
    string(REPLACE "=" ";" staging "${staging}")
    list(GET staging 0 staging_src)
    list(GET staging 1 staging_dst)
    file(REMOVE_RECURSE "${SOURCE_PATH}/${staging_dst}")
    get_filename_component(staging_parent "${SOURCE_PATH}/${staging_dst}" DIRECTORY)
    file(MAKE_DIRECTORY "${staging_parent}")
    file(RENAME "${staging_src}" "${SOURCE_PATH}/${staging_dst}")
endforeach()

# --- Map vcpkg features onto dxvk's Meson options ---
# enable_* are booleans (true/false); native_* are Meson features
# (enabled/disabled). vcpkg_check_features only emits CMake-style ON/OFF, so we
# build these by hand.
set(DXVK_OPTIONS "-Dbuild_id=false")
foreach(api IN ITEMS dxgi d3d8 d3d9 d3d10 d3d11)
    if(api IN_LIST FEATURES)
        list(APPEND DXVK_OPTIONS "-Denable_${api}=true")
    else()
        list(APPEND DXVK_OPTIONS "-Denable_${api}=false")
    endif()
endforeach()
foreach(wsi IN ITEMS sdl2 sdl3 glfw)
    if(wsi IN_LIST FEATURES)
        list(APPEND DXVK_OPTIONS "-Dnative_${wsi}=enabled")
    else()
        list(APPEND DXVK_OPTIONS "-Dnative_${wsi}=disabled")
    endif()
endforeach()

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS ${DXVK_OPTIONS}
)

vcpkg_install_meson()

vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

# The native build installs its public headers (d3d*/dxgi/WSI) under
# include/dxvk; keep the release copy and drop the duplicate debug tree.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

# Upstream only ships pkg-config files. Generate a CMake package config that
# exposes an imported target (DXVK::<component>) for every enabled component so
# consumers can use find_package(DXVK CONFIG). Map each feature to the base name
# of the library it produces.
set(_dxvk_feature_libs
    "dxgi=dxgi:dxvk_dxgi"
    "d3d8=d3d8:dxvk_d3d8"
    "d3d9=d3d9:dxvk_d3d9"
    "d3d10=d3d10core:dxvk_d3d10core"
    "d3d11=d3d11:dxvk_d3d11"
)
set(DXVK_CMAKE_TARGETS "")
foreach(_map IN LISTS _dxvk_feature_libs)
    string(REPLACE "=" ";" _map "${_map}")
    list(GET _map 0 _feature)
    list(GET _map 1 _target)
    if(_feature IN_LIST FEATURES)
        list(APPEND DXVK_CMAKE_TARGETS "${_target}")
    endif()
endforeach()

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/DXVKConfig.cmake.in"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/DXVKConfig.cmake"
    @ONLY
)
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/DXVKConfigVersion.cmake"
    VERSION "${VERSION}"
    COMPATIBILITY SameMajorVersion
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
