#include "os.h"

#define TTY_MAX_X 80
#define TTY_MAX_Y 60
#define VGA_ADDRESS 0x09000000
#define PS2_ADDRESS 0x10000100
#define PS2_DATA (PS2_ADDRESS)
#define PS2_CTRL (PS2_ADDRESS + 4)
#define RED_LEDS 0x10000000

/* data */
int tty_x = 0;
int tty_y = 0;
bool ps2_initialized = false;
char ps2_ascii[256];

/* helpers */
static void prog_print_odd();
static void prog_print_even();
static void prog_add();

static bool str_startswith(char*, char*);
static int str_split(char*, char);
static void vechs_append_str(Vechs*, char*);

static bool file_exists(int, char*);

static void welcome_to_summoners_rift();

/* important */
int main() {
	seog_ti_os();
}

void bdel() {
	welcome_to_summoners_rift();

	int cwd = 0;
	char* prompt = "bdel$ ";
	while (true) {
		// prompt
		//tty_putword(prompt);
		bdel_printstr(prompt);
		char* cmd = bdel_readline();

		// parse
		char** argv = 0;
		int argc = 0;
		skye_parse(cmd, &argv, &argc);
		os_free(cmd);

		// check for empty
		if (argc == 0) {
			continue;
		}

		// check for background
		int pos = 0;
		bool bg = false;
		if (argc > 1 && os_strcmp(argv[0], "bg") == 0) {
			pos = 1;
			bg = true;
		}

		// get command and switch
		char* exec = argv[pos++];
		if (streq(exec, "odd")) {
			int pid = os_fork();
			if (pid == 0) {
				prog_print_odd();
			} else {
				if (!bg) {
					os_foreground_delegate(pid);
					os_wait(pid);
				}
			}
		} else if (streq(exec, "even")) {
			int pid = os_fork();
			if (pid == 0) {
				prog_print_even();
			} else {
				if (!bg) {
					os_foreground_delegate(pid);
					os_wait(pid);
				}
			}
		} else if (streq(exec, "add")) {
			int pid = os_fork();
			if (pid == 0) {
				prog_add();
			} else {
				if (!bg) {
					os_foreground_delegate(pid);
					os_wait(pid);
				}
			}
		} else if (streq(exec, "ls")) {
			Vechs* v = os_cat(cwd);
			int n = os_vechs_size(v);
			for (int i = 0; i < n; i++) {
				int id = os_vechs_get(v, i);
				char* name = os_romania_name_from_node(id);
				char type = 'F';
				if (os_romania_is_dir(id)) {
					type = 'D';
				}
				bdel_putchar(type);
				bdel_printstr(": ");
				bdel_printstr(name);
				bdel_putchar('\n');
				os_free(name);
			}
			os_vechs_delete(v);
		} else if (streq(exec, "touch")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
			} else {
				if (file_exists(cwd, name)) {
					bdel_printstr("File/directory already exists\n");
					continue;
				}
				os_touch(cwd, name);
			}
		} else if (streq(exec, "mkdir")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
			} else {
				if (file_exists(cwd, name)) {
					bdel_printstr("File/directory already exists\n");
					continue;
				}
				os_mkdir(cwd, name);
			}
		} else if (streq(exec, "cat")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
			} else {
				int node_id = os_romania_node_from_name(cwd, name);
				if (node_id == 0) {
					bdel_printstr("Unknown file/folder\n");
				} else {
					if (os_romania_is_dir(node_id)) {
						bdel_printstr("Cannot cat directory\n");
						continue;
					}
					Vechs* contents = os_cat(node_id);
					int n = os_vechs_size(contents);
					for (int i = 0; i < n; i++) {
						bdel_putchar(os_vechs_get(contents, i));
					}
					bdel_putchar('\n');
					os_vechs_delete(contents);
				}
			}
		} else if (streq(exec, "cp")) {
			if (pos + 1 >= argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			char* name2 = argv[pos + 1];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
				continue;
			}
			n = os_strlen(name2);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
				continue;
			}
			int node_id = os_romania_node_from_name(cwd, name);
			if (node_id == 0) {
				bdel_printstr("Unknown file/folder\n");
			} else {
				if (os_romania_is_dir(node_id)) {
					bdel_printstr("Cannot copy directory\n");
					continue;
				}
				if (file_exists(cwd, name2)) {
					bdel_printstr("Destination file already exists\n");
					continue;
				}
				os_cp(node_id, cwd, name2);
			}
		} else if (streq(exec, "rm")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
			} else {
				int node_id = os_romania_node_from_name(cwd, name);
				if (node_id == 0) {
					bdel_printstr("Unknown file/folder\n");
				} else {
					os_rm(node_id);
				}
			}
		} else if (streq(exec, "cd")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			if (streq(name, "..")) {
				cwd = os_romania_parent(cwd);
			} else {
				int n = os_strlen(name);
				if (n <= 0 || n > 12) {
					bdel_printstr("Invalid name\n");
				} else {
					int node_id = os_romania_node_from_name(cwd, name);
					if (node_id == 0) {
						bdel_printstr("Unknown file/folder\n");
					} else {
						if (os_romania_is_dir(node_id)) {
							cwd = node_id;
						} else {
							bdel_printstr("Not a directory\n");
						}
					}
				}
			}
		} else if (streq(exec, "skye")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
			} else {
				int node_id = os_romania_node_from_name(cwd, name);
				if (node_id == 0) {
					bdel_printstr("Unknown file/folder\n");
				} else {
					if (os_romania_is_dir(node_id)) {
						bdel_printstr("Cannot edit directory with skye\n");
						continue;
					}
					Vechs* v = skye();
					os_fwrite(node_id, v);
					os_vechs_delete(v);
				}
			}
		} else if (streq(exec, "susan")) {
			if (pos == argc) {
				bdel_printstr("Not enough arguments\n");
				continue;
			}
			char* name = argv[pos];
			int n = os_strlen(name);
			if (n <= 0 || n > 12) {
				bdel_printstr("Invalid name\n");
				continue;
			}
			int node_id = os_romania_node_from_name(cwd, name);
			if (node_id == 0) {
				bdel_printstr("Unknown file/folder\n");
				continue;
			}
			if (os_romania_is_dir(node_id)) {
				bdel_printstr("Cannot exec a directory\n");
				continue;
			}
			int pid = os_fork();
			if (pid == 0) {
				Vechs* v = os_cat(node_id);
				susan(v);
				os_vechs_delete(v);
				os_mort();
			} else {
				if (!bg) {
					os_foreground_delegate(pid);
					os_wait(pid);
				}
			}
		} else {
			bdel_printstr("Unknown command\n");
		}

		// free parse data
		for (int i = 0; i < argc; i++) {
			os_free(argv[i]);
		}
		if (argv != 0) {
			os_free(argv);
		}
	}
}

