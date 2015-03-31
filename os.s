/*
 * The universe is made of 12 particles of matter, 4 forces of nature
 * # Richard and dfr OS
 * Hmmmmmm.
 *
 * TODO: vechs check for failed malloc
 * TODO: fork pre-increments process num
 * TODO: can load into same register? (e.g. ldw r2, 0(r2))
 * TODO: system call disable interrupts
 * TODO: handle no processes in scheduler?
 * TODO: parent process ID
 * TODO: modifying foreground process
 * TODO: use PROCESS_TABLE_*(r*) instead of hardcoded values
 * TODO: protocol after calling os_schedule - overwriting ea
 *
 * ## Conventions
 * - Most registers are callee-saved; I find this easier to work with
 *   - r0 is zero (hardware)
 *   - r2 is return (least significant bits) (caller-saved)
 *   - r3 is return (most significant bits) (caller-saved)
 *   - r4-r7 are first 16 bytes of arguments (callee-saved, preferably avoid modifying)
 *   - r8-r23 (16 registers, 64 bytes) are general purpose (callee-saved)
 *   - ra (r31) is return address (callee-saved)
 *   - Variables start at r8, values (constants) start at r23
 * - Heavily comment code (explain "what" and "why")
 * - Because system calls cannot be interrupted, the use of `et` in os functions is safe
 *   - i.e. `et` is a temporary register in os functions. Should not be used in user space
 *   - also, it follows that `et` and `ea` do not need to be saved accross processes
 *
 * ## Shoutouts
 * - Susan (nasus -> the late game terror -> VM)
 * - Skye (homage -> editor)
 * - The Master
 * - The Rational (the rational mind *maps* reality)
 * - Romanian innovations (homage -> filesystem)
 * - bdel (homage -> shell)
 * - Vechs (vector -> vec -> vecs)
 *
 * ## Readings
 * - http://www.linusakesson.net/programming/tty/
 * - https://github.com/Raekye/bdel_and_dfr_compiler/blob/master/stdlib.txt
 * - http://www-ug.eecg.toronto.edu/msl/manuals/DE2_Media_Computer.pdf
 * - http://www-ug.eecg.toronto.edu/msl/nios_devices/
 *
 * ## System calls
 * - `wrctl ctl0, r0`; at the beginning
 * - `movi et, 1`;
 *   `wrctl ctl0, et`; at the end
 * - this ensures system calls aren't interrupted
 *
 * ## Romania
 * - inodes (16 bytes) * 256 (2 ^ 8) for total 4096 bytes
 *   - byte 0
 *     - bit 0: in use
 *     - bit 1: 0 for directory, 1 for file
 *     - bits 4-7: upper 4 bits of index of first block
 *   - byte 1: lower 8 bits of index of first block (range 2 ^ 12 = 4096)
 *   - bytes 2-15: name, null terminated, max length 13
 * - blocks (256 bytes) * 1024 (2 ^ 8 * 4) for total 262144 bytes
 *   - common
 *     - byte 0: 0 for free, 1 for in use
 *     - byte 1: length of content in block (range 256 - 3)
 *     - byte 2: next block, 0 for no more blocks
 *   - directories
 *     - list of inode indexes, one byte each
 *     - end of list can be determined by block length
 *   - files
 *     - arbitrary contents of file
 *
 * ## Processes
 * - process table structure
 *   - bytes 0-3: process ID
 *   - bytes 4-7: pc
 *   - bytes 8-11: stack offset
 *   - byte 12: state
 *     - 0: dead/unused
 *     - 1: running
 *     - 2: sleeping
 *     - 3: waiting IO write
 *     - 4: waiting IO read
 *   - bytes 16-19: parent process id
 * - each process has
 *   - saved registers for context switching (total 128 processes * 32 registers * 4 bytes)
 *   - dedicated stack area (total 128 processes * 4096 byte stack)
 * - additional data
 *   - 1 byte: executing process ID
 *   - 1 byte: foreground process ID (which proccess has the terminal, receives stdin)
 *   - 128 process table entries * 4 bytes: sleep time remaining for processes
 *   - 32 registers * 4 bytes: temporary register save
 *     - technically, `r0`, and `et` do not need to be saved, but there is space for them for consistency
 *   - 128 process table entries * 1 byte: data to be written to output
 *
 * ## Dynamic memory
 * - heap block with 4 byte header + `n` bytes data
 *   - bytes 0-3: size of block (0 if free)
 *   - bytes 4-`n + 3`: block data (0 if free)
 * - on free, 0 bytes
 *
 * ## Error codes
 * - Create a `<func_name>_badness` label that sets the error code in `r4` and `br os_badness`
 * 1: no running processes
 * 2: pop/shift empty
 */

/*
 For a template of saving/restoring registers r8-r23, ra, see os_fork
 */

.global seog_ti_os

.equ HEAP_BYTES, 4096

.equ ROMANIA_NODES_BYTES, 4096
.equ ROMANIA_BLOCKS_BYTES, 252144

.equ PROCESS_TABLE_MAX, 128
.equ PROCESS_TABLE_ENTRY_BYTES, 20
.equ PROCESS_TABLE_BYTES, 2560

.equ PROCESS_TABLE_ID, 0
.equ PROCESS_TABLE_PC, 4
.equ PROCESS_TABLE_STACK, 8
.equ PROCESS_TABLE_STATUS, 12
.equ PROCESS_TABLE_PARENT, 16

.equ PROCESS_REGISTERS_BYTES, 16384

.equ PROCESS_STACKS_BYTES, 524288

.equ PROCESS_SLEEPING_BYTES, 512
.equ PROCESS_IO_OUT_BYTES, 128

.equ PROCESS_REGISTERS_TMP_BYTES, 128

.equ LEDS_RED, 0x10000000
.equ LEDS_GREEN, 0x10000010
.equ JTAG_UART, 0x10001000
.equ JTAG_UART_DATA, 0
.equ JTAG_UART_CTRL, 4
.equ TIMER, 0x10002000
.equ TIMER_STATUS, 0
.equ TIMER_CTRL, 4
.equ TIMER_PERIOD_L, 8
.equ TIMER_PERIOD_H, 12
.equ CYCLES_PER_HUNDRED_MILLISECONDS, 50000000

/* DATA */
.data
NULL:
	.skip 4

HEAP:
	.skip HEAP_BYTES

ROMANIA_NODES:
	.skip ROMANIA_NODES_BYTES
ROMANIA_BLOCKS:
	.skip ROMANIA_BLOCKS_BYTES

PROCESS_TABLE:
	.skip PROCESS_TABLE_BYTES

PROCESS_REGISTERS:
	.skip PROCESS_REGISTERS_BYTES

PROCESS_STACKS:
	.skip PROCESS_STACKS_BYTES

PROCESS_CURRENT:
	.skip 4

PROCESS_FOREGROUND:
	.skip 4

/*
 * 0: Shell process
 * 1: Bombadil process
 * 2: badness!!!
 */
PROCESS_NUM:
	.word 2

PROCESS_SLEEPING:
	.skip PROCESS_SLEEPING_BYTES

PROCESS_IO_OUT:
	.skip PROCESS_IO_OUT_BYTES

/*
 * In the wise words of N0vale the Oval, Ender of Ellipses:
 * "Yolo is the only strategy"
 */
PROCESS_IO_YOLOQ:
	.skip 4

PROCESS_REGISTERS_TMP:
	.skip PROCESS_REGISTERS_TMP_BYTES

EPSILON:
	.string ""

FOO:
	.string "foo\n"

BUKKITS_OF_FUN:
	.string "fun\n"

AYY_LMAO:
	.string "a\n"

HMMM:
	.string "hmmm\n"

