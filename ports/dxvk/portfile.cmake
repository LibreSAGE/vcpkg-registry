# dxvk is a Vulkan-based D3D8/9/10/11 translation layer built with the Meson
# build system. See https://github.com/LibreSAGE/dxvk.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO LibreSAGE/dxvk
    REF "v${VERSION}"
    SHA512 dc29ede4d7079b7ecbab0bea4456acf0bb6717cf8fcdfdbe2456b773c1322bc083fd6cc3194a44807b10eb6f3620be3d0e0468f38ba7294f314090316776cac4
    HEAD_REF master
)

# Map vcpkg features onto dxvk's Meson options.
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        dxgi  enable_dxgi
        d3d8  enable_d3d8
        d3d9  enable_d3d9
        d3d10 enable_d3d10
        d3d11 enable_d3d11
)

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -Dbuild_id=false
)

vcpkg_install_meson()

vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

# dxvk ships only runtime DLLs / import libraries; there are no public headers
# to install, so drop the empty include tree if Meson created one.
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
