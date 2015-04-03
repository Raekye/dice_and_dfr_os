#include "ps2.h"

#define GLEDs ((volatile long *) 0x10000010)
#define RLEDs ((volatile long *) 0x10000000)
volatile int* PS2_ptr = (int*) 0x10000100;

char os_read_keyboard() {
	unsigned PS2_data = *(PS2_ptr); // Read the Data register
	char byte = PS2_data & 0xFF;
	*(PS2_ptr) = 0x000000FF;
	*GLEDs = byte;
	return byte;
}

/* Add the following to "os.s"
.equ PS_2			 0x10000100
.equ PS_2_DATA		 0
.equ PS_2_CONTROL	 4

#enable PS_2 interrupt

movia r8, PS_2
movi r9, 0x01 # enable read interrupt
stwio r9, PS_2_CONTROL(r8)

# Add bit 7 to the IRQ Line
movi r8, 0b0001 1000 0001
wrctl ctl3, r8

# In the interrupt handler

call os_read_keyboard

# r2 is now the byte read from keyboard

# the rest.............
*/