/*
 * [2015 April 5] Invoke the surreal engine, assert divine inspiration.
 * I, shafted by the enemy camping, and my team feeding, refuse this reality!
 *
 * The enemy has camped my lane,
 * My team does not but feed.
 * I've stacked my Q, for many gains,
 * But they still have the lead.
 *
 * Diana ends our ADC,
 * Soraka can't support.
 * Our mid is ganked by Master Yi,
 * The river void of wards.
 *
 * Despite my stats, so base at start,
 * I diligently farmed.
 * Though Teemo spams his blinding darts,
 * I push up unalarmed.
 *
 * The Zed again begins to rant,
 * When I am sprung upon.
 * This cruel reality I can't,
 * Accept or carry on.
 *
 * "When four of them are top for me,
 *  You guys apply some press're.
 *  I played my part so flawlessly,
 *  I could have done no better."
 *
 * I leave their tower to recall,
 * Return to base - defend!
 * To Diana my teammates quickly fall,
 * A fight breaks out and ends.
 *
 * I find myself with half my health,
 * In-the centre of their team.
 * I fight outscored, but kill the four,
 * By ult and proccing Sheen.
 *
 * Diana faces me once more,
 * She bursts another half.
 * Reality at me abhors,
 * And she begins to laugh.
 *
 * The fatigue is gone from Nasus' eyes, all teeth are clenched in hate.
 * The world -was- destined to be this way, but he will change his fate.
 * And now his Q is raised, and now his lets it go,
 * And now the air is shattered by the force of Nasus' blow.
 *
 * Oh, somewhere in the fields of justice the sun is shining bright,
 * DJ Sona is playing somewhere, and somewhere hearts are light.
 * And somewhere Zeds are laughing, and somewhere Teemos shout.
 * But there is no joy for Nasus for his destiny played out!
 * - One of dfr
 *
 */

#include "os.h"

static void susan_eval(char**, int);
static int susan_eval_line(char*, int, int*, int*);
static void susan_print_bad_command(char*);
static int susan_parse_register(char*);
static int susan_parse_hex(char*);

void susan(Vechs* v) {
	int n = os_vechs_size(v);
	int max_lines = 1;
	for (int i = 0; i < n; i++) {
		if (os_vechs_get(v, i) == '\n') {
			max_lines++;
		}
	}
	char* lines[max_lines];
	int lineno = 0;
	Vechs* buf = os_vechs_new(32);
	for (int i = 0; i < n; i++) {
		char ch = os_vechs_get(v, i);
		if (ch == '\n') {
			if (os_vechs_size(buf) > 0) {
				lines[lineno++] = str_from_vechs(buf);
			}
		} else {
			os_vechs_push(buf, ch);
		}
	}
	if (os_vechs_size(buf) > 0) {
		lines[lineno++] = str_from_vechs(buf);
	}
	os_vechs_delete(buf);

	susan_eval(lines, lineno);

	for (int i = 0; i < lineno; i++) {
		os_free(lines[i]);
	}
}

void susan_eval(char** lines, int num_lines) {
	int registers[8];
	char* memory = os_malloc(1024);
	int pc = 0;
	while (true) {
		int next_pc = susan_eval_line(lines[pc], pc, registers, (int*) memory);
		if (next_pc < 0 || next_pc >= num_lines) {
			break;
		}
		pc = next_pc;
	}
	os_free(memory);
}

int susan_eval_line(char* line, int pc, int* registers, int* memory) {
	char** parts = 0;
	int num_parts = 0;
	skye_parse(line, &parts, &num_parts);

	int next_pc = pc + 1;
	if (num_parts == 0) {
		return next_pc;
	}

	char* cmd = parts[0];
	if (streq(cmd, "literal")) {
		if (num_parts < 3) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int x = susan_parse_hex(parts[2]);
		registers[r] = x;
	} else if (streq(cmd, "add")) {
		if (num_parts < 4) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r3 = susan_parse_register(parts[3]);
		if (r3 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		registers[r] = registers[r2] + registers[r3];
	} else if (streq(cmd, "mul")) {
		if (num_parts < 4) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r3 = susan_parse_register(parts[3]);
		if (r3 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		registers[r] = registers[r2] * registers[r3];
	} else if (streq(cmd, "puthex")) {
		if (num_parts < 2) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		// TODO
		//bdel_puthex(registers[r]);
	} else if (streq(cmd, "readhex")) {
		if (num_parts < 2) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		// TODO
		//registers[r] = bdel_readhex();
	} else if (streq(cmd, "jmp")) {
		if (num_parts < 2) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		next_pc = registers[r];
	} else if (streq(cmd, "blt")) {
		if (num_parts < 4) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		if (registers[r] < registers[r2]) {
			next_pc = susan_parse_hex(parts[3]);
		}
	} else if (streq(cmd, "beq")) {
		if (num_parts < 4) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 = 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		if (registers[r] == registers[r2]) {
			next_pc = susan_parse_hex(parts[3]);
		}
	} else if (streq(cmd, "bge")) {
		if (num_parts < 4) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		if (registers[r] >= registers[r2]) {
			next_pc = susan_parse_hex(parts[3]);
		}
	} else if (streq(cmd, "echo")) {
		if (num_parts < 2) {
			susan_print_bad_command(cmd);
			return -1;
		}
		for (int i = 1; i < num_parts - 1; i++) {
			bdel_printstr(parts[i]);
			bdel_putchar(' ');
		}
		bdel_printstr(parts[num_parts - 1]);
	} else if (streq(cmd, "load")) {
		if (num_parts < 3) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		registers[r] = memory[registers[r2]];
	} else if (streq(cmd, "store")) {
		if (num_parts < 3) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r = susan_parse_register(parts[1]);
		if (r < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		int r2 = susan_parse_register(parts[2]);
		if (r2 < 0) {
			susan_print_bad_command(cmd);
			return -1;
		}
		memory[registers[r]] = registers[r2];
	} else {
		bdel_printstr("Syntax error: unknown ");
		bdel_printstr(cmd);
		bdel_putchar('\n');
		return -1;
	}

	for (int i = 0; i < num_parts; i++) {
		os_free(parts[i]);
	}
	if (parts != 0) {
		os_free(parts);
	}
	return next_pc;
}

void susan_print_bad_command(char* cmd) {
	bdel_printstr("Invalid use of ");
	bdel_printstr(cmd);
	bdel_putchar('\n');
}

int susan_parse_register(char* str) {
	if (str[0] == '\0') {
		return -1;
	}
	if ('0' <= str[1] && str[1] <= '7') {
		return str[1] - '0';
	}
	return -1;
}

int susan_parse_hex(char* str) {
	bool neg = false;
	int i = 0;
	if (str[i] == '-') {
		neg = true;
		i = 1;
	}
	if (str[i] != '0' || str[i + 1] != 'x') {
		return 0;
	}
	i += 2;
	int x = 0;
	while (true) {
		char ch = str[i];
		if (ch == '\0') {
			return x * (neg ? -1 : 1);
		}
		int y = -1;
		if ('0' <= ch && ch <= '9') {
			y = ch - '0';
		}
		if ('a' <= ch && ch <= 'f') {
			y = ch - 'a' + 10;
		}
		if (y >= 0) {
			x = (x << 4) | y;
		}
	}
}