/* INTERRUPTS */
.section .exceptions, "ax"
ISR:
	# fix pc
	addi ea, ea, -4

	# save registers
	movia et, PROCESS_REGISTERS_TMP
	stw r1, 4(et)
	stw r2, 8(et)
	stw r3, 12(et)
	stw r4, 16(et)
	stw r5, 20(et)
	stw r6, 24(et)
	stw r7, 28(et)
	stw r8, 32(et)
	stw r9, 36(et)
	stw r10, 40(et)
	stw r11, 44(et)
	stw r12, 48(et)
	stw r13, 52(et)
	stw r14, 56(et)
	stw r15, 60(et)
	stw r16, 64(et)
	stw r17, 68(et)
	stw r18, 72(et)
	stw r19, 76(et)
	stw r20, 80(et)
	stw r21, 84(et)
	stw r22, 88(et)
	stw r23, 92(et)
	# NOTE: saving `et` is superfluous
	stw r24, 96(et)
	stw r25, 100(et)
	stw r26, 104(et)
	stw r27, 108(et)
	stw r28, 112(et)
	stw r29, 116(et)
	stw r30, 120(et)
	stw r31, 124(et)

	# check for timer
	rdctl et, ctl4
	andi et, et, 1
	bne et, r0, ISR_HANDLE_TIMER

	# check for jtag uart
	rdctl et, ctl4
	andi et, et, 0x10 # bit 8
	bne et, r0, ISR_HANDLE_JTAG_UART

ISR_HANDLE_TIMER:
	call interrupt_handle_timer
	# clear status bit
	movia et, TIMER
	stwio r0, TIMER_STATUS(et)
	br ISR_EPILOGUE

ISR_HANDLE_JTAG_UART:
	call interrupt_handle_jtag_uart
	br ISR_EPILOGUE

ISR_EPILOGUE:
	movia et, PROCESS_REGISTERS_TMP
	ldw r1, 4(et)
	ldw r2, 8(et)
	ldw r3, 12(et)
	ldw r4, 16(et)
	ldw r5, 20(et)
	ldw r6, 24(et)
	ldw r7, 28(et)
	ldw r8, 32(et)
	ldw r9, 36(et)
	ldw r10, 40(et)
	ldw r11, 44(et)
	ldw r12, 48(et)
	ldw r13, 52(et)
	ldw r14, 56(et)
	ldw r15, 60(et)
	ldw r16, 64(et)
	ldw r17, 68(et)
	ldw r18, 72(et)
	ldw r19, 76(et)
	ldw r20, 80(et)
	ldw r21, 84(et)
	ldw r22, 88(et)
	ldw r23, 92(et)
	# NOTE: restoring `et` is superfluous
	ldw r24, 96(et)
	ldw r25, 100(et)
	ldw r26, 104(et)
	ldw r27, 108(et)
	ldw r28, 112(et)
	# don't overwrite `ea`
	#ldw r29, 116(et)
	ldw r30, 120(et)
	ldw r31, 124(et)
	eret

/* TEXT */
.text
interrupt_handle_timer:
	addi sp, sp, -8
	stw r4, 0(sp)
	stw ra, 4(sp)

	movia r4, AYY_LMAO
	call os_printstr_sync

	# tock... did I do good?
	call os_tick

	# aww yis
	call os_schedule

	ldw r4, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

interrupt_handle_jtag_uart:
	addi sp, sp, -0

	movia r8, JTAG_UART
	ldwio r9, JTAG_UART_CTRL(r8)
	andi r10, r9, 0x10 # bit 8, read interrupt pending
	bne r10, r0, interrupt_handle_jtag_uart_read
	br interrupt_handle_jtag_uart_write

interrupt_handle_jtag_uart_read:
	br interrupt_handle_jtag_uart_epilogue

interrupt_handle_jtag_uart_write:
	# for each space available
	# dequeue io yoloq
	# write the byte
	# update status byte
	br interrupt_handle_jtag_uart_epilogue

interrupt_handle_jtag_uart_epilogue:
	addi sp, sp, 0
	ret

/* main */
seog_ti_os:
	wrctl ctl0, r0
	movia sp, 0x007FFFFC

	/*
	# root dir
	mov r4, r0
	movia r5, EPSILON
	call os_mkdir

	# foo
	movia r5, FOO
	call os_mkdir
	*/

	# reset heap
	movia r4, HEAP
	mov r5, r0
	movia r6, HEAP_BYTES
	call os_memset

	# initialize process io queue
	movi r4, 16
	call os_vechs_new
	movia r23, PROCESS_IO_YOLOQ
	stw r2, 0(r23)

	movia r8, PROCESS_TABLE
	movia r10, PROCESS_STACKS
	movia r23, PROCESS_STACKS_BYTES
	movia r22, PROCESS_REGISTERS
	# stack starts at top address
	add r10, r10, r23

	# shell process
	# process id
	stw r0, 0(r8)
	# pc
	movia r9, os_bdel
	stw r9, PROCESS_TABLE_PC(r8)
	# stack offset
	stw r10, PROCESS_TABLE_STACK(r8)
	# status byte
	movi r9, 1
	stw r9, PROCESS_TABLE_STATUS(r8)
	# parent id
	stw r0, PROCESS_TABLE_PARENT(r8)

	# bombadil process
	addi r8, r8, 20
	add r11, r10, r23
	# process id
	movi r9, 1
	stw r9, 0(r8)
	# pc
	movia r9, os_bombadil
	stw r9, PROCESS_TABLE_PC(r8)
	# stack offset
	stw r11, PROCESS_TABLE_STACK(r8)
	# status byte
	movi r9, 1
	stw r9, PROCESS_TABLE_STATUS(r8)
	# parent id
	stw r0, PROCESS_TABLE_PARENT(r8)
	# set sp register
	# it is the second entry in the process table
	addi r12, r22, 128
	stw r11, 108(r12)

	# set shell to be running process
	movia r23, PROCESS_CURRENT
	stw r0, 0(r23)
	movia r23, PROCESS_FOREGROUND
	stw r0, 0(r23)
	# set stack pointer
	mov sp, r10

	# enable timer interrupts
	movia r8, TIMER
	# clear timer
	stwio r0, TIMER_STATUS(r8)
	movi r9, %hi(CYCLES_PER_HUNDRED_MILLISECONDS)
	stwio r9, TIMER_PERIOD_H(r8)
	movi r9, %lo(CYCLES_PER_HUNDRED_MILLISECONDS)
	stwio r9, TIMER_PERIOD_L(r8)
	movi r9, 0x07 # bits 2, 1, 0 (start, continue, enable interrupt)
	stwio r9, TIMER_CTRL(r8)

	# enable jtag uart interrupts
	movia r8, JTAG_UART
	movi r9, 0x1 # disable write interrupt, enable read interrupt bits
	stwio r9, JTAG_UART_CTRL(r8)

	# enable irq interrupts
	movi r8, 0x11 # bit 8, 0
	wrctl ctl3, r8

	# enable global interrupts
	movi r8, 1
	wrctl ctl0, r8

	# start shell
	br os_bdel

/* romania */
/*
 * @param node id of parent folder
 * @param pointer to string name
 */
os_touch:
	addi sp, sp, -8
	stw r6, 0(sp)
	stw ra, 4(sp)
	# set file bit
	movi r6, 1
	call os_falloc
	ldw r6, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * @param node id of parent folder
 * @param pointer to string name
 */
os_mkdir:
	addi sp, sp, -8
	stw r6, 0(sp)
	stw ra, 4(sp)
	# set directory bit
	mov r6, r0
	call os_falloc
	ldw r6, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * r8: node id
 * r9: node address
 * r10: block id
 * r11: block address
 * r12: temporary register (block id in node structure, others)
 * @param node id of parent folder
 * @param pointer to string name
 * @param 0 for dir, 1 for file
 */
os_falloc:
	addi sp, sp, -44
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r6, 8(sp)
	stw r8, 12(sp)
	stw r9, 16(sp)
	stw r10, 20(sp)
	stw r11, 24(sp)
	stw r12, 28(sp)
	stw r22, 32(sp)
	stw r23, 36(sp)
	stw ra, 40(sp)

	movia r22, ROMANIA_NODES
	movia r23, ROMANIA_BLOCKS

	call os_romania_allocate_node
	mov r8, r2
	add r9, r8, r22
	call os_romania_allocate_block
	mov r10, r2
	add r11, r10, r23

	# upper 4 bits of block id
	srli r12, r10, 8
	slli r12, r12, 4
	# directory or file bit
	slli r6, r6, 1
	# directory or file bit, in use bit
	ori r6, r6, 0xf1
	# set lower bits
	or r12, r12, r6

	stb r12, 0(r9)
	stb r10, 1(r9)

	mov r4, r5
	call os_strlen
	movi r12, 13
	bgt r2, r12, os_mkdir_bad_name
	# then valid name
	# r5 = node address + name offset
	addi r5, r9, 2
	call os_strcpy
	# TODO: null terminate
	mov r2, r8
	br os_mkdir_epilogue

