add_fpga_target(
  NAME simple_ff
  BOARD basys3
  INPUT_IO_FILE basys3.pcf
  SOURCES simple_ff.v
  )

add_vivado_target(
  NAME simple_ff_vivado
  PARENT_NAME simple_ff
  )

add_fpga_target(
  NAME simple_ff_x1y0
  BOARD basys3-x1y0
  INPUT_IO_FILE basys3_x1y0.pcf
  SOURCES simple_ff_x1y0.v
  )

add_vivado_target(
  NAME simple_ff_x1y0_vivado
  PARENT_NAME simple_ff_x1y0
  )
