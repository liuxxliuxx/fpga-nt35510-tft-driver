onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc" -t 1ps -L xpm -L blk_mem_gen_v8_4_4 -L unisims_ver -L unimacro_ver -L secureip -lib blk_mem_gen_v8_4_4 blk_mem_gen_v8_4_4.blk_mem_gen_1 blk_mem_gen_v8_4_4.glbl

do {wave.do}

view wave
view structure
view signals

do {blk_mem_gen_1.udo}

run -all

quit -force
