#####
# 'billee_deployment' Deployment:
#
# This registers the 'billee_deployment' deployment to the build system. 
# Custom components that have not been added at the project-level should be added to 
# the list below.
#
#####

# Deployment is only compatible with the Arduino platform
restrict_platforms(ArduinoFw)

# The cookiecutter that generated this deployment writes autocoded/source
# #includes as "billee_deployment/Top/X.hpp" (e.g. Main.cpp, TopologyDefs.hpp),
# assuming - as F' deployments normally do - that this deployment sits
# directly under settings.ini's project_root, one path segment deep. This
# repo's fprime-bootstrap-generated layout nests it one level deeper instead
# (FprimeArduinoBilleeScm/billee_deployment/), so neither the source tree
# nor the build tree naturally has "FprimeArduinoBilleeScm/" itself on the
# include path - add it explicitly, for both trees, rather than restructure
# the whole project to match the cookiecutter's assumption.
include_directories(
    "${CMAKE_CURRENT_LIST_DIR}/.."
    "${CMAKE_CURRENT_BINARY_DIR}/.."
)

###
# Topology and Components
###
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/config/")
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Top/")

# Add custom components to this specific deployment here
# add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/MyComponent/")

register_fprime_deployment(
    SOURCES
        "${CMAKE_CURRENT_LIST_DIR}/Main.cpp"
    DEPENDS
        ${FPRIME_CURRENT_MODULE}_Top
)

# finalize_arduino_executable() calls setup_arduino_libraries() before
# checking whether this is F''s lightweight sub-build info-cache pass (where
# __fprime_config doesn't exist yet, so setup_arduino_libraries() crashes
# trying to add_dependencies() on it) - and even that check is broken: it
# tests FPRIME_SUBBOUILD_TARGETS (missing an underscore, misspelled
# "BOUILD"), which never matches F' core's real FPRIME_SUB_BUILD_TARGETS, so
# it can never fire on any board or F' version. Do the correct check here,
# first, from project code rather than the submodule.
if (NOT DEFINED FPRIME_SUB_BUILD_TARGETS)
    # setup_arduino_libraries() also does
    # add_dependencies(fprime_arduino_patcher __fprime_config default_config)
    # - but __fprime_config is never defined anywhere in F' core. default_config,
    # the other dependency in that same call, is F' core's actual base-config
    # target. A placeholder target satisfies add_dependencies() (it only needs
    # the target to exist, not do anything); the real config content still
    # comes from default_config.
    if (NOT TARGET __fprime_config)
        add_library(__fprime_config INTERFACE)
    endif()
    finalize_arduino_executable("${FPRIME_CURRENT_MODULE}")
endif()
