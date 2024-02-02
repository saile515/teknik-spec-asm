all: fizzbuzz gameoflife clean

fizzbuzz : fizzbuzz.o
		gcc -z noexecstack -no-pie -o build/fizzbuzz build/fizzbuzz.o

fizzbuzz.o : builddir
		nasm -felf64 -F dwarf fizzbuzz.asm -o build/fizzbuzz.o
		
gameoflife : gameoflife.o
		gcc -z noexecstack -no-pie -o build/gameoflife build/gameoflife.o

gameoflife.o : builddir
		nasm -felf64 -F dwarf gameoflife.asm -o build/gameoflife.o

builddir : 
		mkdir -p build

clean : 
		rm build/fizzbuzz.o build/gameoflife.o
