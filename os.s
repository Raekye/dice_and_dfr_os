/*
 * The universe is made of 12 particles of matter, 4 forces of nature
 * # Richard and dfr OS
 * Hmmmmmm.
 *
 * TODO: malloc, vechs word size
 * TODO: vechs check for failed malloc
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
 *
 * ## Romania
 * - inodes (16 bytes) * 256 (2 ^ 8) for total 4096 bytes
 *   - byte 0
 *     - bit 0: in use
 *     - bit 1: 0 for directory, 1 for file
 *     - bits 4-7: upper 4 bits of index of first block
 *   - byte 1: lower 8 bits of index of first block (range 2 ^ 12 = 4096)
 *   - bytes 2-15: name, null terminated (unless length 14)
 * - blocks (256 bytes) * 1024 (2 ^ 8 * 4) for total 262144 bytes
 *   - common
 *     - byte 0: 0 for free, 1 for in use
 *     - byte 1: length of content in block (range 256 - 2)
 *     - byte 2: next block, 0 for no more blocks
 *   - directories
 *     - list of inode indexes, one byte each
 *     - end of list can be determined by block length
 *   - files
 *     - arbitrary contents of file
 *
 * ## Processes
 * - structure
 *   - byte 0: process ID
 *   - byte 1: state - 0 for dead/unused, 1 for running, 2 for waiting
 * - additional data
 *   - 1 byte: executing process ID
 *   - 1 byte: foreground process ID (which proccess has the terminal, receives stdin)
 *
 * ## Dynamic memory
 * - heap block with 1 byte header + `n` bytes data
 *   - byte 0: size of block (o if free)
 *   - bytes 1-`n`: block data (0 if free)
 */

.global seog_ti_os

.equ HEAP_BYTES 4096
.equ ROMANIA_NODES_BYTES 4096
.equ ROMANIA_BLOCKS_BYTES 252144

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

/* INTERRUPTS */
.section .exceptions, "ax"
ISR:
	addi sp, sp, -4
	eret

/* TEXT */
.text
/* main */
seog_ti_os:
	// stack starts at highest address
	movi sp, -1
	br seog_ti_os

/* romania */
os_touch:
	ret

os_mkdir:
	ret

os_rm:
	ret

/* processes */
os_fork:
	ret

os_mort:
	ret

os_sleep:
	ret

/* dynamic memory */
/*
 * r8: index in heap
 * r9: address in heap (index + heap offset)
 * r10: loaded value from heap
 * r11: counter for free space
 * r21: heap end
 * r22: heap offset
 * r23: heap bytes
 * @param n
 */
os_malloc:
	addi sp, sp, -28
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r11, 12(sp)
	stw r21, 16(sp)
	stw r22, 20(sp)
	stw r23, 24(sp)

	// constraints
	ble r4, r0, os_malloc_oom

	// initialize
	mov r8, r0
	movia r22, HEAP
	movia r23, HEAP_BYTES
	add r21, r22, r23

os_malloc_crawl_loop:
	bge r8, r23, os_malloc_oom
	// reset counter
	mov r11, r0
	// load heap
	add r9, r8, r22
	ldb r10, 0(r9)
	// check block header
	beq r10, r0 os_malloc_found_free_block
	// found used block
	// skip over allocated bytes
	add r8, r8, r10
	// skip over 1 more
	addi r8, r8, 1
	// continue searching
	br os_malloc_crawl_loop

os_malloc_found_free_block:
	// increment counter
	addi r11, r11, 1
	// load heap
	add r9, 1
	beq r9, r21, os_malloc_oom
	ldb r10, 0(r9)
	// if not 0, we hit a block before we found enough space
	bne r10, r0, os_malloc_found_insufficient_block
	// then 0
	// if found enough space
	beq r11, r4, os_malloc_found_sufficient_block
	// then 0, not enough space yet, keep searching
	br os_malloc_found_free_block

os_malloc_found_insufficient_block:
	// r8 + r11 at the last byte we loaded, which was non-zero, meaning it was the header/size of a block
	add r8, r8, r11
	// r8 + r11 + r10 skips the number of bytes in the block we hit
	add r8, r8, r10
	// skip over 1 more
	addi r8, r8, 1
	// continue searching
	br os_malloc_crawl_loop

os_malloc_found_sufficient_block:
	// r8 + r22 at the first zero byte, which will be the header
	add r9, r8, r22
	stw r4, 0(r9)
	// data starts after 1 byte header
	addi r2, r9, 1
	br os_malloc_epilogue