os_mkdir_bad_name:
	# TODO: handle
	br os_mkdir_epilogue

os_mkdir_epilogue:
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r6, 8(sp)
	ldw r8, 12(sp)
	ldw r9, 16(sp)
	ldw r10, 20(sp)
	ldw r11, 24(sp)
	ldw r12, 28(sp)
	ldw r22, 32(sp)
	ldw r23, 36(sp)
	ldw ra, 40(sp)
	addi sp, sp, 40
	ret

/*
 * r8: node address
 * r9: read byte
 * @param node id
 */
os_rm:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw ra, 8(sp)

	movia r22, ROMANIA_NODES
	# r8 = offset + index
	add r8, r22, r4
	ldb r9, 0(r8)
	# get second bit, directory or file
	andi r9, r9, 0x2
	beq r9, r0, os_rm_handle_dir
	br os_rm_handle_file

os_rm_handle_file:
	call os_rm_file
	br os_rm_epilogue

os_rm_handle_dir:
	call os_rm_dir
	br os_rm_epilogue

os_rm_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw ra, 8(sp)
	addi sp, sp, 12
	ret

/*
 * @param node id
 */
os_rm_file:
	addi sp, sp, -8
	stw r4, 0(sp)
	stw ra, 4(sp)

	call os_romania_block_from_node
	call os_romania_free_node
	mov r4, r2
	call os_romania_free_block_chain

os_rm_file_epilogue:
	ldw r4, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * r4: modified
 * r5: counter
 * r8: vechs
 * r9: vechs size
 * @param node id
 */
os_rm_dir:
	addi sp, sp, -20
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r8, 8(sp)
	stw r9, 12(sp)
	stw ra, 16(sp)

	# get block id
	call os_romania_block_from_node
	mov r4, r2
	# get block contents
	call os_romania_read_block_chain
	mov r8, r2
	mov r4, r8
	call os_vechs_size
	mov r9, r2
	mov r5, r0

os_rm_dir_loop:
	beq r5, r9, os_rm_dir_done
	call os_vechs_get
	mov r4, r2
	call os_rm
	# reset r4 to vechs
	mov r4, r8
	addi r5, r5, 1
	br os_rm_dir_loop

os_rm_dir_done:
	call os_vechs_delete

os_rm_dir_epilogue:
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r8, 8(sp)
	ldw r9, 12(sp)
	ldw ra, 16(sp)
	addi sp, sp, 20
	ret

os_cp:
	ret

/*
 * r4: modified
 * r8: vechs
 * r9: block address
 * r10: read byte
 * r11: block address pointer (copying byte)
 * r12: copy counter
 * @param block id
 */
os_romania_read_block_chain:
	addi sp, sp, -28
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r9, 8(sp)
	stw r10, 12(sp)
	stw r11, 16(sp)
	stw r12, 20(sp)
	stw ra, 24(sp)

	call os_vechs_new
	mov r8, r2
	movia r22, ROMANIA_BLOCKS

os_romania_read_block_chain_handle_block:
	# r9 = offset + index
	add r9, r22, r4

	# read length
	ldb r10, 1(r9)
	addi r11, r9, 3
	mov r12, r0

os_romania_read_block_chain_copy_block:
	beq r12, r10, os_romania_read_block_chain_copy_block_done
	mov r4, r8
	ldb r5, 0(r11)
	call os_vechs_push
	addi r12, r12, 1
	addi r11, r11, 1

os_romania_read_block_chain_copy_block_done:
	ldb r4, 2(sp)
	beq r4, r0, os_romania_read_block_chain_done
	br os_romania_read_block_chain_handle_block

os_romania_read_block_chain_done:
	mov r2, r8
	br os_romania_read_block_chain_epilogue

os_romania_read_block_chain_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw r9, 8(sp)
	ldw r10, 12(sp)
	ldw r11, 16(sp)
	ldw r12, 20(sp)
	ldw ra, 24(sp)
	addi sp, sp, 28
	ret

/*
 * @param node id
 */
os_romania_block_from_node:
	addi sp, sp, -16
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r22, 12(sp)

	movia r22, ROMANIA_NODES
	# r8 = offset + index
	add r8, r22, r4
	# load byte 0
	ldb r9, 0(r8)
	# load byte 1
	ldb r10, 1(r8)
	# get upper bits of byte 0, the upper 4 bits of block id
	andi r9, r9, 0xf0
	# shift upper 4 bits of block id
	slli r10, r10, 8
	or r2, r9, r10

os_romania_block_from_node_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r22, 12(sp)
	addi sp, sp, 16

/*
 * @param node id of current folder
 * @param pointer to string name
 */
os_romania_find_node:
	ret

/*
 * r8: address
 * r10: loaded byte
 * r22: nodes offset
 * r23: nodes bytes
 */
os_romania_allocate_node:
	addi sp, sp, -16
	stw r8, 0(sp)
	stw r10, 4(sp)
	stw r22, 8(sp)
	stw r23, 12(sp)

	# initialize
	mov r2, r0
	movia r22, ROMANIA_NODES
	movia r23, ROMANIA_NODES_BYTES

os_romania_allocate_node_loop:
	# r8 = index + offset
	add r8, r2, r22
	# read first byte of a node
	ldb r10, 0(r8)
	# if 0, found block
	beq r10, r0, os_romania_allocate_node_epilogue
	# then non-zero, skip over node
	addi r2, r2, 16
	br os_romania_allocate_node_loop

os_romania_allocate_node_epilogue:
	ldw r8, 0(sp)
	ldw r10, 4(sp)
	ldw r22, 8(sp)
	ldw r23, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r8: address
 * r10: loaded byte
 * r22: blocks offset
 * r23: blocks bytes
 */
os_romania_allocate_block:
	addi sp, sp, -16
	stw r8, 0(sp)
	stw r10, 4(sp)
	stw r22, 8(sp)
	stw r23, 12(sp)

	# initialize
	mov r2, r0
	movia r22, ROMANIA_BLOCKS
	movia r23, ROMANIA_BLOCKS_BYTES

os_romania_allocate_block_loop:
	# r8 = index + offset
	add r8, r2, r22
	# read first byte of a block
	ldb r10, 0(r8)
	# if 0, found block
	beq r10, r0, os_romania_allocate_block_found
	# then non-zero, skip over block
	addi r2, r2, 256
	br os_romania_allocate_block_loop

os_romania_allocate_block_found:
	# NOTE: r23 nolonger needed, used as temporary register
	movi r23, 1
	# mark block as used
	stb r23, 0(r8)
	br os_romania_allocate_block_epilogue

os_romania_allocate_block_epilogue:
	ldw r8, 0(sp)
	ldw r10, 4(sp)
	ldw r22, 8(sp)
	ldw r23, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r4: modified
 * r8: block address
 * r22: block offset
 * @param block id
 */
os_romania_free_block_chain:
	addi sp, sp, -16
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r22, 8(sp)
	stw ra, 12(sp)

	movia r22, ROMANIA_BLOCKS
	# r8 = offset + index
	add r8, r22, r4

	ldb r4, 2(r8)
	beq r4, r0, os_romania_free_block_chain_free
	call os_romania_free_block_chain

os_romania_free_block_chain_free:
	call os_romania_free_block

os_romania_free_block_chain_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw r22, 8(sp)
	ldw ra, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r8: counter
 * r9: index
 * r10: upper bound
 */
os_romania_free_node:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	
	mov r8, r0
	movi r10, 16

os_romania_free_node_loop:
	beq r8, r10, os_romania_free_node_epilogue
	# r9 points to a byte in the node we are zeroing
	add r9, r4, r8
	# zero byte
	stb r0, 0(r9)
	addi r8, r8, 1
	br os_romania_free_node_loop