Vechs* skye() {
	Vechs* v = os_vechs_new(16);
	bool had_prev = false;
	while (true) {
		char* str = bdel_readline();
		int offset = 0;
		if (str[0] == '\\') {
			if (str[1] != '\\') {
				break;
			}
			offset = 1;
		}
		if (had_prev) {
			os_vechs_push(v, '\n');
		}
		vechs_append_str(v, str + offset);
		os_free(str);
		had_prev = true;
	}
	return v;
}

void skye_parse(char* str, char*** argv, int* argc) {
	Vechs* buffer = os_vechs_new(16);
	int len = os_strlen(str);
	if (len == 0) {
		*argc = 0;
		return;
	}
	char** parts = (char**) os_malloc(len * sizeof(char*));
	int num = 0;
	int i = 0;
	while (true) {
		if (str[i] == ' ' || str[i] == '\0') {
			if (os_vechs_size(buffer) > 0) {
				parts[num++] = str_from_vechs(buffer);
				os_vechs_clear(buffer);
			}
			if (str[i] == '\0') {
				break;
			}
		} else {
			os_vechs_push(buffer, str[i]);
		}
		i++;
	}
	os_vechs_delete(buffer);
	*argv = parts;
	*argc = num;
}

char* str_from_vechs(Vechs* v) {
	int n = os_vechs_size(v);
	char* str = os_malloc(n + 1);
	for (int i = 0; i < n; i++) {
		str[i] = os_vechs_get(v, i);
	}
	str[n] = '\0';
	return str;
}

void bdel_putchar(char ch) {
	os_putchar_sync(ch);
	tty_putchar(ch);
}

char bdel_readchar() {
	return os_readchar();
}

void bdel_printstr(char* str) {
	int i = 0;
	while (true) {
		if (str[i] == '\0') {
			break;
		}
		bdel_putchar(str[i]);
		i++;
	}
}

