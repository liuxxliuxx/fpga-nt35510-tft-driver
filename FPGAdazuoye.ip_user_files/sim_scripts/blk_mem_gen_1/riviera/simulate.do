onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+blk_mem_gen_1 -L xpm -L blk_mem_gen_v8_4_4 -L unisims_ver -L unimacro_ver -L secureip -O5 blk_mem_gen_v8_4_4.blk_mem_gen_1 blk_mem_gen_v8_4_4.glbl

do {wave.do}

view wave
view structure

do {blk_mem_gen_1.udo}

run -all

endsim

quit -force