os_romania_free_node_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r8: counter
 * r9: index
 * r10: upper bound
 */
os_romania_free_block:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	
	mov r8, r0
	movi r10, 256

os_romania_free_block_loop:
	beq r8, r10, os_romania_free_block_epilogue
	# r9 points to a byte in the block we are zeroing
	add r9, r4, r8
	# zero byte
	stb r0, 0(r9)
	addi r8, r8, 1
	br os_romania_free_block_loop

os_romania_free_block_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	addi sp, sp, 12
	ret

/* processes */

/*
 * r23: process current
 */
os_process_current:
	addi sp, sp, -4
	stw r23, 0(sp)

	movia r23, PROCESS_CURRENT
	ldw r2, 0(r23)

	ldw r23, 0(sp)
	addi sp, sp, 4
	ret

/*
 * r8: process table counter
 * r9: address in process table
 * r10: loaded data
 * r22: process max
 * r23: process table
 * @param process id
 */
os_process_table_index:
	addi sp, sp, -20
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r22, 12(sp)
	stw r23, 16(sp)

	movia r23, PROCESS_TABLE
	movia r22, PROCESS_TABLE_MAX
	mov r8, r0
	mov r9, r23

os_process_table_index_find_entry:
	# bounds check
	beq r8, r22, os_process_table_index_unfound_entry
	# load process id
	ldw r10, 0(r9)
	# if equals argument
	beq r10, r4, os_process_table_index_found_entry
	# then not equal, increment counter, increment address/pointer
	addi r8, r8, 1
	addi r9, r9, 16
	# loop
	br os_process_table_index_find_entry

os_process_table_index_found_entry:
	mov r2, r8
	br os_process_table_index_epilogue

os_process_table_index_unfound_entry:
	movi r2, -1
	br os_process_table_index_epilogue

os_process_table_index_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r22, 12(sp)
	ldw r23, 16(sp)
	addi sp, sp, 20
	ret

/*
 * r23: process table
 * @param index
 */
os_process_table_entry_from_index:
	addi sp, sp, -4
	stw r23, 0(sp)

	movia r23, PROCESS_TABLE
	# index * size
	muli r2, r4, PROCESS_TABLE_ENTRY_BYTES
	# base address + offset
	add r2, r23, r2

	ldw r23, 0(sp)
	addi sp, sp, 4
	ret

/*
 * r4: process table
 * @param process id
 */
os_process_table_entry:
	addi sp, sp, -8
	stw r4, 0(sp)
	stw ra, 4(sp)

	# get index, first arg forwarded along
	call os_process_table_index
	# set index as arg to next function
	mov r4, r2
	call os_process_table_entry_from_index

	ldw r4, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * r4: modified
 * r5: modified
 * r6: modified
 * @param parent process id
 * @param child process table index
 */
os_process_duplicate_stack:
	addi sp, sp, -16
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r6, 8(sp)
	stw ra, 12(sp)

	movia r23, PROCESS_TABLE
	# get parent process stack offset
	call os_process_stack_offset
	# set first argument
	mov r4, r2
	# set third argument
	movia r6, PROCESS_STACKS_BYTES
	# stack grows downward, point to end
	addi r5, r5, 1
	# offset = index * size
	mul r5, r5, r6
	# address = base + offset
	add r5, r23, r5
	# memcpy
	call os_memcpy

	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r6, 8(sp)
	ldw ra, 12(sp)
	addi sp, sp, 16
	ret

/*
 * @param process id
 */
os_process_stack_offset:
	addi sp, sp, -4
	stw ra, 0(sp)

	call os_process_table_entry
	ldw r2, PROCESS_TABLE_STACK(r2)

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret

/*
 * r8: child process id (process number)
 * r9: index in process table
 * r10: address in process table
 * r11: process table entry state
 * r12: address in process registers
 * r13: pointer to top of stack of child
 * r14: next pc for child process
 * r19: process stacks
 * r20: process registers
 * r21: process table max
 * r22: process table
 * r23: process num
 */
os_fork:
	addi sp, sp, -68
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r11, 12(sp)
	stw r12, 16(sp)
	stw r13, 20(sp)
	stw r14, 24(sp)
	stw r15, 28(sp)
	stw r16, 32(sp)
	stw r17, 36(sp)
	stw r18, 40(sp)
	stw r19, 44(sp)
	stw r20, 48(sp)
	stw r21, 52(sp)
	stw r22, 56(sp)
	stw r23, 60(sp)
	stw ra, 64(sp)

	movia r23, PROCESS_NUM
	movia r22, PROCESS_TABLE
	movia r21, PROCESS_TABLE_MAX
	movia r20, PROCESS_REGISTERS
	movia r19, PROCESS_STACKS
	mov r9, r0
	mov r10, r22

	# load process num
	ldw r8, 0(r23)

os_fork_find_empty_entry:
	# check for max processes
	beq r9, r21, os_fork_out_of_processes
	# read process status
	ldb r11, 12(r10)
	# if 0, then empty entry
	beq r11, r0, os_fork_found_empty_entry
	# then look at next entry
	addi r9, r9, 1
	addi r10, r10, 16
	br os_fork_find_empty_entry

os_fork_found_empty_entry:
	# increment process num
	addi r8, r8, 1
	# save process num
	stw r8, 0(r23)

	# duplicate stack
	call os_process_current
	# set first argument
	mov r4, r2
	# set second argument
	mov r5, r9
	call os_process_duplicate_stack

	# add new entry for child process
	# set process id
	stw r8, PROCESS_TABLE_ID(r10)
	# pc set below
	# set stack pointer
	# point to top
	addi r13, r9, 1
	# index * size
	muli r13, r13, 16
	# base + offset
	add r13, r19, r13
	# save stack pointer
	stw r13, PROCESS_TABLE_STACK(r10)
	# set status running
	# r2 used as temporary register
	movi r2, 1
	stb r2, PROCESS_TABLE_STATUS(sp)

	# save registers for child process
	# offset into registers
	muli r12, r9, 32
	# address = base address + offset
	add r12, r20, r12

	# save registers, except skip r0, r2 <- r0 for child
	stw r1, 4(r12)
	stw r0, 8(r12)
	stw r3, 12(r12)
	stw r4, 16(r12)
	stw r5, 20(r12)
	stw r6, 24(r12)
	stw r7, 28(r12)
	stw r8, 32(r12)
	stw r9, 36(r12)
	stw r10, 40(r12)
	stw r11, 44(r12)
	stw r12, 48(r12)
	stw r13, 52(r12)
	stw r14, 56(r12)
	stw r15, 60(r12)
	stw r16, 64(r12)
	stw r17, 68(r12)
	stw r18, 72(r12)
	stw r19, 76(r12)
	stw r20, 80(r12)
	stw r21, 84(r12)
	stw r22, 88(r12)
	stw r23, 92(r12)
	# NOTE: saving `et` is superfluous
	stw r24, 96(r12)
	stw r25, 100(r12)
	stw r26, 104(r12)
	stw r27, 108(r12)
	stw r28, 112(r12)
	stw r29, 116(r12)
	stw r30, 120(r12)
	stw r31, 124(r12)

	# when the os switches to the child, it will reload the registers, and continue executing (re-execute next instruction, harmless re-write)
	# it will have reloaded 0 as the return value, and return from fork
	nextpc r14
	stw r14, PROCESS_TABLE_PC(r10)

	br os_fork_epilogue

os_fork_out_of_processes:
	movi r2, -1
	br os_fork_epilogue

os_fork_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r11, 12(sp)
	ldw r12, 16(sp)
	ldw r13, 20(sp)
	ldw r14, 24(sp)
	ldw r15, 28(sp)
	ldw r16, 32(sp)
	ldw r17, 36(sp)
	ldw r18, 40(sp)
	ldw r19, 44(sp)
	ldw r20, 48(sp)
	ldw r21, 52(sp)
	ldw r22, 56(sp)
	ldw r23, 60(sp)
	ldw ra, 64(sp)
	addi sp, sp, 68
	ret

