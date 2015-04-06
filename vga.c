#include "vga.h"
#include <stdio.h>

#define MAX_X 80
#define MAX_Y 60
unsigned io_x = 0;
unsigned io_y = 0;

/* set a single pixel on the screen at x,y
 * x in [0,319], y in [0,239], and colour in [0,65535]
 */
void write_pixel(int x, int y, short colour) {
  volatile short *vga_addr=(volatile short*)(0x08000000 + (y<<10) + (x<<1));
  *vga_addr=colour;
}

/* use write_pixel to set entire screen to black (does not clear the character buffer) */
void clear_screen() {
  int x, y;
  for (x = 0; x < 320; x++) {
    for (y = 0; y < 240; y++) {
	  write_pixel(x,y,0);
	}
  }
}

/* write a single character to the character buffer at x,y
 * x in [0,79], y in [0,59]
 */
void write_char(int x, int y, char c) {
  // VGA character buffer
  volatile char* character_buffer = (char *) (0x09000000 + (y<<7) + x);
  *character_buffer = c;
}

void io_normalize(unsigned n) {
	if (io_x > MAX_X - n) {
		io_x = 0;
		io_y++;
	}
	if (io_y > MAX_Y - 1) {
		io_clear();
	}
}

void io_clear() {
	clear_screen();
	unsigned i = 0;
	while (i < MAX_X) {
		unsigned j = 0;
		while (j < MAX_Y) {
			write_char(i, j, ' ');
			j++;
		}
		i++;
	}
	io_x = 0;
	io_y = 0;
}

void io_putchar(char c) {
	io_normalize(1);
	if (c == '\n') {
		io_y++;
		io_x = 0;
	} else {
		write_char(io_x, io_y, c);
		io_x++;
		printf("%d, %d\n", io_x, io_y);
	}
}

void io_putword(char* cp) {
	unsigned length = 0;
	char* tmp = cp;
	while (*tmp) {
		length++;
		tmp++;
	}
	io_normalize(length);
	while (*cp) {
		io_putchar(*cp);
		cp++;
	}
}

void io_cr() {
	io_x = 0;
	unsigned i = 0;
	while (i < MAX_X) {
		io_putchar(' ');
		i++;
	}
	io_x = 0;
}

void io_endl() {
	io_x = MAX_X + 1;
	io_normalize(0);
}

void io_puthex(unsigned val) {
	io_normalize(10);
	io_putword("0x");
	char x[9];
	sprintf(x, "%X", val);
	io_putword(x);
}

void io_putdec(unsigned val) {
	char x[50];
	sprintf(x, "%u", val);
	io_putword(x);
}


