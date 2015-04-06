#ifndef DICE_AND_DFR_OS
#define DICE_AND_DFR_OS

typedef struct {
	char* data;
	int capacity;
	int size;
} Vechs;

int os_ti_seog();

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
int os_romania_find_node(char*);
char* os_romania_name_from_node(int);

Vechs* os_vechs_new(int);
void os_vechs_free(Vechs*);
int os_vechs_size(Vechs*);
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

void bdel();
void susan(Vechs*);
Vechs* skye();

#endif