void bdel_printdec(int x) {
	int power = 1;
	while (x / power >= 10) {
		power *= 10;
	}
	while (power >= 1) {
		int y = x / power;
		bdel_putchar(y + '0');
		x = x % power;
		power /= 10;
	}
}

void bdel_printhex(int x) {
	bdel_putchar('0');
	bdel_putchar('x');
	for (int i = 7; i >= 0; i--) {
		int mask = 0xf << (4 * i);
		int bits = ((unsigned) (x & mask)) >> (4 * i);
		if (bits < 10) {
			bdel_putchar(bits + '0');
		} else {
			bdel_putchar(bits + 'A' - 10);
		}
	}
}

int bdel_readdec() {
	int x = 0;
	while (true) {
		char ch = bdel_readchar();
		bdel_putchar(ch);
		if (ch == '\n') {
			break;
		}
		if ('0' <= ch && ch <= '9') {
			x = (x * 10) + ch - '0';
		}
	}
	return x;
}

int bdel_readhex() {
	int stage = 0;
	while (stage < 2) {
		char ch = bdel_readchar();
		if (stage == 0) {
			if (ch == '0') {
				bdel_putchar(ch);
				stage = 1;
			} else {
				stage = 0;
			}
		} else if (stage == 1) {
			if (ch == 'x') {
				bdel_putchar(ch);
				stage = 2;
			} else {
				stage = 1;
			}
		}
	}
	int x = 0;
	while (true) {
		char ch = bdel_readchar();
		if (ch == '\n') {
			bdel_putchar(ch);
			break;
		}
		int val = -1;
		if ('0' <= ch && ch <= '9') {
			val = ch - '0';
		} else if ('a' <= ch && ch <= 'f') {
			val = ch - 'a' + 10;
		}
		if (val >= 0) {
			x = (x * 16) + val;
			bdel_putchar(ch);
		}
	}
	return x;
}

char* bdel_readline() {
	Vechs* v = os_vechs_new(16);
	while (true) {
		char ch = bdel_readchar();
		if (ch == '\x08') {
			if (os_vechs_size(v) > 0) {
				os_vechs_pop(v);
				bdel_putchar(ch);
			}
			continue;
		}
		bdel_putchar(ch);
		if (ch == '\n') {
			break;
		}
		os_vechs_push(v, ch);
	}
	char* str = str_from_vechs(v);
	os_vechs_delete(v);
	return str;
}

bool streq(char* a, char* b) {
	return os_strcmp(a, b) == 0;
}

/* tty */

static void write_pixel(int x, int y, short colour) {
	volatile char *vga_addr = (volatile char*) (0x08000000 + (y << 10) + (x << 1));
	*vga_addr = colour;
}

static void clear_screen() {
	int x, y;
	for (x = 0; x < 320; x++) {
		for (y = 0; y < 240; y++) {
			write_pixel(x, y, 0);
		}
	}
}

void tty_draw(int x, int y, char ch) {
	for (int i = 0; i < 40; i++) {
		for (int j = 0; j < 40; j++) {
			write_pixel(x + i, y + j, 0);
		}
	}
	*((volatile char*) (VGA_ADDRESS + (y << 7) + x)) = ch;
}

void tty_normalize(unsigned n) {
	if (tty_x > TTY_MAX_X - n) {
		tty_x = 0;
		tty_y++;
	}
	if (tty_y > TTY_MAX_Y - 1) {
		tty_clear();
	}
}

void tty_clear() {
	clear_screen();
	for (int x = 0; x < TTY_MAX_X; x++) {
		for (int y = 0; y < TTY_MAX_Y; y++) {
			tty_draw(x, y, ' ');
		}
	}
	tty_x = 0;
	tty_y = 0;
}

void tty_putchar(char ch) {
	if (ch == '\n') {
		tty_x = 0;
		tty_y++;
		tty_normalize(0);
	} else if (ch == '\r') {
		for (int x = 0; x < TTY_MAX_X; x++) {
			tty_draw(x, tty_y, ' ');
		}
		tty_x = 0;
	// backspace
	} else if (ch == 0x08) {
		tty_x -= 1;
		tty_putchar(' ');
		tty_x -= 1;
	} else {
		tty_normalize(1);
		tty_draw(tty_x, tty_y, ch);
		tty_x++;
	}
}

void tty_putword(char* str) {
	int n = os_strlen(str);
	tty_normalize(n);
	while (*str) {
		tty_putchar(*str);
		str++;
	}
}

