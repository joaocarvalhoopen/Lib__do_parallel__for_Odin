all:
	odin build . -out:examples_do_parallel.exe
#	odin build . -out:examples_do_parallel.exe -vet

opti:
	odin build . -out:examples_do_parallel.exe -o:speed

clean:
	rm examples_do_parallel.exe

run:
	./examples_do_parallel.exe
