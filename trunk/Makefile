all: ur.hex

ur.hex: ur.asm
	tavrasm -o $@ $^

.PHONY: install
install: ur.hex
	avrdude -p m8  -U flash:w:$^:i

.PHONY: clean
clean:
	-rm -f ur.hex