void tty_puthex(unsigned n) {
	tty_normalize(10);
	tty_putword("0x");
	for (int i = 7; i >= 0; i--) {
		int mask = 0xf << (4 * i);
		int bits = ((unsigned) (n & mask)) >> (4 * i);
		if (bits < 10) {
			tty_putchar(bits + '0');
		} else {
			tty_putchar(bits + 'A' - 10);
		}
	}
}

void tty_putdec(unsigned x) {
	tty_normalize(10);
	int power = 1;
	while (x / power >= 10) {
		power *= 10;
	}
	while (power >= 1) {
		int y = x / power;
		tty_putchar(y + '0');
		x = x % power;
		power /= 10;
	}
}

/* plebs */
void prog_print_odd() {
	for (int i = 1; i < 8; i += 2) {
		char ch = i + '0';
		bdel_putchar(ch);
		bdel_putchar('\n');
		os_sleep(10);
	}
	os_mort();
}

void prog_print_even() {
	for (int i = 0; i < 8; i += 2) {
		char ch = i + '0';
		bdel_putchar(ch);
		bdel_putchar('\n');
		os_sleep(10);
	}
	os_mort();
}

void prog_add() {
	bdel_printstr("Please enter a number: ");
	int x = bdel_readdec();
	bdel_printstr("Please enter another number: ");
	int y = bdel_readdec();
	bdel_printstr("The sum is: ");
	bdel_printdec(x + y);
	bdel_putchar('\n');
	os_mort();
}

bool str_startswith(char* str, char* prefix) {
	int i = 0;
	while (true) {
		if (prefix[i] == '\0') {
			return true;
		}
		if (str[i] == '\0') {
			break;
		}
		if (str[i] != prefix[i]) {
			break;
		}
		i++;
	}
	return false;
}

int str_split(char* str, char ch) {
	int i = 0;
	int split = -1;
	while (true) {
		if (str[i] == '\0') {
			break;
		}
		if (split >= 0 && str[i] != ch) {
			break;
		}
		if (str[i] == ch) {
			split = i + 1;
		}
		i++;
	}
	return i;
}

void vechs_append_str(Vechs* v, char* str) {
	int i = 0;
	while (true) {
		if (str[i] == '\0') {
			break;
		}
		os_vechs_push(v, str[i]);
		i++;
	}
}

bool file_exists(int dir, char* name) {
	return os_romania_node_from_name(dir, name) != 0;
}

void welcome_to_summoners_rift() {
	bdel_printstr("Booting...\n");
	os_sleep(5);
	bdel_printstr("           --- Dice and dfr OS ---\n");
	os_sleep(5);
	bdel_printstr("               by Dice\n");
	os_sleep(20);
	bdel_printstr("               and dfr\n");
	bdel_putchar('\n');
	os_sleep(5);
	bdel_printstr("Special thanks to\n");
	os_sleep(10);
	bdel_printstr("- Bdel\n");
	bdel_printstr("- Rbutoi\n");
	bdel_printstr("- Mshl\n");
	bdel_printstr("- N0valey of the 0valey\n");
	for (int i = 0; i < 8; i++) {
		bdel_putchar('.');
		os_sleep(2);
	}
	bdel_putchar('\n');
	os_sleep(2);
	bdel_putchar('\n');
	bdel_printstr("\"Please sing for me again my muse, I need not light or fame.\n");
	bdel_printstr(" In-a universe I cannot choose, this is my final game.\"\n");
	os_sleep(2);
	bdel_putchar('\n');
}

