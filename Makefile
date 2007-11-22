TARGET=clock.hex

all: $(TARGET)

$(TARGET): $(TARGET:.hex=.asm)
	tavrasm -o $@ $^

.PHONY: install
install: $(TARGET)
	avrdude -p m8  -U flash:w:$^:i

.PHONY: clean
clean:
	-rm -f $(TARGET)
