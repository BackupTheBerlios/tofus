all: bootsector kernel

bootsector:
	cd src/boot/ && make

kernel:
	cd src/kernel && make

clean:
	cd src/boot && make clean
	cd src/kernel && make clean

reset:
	cd src/boot && make reset
	cd src/kernel && make reset