os_malloc_oom:
	mov r2, r0
	br os_malloc_epilogue

os_malloc_epilogue:
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r11, 12(sp)
	ldw r21, 16(sp)
	ldw r22, 20(sp)
	ldw r23, 24(sp)
	addi sp, sp, 28
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

	// read header
	ldb r8, -1(r4)
	// zero header
	stb r0, -1(r4)
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
	addi sp, sp, -8
	stw r4, 0(sp)
	stw r8, 4(sp)

	// malloc structure
	movi r4, 12
	call os_malloc
	mov r8, r2
	// malloc space for data
	ldw r4, 0(sp)
	call os_malloc
	// set pointer
	stw r2, 0(r8)
	stw r4, 4(r8)
	stw r0, 8(r8)
	// return pointer to structure
	mov r2, r8

os_vechs_new_epilogue:
	ldw r4, 0(sp)
	ldw r8, 0(sp)
	addi sp, sp, 8
	ret

/*
 * r4: modified
 * r8: pointer to data
 * @param ptr
 */
os_vechs_delete:
	addi sp, sp, -8
	stw r4, 0(sp)
	stw r8, 4(sp)

	// get pointer to data
	ldw r8, 0(r4)
	// free structure
	call os_free
	// free data
	mov r4, r8
	call os_free

os_vechs_delete_epilogue:
	ldw r4, 0(sp)
	ldw r8, 4(sp)
	addi, sp, sp, 8
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
	ldw r2, 0(r2)
	ret

/*
 * @param ptr
 * @param i
 * @param x
 */
os_vechs_set:
	ldw r2, 0(r4)
	add r2, r2, r5
	stw r6, 0(r2)
	ret

/*
 * r5: modified
 * r6: modified
 * @param ptr
 * @param x
 */
os_vechs_push:
	addi sp, sp, -4
	stw r6, 0(sp)

	// ensure capacity
	call os_vechs_normalize
	// get size
	call os_vechs_size
	// set top value
	mov r6, r5
	mov r5, r2
	call os_vechs_set
	// update size
	addi r2, r5, 1
	stw r2, 8(r4)

os_vechs_push_epilogue:
	mov r5, r6
	ldw r6, 0(sp)
	addi sp, sp, 4
	ret

/*
 * r5: modified
 * @param ptr
 */
os_vechs_pop:
	addi sp, sp, -4
	stw r5, 0(sp)

	call os_vechs_size
	// calculate next size
	addi r5, r2, -1
	// retrieve top value
	call os_vechs_get
	// update size
	stw r5, 8(r4)

os_vechs_pop_epilogue:
	ldw r5, 0(sp)
	addi sp, sp, 4
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
	addi sp, sp, -24
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r8, 8(sp)
	stw r9, 12(sp)
	stw r10, 16(sp)
	stw r11, 20(sp)

	// used size
	call os_vechs_size
	// allocated size
	ldw r8, 4(r4)
	// if used < allocated (should never be greater than), return
	bne r2, r8 os_vechs_normalize_epilogue
	// then used == allocated
	// size prime
	addi r9, r8, 4
	// array prime
	mov r4, r9
	call os_malloc
	mov r10, r2
	// initialize counter
	mov r5, r0
	// initialize pointer to array prime
	mov r11, r10
	// reset r4 to point to the vector structure
	ldw r4, 0(sp)

os_vechs_normalize_copy_loop:
	// if counter == num elements
	beq r5, r8, os_vechs_normalize_finalize
	call os_vechs_get
	stw r2, 0(r11)
	addi r5, r5, 1
	addi r11, r11, 4
	br os_vechs_normalize_copy_loop

os_vechs_normalize_finalize:
	// get pointer to old array
	ldw r4, 0(r4)
	// free old array
	call os_free
	// reset r4 to the vector structure
	ldw r4, 0(sp)
	// set new array pointer
	stw r10, 0(r4)
	// update size allocated
	stw r9, 4(r4)
	br os_vechs_normalize_epilogue

os_vechs_normalize_epilogue:
	add sp, sp, 24
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r8, 8(sp)
	ldw r9, 12(sp)
	ldw r10, 16(sp)
	ldw r11, 20(sp)
	ret

/* rational */
os_rational_new:
	ret

os_vechs_normalize:
	ret

os_rational_delete:
	ret

/* skye */
os_skye:
	ret