/*
 * Terminate own process
 */
os_mort:
	# TODO: cycle through processes, update children's parent IDs
	# TODO: release foreground to parent, if has
	# TODO: clear own process table entry
	# TODO: execute scheduler
	ret

/*
 * Delegates forground to child process
 * @param child id
 */
os_foreground_delegate:
	ret

/*
 * @param time in 0.1 seconds (hundred milliseconds)
 */
os_sleep:
	wrctl ctl0, r0
	movia et, PROCESS_REGISTERS_TMP
	stw r1, 4(et)
	stw r2, 8(et)
	stw r3, 12(et)
	stw r4, 16(et)
	stw r5, 20(et)
	stw r6, 24(et)
	stw r7, 28(et)
	stw r8, 32(et)
	stw r9, 36(et)
	stw r10, 40(et)
	stw r11, 44(et)
	stw r12, 48(et)
	stw r13, 52(et)
	stw r14, 56(et)
	stw r15, 60(et)
	stw r16, 64(et)
	stw r17, 68(et)
	stw r18, 72(et)
	stw r19, 76(et)
	stw r20, 80(et)
	stw r21, 84(et)
	stw r22, 88(et)
	stw r23, 92(et)
	# NOTE: saving `et` is superfluous
	stw r24, 96(et)
	stw r25, 100(et)
	stw r26, 104(et)
	stw r27, 108(et)
	stw r28, 112(et)
	stw r29, 116(et)
	stw r30, 120(et)
	stw r31, 124(et)

	movia r23, PROCESS_SLEEPING
	# save sleep time in temporary register
	mov r8, r4
	# get process id
	call os_process_current
	# get table entry address
	mov r4, r2
	call os_process_table_index
	# offset = index * size
	muli r9, r2, 4
	# address = base + offset
	add r9, r23, r9
	# save sleep time
	stw r8, 0(r9)

	# get table entry address
	mov r4, r2
	call os_process_table_entry_from_index
	# save sleeping status byte
	movi r9, 2
	stw r9, 0(r2)

	call os_schedule
	mov ra, ea

os_sleep_epilogue:
	movia et, PROCESS_REGISTERS_TMP
	ldw r1, 4(et)
	ldw r2, 8(et)
	ldw r3, 12(et)
	ldw r4, 16(et)
	ldw r5, 20(et)
	ldw r6, 24(et)
	ldw r7, 28(et)
	ldw r8, 32(et)
	ldw r9, 36(et)
	ldw r10, 40(et)
	ldw r11, 44(et)
	ldw r12, 48(et)
	ldw r13, 52(et)
	ldw r14, 56(et)
	ldw r15, 60(et)
	ldw r16, 64(et)
	ldw r17, 68(et)
	ldw r18, 72(et)
	ldw r19, 76(et)
	ldw r20, 80(et)
	ldw r21, 84(et)
	ldw r22, 88(et)
	ldw r23, 92(et)
	# NOTE: restoring `et` is superfluous
	ldw r24, 96(et)
	ldw r25, 100(et)
	ldw r26, 104(et)
	ldw r27, 108(et)
	ldw r28, 112(et)
	ldw r29, 116(et)
	ldw r30, 120(et)
	ldw r31, 124(et)

	movi et, 1
	wrctl ctl0, et
	ret

/*
 * Decrements sleep time remaining of all processes
 * If dropped to 0, update sleeping process to running
 *
 * r4: modified
 * r8: address in process_sleeping
 * r9: counter
 * r10: time remaining loaded
 * r11: 2
 * r22: process table max
 * r23: process sleeping
 */
os_tick:
	addi sp, sp, -32
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r9, 8(sp)
	stw r10, 12(sp)
	stw r11, 16(sp)
	stw r22, 20(sp)
	stw r23, 24(sp)
	stw ra, 28(sp)

	movia r23, PROCESS_SLEEPING
	movia r22, PROCESS_TABLE_MAX
	mov r8, r23
	mov r9, r0

os_tick_loop:
	# if counter == num entries
	beq r9, r22, os_tick_epilogue

	# read time remaining
	ldw r10, 0(r8)

	# if time remaining was already 0 (not sleeping)
	beq r10, r0, os_tick_loop_after
	# then process is sleeping
	# decrement counter
	addi r10, r10, -1
	# save value
	ldw r10, 0(r8)
	# if time dropped to 0
	beq r10, r0, os_tick_loop_wake
	# then next
	br os_tick_loop_after

os_tick_loop_wake:
	# set index as arg
	mov r4, r9
	call os_process_table_entry_from_index
	# set ldatus byte to running
	movi r11, 1
	ldw r11, PROCESS_TABLE_STATUS(r2)
	br os_tick_loop_after

os_tick_loop_after:
	addi r8, r8, 4
	addi r9, r9, 1
	br os_tick_loop

os_tick_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw r9, 8(sp)
	ldw r10, 12(sp)
	ldw r11, 16(sp)
	ldw r22, 20(sp)
	ldw r23, 24(sp)
	ldw ra, 28(sp)
	addi sp, sp, 32
	ret

/*
 * Cycles through process table and switches to another process
 * Starts looking in the process table at the current process table index + 1
 *
 * Callers of this function should save the current executing process' registers into `PROCESS_REGISTERS_TMP`, and do `mov ea, ra`
 * This function will save those registers into the process table
 * This function will save the next process' registers (from the process table) into `PROCESS_REGISTERS_TMP`
 *
 * This function sets `ea` to be the `pc` of the next process to be run
 * When called from the interrupt, the interrupt handler will return to that process
 * OS functions that call this should do update registers, and do `mov ra, ea` before they return
 *
 * TODO: r8 and r14 duplication
 *
 * r8: current process table index
 * r9: process table index inspecting
 * r10: address in process table for next process
 * r11: loaded status byte
 * r12: temporary register for computing addresses
 * r13: loaded register from process registers tmp
 * r14: next process id
 * r15: address in process registers
 * r16: address in process table for current process
 * r17: counter looping through processes
 * r18: process current
 * r19: leds green
 * r20: process table max
 * r21: process registers
 * r22: 1
 * r23: process table
 */
os_schedule:
	addi sp, sp, -68
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r11, 12(sp)
	stw r12, 16(sp)
	stw r13, 20(sp)
	stw r14, 24(sp)
	stw r15, 28(sp)
	stw r16, 32(sp)
	stw r17, 36(sp)
	stw r18, 40(sp)
	stw r19, 44(sp)
	stw r20, 48(sp)
	stw r21, 52(sp)
	stw r22, 56(sp)
	stw r23, 60(sp)
	stw ra, 64(sp)

	movia r23, PROCESS_TABLE
	movi r22, 1
	movia r21, PROCESS_REGISTERS
	movia r20, PROCESS_TABLE_MAX
	movia r19, LEDS_GREEN
	movia r18, PROCESS_CURRENT

	call os_process_current
	mov r4, r2
	call os_process_table_index
	mov r8, r2
	# start inspecting the next entry
	addi r9, r8, 1
	# initialize counter
	mov r17, r0

os_schedule_find_process:
	# NOTE: implementation detail
	#       because there are 128 entries in the process table
	#       and 128 is a power of 2, we can simulate mod (remainder) with a bitwise and with 127
	andi r9, r9, 127
	# index * size
	muli r12, r9, PROCESS_TABLE_ENTRY_BYTES
	# base + offset
	add r10, r23, r12
	# checked all entries
	beq r17, r20, os_schedule_no_running_processes
	# load status byte
	ldb r11, PROCESS_TABLE_STATUS(r10)
	# if status byte is 1
	beq r11, r22, os_schedule_found_running_process
	# then increment index into process table and counter
	addi r9, r9, 1
	addi r17, r17, 1
	# loop
	br os_schedule_found_running_process

