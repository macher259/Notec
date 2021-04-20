# Notec
Simple function in x64 Assembly
To compile with an example:

```
nasm -DN=$N -f elf64 -w+all -w+error -o notec.o notec.asm
gcc -DN=$N -c -Wall -Wextra -O2 -std=c11 -o example.o example.c
gcc notec.o example.o -lpthread -o example
```
where `$N` is some numeric constant greater than 0.
