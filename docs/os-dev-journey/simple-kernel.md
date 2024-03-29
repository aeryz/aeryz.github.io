---
layout: default
title: Building a Simple Kernel 
parent: OS Dev Journey
nav_order: 4
---

# Building a Simple Kernel for IA-32

## How to get the most out of this post?

Before digging into some weird stuff, I want to share some thoughts to make sure that you are getting the most out of this blog post. First of all, this post encourages you to make lots of research and read a lot. There are several reasons for that:

1. Getting used to reading official documentation is super beneficial and you will always find lots of hidden gems and hacks when you read official docs.

2. Although there are few great resources about OS development, this is a field where you should find and figure out things by yourself.

Secondly, I will give you some hints and resources and ask you to stop and try it on your own. No matter how painful it is, please try those things yourself before going further. You may lose your mind but that's the beauty of it :)

That's enough already, let's dig into the real thing.

## Introduction

Before digging into more complex stuff like CPU scheduling, paging, etc. we should of course have a bootable kernel. You can do some research about the boot process, we will just make a kernel that supports Multiboot.

You can find the source code in [here](https://github.com/aeryz/isletiyOS).

## Supporting multiboot specification

Multiboot specification is an open standard describing how a boot loader can load an x86 operating system kernel[\[\*\]](https://en.wikipedia.org/wiki/Multiboot_specification). This way, any boot loader that support multiboot can load any multiboot compliant kernel and we won't need to write our own boot loader. Of course one can say that there is Linux, so we don't need to write our own operating system. But it is fun and helps you to understand how real systems really work.

There are few requirements in the [specification](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html) to make things work. First of all the specification says:

> *The Multiboot header must be contained completely within the first 8192 bytes of the OS image, and must be longword (32-bit) aligned. In general, it should come as early as possible and maybe embedded at the beginning of the text segment after the real executable header.*

So we will make our header 32-bit aligned and put it as early as possible. The header fields that we will be using are:

| Offset | Type | Field Name |
| ------ | ---- | -----------|
| 0      | u32  | magic      |
| 4      | u32  | flags      |
| 8      | u32  | checksum   |

Let's start implementing this.

I prefer the Intel syntax. Let's use it.

```nasm
.intel_syntax noprefix
```

After this, we can start putting our 4-byte aligned header.

```
.align 4                 # 1
.section .multiboot      # 2
.long 0x1BADB002         # 3
.long 0                  # 4
.long -(0x1BADB002 + 0)  # 5
```

1. The multiboot header should be 32-bit (4 bytes) aligned. So we aligned the section by using `.align` [directive](https://ftp.gnu.org/old-gnu/Manuals/gas-2.9.1/html_chapter/as_7.html).
3. We name this section as `.multiboot` and will be using this name, later on, to make sure that our header is 4-byte aligned and loaded very early in the executable file.
4. Magic number that indicates multiboot 1.
5. We don't have any flags set. So we put 0.
6. We put the checksum value. It should give 0 when added to the other magic fields.

To be able to assemble `boot.s` for our bare-bones x86 target, we need to use a cross-platform toolchain. We don't want anything that depends on our host ecosystem. We can achieve this by using `binutils`.

Let's assemble `boot.s` and validate our multiboot header.

```sh
i386-elf-as -msyntax=intel -mmnemonic=intel boot.s -o boot.o
```

As you can guess, `-msyntax` and `-mmnemonic` arguments are used for intel syntax.

Validate the header:
```sh
grub-file --is-x86-multiboot boot.o || echo ":("
```

If the command does not give us a sad face, then we are good to go.

## Writing some code

The boot loader will jump to the `_start` symbol. If we don't define the `_start` symbol, the linker will provide it with a predefined location. Our super simple kernel would probably work if we won't define the `_start` symbol. Because we will put our kernel code to the beginning of the `.text` section. Otherwise this probably wouldn't work.

```nasm
.section .text #1
.global _start #2
_start:
```

1. Executable part of the binary goes into `.text` section.
2. We make `_start` symbol accessible from outside of the file.

Let's print a very simple `Hi` message to see if everything works fine. Since we don't have any underlying OS (basically we are the OS), we don't have anything like `printf` or `write` system call. Because the system calls are provided by the operating system. We need to implement such things ourselves in this wild, bare-bones environment.

We will use the [VGA text mode](https://en.wikipedia.org/wiki/VGA_text_mode) to print to screen. The one we will be using in `qemu` provides a `80x25 16-bit` buffer located at physical memory address `0xB8000`. The layout of a character is like this:

| Bits  | Description       |
| ------| ------------------|
| 0-7   | Code point        |
| 8-11  | Foreground color  |
| 12-15 | Background color  |

You can also check out the 4-bit color palette [here](https://www.fountainware.com/EXPL/vga_color_palettes.htm).

To print a white-on-black `HI` message, we need to do small math.

```nasm
.section .text
.global _start
_start:
    mov word ptr [0xb8000], 'h' | (0xF << 8)
    mov word ptr [0xb8000 + 0x2], 'i' | (0xF << 8)

    hlt
```

We left-shift the foreground color (WHITE) by 8 bits and OR it with `h` and `i` to get white-on-black characters and put it to physical address `0xb8000` which is the address of the VGA buffer.

## Running the code

We will be using [qemu](https://www.qemu.org) to run our kernel. To generate a bootable kernel, we again need to use the cross-platform linker. But we cannot use the linker like that because we also need to tell the linker how to construct the executable file.

Let's think about our needs for a second:
1. Our entry point's name is `_start`
2. Multiboot header should be 4-byte aligned.
3. Multiboot header should be within the first 8192 bytes of the OS image. (We can just put it to the top)
4. Any OS data should not collide with any special locations. (Like VGA buffer in `0xb8000`)

*DIY: Try to write your own linker script by considering the requirements above.*

If you didn't write your own linker script, it is fine :) Here is a very minimalistic linker script (linker.ld):

```
ENTRY(_start) /* 1 */

SECTIONS
{
    . = 1M; /* 2 */

    /* 3 */
    .multiboot : ALIGN(4) {
        *(.multiboot)
    }

    /* 4 */
    .text : {
        *(.text)
    }
}
```

1. We defined `_start` as the entry point.
2. We make the kernel code start from 1 MB, it is a convenient location to put the kernel code. Also, this way our kernel code won't collide with the VGA buffer.
3. We put the `.multiboot` section to top and align it to 4 bytes.
4. We put the actual code.

*Note: You can see the linker script that is used by the linker by using `--verbose` argument*

We can finally run our kernel. Let's create a simple build script.

```sh
#!/bin/sh

i386-elf-as -msyntax=intel -mmnemonic=intel boot.s -o boot.o # 1
i386-elf-ld -T linker.ld boot.o -o kernel.bin                # 2
```

1. We assemble the `boot.s`.
2. We generated our kernel executable by running the linker with `linker.ld`.

And let's run the kernel.

```sh
./build.sh && qemu-system-i386 -kernel kernel.bin
```


If everything works fine, you should see `hi` printed to qemu screen.

## Adding some C code

Assembly is great, but it would be really painful to extend our kernel's capabilities with it. So let's create a helper C file for VGA.

The first thing we need to know is that we cannot use anything that depends on an underlying OS like `stdio`.

*DIY: Try to write your own vga helper. It should be easy to use and incrementally write the characters starting from the physical address `0xb8000`.*

Since this is just an abstraction and nothing really fancy happens, I will just provide the files.

**vga.h**
```c
#ifndef VGA_H_
#define VGA_H_

typedef enum {
  VGA_BLACK,
  VGA_BLUE,
  VGA_GREEN,
  VGA_CYAN,
  VGA_RED,
  VGA_MAGENTA,
  VGA_BROWN,
  VGA_WHITE,
  VGA_GRAY,
  VGA_LIGHT_BLUE,
  VGA_LIGHT_GREEN,
  VGA_LIGHT_CYAN,
  VGA_LIGHT_RED,
  VGA_LIGHT_MAGENTA,
  VGA_YELLOW,
  VGA_BRIGHT_WHITE
} vga_color_t;

void vga_print(const char *);

void vga_set_color(vga_color_t bg, vga_color_t fg);

#endif
```

**vga.c**
```c
#include "vga.h"
#include <stddef.h>
#include <stdint.h>

#define MAX_COL 80
#define MAX_ROW 25

#define VGA_ADDR 0xb8000
#define BG_COL(X) (X << 12)
#define FG_COL(X) (X << 8)

static uint16_t *const VGA_BUFFER = (uint16_t *)VGA_ADDR;

static int vga_index = 0;

static uint16_t active_color = BG_COL(VGA_BLACK) | FG_COL(VGA_BRIGHT_WHITE);

static void vga_print_char(char character) {
  if (vga_index >= MAX_COL * MAX_ROW) {
    return;
  }

  if ('\n' == character) {
    vga_index = vga_index + MAX_COL - ((vga_index) % MAX_COL);
    return;
  }

  VGA_BUFFER[vga_index++] = active_color | character;
}

void vga_print(const char *string) {
  for (int i = 0;; ++i) {
    if (string[i] == '\0') {
      return;
    }
    vga_print_char(string[i]);
  }
}

void vga_set_color(vga_color_t bg, vga_color_t fg) {
  active_color = BG_COL(bg) | FG_COL(fg);
}
```

Our compiled code should not depend on the host environment. So we will use `-ffreestanding` argument of `gcc`. The manual file says:

>***-ffreestanding**
Assert that compilation takes place in a freestanding environment. This implies -fno-builtin. A freestanding environment is one in which the standard library may not exist, and program startup may not necessarily be at "main". The most obvious example is an OS kernel. This is equivalent to -fno-hosted.*

And we just want to compile the file, not link it. So we will use `-c` argument for that.

**build.sh**
```sh
#!/bin/sh

i386-elf-as -msyntax=intel -mmnemonic=intel boot.s -o boot.o
i386-elf-gcc -c vga.c -ffreestanding -o vga.o
i386-elf-ld -T linker.ld boot.o vga.o -o kernel.bin
```

Note that the object file `vga.o` is added to call to the linker. Otherwise, we won't be able to call any function of `vga` from `boot`.

## Calling a C function

To properly call a function, we need to use `call` instruction. What this instruction does is:

- Push `eip` to the stack (so that we can return from the function)
- Jump to the function's address

Simple, right?

Not so fast. Don't forget that we are the OS, so we don't have a stack. To have a stack, we first need to reserve some bytes and set the stack pointer (`esp`).

Our stack will be some uninitialized bytes. The `.bss` section contains statically allocated variables that are declared but have not been assigned a value yet[\[\*\]](https://en.wikipedia.org/wiki/.bss). So let's put our stack to `.bss` section.

**boot.s**
```
.section .text
.global _start
_start:
    lea esp, [stack_top]

    mov word ptr [0xb8000], 'h' | (0xF << 8)
    mov word ptr [0xb8000 + 0x2], 'i' | (0xF << 8)

    hlt

.section .bss
stack_bottom:
.skip 8192 # 8 KB
stack_top:
```

We put our stack to the `.bss` section. Note that `stack_top` is below `stack_bottom`. Because stacks grow through the lower addresses.

Let's add the `.bss` section to our linker script as well.

```
ENTRY(_start)

SECTIONS
{
    . = 1M;

    .multiboot : ALIGN(4) {
        *(.multiboot)
    }

    .text : {
        *(.text)
    }

    .bss : {
        *(.bss)
    }
}
```

But we are still not done :)

## Segmentation

We can consider an operating system as an abstraction over hardware. To make our lives easier, provide security, and improve performance, operating systems virtualize the physical memory. Memory addresses that we use are logical addresses that are translated into physical addresses with the help of the hardware. The hardware also provides us some security features.

*DIY: To understand the segmentation, I really suggest you to go read `Segmentation` part of the [OSTEP book](https://pages.cs.wisc.edu/~remzi/OSTEP/). I will just show you the basic segmentation setup in IA-32 architecture by skimming through the [Intel's developer manual](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html) Volume 3, Chapter 3.*

**All of the references are from Intel's developer manual, Volume 3, Chapter 3. Also, we won't do paging on this post. This is too much already.**

It says in 3.1
> *A logical address consists of a segment selector and an offset. The segment selector is a unique identifier for a segment. Among other things, it provides an offset into a descriptor table (such as the global descriptor table, GDT) to a data structure called a segment descriptor. Each segment has a segment descriptor, which specifies the size of the segment, the access rights and privilege level for the segment, the segment type, and the location of the first byte of the segment in the linear address space (called the base address of the segment). The offset part of the logical address is added to the base address for the segment to locate a byte within the segment. The base address plus the offset thus forms a linear address in the processor’s linear address space.*

And in 3.2.1
> *To implement a basic flat memory model with the IA-32 architecture, at least two segment descriptors must be created, one for referencing a code segment and one for referencing a data segment (see Figure 3-2). Both of these segments, however, are mapped to the entire linear address space: that is, both segment descriptors have the same base address value of 0 and the same segment limit of 4 GBytes. By setting the segment limit to 4 GBytes, the segmentation mechanism is kept from generating exceptions for out of limit memory references, even if no physical memory resides at a particular address.*

To achieve a basic flat model, what we have to do is:
- Create a GDT that contains 3 segment descriptors:
    - Null segment descriptor.
    - Code segment descriptor.
    - Data segment descriptor.
- Create a GDT descriptor:
    - Size of the GDT - 1.
    - Address of the GDT.
- Load the correct values to segment registers:
    - Code segment register should point to the code segment descriptor.
    - Other segment registers should point to the data segment descriptor.

You can see the visual representation of GDT [here](https://wiki.osdev.org/Global_Descriptor_Table).

So let's start by creating the null descriptor. This is required by the IA-32 architecture.

**boot.s**
```nasm
    ...
    hlt

gdt:
    .long 0x0
    .long 0x0
```

After that let's create the code and data segment descriptors. But to do that, let's first check out the structure of the segment descriptor. You can check out the detailed explanation of the segment descriptor structure in [here](https://wiki.osdev.org/Global_Descriptor_Table).

**Please check it out. Otherwise, you won't understand the following part.**

*DIY: I put the first null descriptor for you. By following the document from OSDev, try to set up the code and data segment descriptors.*

**boot.s**
```nasm

gdt:
    .long 0x0
    .long 0x0
code_desc:
    .word 0xffff
    .word 0x0
    .byte 0x0
    .byte 0x9a
    .byte 0xcf
    .byte 0x0
data_desc:
    .word 0xffff
    .word 0
    .byte 0
    .byte 0x92
    .byte 0xcf
    .byte 0
```

After this, we need one more descriptor that describes the GDT. It is like a pointer to an array that contains pointers.

*DIY: Create a GDT descriptor called `gdt_desc` and put 16-bit size of GDT - 1 and 32-bit pointer to GDT.*

**boot.s**
```nasm
data_desc:
    ...
gdt_desc:
    .word (gdt_desc - gdt - 1)
    .long gdt
```

And finally, we can load our GDT to `gdtr` (Global Descriptor Table Register) and fill the segment registers.

**boot.s**
```nasm
.section .text
.global _start
_start:
    lea esp, [stack_top]

    lgdt [gdt_desc]   # 1
    mov ax, 0x10
    mov ss, ax        # 2
    mov ds, ax
    mov es, ax
    mov fs, ax
    jmp 0x8:.load_cs  # 3

.load_cs:
```

1. We load our GDT descriptor to `gdtr` by using `lgdt` (Load Global Descriptor Table) instruction.
2. We make the segment registers (other than CS) point to the data segment descriptor.
3. Since we cannot write to CS register, we did a long jump to load `0x8` to the CS register.

But wait a minute, what are these `0x10` and `0x8`? How are these make the segment registers to point to the correct descriptor?

Yeah, good point!

As it says in 3.4.2:
> *A segment selector is a 16-bit identifier for a segment (see Figure 3-6). It does not point directly to the segment but instead points to the segment descriptor that defines the segment.*

- First 2 bits of the segment selector is Requested Privilege Level, since we are just using the privilege level 0, we will make this 0 as well.
- The following bit is the Table Indicator. It indicates if the table is LDT or GDT. It is GDT, so we will make this 0.
- Remaining bits indicate the index of the segment descriptor.

We load `0x8` to CS. The underlying math is this:
- RPL is 0
- Table Indicator is 0
- Index is 1

```
(1 << 3) = 0x8
```

And we load `0x10` to other segment registers.
- RPL is 0
- Table Indicator is 0
- Index is 2

```
(2 << 3) = 0x10
```

## Calling the C function (for real)

Finally, we can call the helper function that we wrote.

To properly call a function, we need to follow some calling conventions.

*DIY: Call the function by following the `cdecl` convention*

The arguments are pushed to stack from right-to-left, and the caller cleans up the pushed arguments after the function returns.

Let's print something fancy.
```nasm
.load_cs:
    push 0xF            # int fg
    push 0x4            # int bg
    call vga_set_color  
    add esp, 0x8        # clean up the stack

    lea eax, [my_brain_text] # Load the string's address
    push eax                 # const char *
    call vga_print
    add esp, 0x4

    push 0x4
    push 0xF
    call vga_set_color
    add esp, 0x8

    lea eax, [hurts_text]
    push eax
    call vga_print
    add esp, 0x4

    hlt

my_brain_text:
.ascii "My Brain\n\0"
hurts_text:
.ascii "Hurts\n\0"
```

## What's next?

We will deal with the interrupts and paging on the next posts. Feel free to contact if you find anything wrong, you have any questions or any ideas.