os_schedule_found_running_process:
	# offset = index * size
	muli r12, r8, PROCESS_TABLE_ENTRY_BYTES
	# address = base + offset
	add r16, r23, r12
	# save current process pc in process table
	stw ea, PROCESS_TABLE_PC(r16)

	# load next process pc from process table
	ldw ea, PROCESS_TABLE_PC(r10)

	# get next process id
	ldw r14, PROCESS_TABLE_ID(r10)
	# set process current
	stw r14, 0(r18)
	# set green leds
	stw r14, 0(r19)

	# 32 registers * 4 bytes
	muli r12, r8, 128
	# address = base + offset
	add r15, r21, r12

	movia et, PROCESS_REGISTERS_TMP

	# copy current process' registers, saved in process registers tmp, to its entry in process registers
	ldw r13, 4(et)
	stw r13, 4(r15)
	ldw r13, 8(et)
	stw r13, 8(r15)
	ldw r13, 12(et)
	stw r13, 12(r15)
	ldw r13, 16(et)
	stw r13, 16(r15)
	ldw r13, 20(et)
	stw r13, 20(r15)
	ldw r13, 24(et)
	stw r13, 24(r15)
	ldw r13, 28(et)
	stw r13, 28(r15)
	ldw r13, 32(et)
	stw r13, 32(r15)
	ldw r13, 36(et)
	stw r13, 36(r15)
	ldw r13, 40(et)
	stw r13, 40(r15)
	ldw r13, 44(et)
	stw r13, 44(r15)
	ldw r13, 48(et)
	stw r13, 48(r15)
	ldw r13, 52(et)
	stw r13, 52(r15)
	ldw r13, 56(et)
	stw r13, 56(r15)
	ldw r13, 60(et)
	stw r13, 60(r15)
	ldw r13, 64(et)
	stw r13, 64(r15)
	ldw r13, 68(et)
	stw r13, 68(r15)
	ldw r13, 72(et)
	stw r13, 72(r15)
	ldw r13, 76(et)
	stw r13, 76(r15)
	ldw r13, 80(et)
	stw r13, 80(r15)
	ldw r13, 84(et)
	stw r13, 84(r15)
	ldw r13, 88(et)
	stw r13, 88(r15)
	ldw r13, 92(et)
	stw r13, 92(r15)
	ldw r13, 96(et)
	stw r13, 96(r15)
	ldw r13, 100(et)
	stw r13, 100(r15)
	ldw r13, 104(et)
	stw r13, 104(r15)
	ldw r13, 108(et)
	stw r13, 108(r15)
	ldw r13, 112(et)
	stw r13, 112(r15)
	ldw r13, 116(et)
	stw r13, 116(r15)
	ldw r13, 120(et)
	stw r13, 120(r15)
	ldw r13, 124(et)
	stw r13, 124(r15)

	# 32 registers * 4 bytes
	muli r12, r9, 128
	# address = base + offset
	add et, r21, r12

	movia r15, PROCESS_REGISTERS_TMP

	# copy next process' registers to process registers tmp
	# the ldw/stw code is the same as above; et and r15 are switched
	ldw r13, 4(et)
	stw r13, 4(r15)
	ldw r13, 8(et)
	stw r13, 8(r15)
	ldw r13, 12(et)
	stw r13, 12(r15)
	ldw r13, 16(et)
	stw r13, 16(r15)
	ldw r13, 20(et)
	stw r13, 20(r15)
	ldw r13, 24(et)
	stw r13, 24(r15)
	ldw r13, 28(et)
	stw r13, 28(r15)
	ldw r13, 32(et)
	stw r13, 32(r15)
	ldw r13, 36(et)
	stw r13, 36(r15)
	ldw r13, 40(et)
	stw r13, 40(r15)
	ldw r13, 44(et)
	stw r13, 44(r15)
	ldw r13, 48(et)
	stw r13, 48(r15)
	ldw r13, 52(et)
	stw r13, 52(r15)
	ldw r13, 56(et)
	stw r13, 56(r15)
	ldw r13, 60(et)
	stw r13, 60(r15)
	ldw r13, 64(et)
	stw r13, 64(r15)
	ldw r13, 68(et)
	stw r13, 68(r15)
	ldw r13, 72(et)
	stw r13, 72(r15)
	ldw r13, 76(et)
	stw r13, 76(r15)
	ldw r13, 80(et)
	stw r13, 80(r15)
	ldw r13, 84(et)
	stw r13, 84(r15)
	ldw r13, 88(et)
	stw r13, 88(r15)
	ldw r13, 92(et)
	stw r13, 92(r15)
	ldw r13, 96(et)
	stw r13, 96(r15)
	ldw r13, 100(et)
	stw r13, 100(r15)
	ldw r13, 104(et)
	stw r13, 104(r15)
	ldw r13, 108(et)
	stw r13, 108(r15)
	ldw r13, 112(et)
	stw r13, 112(r15)
	ldw r13, 116(et)
	stw r13, 116(r15)
	ldw r13, 120(et)
	stw r13, 120(r15)
	ldw r13, 124(et)
	stw r13, 124(r15)

	br os_schedule_epilogue

os_schedule_no_running_processes:
	movi r4, 1
	br os_badness

os_schedule_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r11, 12(sp)
	ldw r12, 16(sp)
	ldw r13, 20(sp)
	ldw r14, 24(sp)
	ldw r15, 28(sp)
	ldw r16, 32(sp)
	ldw r17, 36(sp)
	ldw r18, 40(sp)
	ldw r19, 44(sp)
	ldw r20, 48(sp)
	ldw r21, 52(sp)
	ldw r22, 56(sp)
	ldw r23, 60(sp)
	ldw ra, 64(sp)
	addi sp, sp, 68
	ret

/* dynamic memory */
/*
 * r8: index in heap
 * r9: address in heap (index + heap offset)
 * r10: loaded value from heap
 * r11: counter for free space
 * r20: -4
 * r21: heap end
 * r22: heap offset
 * r23: heap bytes
 * @param n
 */
os_malloc:
	addi sp, sp, -40
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r9, 8(sp)
	stw r10, 12(sp)
	stw r11, 16(sp)
	stw r12, 20(sp)
	stw r10, 24(sp)
	stw r21, 28(sp)
	stw r22, 32(sp)
	stw r23, 36(sp)

	# constraints
	ble r4, r0, os_malloc_oom

	# initialize
	mov r8, r0
	movia r22, HEAP
	movia r23, HEAP_BYTES
	add r21, r22, r23
	movi r20, -4

	# round size up to multiple of 4 bytes
	# get lower 2 bits
	andi r12, r4, 0x3
	# invert bits
	xori r12, r12, 0xff
	# increment
	addi r12, r12, 1
	# grab lower 2 bits
	andi r12, r12, 0x3
	# add
	add r4, r4, r12

os_malloc_crawl_loop:
	bge r8, r23, os_malloc_oom
	# reset counter
	mov r11, r0
	# load header
	add r9, r8, r22
	ldw r10, 0(r9)
	# skip over header bytes
	addi r8, r8, 4
	addi r9, r9, 4
	# check block header
	beq r10, r0, os_malloc_found_free_block
	# found used block
	# skip over allocated bytes
	add r8, r8, r10
	# continue searching
	br os_malloc_crawl_loop

os_malloc_found_free_block:
	# check oom
	beq r9, r21, os_malloc_oom
	# increment counter
	addi r11, r11, 1
	# load heap
	ldb r10, 0(r9)
	# increment heap pointer
	addi r9, r9, 1
	# if not 0, we hit a block before we found enough space
	bne r10, r0, os_malloc_found_insufficient_block
	# then 0
	# if found enough space
	beq r11, r4, os_malloc_found_sufficient_block
	# then 0, not enough space yet, keep searching
	br os_malloc_found_free_block

os_malloc_found_insufficient_block:
	# r8 + r11 at the last byte we loaded, which was non-zero, meaning it was the header/size of a block
	add r8, r8, r11
	# -4 in binary is all 1s with least significant two 0s
	and r8, r8, r20
	# address of header
	add r9, r8, r22
	# load header
	ldw r10, 0(r9)
	# skip over header
	addi r8, r8, 4
	# skips the number of bytes in the block we hit
	add r8, r8, r10
	# continue searching
	br os_malloc_crawl_loop

os_malloc_found_sufficient_block:
	# r8 + r22 at the first data byte
	add r2, r8, r22
	# save header
	stw r4, -4(r2)
	br os_malloc_epilogue

