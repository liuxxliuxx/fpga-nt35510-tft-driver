onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib blk_mem_gen_v8_4_4 blk_mem_gen_1_opt

do {wave.do}

view wave
view structure
view signals

do {blk_mem_gen_1.udo}

run -all

quit -force