/* ps2 */
char ps2_decode(char x) {
	if (x == 0x1C) return 'a';
	if (x == 0x32) return 'b';
	if (x == 0x21) return 'c';
	if (x == 0x23) return 'd';
	if (x == 0x24) return 'e';
	if (x == 0x2B) return 'f';
	if (x == 0x34) return 'g';
	if (x == 0x33) return 'h';
	if (x == 0x43) return 'i';
	if (x == 0x3B) return 'j';
	if (x == 0x42) return 'k';
	if (x == 0x4B) return 'l';
	if (x == 0x3A) return 'm';
	if (x == 0x31) return 'n';
	if (x == 0x44) return 'o';
	if (x == 0x4D) return 'p';
	if (x == 0x15) return 'q';
	if (x == 0x2D) return 'r';
	if (x == 0x1B) return 's';
	if (x == 0x2C) return 't';
	if (x == 0x3C) return 'u';
	if (x == 0x2A) return 'v';
	if (x == 0x1D) return 'w';
	if (x == 0x22) return 'x';
	if (x == 0x35) return 'y';
	if (x == 0x1A) return 'z';

	if (x == 0x45) return '0';
	if (x == 0x16) return '1';
	if (x == 0x1E) return '2';
	if (x == 0x26) return '3';
	if (x == 0x25) return '4';
	if (x == 0x2E) return '5';
	if (x == 0x36) return '6';
	if (x == 0x3D) return '7';
	if (x == 0x3E) return '8';
	if (x == 0x46) return '9';
	if (x == 0x0E) return '`';
	if (x == 0x4E) return '-';
	if (x == 0x55) return '=';
	if (x == 0x5D) return '\\';

	if (x == 0x66) return 0x08; // backspace
	if (x == 0x29) return ' ';
	if (x == 0x0D) return '\t';
	
	if (x == 0x5A) return '\n';

	if (x == 0x54) return '[';
	if (x == 0x7C) return '*';
	if (x == 0x7B) return '-';
	if (x == 0x79) return '+';
	if (x == 0x71) return '.';
	if (x == 0x70) return '0';
	if (x == 0x69) return '1';
	if (x == 0x72) return '2';
	if (x == 0x7A) return '3';
	if (x == 0x6B) return '4';
	if (x == 0x73) return '5';
	if (x == 0x74) return '6';
	if (x == 0x6C) return '7';
	if (x == 0x75) return '8';
	if (x == 0x7D) return '9';
	if (x == 0x5B) return ']';
	if (x == 0x4C) return ';';
	if (x == 0x52) return '\'';
	if (x == 0x41) return ',';
	if (x == 0x49) return '.';
	if (x == 0x4A) return '/';
	return 0;
}


char upper(char x) {
	//if (x =='a';
	//if (x =='b';
	if (x == 0x21) return 'c';
	if (x == 0x23) return 'd';
	if (x == 0x24) return 'e';
	if (x == 0x2B) return 'f';
	if (x == 0x34) return 'g';
	if (x == 0x33) return 'h';
	if (x == 0x43) return 'i';
	if (x == 0x3B) return 'j';
	if (x == 0x42) return 'k';
	if (x == 0x4B) return 'l';
	if (x == 0x3A) return 'm';
	if (x == 0x31) return 'n';
	if (x == 0x44) return 'o';
	if (x == 0x4D) return 'p';
	if (x == 0x15) return 'q';
	if (x == 0x2D) return 'r';
	if (x == 0x1B) return 's';
	if (x == 0x2C) return 't';
	if (x == 0x3C) return 'u';
	if (x == 0x2A) return 'v';
	if (x == 0x1D) return 'w';
	if (x == 0x22) return 'x';
	if (x == 0x35) return 'y';
	if (x == 0x1A) return 'z';

	if (x == 0x45) return '0';
	if (x == 0x16) return '1';
	if (x == 0x1E) return '2';
	if (x == 0x26) return '3';
	if (x == 0x25) return '4';
	if (x == 0x2E) return '5';
	if (x == 0x36) return '6';
	if (x == 0x3D) return '7';
	if (x == 0x3E) return '8';
	if (x == 0x46) return '9';
	if (x == 0x0E) return '`';
	if (x == 0x4E) return '-';
	if (x == 0x55) return '=';
	if (x == 0x5D) return '\\';

	if (x == 0x66) return 0x08; // backspace
	if (x == 0x29) return ' ';
	if (x == 0x0D) return '\t';
	
	if (x == 0x5A) return '\n';

	if (x == 0x54) return '[';
	if (x == 0x7C) return '*';
	if (x == 0x7B) return '-';
	if (x == 0x79) return '+';
	if (x == 0x71) return '.';
	if (x == 0x70) return '0';
	if (x == 0x69) return '1';
	if (x == 0x72) return '2';
	if (x == 0x7A) return '3';
	if (x == 0x6B) return '4';
	if (x == 0x73) return '5';
	if (x == 0x74) return '6';
	if (x == 0x6C) return '7';
	if (x == 0x75) return '8';
	if (x == 0x7D) return '9';
	if (x == 0x5B) return ']';
	if (x == 0x4C) return ';';
	if (x == 0x52) return '\'';
	if (x == 0x41) return ',';
	if (x == 0x49) return '.';
	if (x == 0x4A) return '/';
	return 0;
}

