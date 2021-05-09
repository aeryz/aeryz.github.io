---
layout: default
title: Building a Simple Kernel 
parent: OS Dev Journey
nav_order: 4
---

# Building a Simple Kernel for IA-32 

## How to get most out this post?

Before digging into some weird stuff, I want to share some thoughts to make sure that you are getting the most out of this blog post. First of all, this post really encourages you to make lots of research and read a lot. There are several reasons to that:

1. Getting used to reading official documentations is super benefitial and you will always find lots of hidden gems and hacks when you read official docs.

2. Although there are few great resources about OS development, this is a field where you should find and figure out things by yourself.

Secondly, I will give you some hints and resources and ask you to stop and try it on your own. No matter how painful it is, please try those things yourself before going further. You may lose your mind but that's the beauty of it :)

That's enough already, let's dig into the real thing.

## Introduction

Before digging into more complex stuff like cpu scheduling, paging, etc. we should of course have a bootable kernel. You can do some research about the boot process, we will just make a kernel that supports Multiboot.

## Supporting multiboot specification

Multiboot specification is an open standard describing how a boot loader can load an x86 operating system kernel[\[\*\]](https://en.wikipedia.org/wiki/Multiboot_specification). This way, any boot loader that are able to load multiboot compliant kernel and we won't need to write our own boot loader. Of course one can say that there is Linux, so we don't need to write our own operating system. But it is fun and helps you to understand how real systems really work.

There are few requirements in the [specification](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html) to make things work. First of all the specification says:

> *The Multiboot header must be contained completely within the first 8192 bytes of the OS image, and must be longword (32-bit) aligned. In general, it should come as early as possible, and may be embedded in the beginning of the text segment after the real executable header.*

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

1. The multiboot header should be 32-bit (4 byte) aligned. So we aligned the section by using `.align` [directive](https://ftp.gnu.org/old-gnu/Manuals/gas-2.9.1/html_chapter/as_7.html)
3. We name this section as `.multiboot` and will be using this name later on to make sure that our header is 4-byte aligned and loaded very early in the executable file.
4. Magic number that indicates multiboot 1.
5. We don't have any flags set. So we put 0.
6. We put the checksum value. It should give 0, when added to the other magic fields.

To be able to assemble `boot.s` for our bare bones x86 target, we need to use a cross-platform toolchain. We don't want anything that depends on our host ecosystem. We can achieve this by using `binutils`.

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

## Running some code

The boot loader will jump to the `_start` symbol. If we don't define the `_start` symbol, the linker will provide it with a predefined location. Our super simple kernel would probably work if we won't define the `_start` symbol. I will demonstrate what I mean later.

```nasm
.section .text #1
.global _start #2
_start: 
```

1. Executable part of the binary goes into `.text` section.
2. We make `_start` symbol accessible from outside of the file.

Let's print a very simple `Hi` message to see if everything works fine. Since we don't have any underlying OS (basically we are the OS), we don't have anything like `printf` or `write` system call. Because the system calls are provided by the operating system. We need to implement such things ourselves in this wild, bare bones environment. 

We will use the [VGA text mode](https://en.wikipedia.org/wiki/VGA_text_mode) to print to screen. The one we will be using in `qemu` provides a `80x25 16-bit` buffer located at physical memory address `0xB8000`. Layout of a character is like this:

| Bits  | Description       |
| ------| ------------------|
| 0-7   | Code point        | 
| 8-11  | Foreground color  | 
| 12-15 | Background color  | 

You can also check out the 4-bit color palette [here](https://www.fountainware.com/EXPL/vga_color_palettes.htm).

To print a white-on-black `HI` message, we need to do a small math.

```nasm
.section .text
.global _start
_start:
    mov word ptr [0xb8000], 'h' | (0xF << 8)
    mov word ptr [0xb8000 + 0x2], 'i' | (0xF << 8)
    
    hlt
```

We basically left-shift the foreground color (WHITE) by 8 bits and OR it with `h` and `i` to get white-on-black characters and put it to physical address `0xb8000` which is the address of the VGA buffer.



