/*
 * The universe is made of 12 particles of matter, 4 forces of nature
 * # Richard and dfr OS
 * Hmmmmmm.
 *
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
 * - structure
 *   - byte 0: process ID
 *   - byte 1: state - 0 for dead/unused, 1 for running, 2 for waiting
 *   - bytes 4-7: pc
 * - additional data
 *   - 1 byte: executing process ID
 *   - 1 byte: foreground process ID (which proccess has the terminal, receives stdin)
 *
 * ## Dynamic memory
 * - heap block with 4 byte header + `n` bytes data
 *   - bytes 0-3: size of block (0 if free)
 *   - bytes 4-`n + 3`: block data (0 if free)
 * - on free, 0 bytes
 */

/*
addi sp, sp, -84
stw r4, 0(sp)
stw r5, 4(sp)
stw r6, 8(sp)
stw r7, 12(sp)
stw r8, 16(sp)
stw r9, 20(sp)
stw r10, 24(sp)
stw r11, 28(sp)
stw r12, 32(sp)
stw r13, 36(sp)
stw r14, 40(sp)
stw r15, 44(sp)
stw r16, 48(sp)
stw r17, 52(sp)
stw r18, 56(sp)
stw r19, 60(sp)
stw r20, 64(sp)
stw r21, 68(sp)
stw r22, 72(sp)
stw r23, 76(sp)
stw ra, 80(sp)

ldw r4, 0(sp)
ldw r5, 4(sp)
ldw r6, 8(sp)
ldw r7, 12(sp)
ldw r8, 16(sp)
ldw r9, 20(sp)
ldw r10, 24(sp)
ldw r11, 28(sp)
ldw r12, 32(sp)
ldw r13, 36(sp)
ldw r14, 40(sp)
ldw r15, 44(sp)
ldw r16, 48(sp)
ldw r17, 52(sp)
ldw r18, 56(sp)
ldw r19, 60(sp)
ldw r20, 64(sp)
ldw r21, 68(sp)
ldw r22, 72(sp)
ldw r23, 76(sp)
ldw ra, 80(sp)
addi sp, sp, 84
 */

/*
addi sp, sp, -56
stw r4, 0(sp)
stw r5, 4(sp)
stw r6, 8(sp)
stw r7, 12(sp)
stw r8, 16(sp)
stw r9, 20(sp)
stw r10, 24(sp)
stw r11, 28(sp)
stw r12, 32(sp)
stw r20, 36(sp)
stw r21, 40(sp)
stw r22, 44(sp)
stw r23, 48(sp)
stw ra, 52(sp)

ldw r4, 0(sp)
ldw r5, 4(sp)
ldw r6, 8(sp)
ldw r7, 12(sp)
ldw r8, 16(sp)
ldw r9, 20(sp)
ldw r10, 24(sp)
ldw r11, 28(sp)
ldw r12, 32(sp)
ldw r20, 36(sp)
ldw r21, 40(sp)
ldw r22, 44(sp)
ldw r23, 48(sp)
ldw ra, 52(sp)
addi sp, sp, 56
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

EPSILON:
	.string ""

FOO:
	.string "foo"

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

	// root dir
	mov r4, r0
	movia r5, EPSILON
	call os_mkdir

	// foo
	movia r5, FOO
	call os_kdir

	br have_fun_looping

/* romania */
/*
 * @param node id of parent folder
 * @param pointer to string name
 */
os_touch:
	addi sp, sp, -8
	stw r6, 0(sp)
	stw ra, 4(sp)
	// set file bit
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
	// set directory bit
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

	// upper 4 bits of block id
	srli r12, r10, 8
	slli r12, r12, 4
	// directory or file bit
	slli r6, r6, 1
	// directory or file bit, in use bit
	ori r6, r6, 0xf1
	// set lower bits
	or r12, r12, r6
	mov r12, 0x1

	stb r12, 0(r9)
	stb r10, 1(r9)

	mov r4, r5
	call os_strlen
	movi r12, 13
	bgt r2, r12, os_mkdir_bad_name
	// then valid name
	// r5 = node address + name offset
	addi r5, r9, 2
	call os_strcpy
	// TODO: null terminate
	mov r2, r8
	br os_mkdir_epilogue

os_mkdir_bad_name:
	// TODO: handle
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
	// r8 = offset + index
	add r8, r22, r4
	ldb r9, 0(r8)
	// get second bit, directory or file
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

	// get block id
	call os_romania_block_from_node
	mov r4, r2
	// get block contents
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
	// reset r4 to vechs
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
	// r9 = offset + index
	add r9, r22, r4

	// read length
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
	// r8 = offset + index
	add r8, r22, r4
	// load byte 0
	ldb r9, 0(r8)
	// load byte 1
	ldb r10, 1(r8)
	// get upper bits of byte 0, the upper 4 bits of block id
	andi r9, r9, 0xf0
	// shift upper 4 bits of block id
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
 * r22: nodes offset
 * r23: nodes bytes
 */
