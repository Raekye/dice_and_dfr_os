#include "decode.h"
#include <stdio.h>

#define SIZE 132

char* key[SIZE];
char ascii[SIZE];

int init() {
	for (int i = 0; i < SIZE; i++) {
		key[i] = "";
	}
	key[0x1c] = "A";
	key[0x32] = "B";
	key[0x21] = "C";
	key[0x23] = "D";
	key[0x24] = "E";
	key[0x2B] = "F";
	key[0x34] = "G";
	key[0x33] = "H";
	key[0x43] = "I";
	key[0x3B] = "J";
	key[0x42] = "K";
	key[0x4B] = "L";
	key[0x3A] = "M";
	key[0x31] = "N";
	key[0x44] = "O";
	key[0x4D] = "P";
	key[0x15] = "Q";
	key[0x2D] = "R";
	key[0x1B] = "S";
	key[0x2C] = "T";
	key[0x3C] = "U";
	key[0x2A] = "V";
	key[0x1D] = "W";
	key[0x22] = "X";
	key[0x35] = "Y";
	key[0x1A] = "Z";

	key[0x45] = "0";
	key[0x16] = "1";
	key[0x1E] = "2";
	key[0x26] = "3";
	key[0x25] = "4";
	key[0x2E] = "5";
	key[0x36] = "6";
	key[0x3D] = "7";
	key[0x3E] = "8";
	key[0x46] = "9";
	key[0x0E] = "`";
	key[0x4E] = "-";
	key[0x55] = "=";
	key[0x5D] = "\\";

	key[0x66] = "BKSP";
	key[0x29] = "SPACE";
	key[0x0D] = "TAB";
	key[0x58] = "CAPS";
	key[0x12] = "L SHFT";
	key[0x14] = "L CTRL";
	key[0x11] = "L ALT";
	key[0x59] = "R SHFT";
	key[0x5A] = "ENTER";
	key[0x76] = "ESC";
	key[0x05] = "F1";
	key[0x06] = "F2";
	key[0x04] = "F3";
	key[0x0C] = "F4";
	key[0x03] = "F5";
	key[0x0B] = "F6";
	key[0x83] = "F7";
	key[0x0A] = "F8";
	key[0x01] = "F9";
	key[0x09] = "F10";
	key[0x78] = "F11";
	key[0x07] = "F12";
	key[0x7E] = "SCROLL";

	key[0x54] = "[";
	key[0x77] = "NUM";
	key[0x7C] = "KP *";
	key[0x7B] = "KP -";
	key[0x79] = "KP +";
	key[0x71] = "KP .";
	key[0x70] = "KP 0";
	key[0x69] = "KP 1";
	key[0x72] = "KP 2";
	key[0x7A] = "KP 3";
	key[0x6B] = "KP 4";
	key[0x73] = "KP 5";
	key[0x74] = "KP 6";
	key[0x6C] = "KP 7";
	key[0x75] = "KP 8";
	key[0x7D] = "KP 9";
	key[0x5B] = "]";
	key[0x4C] = ";";
	key[0x52] = "'";
	key[0x41] = ",";
	key[0x49] = ".";
	key[0x4A] = "/";

	// initialize ascii values to null
	for (int i = 0; i < SIZE; i++) {
		ascii[i] = 0;
	}
	ascii[0x1c] = 'a';
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
	ascii[0x29] = 0x20;
	ascii[0x0D] = 0x09;
	
	ascii[0x5A] = '\n';
	ascii[0x76] = 0x1B;

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

	return 0;
}

char get_ascii(char index) {
	return ascii[index];
}

int ascii_exist(char index) {
	return (ascii[index] != 0 || index >= SIZE);
}

char* get_key_name(char index) {
	return key[index];
}

int key_name_exist(char index) {
	return (key[index] != "" || index >= SIZE);
}