os_malloc_oom:
	mov r2, r0
	br os_malloc_epilogue

os_malloc_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw r9, 8(sp)
	ldw r10, 12(sp)
	ldw r11, 16(sp)
	ldw r12, 20(sp)
	ldw r20, 24(sp)
	ldw r21, 28(sp)
	ldw r22, 32(sp)
	ldw r23, 36(sp)
	addi sp, sp, 40
	ret

/*
 * r8: read header
 * r9: counter
 * r10: current address zeroing out
 * @param ptr
 */
os_free:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)

	# read header
	ldw r8, -4(r4)
	# zero header
	stw r0, -4(r4)
	mov r9, r0
	mov r10, r4

os_free_loop:
	beq r9, r8, os_free_epilogue
	stb r0, 0(r10)
	addi r9, r9, 1
	addi r10, r10, 1
	br os_free_loop

os_free_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	addi sp, sp, 12
	ret

/* vechs */
/*
 * r4: modified
 * r8: pointer to structure
 * @param n
 */
os_vechs_new:
	addi sp, sp, -12
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw ra, 8(sp)

	# malloc structure
	movi r4, 12
	call os_malloc
	mov r8, r2
	# malloc space for data
	ldw r4, 0(sp)
	call os_malloc
	# set pointer
	stw r2, 0(r8)
	stw r4, 4(r8)
	stw r0, 8(r8)
	# return pointer to structure
	mov r2, r8

os_vechs_new_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw ra, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r4: modified
 * r8: pointer to data
 * @param ptr
 */
os_vechs_delete:
	addi sp, sp, -12
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw ra, 8(sp)

	# get pointer to data
	ldw r8, 0(r4)
	# free structure
	call os_free
	# free data
	mov r4, r8
	call os_free

os_vechs_delete_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw ra, 8(sp)
	addi sp, sp, 12
	ret

/*
 * @param ptr
 */
os_vechs_size:
	ldw r2, 8(r4)
	ret

/*
 * @param ptr
 * @param i
 */
os_vechs_get:
	ldw r2, 0(r4)
	add r2, r2, r5
	ldb r2, 0(r2)
	ret

/*
 * @param ptr
 * @param i
 * @param x
 */
os_vechs_set:
	ldw r2, 0(r4)
	add r2, r2, r5
	stb r6, 0(r2)
	ret

/*
 * r5: modified
 * r6: modified
 * @param ptr
 * @param x
 */
os_vechs_push:
	addi sp, sp, -8
	stw r6, 0(sp)
	stw ra, 4(sp)

	# ensure capacity
	call os_vechs_normalize
	# get size
	call os_vechs_size
	# set top value
	mov r6, r5
	mov r5, r2
	call os_vechs_set
	# update size
	addi r2, r5, 1
	stw r2, 8(r4)

os_vechs_push_epilogue:
	mov r5, r6
	ldw r6, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * r5: modified
 * @param ptr
 */
os_vechs_pop:
	addi sp, sp, -8
	stw r5, 0(sp)
	stw ra, 4(sp)

	call os_vechs_size
	# calculate next size
	addi r5, r2, -1
	# retrieve top value
	call os_vechs_get
	# update size
	stw r5, 8(r4)

os_vechs_pop_epilogue:
	ldw r5, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
	ret

/*
 * r5: modified, index
 * r6: modified
 * r8: saved return value
 * r9: size
 * @param ptr
 */
os_vechs_shift:
	addi sp, sp, -20
	stw r5, 0(sp)
	stw r6, 4(sp)
	stw r8, 8(sp)
	stw r9, 12(sp)
	stw ra, 16(sp)

	call os_vechs_size
	mov r9, r2

	beq r9, r0, os_vechs_shift_badness

	# get head, save return value
	mov r5, r0
	call os_vechs_get
	mov r8, r2

	# r5 is the index of the element we are moving from
	movi r5, 1

os_vechs_shift_loop:
	# while index < length
	bge r5, r9, os_vechs_shift_loop_done
	# get element
	call os_vechs_get
	# argument 3 for set
	mov r6, r2
	# argument 2 for set
	addi r5, r5, -1
	call os_vechs_set
	# index = index + 1 (we subtracted 1 above)
	addi r5, r5, 2
	br os_vechs_shift_loop

os_vechs_shift_loop_done:
	# remove last element
	call os_vechs_pop
	mov r2, r8

os_vechs_shift_epilogue:
	ldw r5, 0(sp)
	ldw r6, 4(sp)
	ldw r8, 8(sp)
	ldw r9, 12(sp)
	ldw ra, 16(sp)
	addi sp, sp, 20
	ret

os_vechs_shift_badness:
	movi r4, 2
	br os_badness

/*
 * r5: modified
 * r6: modified
 * r8: old size
 * @param ptr
 * @param BUDGIE // such shoutouts, no-one else can follow the connections because they are too obscure and ambiguous
 * @timeCapsule I WANT IT ALL
 */
os_vechs_unshift:
	addi sp, sp, -16
	stw r5, 0(sp)
	stw r6, 4(sp)
	stw r8, 8(sp)
	stw ra, 12(sp)

	# get size
	call os_vechs_size
	mov r8, r2

	# add the budgie to the end, increasing the size
	call os_vechs_push

	# r5 is the index we are moving to
	mov r5, r8

os_vechs_unshift_loop:
	# while index > 0
	beq r5, r0, os_vechs_unshift_loop_done
	# get src
	addi r5, r5, -1
	call os_vechs_get
	# set dest
	mov r6, r2
	addi r5, r5, 1
	call os_vechs_set
	# decrement index
	addi r5, r5, -1
	br os_vechs_unshift_loop

os_vechs_unshift_loop_done:
	# get budgie
	ldw r6, 0(sp)
	# r5 already 0
	# set first element
	call os_vechs_set

os_vechs_unshift_epilogue:
	ldw r5, 0(sp)
	ldw r6, 4(sp)
	ldw r8, 8(sp)
	ldw ra, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r4: modified
 * r5: modified, copy counter
 * r8: allocated size
 * r9: size prime
 * r10: array prime
 * r11: pointer to location in array prime
 * @param ptr
 */
os_vechs_normalize:
	addi sp, sp, -28
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r8, 8(sp)
	stw r9, 12(sp)
	stw r10, 16(sp)
	stw r11, 20(sp)
	stw ra, 24(sp)

	# used size
	call os_vechs_size
	# allocated size
	ldw r8, 4(r4)
	# if used < allocated (should never be greater than), return
	bne r2, r8, os_vechs_normalize_epilogue
	# then used == allocated
	# size prime
	addi r9, r8, 4
	# array prime
	mov r4, r9
	call os_malloc
	mov r10, r2
	# initialize counter
	mov r5, r0
	# initialize pointer to array prime
	mov r11, r10
	# reset r4 to point to the vector structure
	ldw r4, 0(sp)

os_vechs_normalize_copy_loop:
	# if counter == num elements
	beq r5, r8, os_vechs_normalize_finalize
	call os_vechs_get
	stw r2, 0(r11)
	addi r5, r5, 1
	addi r11, r11, 4
	br os_vechs_normalize_copy_loop

os_vechs_normalize_finalize:
	# get pointer to old array
	ldw r4, 0(r4)
	# free old array
	call os_free
	# reset r4 to the vector structure
	ldw r4, 0(sp)
	# set new array pointer
	stw r10, 0(r4)
	# update size allocated
	stw r9, 4(r4)
	br os_vechs_normalize_epilogue

os_vechs_normalize_epilogue:
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r8, 8(sp)
	ldw r9, 12(sp)
	ldw r10, 16(sp)
	ldw r11, 20(sp)
	ldw ra, 24(sp)
	addi sp, sp, 28
	ret

/* skye */
os_skye:
	ret

/* strings */
/*
 * r4: pointer to src char
 * r5: pointer to dest char
 * r8: loaded char
 * @param from address
 * @param to address
 */
os_strcpy:
	addi sp, sp, -12
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r8, 8(sp)

os_strcpy_loop:
	ldb r8, 0(r4)
	stw r8, 0(r5)
	beq r8, r0, os_strlen_epilogue
	addi r4, r4, 1
	addi r5, r5, 1
	br os_strlen_loop