os_romania_allocate_node:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r22, 4(sp)
	stw r23, 8(sp)

	// initialize
	mov r2, r0
	movia r22, ROMANIA_NODES
	movia r23, ROMANIA_NODES_BYTES

os_romania_allocate_node_loop:
	// r8 = index + offset
	add r8, r2, r22
	// read first byte of a node
	ldb r10, 0(r8)
	// if 0, found block
	beq r10, r0, os_romania_allocate_node_epilogue
	// then non-zero, skip over node
	addi r2, r2, 16
	br os_romania_allocate_node_loop

os_romania_allocate_node_epilogue:
	ldw r8, 0(sp)
	ldw r22, 4(sp)
	ldw r23, 8(sp)
	addi sp, sp, 12
	ret

/*
 * r8: address
 * r22: blocks offset
 * r23: blocks bytes
 */
os_romania_allocate_block:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r22, 4(sp)
	stw r23, 8(sp)

	// initialize
	mov r2, r0
	movia r22, ROMANIA_BLOCKS
	movia r23, ROMANIA_BLOCKS_BYTES

os_romania_allocate_block_loop:
	// r8 = index + offset
	add r8, r2, r22
	// read first byte of a block
	ldb r10, 0(r8)
	// if 0, found block
	beq r10, r0, os_romania_allocate_block_found
	// then non-zero, skip over block
	addi r2, r2, 256
	br os_romania_allocate_block_loop

os_romania_allocate_block_found:
	// NOTE: r23 nolonger needed, used as temporary register
	movi r23, 1
	// mark block as used
	stb r23, 0(r8)
	br os_romania_allocate_block_epilogue

os_romania_allocate_block_epilogue:
	ldw r8, 0(sp)
	ldw r22, 4(sp)
	ldw r23, 8(sp)
	addi sp, sp, 12
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

	mov r22, ROMANIA_BLOCKS
	// r8 = offset + index
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
	// r9 points to a byte in the node we are zeroing
	add r9, r4, r8
	// zero byte
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
	// r9 points to a byte in the block we are zeroing
	add r9, r4, r8
	// zero byte
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
	addi sp, sp, -36
	stw r4, 0(sp)
	stw r8, 4(sp)
	stw r9, 8(sp)
	stw r10, 12(sp)
	stw r11, 16(sp)
	stw r12, 20(sp)
	stw r21, 24(sp)
	stw r22, 28(sp)
	stw r23, 32(sp)

	// constraints
	ble r4, r0, os_malloc_oom

	// initialize
	mov r8, r0
	movia r22, HEAP
	movia r23, HEAP_BYTES
	add r21, r22, r23

	// round size up to multiple of 4 bytes
	// get lower 2 bits
	andi r12, r4, 0x3
	// invert bits
	xori r12, r12, 0xff
	// increment
	addi r12, r12, 1
	// grab lower 2 bits
	andi r12, r12, 0x3
	// add
	add r4, r4, r12

os_malloc_crawl_loop:
	bge r8, r23, os_malloc_oom
	// reset counter
	mov r11, r0
	// load header
	add r9, r8, r22
	ldw r10, 0(r9)
	// skip over header bytes
	addi r8, r8, 4
	// check block header
	beq r10, r0 os_malloc_found_free_block
	// found used block
	// skip over allocated bytes
	add r8, r8, r10
	// continue searching
	br os_malloc_crawl_loop

os_malloc_found_free_block:
	// check oom
	beq r9, r21, os_malloc_oom
	// increment counter
	addi r11, r11, 1
	// load heap
	ldb r10, 0(r9)
	// increment heap pointer
	addi r9, r9, 1
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
	// address of last byte we loaded
	add r9, r8, r22
	// -4 in binary is all 1s with least significant two 0s
	andi r9, r9, -4
	// load header
	ldw r10, 0(r9)
	// r8 + r11 + r10 skips the number of bytes in the block we hit
	add r8, r8, r10
	// skip over header
	addi r8, r8, 4
	// continue searching
	br os_malloc_crawl_loop

os_malloc_found_sufficient_block:
	// r8 + r22 at the first zero byte, which will be the header
	add r9, r8, r22
	stw r4, 0(r9)
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
	ldw r21, 24(sp)
	ldw r22, 28(sp)
	ldw r23, 32(sp)
	addi sp, sp, 36
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
	ldw r8, -4(r4)
	// zero header
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
	ldw ra, 8(sp)
	addi, sp, sp, 12
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
	addi sp, sp, -8
	stw r6, 0(sp)
	stw ra, 4(sp)

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
	ldw ra, 4(sp)
	addi sp, sp, 4
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
	// calculate next size
	addi r5, r2, -1
	// retrieve top value
	call os_vechs_get
	// update size
	stw r5, 8(r4)

os_vechs_pop_epilogue:
	ldw r5, 0(sp)
	ldw ra, 4(sp)
	addi sp, sp, 8
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
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r8, 8(sp)
	ldw r9, 12(sp)
	ldw r10, 16(sp)
	ldw r11, 20(sp)
	stw ra, 24(sp)
	add sp, sp, 28
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

/* hmmm */
os_putchar:
	ret

have_fun_looping:
	br have_fun_looping
