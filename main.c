#include "vga.h"
#include "ps2.h"
#include <stdio.h>

int main() {	
	io_clear();
	io_putword("Hello world");
	printf("%d, %d\n", io_x, io_y);
	seog_ti_os();
	while (1) {
		int i = 0;
	}
	return 0;
}