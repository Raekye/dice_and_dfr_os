Dice and dfr OS
===============

This is a proof of concept multiprocess operating system in Altera Nios II assembly.
Some VGA and PS2 code is in C, a simple shell is written in C, and a simple interpreter for a tiny arbitrary language is written in C.
No C standard library or functions have been used.
Code quality is questionable, though there is a method to the madness.
This project isn't serious; just something we did for fun (though we had to rush at the end because life goes on).
However, it's simple enough I think it might be mildly interesting to some people.
Many odd names are used; hopefully it doesn't detract too much from following along.

In assembly:
- linear `malloc` and `free`
- dynamically resizing arrays ("`vechs`")
- filesystem with nodes (metadata) and blocks (contents)
- supports multiprocessing; "user programs" can be written as normal, and the OS figures out how to schedule multiple processes so it appears that they are running in parallel
	- simple implementation of `fork` ("duplicates" process, returns child pid to parent, 0 to child)
	- system calls like waiting for input or sleeping put processes in a waiting state (won't be scheduled until they are ready)

The assembly file has more details (big comment block at top of file).
In this file I'll try to explain our basic implementation of multiprocessing.

## Multiprocess OS
Hopefully you know the basics of assembly.
You probably know that a single core processor can be used to simulate parallel execution by quickly cycling between running each of the programs.
A program should be able to be written without knowing it is going to be run in parallel, and the OS should take care of scheduling multiple processes without corrupting data.
Let's start breaking it down.

### Capturing the state of a process
As you may know, a processor is a state machine.
Only considering a single program, how would we "capture" an instance of it?
There are the values in registers and external memory (e.g. RAM).
There is a program counter pointing to the location of the current/next instruction.
Conventionally, programs typically have a "stack" and a stack pointer pointing to the top of the stack, and a return address for function calls.
But the stack is typically in RAM and the stack pointer and return address are in registers, so they're already taken care of.
So these three things capture everything about a program executing on a processor at any given time:
- registers
- memory (RAM)
- program counter (PC)

So now our idea about the OS is a little better:
1. It's running a process/program
1. It runs for a little bit, and then the OS somehow needs to stop it
1. The OS needs to save all that information somewhere
1. Then it picks a new process to run
1. It should have all the corresponding information for the new process somewhere
1. It needs to "load up" all that information
1. It needs to tell the processor to continue where the new process last left off (the new process' PC).

### Retreiving control of the processor
Suppose you write a program that repeatedly calculates odd numbers.
So it's just going about adding 2 to the previous odd number.
The assembly might look like this:

```
loop:
	addi r8, r8, 2
	br loop
```

So it's just doing those two instructions over and over, but after a short amount of time (say 0.1 seconds) you want the processor to stop executing those instructions, and start executing some OS code, so the OS can schedule another process to run.
We can do that using a hardware interrupt from the timer.
When an interrupt happens, the processor knows to save the PC, and jumps to a special location in memory where an interrupt handler is supposed to be.
So we can tell the timer to interrupt us every 0.1 seconds.
When we're interrupted, we'll be taken to a handler (which the OS should implement) where we can save the current values in the registers, memory, and PC.
Hopefully that makes sense, and you can see how theoretically, step 2 from above can be implemented.

### System calls
#### Sleeping
#### Reading input
#### Waiting for a child process

### Integrity and disabling interrupts for critical OS code

### Taking care to handle special registers


### The process table

#### Process exits

### Fork
