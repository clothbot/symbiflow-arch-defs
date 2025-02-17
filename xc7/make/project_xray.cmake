function(get_project_xray_dependencies var part element)
  list(APPEND ${var} ${PRJXRAY_DB_DIR}/Info.md)
  string(TOLOWER ${element} element_LOWER)
  file(GLOB other_sources ${PRJXRAY_DB_DIR}/${part}/*${element_LOWER}*.db)
  list(APPEND ${var} ${other_sources})
  file(GLOB other_sources ${PRJXRAY_DB_DIR}/${part}/*${element}*.json)
  list(APPEND ${var} ${other_sources})
  set(${var} ${${var}} PARENT_SCOPE)
endfunction()

function(PROJECT_XRAY_DUMMY_SITE)
  set(options)
  set(oneValueArgs PART SITE)

  cmake_parse_arguments(
    PROJECT_XRAY_DUMMY_SITE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  string(TOLOWER ${PROJECT_XRAY_DUMMY_SITE_SITE} SITE)

  get_target_property_required(PYTHON3 env PYTHON3)
  get_target_property(PYTHON3_TARGET env PYTHON3_TARGET)

  set(DUMMY_SITE_IMPORT ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_generate_dummy_site.py)
  get_project_xray_dependencies(DEPS ${PROJECT_XRAY_DUMMY_SITE_PART} ${SITE})

  add_custom_command(
    OUTPUT ${SITE}.pb_type.xml ${SITE}.model.xml
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${DUMMY_SITE_IMPORT}
    --part ${PROJECT_XRAY_DUMMY_SITE_PART}
    --site_type ${PROJECT_XRAY_DUMMY_SITE_SITE}
    --output-pb-type ${CMAKE_CURRENT_BINARY_DIR}/${SITE}.pb_type.xml
    --output-model ${CMAKE_CURRENT_BINARY_DIR}/${SITE}.model.xml
    DEPENDS
    ${DUMMY_SITE_IMPORT}
      ${DEPS}
      ${PYTHON3} ${PYTHON3_TARGET}
    )

  add_file_target(FILE ${SITE}.pb_type.xml GENERATED)
  add_file_target(FILE ${SITE}.model.xml GENERATED)
endfunction()

function(PROJECT_XRAY_TILE)
  #
  # This function is used to create targets to generate pb_type, model and tile XML definitions.
  #
  # PART name of the part that is considered (e.g. artix7, zynq7, etc.)
  # TILE name of the tile that has to be generated (e.g. CLBLM_R, BRAM_L, etc.)
  # SITE_TYPES list of sites contained in the considered tile (e.g. CLBLM_R contains a SLICEM and SLICEL sites)
  # EQUIVALENT_TILES list of pb_types that can be placed at the tile's location (e.g. SLICEM tile can have both SLICEM and SLICEL pb_types)
  # SITE_AS_TILE option to state if the tile physically is a site, but it needs to be treated as a site
  # USE_DATABASE option enables usage of connection database for tile
  #     definition, instead of using the project X-Ray database.
  # PRIORITY option that enables the priority assignments to the equivalent sites
  # BOTH_SIDE_COORD option that enables the assignment of both coordinates to the fasm prefixes
  # FILTER_X can be supplied to filter to sites that have the given X
  #     coordinate.
  #
  # Usage:
  # ~~~
  # project_xray_tile(
  #   PART <part_name>
  #   TILE <tile_name>
  #   SITE_TYPES <site_name_1> <site_name_2> ...
  #   EQUIVALENT_SITES <equivalent_site_name_1> <equivalent_site_name_2> ...
  #   PRIORITY (option)
  #   SITE_AS_TILE (option)
  #   FUSED_SITES (option)
  #   USE_DATABASE (option)
  #   BOTH_SITE_COORDS (option)
  #   [FILTER_X <x_coord>]
  #   )
  # ~~~

  set(options PRIORITY FUSED_SITES SITE_AS_TILE USE_DATABASE BOTH_SITE_COORDS)
  set(oneValueArgs PART TILE FILTER_X)
  set(multiValueArgs SITE_TYPES EQUIVALENT_SITES)
  cmake_parse_arguments(
    PROJECT_XRAY_TILE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  string(TOLOWER ${PROJECT_XRAY_TILE_TILE} TILE)

  get_target_property_required(PYTHON3 env PYTHON3)
  get_target_property(PYTHON3_TARGET env PYTHON3_TARGET)

  set(TILE_IMPORT ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_tile_import.py)
  get_project_xray_dependencies(DEPS ${PROJECT_XRAY_TILE_PART} ${TILE})

  set(PART ${PROJECT_XRAY_TILE_PART})
  set(PB_TYPE_INCLUDE_FILES "")
  set(MODEL_INCLUDE_FILES "")
  foreach(SITE_TYPE ${PROJECT_XRAY_TILE_SITE_TYPES})
    string(TOLOWER ${SITE_TYPE} SITE_TYPE_LOWER)
    append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}.pb_type.xml)
    append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}.model.xml)
    list(APPEND PB_TYPE_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}.pb_type.xml)
    list(APPEND MODEL_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}.model.xml)
  endforeach()
  string(REPLACE ";" "," SITE_TYPES_COMMA "${PROJECT_XRAY_TILE_SITE_TYPES}")

  append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)
  get_file_location(PIN_ASSIGNMENTS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)

  set(FUSED_SITES_ARGS "")
  if(PROJECT_XRAY_TILE_FUSED_SITES)
      set(FUSED_SITES_ARGS "--fused_sites")
  endif()
  if(PROJECT_XRAY_TILE_SITE_AS_TILE)
      set(FUSED_SITES_ARGS "--site_as_tile")
  endif()
  if(PROJECT_XRAY_TILE_USE_DATABASE)
      set(GENERIC_CHANNELS
        ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/channels.db)
      get_file_location(GENERIC_CHANNELS_LOCATION ${GENERIC_CHANNELS})
      append_file_dependency(DEPS ${GENERIC_CHANNELS})
      set(FUSED_SITES_ARGS --connection_database ${GENERIC_CHANNELS_LOCATION})
  endif()

  set(PHYSICAL_TILE_ARGS "")
  if(PROJECT_XRAY_TILE_PRIORITY)
    set(PHYSICAL_TILE_ARGS "--priority")
  endif()

  set(BOTH_SITE_COORDS_ARGS "")
  if(PROJECT_XRAY_TILE_BOTH_SITE_COORDS)
    set(BOTH_SITE_COORDS_ARGS "--both_site_coords")
  endif()
  set(FILTER_X_ARGS "")
  if(NOT "${PROJECT_XRAY_TILE_FILTER_X}" STREQUAL "")
      set(FILTER_X_ARGS --filter_x ${PROJECT_XRAY_TILE_FILTER_X})
  endif()

  add_custom_command(
    OUTPUT ${TILE}.pb_type.xml ${TILE}.model.xml
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${TILE_IMPORT}
    --part ${PROJECT_XRAY_TILE_PART}
    --tile ${PROJECT_XRAY_TILE_TILE}
    --site_directory ${symbiflow-arch-defs_BINARY_DIR}/xc7/primitives
    --site_types ${SITE_TYPES_COMMA}
    --pin_assignments ${PIN_ASSIGNMENTS}
    --output-pb-type ${CMAKE_CURRENT_BINARY_DIR}/${TILE}.pb_type.xml
    --output-model ${CMAKE_CURRENT_BINARY_DIR}/${TILE}.model.xml
    ${FUSED_SITES_ARGS}
    ${BOTH_SITE_COORDS_ARGS}
    ${FILTER_X_ARGS}
    DEPENDS
    ${TILE_IMPORT}
      ${DEPS}
      ${PYTHON3} ${PYTHON3_TARGET} simplejson
    )

  add_file_target(FILE ${TILE}.pb_type.xml GENERATED)
  get_file_target(PB_TYPE_TARGET ${TILE}.pb_type.xml)
  set_target_properties(${PB_TYPE_TARGET} PROPERTIES INCLUDE_FILES "${PB_TYPE_INCLUDE_FILES}")

  get_file_target(MODEL_TARGET ${TILE}.model.xml)
  add_custom_target(${MODEL_TARGET})

  # Linearize the dependency to prevent double builds.
  add_dependencies(${MODEL_TARGET} ${PB_TYPE_TARGET})
  set_target_properties(${MODEL_TARGET} PROPERTIES
      INCLUDE_FILES "${MODEL_INCLUDE_FILES}"
      LOCATION ${CMAKE_CURRENT_BINARY_DIR}/${TILE}.model.xml
      )

  # tile tags
  set(PHYSICAL_TILE_IMPORT ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_physical_tile_import.py)
  get_project_xray_dependencies(DEPS ${PROJECT_XRAY_TILE_PART} ${TILE})

  foreach(EQUIVALENT_SITE ${PROJECT_XRAY_TILE_EQUIVALENT_SITES})
    string(TOLOWER ${EQUIVALENT_SITE} EQUIVALENT_SITE_LOWER)
    append_file_dependency(TILES_DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${EQUIVALENT_SITE_LOWER}/${EQUIVALENT_SITE_LOWER}.pb_type.xml)
    list(APPEND EQUIVALENT_SITES_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${EQUIVALENT_SITE_LOWER}/${EQUIVALENT_SITE_LOWER}.pb_type.xml)
  endforeach()
  append_file_dependency(TILES_DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${TILE}/${TILE}.pb_type.xml)
  list(APPEND EQUIVALENT_SITES_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${TILE}/${TILE}.pb_type.xml)

  string(REPLACE ";" "," EQUIVALENT_SITES_COMMA "${PROJECT_XRAY_TILE_EQUIVALENT_SITES}")

  add_custom_command(
    OUTPUT ${TILE}.tile.xml
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${PHYSICAL_TILE_IMPORT}
    --part ${PROJECT_XRAY_TILE_PART}
    --tile ${PROJECT_XRAY_TILE_TILE}
    --tiles-directory ${symbiflow-arch-defs_BINARY_DIR}/xc7/archs/${PART}/tiles
    --equivalent-sites=${EQUIVALENT_SITES_COMMA}
    --pin-prefix=${PIN_PREFIX_COMMA}
    --output-tile ${CMAKE_CURRENT_BINARY_DIR}/${TILE}.tile.xml
    --pin_assignments ${PIN_ASSIGNMENTS}
    ${PHYSICAL_TILE_ARGS}
    DEPENDS
    ${PHYSICAL_TILE_IMPORT}
      ${TILES_DEPS}
      ${PYTHON3} ${PYTHON3_TARGET} simplejson
    )

  add_file_target(FILE ${TILE}.tile.xml GENERATED)
  get_file_target(TILE_TARGET ${TILE}.tile.xml)
  set_target_properties(${TILE_TARGET} PROPERTIES INCLUDE_FILES "${EQUIVALENT_SITES_INCLUDE_FILES}")
endfunction()

function(PROJECT_XRAY_ARCH)
  set(options)
  set(oneValueArgs PART USE_ROI DEVICE GRAPH_LIMIT)
  set(multiValueArgs TILE_TYPES PB_TYPES)
  cmake_parse_arguments(
    PROJECT_XRAY_ARCH
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  get_target_property_required(PYTHON3 env PYTHON3)
  get_target_property(PYTHON3_TARGET env PYTHON3_TARGET)

  set(PART ${PROJECT_XRAY_ARCH_PART})
  set(DEVICE ${PROJECT_XRAY_ARCH_DEVICE})

  set(ARCH_IMPORT ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_arch_import.py)
  set(CREATE_SYNTH_TILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_create_synth_tiles.py)
  set(CREATE_EDGES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_create_edges.py)
  set(DEPS ${PRJXRAY_DB_DIR}/${PART}/tilegrid.json)

  if("${PROJECT_XRAY_ARCH_PB_TYPES}" STREQUAL "")
    set(PROJECT_XRAY_ARCH_PB_TYPES ${PROJECT_XRAY_ARCH_TILE_TYPES})
  endif()

  set(ARCH_INCLUDE_FILES "")
  foreach(TILE_TYPE ${PROJECT_XRAY_ARCH_TILE_TYPES})
    string(TOLOWER ${TILE_TYPE} TILE_TYPE_LOWER)
    set(TILE_XML ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${TILE_TYPE_LOWER}/${TILE_TYPE_LOWER}.tile.xml)
    append_file_dependency(DEPS ${TILE_XML})
    get_file_location(TILE_XML_LOCATION ${TILE_XML})

    get_file_target(TILE_TARGET ${TILE_XML})
    get_target_property(INCLUDE_FILES ${TILE_TARGET} INCLUDE_FILES)
    list(APPEND ARCH_INCLUDE_FILES ${TILE_XML} ${INCLUDE_FILES})
  endforeach()

  foreach(PB_TYPE ${PROJECT_XRAY_ARCH_PB_TYPES})
    string(TOLOWER ${PB_TYPE} PB_TYPE_LOWER)
    set(PB_TYPE_XML ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.pb_type.xml)
    set(MODEL_XML ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/tiles/${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.model.xml)
    append_file_dependency(DEPS ${PB_TYPE_XML})
    append_file_dependency(DEPS ${MODEL_XML})

    get_file_target(PB_TYPE_TARGET ${PB_TYPE_XML})
    get_target_property(INCLUDE_FILES ${PB_TYPE_TARGET} INCLUDE_FILES)
    list(APPEND ARCH_INCLUDE_FILES ${PB_TYPE_XML} ${INCLUDE_FILES})

    get_file_target(MODEL_TARGET ${MODEL_XML})
    get_target_property(INCLUDE_FILES ${MODEL_TARGET} INCLUDE_FILES)
    list(APPEND ARCH_INCLUDE_FILES ${MODEL_XML} ${INCLUDE_FILES})
  endforeach()

  set(ROI_ARG "")
  set(ROI_ARG_FOR_CREATE_EDGES "")

  set(GENERIC_CHANNELS
      ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/channels.db)
  get_file_location(GENERIC_CHANNELS_LOCATION ${GENERIC_CHANNELS})

  if(NOT "${PROJECT_XRAY_ARCH_USE_ROI}" STREQUAL "")
    set(SYNTH_DEPS "")
    append_file_dependency(SYNTH_DEPS ${GENERIC_CHANNELS})
    add_custom_command(
      OUTPUT synth_tiles.json
      COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
      ${PYTHON3} ${CREATE_SYNTH_TILES}
        --db_root ${PRJXRAY_DB_DIR}/${PART}/
        --connection_database ${GENERIC_CHANNELS_LOCATION}
        --roi ${PROJECT_XRAY_ARCH_USE_ROI}
        --synth_tiles ${CMAKE_CURRENT_BINARY_DIR}/synth_tiles.json
      DEPENDS
        ${CREATE_SYNTH_TILES}
        ${PROJECT_XRAY_ARCH_USE_ROI} ${SYNTH_DEPS}
        ${PYTHON3} ${PYTHON3_TARGET} simplejson intervaltree
        )

    add_file_target(FILE synth_tiles.json GENERATED)
    set_target_properties(${ARCH_TARGET} PROPERTIES USE_ROI TRUE)
    set_target_properties(${ARCH_TARGET} PROPERTIES
        SYNTH_TILES ${CMAKE_CURRENT_SOURCE_DIR}/synth_tiles.json)

    set(ROI_ARG --use_roi ${PROJECT_XRAY_ARCH_USE_ROI} --synth_tiles ${CMAKE_CURRENT_BINARY_DIR}/synth_tiles.json)
    append_file_dependency(DEPS synth_tiles.json)
    list(APPEND DEPS ${PROJECT_XRAY_ARCH_USE_ROI})

    set(ROI_ARG_FOR_CREATE_EDGES --synth_tiles ${CMAKE_CURRENT_BINARY_DIR}/synth_tiles.json)
    append_file_dependency(CHANNELS_DEPS synth_tiles.json)
  endif()

  if(NOT "${PROJECT_XRAY_ARCH_GRAPH_LIMIT}" STREQUAL "")
    set(ROI_ARG_FOR_CREATE_EDGES --graph_limit ${PROJECT_XRAY_ARCH_GRAPH_LIMIT})
    set(ROI_ARG --graph_limit ${PROJECT_XRAY_ARCH_GRAPH_LIMIT})
  endif()


  set(GENERIC_CHANNELS
      ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/channels.db)
  append_file_dependency(CHANNELS_DEPS ${GENERIC_CHANNELS})
  append_file_dependency(CHANNELS_DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)
  get_file_location(PIN_ASSIGNMENTS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)
  list(APPEND CHANNELS_DEPS ${PRJXRAY_DB_DIR}/${PART}/tilegrid.json)
  list(APPEND CHANNELS_DEPS ${PRJXRAY_DB_DIR}/${PART}/tileconn.json)

  add_custom_command(
    OUTPUT channels.db
    COMMAND ${CMAKE_COMMAND} -E copy ${GENERIC_CHANNELS_LOCATION} ${CMAKE_CURRENT_BINARY_DIR}/channels.db
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${CREATE_EDGES}
      --db_root ${PRJXRAY_DB_DIR}/${PART}/
      --pin_assignments ${PIN_ASSIGNMENTS}
      --connection_database ${CMAKE_CURRENT_BINARY_DIR}/channels.db
      ${ROI_ARG_FOR_CREATE_EDGES}
    DEPENDS
    ${PYTHON3} ${PYTHON3_TARGET} ${CREATE_EDGES}
      ${CHANNELS_DEPS}
    )

  add_file_target(FILE channels.db GENERATED)

  append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)
  append_file_dependency(DEPS channels.db)

  string(REPLACE ";" "," TILE_TYPES_COMMA "${PROJECT_XRAY_ARCH_TILE_TYPES}")
  string(REPLACE ";" "," PB_TYPES_COMMA "${PROJECT_XRAY_ARCH_PB_TYPES}")

  add_custom_command(
    OUTPUT arch.xml
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${ARCH_IMPORT}
      --part ${PROJECT_XRAY_ARCH_PART}
      --connection_database ${CMAKE_CURRENT_BINARY_DIR}/channels.db
      --output-arch ${CMAKE_CURRENT_BINARY_DIR}/arch.xml
      --tile-types "${TILE_TYPES_COMMA}"
      --pb_types "${PB_TYPES_COMMA}"
      --pin_assignments ${PIN_ASSIGNMENTS}
      --device ${DEVICE}
      ${ROI_ARG}
    DEPENDS
    ${ARCH_IMPORT}
    ${DEPS}
    ${PYTHON3} ${PYTHON3_TARGET} simplejson
    )

  add_file_target(FILE arch.xml GENERATED)
  get_file_target(ARCH_TARGET arch.xml)
  set_target_properties(${ARCH_TARGET} PROPERTIES INCLUDE_FILES "${ARCH_INCLUDE_FILES}")
endfunction()

function(PROJECT_XRAY_PREPARE_DATABASE)
  set(options)
  set(oneValueArgs PART)
  set(multiValueArgs )
  cmake_parse_arguments(
    PROJECT_XRAY_PREPARE_DATABASE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  get_target_property_required(PYTHON3 env PYTHON3)
  get_target_property(PYTHON3_TARGET env PYTHON3_TARGET)

  set(PART ${PROJECT_XRAY_PREPARE_DATABASE_PART})
  set(FORM_CHANNELS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_form_channels.py)
  set(ASSIGN_PINS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_assign_tile_pin_direction.py)
  file(GLOB DEPS ${PRJXRAY_DB_DIR}/${PART}/*.json)
  file(GLOB DEPS2 ${PRJXRAY_DIR}/prjxray/*.py)

  set(CHANNELS channels.db)
  add_custom_command(
    OUTPUT ${CHANNELS}
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${FORM_CHANNELS}
    --db_root ${PRJXRAY_DB_DIR}/${PART}/
    --connection_database ${CMAKE_CURRENT_BINARY_DIR}/${CHANNELS}
    DEPENDS
    ${FORM_CHANNELS}
    ${DEPS} ${DEPS2} simplejson progressbar2 intervaltree hilbertcurve
    ${PYTHON3} ${PYTHON3_TARGET}
    )

  add_file_target(FILE ${CHANNELS} GENERATED)

  append_file_dependency(DEPS ${CHANNELS})
  set(PIN_ASSIGNMENTS pin_assignments.json)
  add_custom_command(
    OUTPUT ${PIN_ASSIGNMENTS}
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${ASSIGN_PINS}
    --db_root ${PRJXRAY_DB_DIR}/${PART}/
    --connection_database ${CMAKE_CURRENT_BINARY_DIR}/${CHANNELS}
    --pin_assignments ${CMAKE_CURRENT_BINARY_DIR}/${PIN_ASSIGNMENTS}
    DEPENDS
    ${ASSIGN_PINS}
    ${DEPS} ${DEPS2}
    ${PYTHON3} ${PYTHON3_TARGET} simplejson progressbar2
    )

  add_file_target(FILE ${PIN_ASSIGNMENTS} GENERATED)
endfunction()

function(PROJECT_XRAY_EQUIV_TILE)
  #
  # This function is used to create targets to generate pb_type, model and
  # tile XML definitions for tile groups.
  #
  # A tile group is a set of related tiles that share some equivilances.
  #
  # PART name of the part that is considered (e.g. artix7, zynq7, etc.)
  # TILES name of the tile that has to be generated (e.g. RIOPAD_M, etc.)
  # PB_TYPES list of pb_types to be generated that map into tiles.
  # PB_TYPE_SITES list of variables containing a list of site types in each
  #     PB_TYPE.
  # SITE_EQUIV list of sites that have an equivalent relationship.
  #
  #     Examples:
  #         SITE_EQUIV IOB33M=IOB33 IOB33S=IOB33
  #
  #         IOB33M can be used as a IOB33
  #         IOB33S can be used as a IOB33.
  #
  #  The length of PB_TYPES and PB_TYPE_SITES should be the same
  #
  # Usage:
  # ~~~
  # project_xray_equiv_tile(
  #   PART <part_name>
  #   TILES <tile_name_1> <tile_name_2> ...
  #   PB_TYPES <site_name_1> <site_name_2> ...
  #   PB_TYPE_SITES <list_name_1> <list_name_2> ...
  #   SITE_EQUIV <general_site1>=<specific_site1> ...
  #   )
  # ~~~

  set(options)
  set(oneValueArgs PART)
  set(multiValueArgs TILES PB_TYPES PB_TYPE_SITES SITE_EQUIV)
  cmake_parse_arguments(
    PROJECT_XRAY_EQUIV_TILE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  if(NOT "${CMAKE_CURRENT_SOURCE_DIR}" STREQUAL "${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PROJECT_XRAY_EQUIV_TILE_PART}/tiles")
      message(FATAL_ERROR "project_xray_equiv_tile can only be invoked from the PART tiles directory (xc7/archs/${PROJECT_XRAY_EQUIV_TILE_PART}/tiles/), in ${CMAKE_CURRENT_SOURCE_DIR}")
  endif()


  # This code is using prefixed variables because PB_TYPE_SITES list are
  # variables from parent scope, and prefixing is the canonical CMake way to
  # avoid collisions.
  list(LENGTH PROJECT_XRAY_EQUIV_TILE_PB_TYPES      PROJECT_XRAY_EQUIV_TILE_NPB_TYPES)
  list(LENGTH PROJECT_XRAY_EQUIV_TILE_PB_TYPE_SITES PROJECT_XRAY_EQUIV_TILE_NPB_TYPE_SITES)

  if(NOT ${PROJECT_XRAY_EQUIV_TILE_NPB_TYPES} EQUAL ${PROJECT_XRAY_EQUIV_TILE_NPB_TYPE_SITES})
      message(FATAL_ERROR "Number of pb_types (${PROJECT_XRAY_EQUIV_TILE_NPB_TYPES}) != number of pb_type sites (${PROJECT_XRAY_EQUIV_TILE_NPB_TYPE_SITES})")
  endif()

  set(PROJECT_XRAY_EQUIV_TILE_SITES "")
  set(PROJECT_XRAY_EQUIV_TILE_PB_TYPES_ARGS "")
  math(EXPR PROJECT_XRAY_EQUIV_TILE_NPB_TYPES_N1 ${PROJECT_XRAY_EQUIV_TILE_NPB_TYPES}-1)
  foreach(PROJECT_XRAY_EQUIV_TILE_IDX RANGE ${PROJECT_XRAY_EQUIV_TILE_NPB_TYPES_N1})
      list(GET PROJECT_XRAY_EQUIV_TILE_PB_TYPES ${PROJECT_XRAY_EQUIV_TILE_IDX} PROJECT_XRAY_EQUIV_TILE_PB_TYPE)
      list(GET PROJECT_XRAY_EQUIV_TILE_PB_TYPE_SITES  ${PROJECT_XRAY_EQUIV_TILE_IDX} PROJECT_XRAY_EQUIV_TILE_PB_SITES)

      # Bring in list from parent scope.
      set(PROJECT_XRAY_EQUIV_TILE_PB_SITES ${${PROJECT_XRAY_EQUIV_TILE_PB_SITES}})

      foreach(PROJECT_XRAY_EQUIV_TILE_SITE ${PROJECT_XRAY_EQUIV_TILE_PB_SITES})
        list(APPEND PROJECT_XRAY_EQUIV_TILE_SITES ${PROJECT_XRAY_EQUIV_TILE_PB_SITES})
      endforeach()

      set(PROJECT_XRAY_EQUIV_TILE_ARG "${PROJECT_XRAY_EQUIV_TILE_PB_TYPE}=${PROJECT_XRAY_EQUIV_TILE_PB_SITES}")
      string(REPLACE ";" "," PROJECT_XRAY_EQUIV_TILE_ARG "${PROJECT_XRAY_EQUIV_TILE_ARG}")

      list(APPEND PROJECT_XRAY_EQUIV_TILE_PB_TYPES_ARGS ${PROJECT_XRAY_EQUIV_TILE_ARG})
  endforeach()

  # Done with variables from parent scope, prefix is not longer required.


  get_target_property_required(PYTHON3 env PYTHON3)
  get_target_property(PYTHON3_TARGET env PYTHON3_TARGET)

  set(PART ${PROJECT_XRAY_EQUIV_TILE_PART})
  set(PB_TYPE_INCLUDE_FILES "")
  set(MODEL_INCLUDE_FILES "")
  list(REMOVE_DUPLICATES PROJECT_XRAY_EQUIV_TILE_SITES)
  foreach(SITE_TYPE ${PROJECT_XRAY_EQUIV_TILE_SITES})
    string(TOLOWER ${SITE_TYPE} SITE_TYPE_LOWER)
    append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}/${SITE_TYPE_LOWER}.pb_type.xml)
    append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}/${SITE_TYPE_LOWER}.model.xml)
    list(APPEND PB_TYPE_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}/${SITE_TYPE_LOWER}.pb_type.xml)
    list(APPEND MODEL_INCLUDE_FILES ${symbiflow-arch-defs_SOURCE_DIR}/xc7/primitives/${SITE_TYPE_LOWER}/${SITE_TYPE_LOWER}.model.xml)
  endforeach()

  set(TILES_ARGS "${PROJECT_XRAY_EQUIV_TILE_TILES}")
  string(REPLACE ";" "," TILES_ARGS "${TILES_ARGS}")

  set(EQUIV_ARGS "${PROJECT_XRAY_EQUIV_TILE_SITE_EQUIV}")
  string(REPLACE ";" "," EQUIV_ARGS "${EQUIV_ARGS}")

  append_file_dependency(DEPS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)
  get_file_location(PIN_ASSIGNMENTS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/pin_assignments.json)

  set(GENERIC_CHANNELS ${symbiflow-arch-defs_SOURCE_DIR}/xc7/archs/${PART}/channels.db)
  get_file_location(GENERIC_CHANNELS_LOCATION ${GENERIC_CHANNELS})
  append_file_dependency(DEPS ${GENERIC_CHANNELS})

  set(OUTPUTS "")

  foreach(TILE ${PROJECT_XRAY_EQUIV_TILE_TILES})
      string(TOLOWER ${TILE} TILE_LOWER)
      list(APPEND OUTPUTS ${TILE_LOWER}/${TILE_LOWER}.tile.xml)
  endforeach()

  foreach(PB_TYPE ${PROJECT_XRAY_EQUIV_TILE_PB_TYPES})
      string(TOLOWER ${PB_TYPE} PB_TYPE_LOWER)
      list(APPEND OUTPUTS ${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.pb_type.xml)
      list(APPEND OUTPUTS ${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.model.xml)
  endforeach()

  set(TILE_IMPORT ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_create_equiv_tiles.py)
  add_custom_command(
    OUTPUT ${OUTPUTS}
    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils
    ${PYTHON3} ${TILE_IMPORT}
    --output_directory ${symbiflow-arch-defs_BINARY_DIR}/xc7/archs/${PART}/tiles
    --site_directory ${symbiflow-arch-defs_BINARY_DIR}/xc7/primitives
    --connection_database ${GENERIC_CHANNELS_LOCATION}
    --tile_types ${TILES_ARGS}
    --pb_types ${PROJECT_XRAY_EQUIV_TILE_PB_TYPES_ARGS}
    --site_equivilances ${EQUIV_ARGS}
    --pin_assignments ${PIN_ASSIGNMENTS}
    DEPENDS
      ${TILE_IMPORT}
      ${DEPS}
      ${PYTHON3} ${PYTHON3_TARGET} simplejson
    )

  set(TARGETS "")
  foreach(TILE ${PROJECT_XRAY_EQUIV_TILE_TILES})
    string(TOLOWER ${TILE} TILE_LOWER)
    set(FILE_REL ${TILE_LOWER}/${TILE_LOWER}.tile.xml)
    add_file_target(FILE ${FILE_REL} GENERATED)
    get_file_target(TILE_TARGET ${FILE_REL})
    list(APPEND TARGETS ${TILE_TARGET})
  endforeach()

  foreach(PB_TYPE ${PROJECT_XRAY_EQUIV_TILE_PB_TYPES})
    string(TOLOWER ${PB_TYPE} PB_TYPE_LOWER)
    set(FILE_REL ${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.pb_type.xml)
    add_file_target(FILE ${FILE_REL} GENERATED)
    get_file_target(PB_TYPE_TARGET ${FILE_REL})
    set_target_properties(${PB_TYPE_TARGET} PROPERTIES
        INCLUDE_FILES "${PB_TYPE_INCLUDE_FILES}")
    list(APPEND TARGETS ${PB_TYPE_TARGET})

    set(FILE_REL ${PB_TYPE_LOWER}/${PB_TYPE_LOWER}.model.xml)
    add_file_target(FILE ${FILE_REL} GENERATED)
    get_file_target(MODEL_TARGET ${FILE_REL})
    set_target_properties(${MODEL_TARGET} PROPERTIES
        INCLUDE_FILES "${MODEL_INCLUDE_FILES}")
    list(APPEND TARGETS ${MODEL_TARGET})
  endforeach()

  # Linearize the dependency to prevent double builds.
  list(GET TARGETS 0 TARGET0)
  list(LENGTH TARGETS NTARGETS)

  math(EXPR NTARGETS_N1 ${NTARGETS}-1)
  foreach(IDX RANGE 1 ${NTARGETS_N1})
    list(GET TARGETS ${IDX} TARGET)
    add_dependencies(${TARGET} ${TARGET0})
  endforeach()
endfunction()
