CC ?= gcc

all:
	cd build && bison -d ../src/parser.y
	cd build && flex ../src/scanner.l
	cd build && $(CC) -std=c99 parser.c scanner.c  -o py_check

clean:
	rm build/*
