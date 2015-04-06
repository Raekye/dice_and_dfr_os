#ifndef DICE_AND_DFR_OS
#define DICE_AND_DFR_OS

#define true 1
#define false 0

typedef char bool;

typedef struct {
	char* data;
	int capacity;
	int size;
} Vechs;

// os.s
int seog_ti_os();

char* os_malloc(int);
void os_free(void*);

int os_fork();
void os_mort();
void os_foreground_delegate(int);
void os_sleep(int);
void os_pause(int);

void os_putchar_sync(char);
void os_printstr_sync(char*);
char os_readchar();

int os_cp(int, int, char*);
void os_rm(int);
Vechs* os_cat(int);
int os_touch(int, char*);
int os_mkdir(int, char*);
void os_fwrite(int, Vechs*);
void os_fappend(int, Vechs*);
int os_romania_node_from_name(char*);
char* os_romania_name_from_node(int);

Vechs* os_vechs_new(int);
void os_vechs_delete(Vechs*);
int os_vechs_size(Vechs*);
char os_vechs_get(Vechs*, int);
void os_vechs_set(Vechs*, int, char);
void os_vechs_push(Vechs*, char);
char os_vechs_pop(Vechs*);
void os_vechs_unshift(Vechs*, char);
char os_vechs_shift(Vechs*);
int os_vechs_index(Vechs*, char);
void os_vechs_slice(Vechs*, int);
void os_vechs_extend(Vechs*, Vechs*);
Vechs* os_vechs_dup(Vechs*);

void os_memset(char*, char, int);
void os_memcpy(char*, char*, int);
int os_strlen(char*);
void os_strcpy(char*, char*);
int os_strcmp(char*, char*);

// hmmm
void bdel();
void susan(Vechs*);
Vechs* skye();

// tty
void tty_draw(int, int, char);
void tty_clear();
void tty_normalize(unsigned);
void tty_putchar(char);
void tty_putword(char*);
void tty_puthex(unsigned);
void tty_putdec(unsigned);
char tty_readchar();
unsigned tty_readdec();
unsigned tty_readhex();
char* tty_readline();

// ps2
void ps2_init();
char ps2_decode(char);
char ps2_read_keyboard();

#endif
