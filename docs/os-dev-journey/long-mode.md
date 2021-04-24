---
layout: default
title: 2. Long Mode
parent: OS Dev Journey
nav_order: 4
---

# Entering Long Mode

To be able to use the features that comes with the long mode (such as 64-bit registers, multimedia registers, memory addresses that are higher than 4GiB), [the long mode](https://wiki.osdev.org/Setting_Up_Long_Mode) should be enabled.

Before enabling the long mode, we should first check if it is supported by the CPU. First step is to detect if CPUID is supported. We use CPUID to check if long mode is supported.

To detect the support for CPUID, we need to if 21. bit of `EFLAGS` can be modified. There are two notable instructions here:

```
pushfd ; push eflags to the stack
popfd  ; pop eflags from the stack
```

After this, CPUID should be called with the correct argument to check for the long mode support. CPUID accepts its argument from `eax` register.

```
mov eax, 0x80000000    ; Set the A-register to 0x80000000.
cpuid                  ; CPU identification.
cmp eax, 0x80000001    ; Compare the A-register with 0x80000001.
jb .NoLongMode
```

This code from [OSDev](https://wiki.osdev.org/Setting_Up_Long_Mode#x86_or_x86-64) is calling `cpuid` with an argument to [get highest extended function implemented](https://en.wikipedia.org/wiki/CPUID#EAX=80000000h:_Get_Highest_Extended_Function_Implemented). If the returned value is smaller than `0x80000001`, we understand that the long mode is not supported.

```
mov eax, 0x80000001    ; Set the A-register to 0x80000001.
cpuid                  ; CPU identification.
test edx, 1 << 29      ; Test if the LM-bit, which is bit 29, is set in the D-register.
jz .NoLongMode         ; They aren't, there is no long mode.
```

Then the next code from [OSDev](https://wiki.osdev.org/Setting_Up_Long_Mode#x86_or_x86-64) is calling `cpuid` again to get the [extended processor info and feature bits](https://en.wikipedia.org/wiki/CPUID#EAX=80000001h:_Extended_Processor_Info_and_Feature_Bits) which returns the feature flags in `edx` and `ecx` registers. We check the 29. bit of `edx` to see if the long mode is supported.

To have fun, I also wanted to print the vendor name of cpu. To get that information, we need to call `cpuid` with `eax = 0`, which returns the manufacturer id in `ebx`, `ecx` and `edx`. So we can write a function to call `cpuid` and print those 12 bytes to the screen.

```
print_cpu_vendor:
	mov eax, 0
	cpuid
    
    ; push the returned characters with the correct order to stack so that 
    ; we can easily iterate through them and be able to use the registers
	push ebx
	push ecx
	push edx

    ; for each character, we move the character to the vga buffer with the correct
    ; color code (in this case we use 0x2f for green background and white foreground)
	mov ecx, 0
.pcv_loop:
	cmp ecx, 12
	je .pcv_end
	mov al, byte [esp + ecx]
	mov ebx, 0xb8000
	lea edx, [ecx * 2]
	add ebx, edx
	mov byte [ebx], al
	add ebx, 1
	mov byte [ebx], 0x2f
	add ecx, 1
	jmp .pcv_loop
.pcv_end:
    ; never forget to clean your mess
	pop eax
	pop eax
	pop eax
	ret
```

## To be continued..