os_strcpy_epilogue:
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r8, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r4: pointer to str
 * r8: loaded char
 * @param str
 */
os_strlen:
	addi sp, sp, -8
	stw r4, 0(sp)
	stw r8, 4(sp)

	mov r2, r0

os_strlen_loop:
	ldb r8, 0(r4)
	beq r8, r0, os_strlen_epilogue
	addi r4, r4, 1
	addi r2, r2, 1
	br os_strlen_loop

os_strlen_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	addi sp, sp, 8
	ret

/* bdel */

/*
 * Entry to the shell
 * Should never terminate
 */
os_bdel:
	movia r4, FOO
	call os_printstr_sync
	call os_pause
	br os_bdel

/* hmmm */
/*
 * r4: modified
 * r8: process io out address
 * r9: 3
 * r23: process io out base
 * @param byte to print
 */
os_putchar:
	wrctl ctl0, r0
	movia et, PROCESS_REGISTERS_TMP
	stw r1, 4(et)
	stw r2, 8(et)
	stw r3, 12(et)
	stw r4, 16(et)
	stw r5, 20(et)
	stw r6, 24(et)
	stw r7, 28(et)
	stw r8, 32(et)
	stw r9, 36(et)
	stw r10, 40(et)
	stw r11, 44(et)
	stw r12, 48(et)
	stw r13, 52(et)
	stw r14, 56(et)
	stw r15, 60(et)
	stw r16, 64(et)
	stw r17, 68(et)
	stw r18, 72(et)
	stw r19, 76(et)
	stw r20, 80(et)
	stw r21, 84(et)
	stw r22, 88(et)
	stw r23, 92(et)
	# NOTE: saving `et` is superfluous
	stw r24, 96(et)
	stw r25, 100(et)
	stw r26, 104(et)
	stw r27, 108(et)
	stw r28, 112(et)
	stw r29, 116(et)
	stw r30, 120(et)
	stw r31, 124(et)

	addi sp, sp, -4
	stw r4, 0(sp)

	movia r23, PROCESS_IO_OUT

	# get table index
	call os_process_current
	mov r4, r2

	# set status byte
	call os_process_table_entry
	movi r9, 3
	stb r9, PROCESS_TABLE_STATUS(r2)

	# enqueue yoloq
	call os_io_yoloq_enqueue

	# address = offset + index
	call os_process_table_index
	add r8, r23, r2
	# set output byte
	ldw r4, 0(sp)
	stb r4, 0(r8)

	addi sp, sp, 4
	call os_schedule
	mov ra, ea

os_putchar_epilogue:
	movia et, PROCESS_REGISTERS_TMP
	ldw r1, 4(et)
	ldw r2, 8(et)
	ldw r3, 12(et)
	ldw r4, 16(et)
	ldw r5, 20(et)
	ldw r6, 24(et)
	ldw r7, 28(et)
	ldw r8, 32(et)
	ldw r9, 36(et)
	ldw r10, 40(et)
	ldw r11, 44(et)
	ldw r12, 48(et)
	ldw r13, 52(et)
	ldw r14, 56(et)
	ldw r15, 60(et)
	ldw r16, 64(et)
	ldw r17, 68(et)
	ldw r18, 72(et)
	ldw r19, 76(et)
	ldw r20, 80(et)
	ldw r21, 84(et)
	ldw r22, 88(et)
	ldw r23, 92(et)
	# NOTE: restoring `et` is superfluous
	ldw r24, 96(et)
	ldw r25, 100(et)
	ldw r26, 104(et)
	ldw r27, 108(et)
	ldw r28, 112(et)
	ldw r29, 116(et)
	ldw r30, 120(et)
	ldw r31, 124(et)

	movi et, 1
	wrctl ctl0, et
	ret

/*
 * r4: modified
 * r5: modified
 * r23: process io yoloq
 * @param process id
 */
os_io_yoloq_enqueue:
	addi sp, sp, -16
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r23, 8(sp)
	stw ra, 12(sp)

	# mov process id argument position
	mov r5, r4

	movia r23, PROCESS_IO_YOLOQ
	ldw r4, 0(r23)

	# byte 0
	call os_vechs_push
	# byte 1
	srli r5, r5, 8
	call os_vechs_push
	# byte 2
	srli r5, r5, 8
	call os_vechs_push
	# byte 3
	srli r5, r5, 8
	call os_vechs_push

	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r23, 8(sp)
	ldw ra, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r4: modified
 * r8: temporary
 * r23: process io yoloq
 */
os_io_yoloq_dequeue:
	addi sp, sp, -16
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r23, 8(sp)
	stw ra, 12(sp)

	movia r23, PROCESS_IO_YOLOQ
	ldw r4, 0(r23)

	# byte 0
	call os_vechs_shift
	mov r8, r2

	# byte 1
	call os_vechs_shift
	slli r8, r8, 8
	or r8, r8, r2

	# byte 2
	call os_vechs_shift
	slli r8, r8, 8
	or r8, r8, r2

	# byte 3
	call os_vechs_shift
	slli r8, r8, 8
	or r2, r8, r2

	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw r23, 8(sp)
	ldw ra, 12(sp)
	addi sp, sp, 16
	ret

/*
 * r8: polling spaces available for write
 * r23: jtag uart
 * @param char
 */
os_putchar_sync:
	wrctl ctl0, r0

	addi sp, sp, -8
	stw r8, 0(sp)
	stw r23, 4(sp)

	movia r23, JTAG_UART

os_putchar_sync_poll:
	ldwio r8, JTAG_UART_CTRL(r23)
	srli r8, r8, 16
	beq r8, r0, os_putchar_sync_poll

	# done polling
	stwio r4, JTAG_UART_DATA(r23)

os_putchar_sync_epilogue:
	ldw r8, 0(sp)
	ldw r23, 4(sp)
	addi sp, sp, 8

	movi et, 1
	wrctl ctl0, et
	ret

os_printstr_sync:
	addi sp, sp, -12
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw ra, 8(sp)

	mov r8, r4

os_printstr_sync_loop:
	ldb r4, 0(r8)
	beq r4, r0, os_printstr_sync_epilogue
	call os_putchar_sync
	addi r8, r8, 1
	br os_printstr_sync_loop

os_printstr_sync_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	ldw ra, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r8: counter
 * r9: address
 * r10: loaded byte
 * @param from address
 * @param to address
 * @param num bytes
 */
os_memcpy:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)

	mov r8, r0

os_memcpy_loop:
	beq r8, r6, os_memcpy_epilogue
	# address = base + offset
	add r9, r4, r8
	# load byte
	ldb r10, 0(r9)
	# address = base + offset
	add r9, r5, r8
	# store byte
	stb r10, 0(r9)
	# increment
	addi r8, r8, 1
	# loop
	br os_memcpy_loop

os_memcpy_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r8: counter
 * r9: address
 * @param address
 * @param value
 * @param num bytes
 */
os_memset:
	addi sp, sp, -8
	stw r8, 0(sp)
	stw r9, 4(sp)

	mov r8, r0

os_memset_loop:
	beq r8, r6, os_memset_epilogue
	add r9, r4, r8
	stb r5, 0(r9)
	addi r8, r8, 1
	br os_memset_loop

os_memset_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	addi sp, sp, 8

/*
 * r8: counter
 * r9: upper bound
 * Synchronous pause for ~1 second
 */
os_pause:
	addi sp, sp, -8
	stw r8, 0(sp)
	stw r9, 4(sp)

	mov r8, r0
	movia r9, 10000000

os_pause_loop:
	beq r8, r9, os_pause_epilogue
	addi r8, r8, 1
	br os_pause_loop

os_pause_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	addi sp, sp, 8
	ret

os_badness:
	wrctl ctl0, r0
	movia r23, LEDS_RED
	stw r4, 0(r23)
	br have_fun_looping

have_fun_looping:
	br have_fun_looping

os_bombadil:
	movia r4, BUKKITS_OF_FUN
	call os_printstr_sync
	call os_pause
	br os_bombadil