void ps2_init() {
	char* ascii = ps2_ascii;
	os_memset(ascii, 0, 256);
	ascii[0x1C] = 'a';
	ascii[0x32] = 'b';
	ascii[0x21] = 'c';
	ascii[0x23] = 'd';
	ascii[0x24] = 'e';
	ascii[0x2B] = 'f';
	ascii[0x34] = 'g';
	ascii[0x33] = 'h';
	ascii[0x43] = 'i';
	ascii[0x3B] = 'j';
	ascii[0x42] = 'k';
	ascii[0x4B] = 'l';
	ascii[0x3A] = 'm';
	ascii[0x31] = 'n';
	ascii[0x44] = 'o';
	ascii[0x4D] = 'p';
	ascii[0x15] = 'q';
	ascii[0x2D] = 'r';
	ascii[0x1B] = 's';
	ascii[0x2C] = 't';
	ascii[0x3C] = 'u';
	ascii[0x2A] = 'v';
	ascii[0x1D] = 'w';
	ascii[0x22] = 'x';
	ascii[0x35] = 'y';
	ascii[0x1A] = 'z';

	ascii[0x45] = '0';
	ascii[0x16] = '1';
	ascii[0x1E] = '2';
	ascii[0x26] = '3';
	ascii[0x25] = '4';
	ascii[0x2E] = '5';
	ascii[0x36] = '6';
	ascii[0x3D] = '7';
	ascii[0x3E] = '8';
	ascii[0x46] = '9';
	ascii[0x0E] = '`';
	ascii[0x4E] = '-';
	ascii[0x55] = '=';
	ascii[0x5D] = '\\';

	ascii[0x66] = 0x08; // backspace
	ascii[0x29] = ' ';
	ascii[0x0D] = '\t';
	
	ascii[0x5A] = '\n';

	ascii[0x54] = '[';
	ascii[0x7C] = '*';
	ascii[0x7B] = '-';
	ascii[0x79] = '+';
	ascii[0x71] = '.';
	ascii[0x70] = '0';
	ascii[0x69] = '1';
	ascii[0x72] = '2';
	ascii[0x7A] = '3';
	ascii[0x6B] = '4';
	ascii[0x73] = '5';
	ascii[0x74] = '6';
	ascii[0x6C] = '7';
	ascii[0x75] = '8';
	ascii[0x7D] = '9';
	ascii[0x5B] = ']';
	ascii[0x4C] = ';';
	ascii[0x52] = '\'';
	ascii[0x41] = ',';
	ascii[0x49] = '.';
	ascii[0x4A] = '/';
}

char ps2_shift(char c) {
	if (!ps2_is_shift_down()) {
		return c;
	}
	if (c == 'a') return 'A';
	if (c == 'b') return 'B';
	if (c == 'c') return 'C';
	if (c == 'd') return 'D';
	if (c == 'e') return 'E';
	if (c == 'f') return 'F';
	if (c == 'g') return 'G';
	if (c == 'h') return 'H';
	if (c == 'i') return 'I';
	if (c == 'j') return 'J';
	if (c == 'k') return 'K';
	if (c == 'l') return 'L';
	if (c == 'm') return 'M';
	if (c == 'n') return 'N';
	if (c == 'o') return 'O';
	if (c == 'p') return 'P';
	if (c == 'q') return 'Q';
	if (c == 'r') return 'R';
	if (c == 's') return 'S';
	if (c == 't') return 'T';
	if (c == 'u') return 'U';
	if (c == 'v') return 'V';
	if (c == 'w') return 'W';
	if (c == 'x') return 'X';
	if (c == 'y') return 'Y';
	if (c == 'z') return 'Z';
	if (c == '`') return '~';
	if (c == '1') return '!';
	if (c == '2') return '@';
	if (c == '3') return '#';
	if (c == '4') return '$';
	if (c == '5') return '%';
	if (c == '6') return '^';
	if (c == '7') return '&';
	if (c == '8') return '*';
	if (c == '9') return '(';
	if (c == '0') return ')';
	if (c == '-') return '_';
	if (c == '=') return '+';
	if (c == '[') return '{';
	if (c == ']') return '}';
	if (c == ';') return ':';
	if (c == '\'') return '"';
	if (c == ',') return '<';
	if (c == '.') return '>';
	if (c == '/') return '?';
	return ' ';
}
