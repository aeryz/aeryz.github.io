---
layout: default
title: Introduction
parent: OS Dev Journey
nav_order: 4
---

# Introduction

I followed the first edition of [phil-opp's series](https://os.phil-opp.com/multiboot-kernel/). I didn't want to go with the newest version because it uses a helper tool that does too much. After I understand and experiment with the booting process, I'm gonna switch to the new version though. So, today's gainings are:

- I skimmed through the [Multiboot Specification](https://nongnu.askapache.com/grub/phcoder/multiboot.pdf) and implement a simple Multiboot header in assembly.
- I was familiar with assembly, and binary analysis tools like hexdump, objdump, etc. So I refreshed my knowledge about them.
- I wrote my first linker script. I wasn't aware of they exist and it was cool. I wrote the below script, which defines the entry point as `start`, sets the load address of the first section to 1 MiB, and puts the multiboot header and the os code in order. One important thing is to run `ld` command with the parameter `-n` to disable the automatic section alignment. Otherwise the grub may not be able to find the Multiboot header.

```
ENTRY(start)

SECTIONS {
    . = 1M;

    .boot :
    {
        /* ensure that the multiboot header is at the beginning */
        *(.multiboot_header)
    }

    .text :
    {
        *(.text)
    }
}
```
 
- I wrote a simple `grub` configuration file and generate an `iso` file.

- I ran this simples OS possible in `qemu`. But since I use my Linux computer over ssh, I used `curses` instead of the GUI. I achieved this by running.

```
qemu-system-x86_64 -cdrom os.iso -curses -monitor stdio
```

`monitor` is used to be able to input commands to `qemu`. Otherwise you won't be able to exit from it.

- I automate the build process by using `make`.

- After understanding what's going on, I rewrote everything from scratch to have a more clear understanding.

## Next Step

I will continue with [Entering Long Mode](https://os.phil-opp.com/entering-longmode/) post.
