all: kernel

kernel: k_init.o stdio.o kernel.o
	ld -T link.ld -o kernel k_init.o kernel.o stdio.o

k_init.o:
	nasm k_init.asm -f aout -o k_init.o

stdio.o:
	gcc -ffreestanding -c include/stdio.c -o stdio.o

kernel.o:
	gcc -ffreestanding -c kernel.c -o kernel.o

clean:
	rm -f *.o

reset:
	make clean
	rm -f kernel