add_subdirectory(bram_l)
add_subdirectory(bram_r)
add_subdirectory(slicel)
add_subdirectory(slicem)
add_subdirectory(clk_bufg_top_r)
add_subdirectory(clk_bufg_bot_r)

set(IOPAD_SITES IOB33 IDELAYE2 ILOGICE3 OLOGICE3)
set(IOPAD_S_SITES IOB33S IDELAYE2 ILOGICE3 OLOGICE3)
set(IOPAD_M_SITES IOB33M IDELAYE2 ILOGICE3 OLOGICE3)
project_xray_equiv_tile(
  PART artix7
  TILES RIOPAD_M RIOPAD_S RIOPAD_SING LIOPAD_M LIOPAD_S LIOPAD_SING
  PB_TYPES IOPAD IOPAD_S IOPAD_M
  PB_TYPE_SITES IOPAD_SITES IOPAD_S_SITES IOPAD_M_SITES
  SITE_EQUIV IOB33M=IOB33 IOB33S=IOB33
  )
