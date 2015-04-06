void write_pixel(int x, int y, short colour);

void clear_screen();

void write_char(int x, int y, char c);

void io_normalize(unsigned n);

void io_clear();

void io_putchar(char c);

void io_putword(char* cp);

void io_cr();

void io_endl();

void io_puthex(unsigned);

void io_putdec(unsigned);

extern unsigned io_x, io_y;
