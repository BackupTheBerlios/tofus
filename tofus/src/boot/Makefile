all: image

image: stage1 stage2
	cat stage1 > image
	cat stage2 >> image

stage1:
	nasm boot.asm -o stage1 -f bin

stage2:
	nasm stage2.asm -o stage2 -f bin

clean:
	rm -f stage1
	rm -f stage2

reset:
	make clean
	rm -f image