---
layout: default
title: x86_64 Tcp Server
parent: Small Projects
nav_order: 4
---

# x86_64 Tcp Server

## Introduction

I like reversing things, and being a reverse engineer means being a computer geek who knows lots of things' internals. And knowledge of assembly is one of them. So we will make a simple assembly project. Since there are many resources about assembly, I don't want to explain basic things like what does the `mov` instruction do. Instead, I will suggest you some resources and kindly ask you to study them first. After reading this blog post, - assuming I am not terrible at explaining stuff :) - you will have a basic understanding of:

- Properly using and understanding the stack,
- Calling conventions,
- Using `rep` instructions,
- Writing code for different platforms by using NASM preprocessor,
- Doing syscalls.

*By saying assembly, I am referring to x64 assembly.*

## Requirements

- To understand things covered in this post, you should have at least a basic understanding of assembly. 
- You should know what are sockets. If you did socket programming before, you would probably understand every syscall easily.

## Resources 

- Amazing [resource](https://www.opensecuritytraining.info) about x86 and x64 assembly and much more.
- [Intel's developer manual.](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html)

## Syscalls

> *[System Calls](https://wiki.osdev.org/System_Calls) are used to call a kernel service from the userland. The goal is to be able to switch from user mode to kernel mode, with the associated privileges.*

For example, when we call `printf` in C, or `print` in Python, it calls the `write` system call to print something to the standard output. Or when we want to open some file in C,
we call `open` system call. 

So we will start by doing a super simple 'Hello World' application by calling the `write` system call.

The prototype of the `write` function is like this:
```c
ssize_t write(int fd, const void *buf, size_t count);
```

Making a syscall in C is super simple, you pass the correct arguments and call the correct function. But calling a function properly in assembly is a little bit different. We cannot call a syscall like this:

```nasm
syscall write(1, buffer, 10)
```

Firstly, system calls are not like regular functions. We trigger an interrupt to make the OS take care of the system call. And secondly, `write(1, buffer, 10)` like C won't work in assembly because there is no mechanism to pass the parameters magically in assembly. So we need to know how the kernel expects the parameters. [The calling convention](https://wiki.osdev.org/Calling_Conventions) of x86_64 System V ABI is like this (these are the ones that we will use, for more detail please go to the reference):

- Parameters are put in registers `rdi, rsi, rdx` from left to right. 
- The stack pointer (`rsp`) needs to be 16-byte aligned at call.
- The return value should be put to `rax`.
- `rbx, rsp, rbp` should be preserved. This means that they must be the same before and after the function call.

As I said earlier, system calls are not like regular function calls. We are requesting a service from the operating system. To make a system call, we need to provide to kernel the syscall that we want to make. Like `write` or `open`. And then we can make the system call. We can specify the system call by putting the number of the system call to `rax` before making the system call. You can find 64-bit system call numbers of Linux in [here](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl).

As you can see, the number of `write` system call is `1`. Here is an example usage of `write` system call:

```nasm
; export the main symbol so that `gcc` can find it
global main

section .text

main:
    ; write(stdout, HELLO_STR, 14)
    mov rax, 1          ; Syscall number of `write`
    mov rdi, 1          ; Stdout
    mov rsi, HELLO_STR
    mov rdx, 14         ; Length of HELLO_STR
    syscall

    ; exit(0)
    mov rax, 60         ; Syscall number of `exit`
    mov rdi, 0
    syscall

section .data
HELLO_STR:
    db "Hello, World!", 10, 0  ; "Hello, World!" followed by a newline and the null character.
```

Let's run it:
```sh
nasm -f elf64 hello_world.s && gcc hello_world.o -o hello_world
./hello_world

$ Hello, World!
```

> ***DIY: Take input from stdin by using `read` syscall and print the string that you read. Hint: You use `resb` to allocate a buffer or make enough space on the stack and use the stack.***

## Using the NASM Preprocessor

As you can see, we put `1` for `write` and `60` for `exit` to `rax`. Is it really necessary to memorize these numbers or look at the table each time? Of course not, like in C, we will use [the NASM's preprocessor](https://www.nasm.us/doc/nasmdoc4.html) to define those numbers. 

Let's create a file named `defines.s`.
```nasm
%define EXIT 60
%define READ 0
%define WRITE 1
%define CLOSE 3
%define ACCEPT 43
%define SOCKET 41
%define BIND 49
%define SETSOCKOPT 54
%define LISTEN 50

%define STDOUT 1
```

Now we can include this file and change the syscall with the corresponding names.

```nasm
%include "defines.s"
...
    mov rax, WRITE
...
    mov rax, EXIT
...
```

Another reason that we use the preprocessor is to make it super easy to write code for both OS X and Linux. There are some small differences between the OS X and Linux (of course there are huge differences but I am talking about our little program):

- System call numbers,
- Some data structures,
- Name of the 'main' function,
- OS X requires a base number that needs to be added to each system call.

Let's enhance our definitions by using the conditionals:

```nasm
; Like in C, if we compile our code by defining PLATFORM_OSX, first part will be active, otherwise the `elif` part will be active.
%ifdef PLATFORM_OSX
    %define SYSCALL_BASE 0x2000000
    %define EXIT 1
    %define READ 3
    %define WRITE 4
    %define CLOSE 6
    %define ACCEPT 30
    %define SOCKET 97
    %define BIND 104
    %define SETSOCKOPT 105
    %define LISTEN 106
%elifdef PLATFORM_LINUX
    %define SYSCALL_BASE 0
    %define EXIT 60
    %define READ 0
    %define WRITE 1
    %define CLOSE 3
    %define ACCEPT 43
    %define SOCKET 41
    %define BIND 49
    %define SETSOCKOPT 54
    %define LISTEN 50
%endif

%define STDOUT 1

; We don't want to add the base number every time we make a syscall,
; this is a nice way to prevent that.
%define SYSCALL(NUM) (SYSCALL_BASE + NUM)
```

And also, on OS X, the compiler expects `_main` symbol to be exported. So we need to make it conditional as well.

> ***DIY: Update `hello_world.s` to run for both OS X and Linux***

Here is the final version of `hello_world.s`:

```nasm
%include "defines.s"

%ifdef PLATFORM_LINUX
global main
%elifdef PLATFORM_OSX
global _main
%endif

section .text

%ifdef PLATFORM_LINUX
main:
%elifdef PLATFORM_OSX
_main:
%endif
    ; write(stdout, HELLO_STR, 14)
    mov rax, SYSCALL(WRITE)
    mov rdi, STDOUT          
    mov rsi, HELLO_STR
    mov rdx, 14
    syscall

    ; exit(0)
    mov rax, SYSCALL(EXIT)
    mov rdi, 0
    syscall

section .data
HELLO_STR:
    db "Hello, World!", 10, 0  ; "Hello, World!" followed by a newline and the null character.
```

Now, we need to specify the platform on the compilation, and there is a small tweak that we need to do for OS X. So let's create a shell script to ease the build.

In `build.sh`:

```sh
#!/bin/bash

FILES=(hello_world)

if [ "PLATFORM_OSX" = "$1" ]
then
    FORMAT="macho64"
    PLATFORM="$1"
else
    FORMAT="elf64"
    PLATFORM="PLATFORM_LINUX"
fi

OBJ_FILES=""

for f in ${FILES[@]}
do
    echo 'Building: ' $f
    nasm -d$PLATFORM -f $FORMAT $f.s
    OBJ_FILES+="$f.o "
done

echo "Linking $OBJ_FILES"
if [ "PLATFORM_OSX" = "$PLATFORM" ]
then
    gcc -Wl,-no_pie $OBJ_FILES -o hello_world
else
    gcc $OBJ_FILES -o hello_world
fi
```

The script gets a platform specifier and compiles each file in `FILES` list for the target platform.

Let's run it:
```sh
chmod +x build.sh

# For Linux
./build.sh PLATFORM_LINUX

# For OS X
./build.sh PLATFORM_OSX

./hello_world
```

## Creating a Socket

To create a socket, we need to use [`socket`](https://man7.org/linux/man-pages/man2/socket.2.html) system call. Here is the prototype of `socket`:
```c
int socket(int domain, int type, int protocol);
```

- `domain` argument specifies a communication domain. Since we want to use IPv4 internet protocols, we want to use `AF_INET` - which expands to `2` - for this. `AF_INET` is defined in `sys/socket.h`.

> *Hint: You can print the value of things by writing a C program or use an IDE or a text editor with an extension to jump to the definition of something. For example, I am using neovim with coc.*

- `type` will be `SOCK_STREAM` - which expands to `1` - for a TCP connection.
- `protocol` will be `0` since we use a single protocol.

In `socket.s`:

```nasm
%include "defines.s"

%define AF_INET 2
%define SOCK_STREAM 1

; Export the `socket_listen` function
global socket_listen

section .text

socket_listen:
    ; socket(rdi: AF_INET, rsi: SOCK_STREAM, rdx: 0)
    mov rax, SYSCALL(SOCKET)
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
```

Now we can find the created socket descriptor on `rax` register.

## Binding a Socket

To assign an address and a port to a socket, we need to make a [`bind`](https://man7.org/linux/man-pages/man2/bind.2.html) syscall. Here is the prototype of `bind`:

- `sockfd` is the socket's file descriptor which is returned from the `socket` syscall.
- `addr` is a pointer to the address information.
- `addrlen` is the length of address information.

Until this point, we only deal with values and not pointers. But this time the `addr` parameter points to a location that stores the actual data. So we need to reserve some space for the data. If we would use C, we would probably define `addr` as a local variable like this:

```c
struct sockaddr_in addr;
// ...
bind(.., &addr, sizeof(addr));
```

As you might know, non-static local variables are reserved on the stack. But before reserving a space for `addr` on the stack, we actually need to reserve a space on the stack for our function which is generally called as the stack frame. 

## Properly Setting Up the Stack Frame

Each function generally has its own stack frame. I am saying generally because some optimization might omit allocating the stack process. This stack frame is used to store our local variables and return addresses. Let's say the `main` function calls `foo` function. Right after the call happens, the stack would look like this:

```
       +------------------------+
       | Lower Addresses        |
       +------------------------+
rsp -> | return address of main |
       | some local variable    |
rbp -> |                        |
       +------------------------+
       | Higher Addresses       |
       +------------------------+
```

The `call` instruction pushes the return address of `main` to the stack. Because think about it, how would the CPU know, which instruction to return to otherwise? The part of the stack that is between `rsp` and `rbp` is called a stack frame. Right after the call, the stack frame is the `main` function's stack frame. To reserve a stack frame for `foo`, we do this:

1. Save `rbp`. Because we need to restore it before we return from `foo`. Otherwise, we would lose `main` function's base of the stack.
2. Move `rbp` to `rsp`. This would move the base of the stack frame of `foo` on top of the stack frame of `main`.
3. Reserve the necessary space by decrementing `rsp`. 

After doing the above steps, our stack will look like this:

```
       +------------------------+
       | Lower Addresses        |
       +------------------------+
rsp -> | reserved               |
       | reserved               |
rbp -> | saved rbp              |
       | return address of main |
       | some local variable    |
       +------------------------+
       | Higher Addresses       |
       +------------------------+
```

And to return from the function, we will restore the caller's stack frame not to mess things up.

1. Move `rsp` to `rbp`. This will make us discard all the reserved space.
2. Pop `rbp`. By doing this, we will restore the `saved rbp` and, since `pop` increments `rsp` we will also restore the `rsp`.
3. Execute `ret`. This will pop the return address to `rip` so that the program will continue to execute the caller function.

## Reserving `addr` On Stack

Let's properly set up the stack and reserve enough space for `addr`.

`struct sockaddr` is a generic data structure and for IP-based communication, we need to use `struct sockaddr_in`. If we use C, we would use `struct sockaddr_in` and case it to `struct sockaddr *` when we call the `bind` function. On Linux, the definition of `struct sockaddr_in` is like this:

```c
struct sockaddr_in {
    short          sin_family;
    unsigned short sin_port;
    struct in_addr sin_addr;
    char           sin_zero[8];
}
```

If you go to the definition by yourself, you will see some fancy stuff. This is a simplified version.

- `sin_family` will be `AF_INET` like we did before.
- `sin_port` will be the port number in network byte-order.
- `in_addr` is an `unsigned long` and it will be [`INADDR_ANY`](https://man7.org/linux/man-pages/man7/ip.7.html).
- `sin_zero` will be bunch of zeros.

In C, you can assign a variable with the equal sign and do not care about the size. But in assembly, we need to put the variables in the correct place, in the correct order, in the correct size.

Since the size of the `struct sockaddr` is 16 bytes, let's start improving our function by reserving 16 bytes.

```nasm
socket_listen:
    ; Set up the stack frame
    push rbp
    mov rbp, rsp
    ; Reserve 16 bytes on stack
    sub rsp, 0x10 
```

After that, let's correctly fill the reserved space for the address.

```nasm
socket_listen:
    ...
    mov word [rsp+0x0], AF_INET
    mov word [rsp+0x2], 23569      ; port 4444 in network byte-order.
    mov dword[rsp+0x4], INADDR_ANY
    mov qword[rsp+0x8], 0          ; zero out `sin_zero`
```

There is a thing that we need to do. On OS X, the definition of `struct sockaddr_in` is like this:

```c
struct sockaddr_in {
    __uint8_t      sin_len;
    __uint8_t      sin_family;
    __uint16_t     sin_port;
    struct in_addr sin_addr;
    char           sin_zero[8];
}
```

As you can see, now the size of `sin_family` is 1 byte and a new field called `sin_len` which is the size of `addr` is added. So we need to use conditional assembly in here.

```nasm
%ifdef PLATFORM_LINUX
    mov word [rsp+0x0], AF_INET    ; 2 bytes family
%elifdef PLATFORM_OSX
    mov byte [rsp+0x0], 0x10       ; size of the `addr`
    mov byte [rsp+0x1], AF_INET    ; 1 byte family
%endif
    mov word [rsp+0x2], 23569      ; port 4444 in network byte-order.
    mov dword[rsp+0x4], INADDR_ANY
    mov qword[rsp+0x8], 0          ; zero out `sin_zero`
```

Now we can call `bind`.

```nasm
%include "defines.s"

%define AF_INET 2
%define SOCK_STREAM 1
%define INADDR_ANY 0

global socket_listen

section .text

socket_listen:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    ; socket(rdi: AF_INET, rsi: SOCK_STREAM, rdx: 0)
    mov rax, SYSCALL(SOCKET)
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

%ifdef PLATFORM_LINUX
    mov word [rsp+0x0], AF_INET    ; 2 bytes family
%elifdef PLATFORM_OSX
    mov byte [rsp+0x0], 0x10       ; size of the `addr`
    mov byte [rsp+0x1], AF_INET    ; 1 byte family
%endif
    mov word [rsp+0x2], 23569      ; port 4444 in network byte-order.
    mov dword[rsp+0x4], INADDR_ANY
    mov qword[rsp+0x8], 0          ; zero out `sin_zero`

    ; bind(rdi: socket, rsi: addr, rdx: sizeof(addr))
    mov rdi, rax
    mov rax, SYSCALL(BIND)
    mov rsi, rsp
    mov rdx, 0x10
    syscall
```

You might not see it at first but we have a problem in here. `socket` returns the created socket descriptor in `rax` and `bind` returns the status code in `rax` as well. So after we call `bind`, we lost the returned socket descriptor. So let's save it to `rbx` before we call `socket`. We are saving it to `rbx` because we know that it will be preserved as it said in the calling convention. 

We are expecting `rbx` to remain unchanged but also the function that calls `socket_listen` expects `rbx` to remain unchanged. So we need to save it before we change it so that we can restore it later.


```nasm
%include "defines.s"

%define AF_INET 2
%define SOCK_STREAM 1
%define INADDR_ANY 0

global socket_listen

section .text

socket_listen:
    push rbp
    mov rbp, rsp
    push rbx       ; --> NEW: save `rbx`
    sub rsp, 0x10

    ; socket(rdi: AF_INET, rsi: SOCK_STREAM, rdx: 0)
    mov rax, SYSCALL(SOCKET)
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

    mov rbx, rax  ; --> NEW

%ifdef PLATFORM_LINUX
    mov word [rsp+0x0], AF_INET    ; 2 bytes family
%elifdef PLATFORM_OSX
    mov byte [rsp+0x0], 0x10       ; size of the `addr`
    mov byte [rsp+0x1], AF_INET    ; 1 byte family
%endif
    mov word [rsp+0x2], 23569      ; port 4444 in network byte-order.
    mov dword[rsp+0x4], INADDR_ANY
    mov qword[rsp+0x8], 0          ; zero out `sin_zero`

    ; bind(rdi: socket, rsi: addr, rdx: sizeof(addr))
    mov rax, SYSCALL(BIND)
    mov rdi, rbx  ;  --> NEW
    mov rsi, rsp
    mov rdx, 0x10
    syscall
```

## Listening on a Socket

Now we need to [`listen`](https://man7.org/linux/man-pages/man2/listen.2.html) for connection on the socket. Prototype of `listen` is:

```c
int listen(int sockfd, int backlog);
```

- `sockfd` is the socket descriptor that is returned from `socket`.
- `backlog` argument defines the maximum length to which queue of pending connections for `sockfd` may grow. We assign this to `5` just in case.

```nasm
socket_listen:
    ...
    ; listen(rdi: socket, rsi: backlog(5))
    mov rax, SYSCALL(LISTEN)
    mov rdi, rbx
    mov rsi, 5
    syscall
```

And we can finally restore the stack and `rbx` and return.

```nasm
socket_listen:
    ...
    ; Set the return value to the socket descriptor
    mov rax, rbx
    ; Restore rbx
    mov rbx, QWORD [rsp + 0x10]
    ; Properly return from the function
    mov rsp, rbp
    pop rbp
    ret
```

## Catching Failures

As you might know, system calls might fail. So we need to detect them before making a new call.

Here is how we can do that:
```nasm
socket_listen:
    ; Save the stack's base pointer.
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 0x10

    ; socket(rdi: AF_INET, rsi: SOCK_STREAM, rdx: 0)
    mov rax, SYSCALL(SOCKET)
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

    ; Socket returns <0 on failure.
    cmp rax, 0
    jl .socket_failed

    ; Save the returned socket descriptor.
    mov rbx, rax

%ifdef PLATFORM_LINUX
    mov word [rsp+0x0], AF_INET
%elifdef PLATFORM_OSX
    mov byte [rsp+0x0], 0x10
    mov byte [rsp+0x1], AF_INET

%endif
    mov word [rsp+0x2], 23569
    mov dword[rsp+0x4], INADDR_ANY
    mov qword[rsp+0x8], 0

    ; bind(rdi: socket, rsi: addr, rdx: sizeof(addr))
    mov rax, SYSCALL(BIND)
    mov rdi, rbx
    mov rsi, rsp
    mov rdx, 0x10
    syscall

    cmp rax, 0
    jl .bind_failed

    ; listen(rdi: socket, rsi: backlog(5))
    mov rax, SYSCALL(LISTEN)
    mov rdi, rbx
    mov rsi, 5
    syscall

    cmp rax, 0
    jl .listen_failed

    ; Restore the socket to return.
    mov rax, rbx
    jmp .ret

.socket_failed:
    mov rsi, SOCKET_FAILED
    jmp .err_msg
.bind_failed:
    mov rsi, BIND_FAILED
    jmp .err_msg
.listen_failed:
    mov rsi, LISTEN_FAILED
    jmp .err_msg
.err_msg:
    ; write(rdi: fd, rsi: buffer, rdx: count of bytes to write);
    mov rax, SYSCALL(WRITE)
    mov rdi, 1
    mov rdx, 20 ; Not generic :(
    syscall

    mov rax, -1
.ret:
    ; Restore rbx
    mov rbx, QWORD [rsp + 0x10]
    ; Properly return from the function
    mov rsp, rbp
    pop rbp
    ret

section .data

SOCKET_FAILED:
    db "socket() failed", 10, 0
BIND_FAILED:
    db "bind() failed", 10, 0
LISTEN_FAILED:
    db "listen() failed", 10, 0
ACCEPT_FAILED:
    db "accept() failed", 10, 0
```

What we do is fairly simple, after each system call, we checked the returned value and see if an error is occurred. And instead of copy-pasting the `write` syscall, we jumped to `.err_msg` which prints the string that is passed with `rsi`.

You can see that the length of the string is not generic. We will solve that really soon :)

## Running Our Server

Of course, our server won't do anything right now, but we can at least trace the system calls and see if things work.

> ***DIY: Write the main function that calls `socket_listen` and edit `build.sh` to compile and run the server.***

Let's create a simple main file `main.s`:

```nasm
%include "defines.s"

extern socket_listen

%ifdef PLATFORM_OSX
global _main
%elifdef PLATFORM_LINUX
global main
%endif

section .text

%ifdef PLATFORM_OSX
_main:
%elifdef PLATFORM_LINUX
main:
%endif
    call socket_listen

.ret:
    mov rax, SYSCALL(EXIT)
    mov rdi, 0
    syscall
```

And also change `build.sh`:
```sh
#!/bin/bash

FILES=(main socket)

if [ "PLATFORM_OSX" = "$1" ]
then
    FORMAT="macho64"
    PLATFORM="$1"
else
    FORMAT="elf64"
    PLATFORM="PLATFORM_LINUX"
fi

OBJ_FILES=""

for f in ${FILES[@]}
do
    echo 'Building: ' $f
    nasm -d$PLATFORM -f $FORMAT $f.s
    OBJ_FILES+="$f.o "
done

echo "Linking $OBJ_FILES"
if [ "PLATFORM_OSX" = "$PLATFORM" ]
then
    gcc -Wl,-no_pie $OBJ_FILES -o server
else
    gcc $OBJ_FILES -o server
fi
```

To see what's going on, we can use `strace` on Linux to trace system calls. You can use `dtruss` on OS X. 

Let's run `strace`:
```sh
strace ./server
```

You can see these system calls in the bottom of the output:
```
socket(AF_INET, SOCK_STREAM, IPPROTO_IP) = 3
bind(3, {sa_family=AF_INET, sin_port=htons(4444), sin_addr=inet_addr("0.0.0.0")}, 16) = 0
listen(3, 5)                            = 0
exit(0)
```

So everything works as expected:
- The program first creates a socket with the correct arguments, and the socket descriptor 3 is returned from the `socket` call.
- It calls `bind` with the correct address and port and no error is returned.
- It calls `listen` with the returned socket file descriptor. It also returns success.
- Program exits.

> *`strace` is a really handy tool to analyze binaries. It tells a lot about what's going on. So I suggest you experiment with it and read its manual.*

## Writing Some Helper Functions

Our program works but there are few things that I don't like. 

1. We are converting port number 4444 to the network byte-order by hand. That should be automized with a function.
2. Initializing the memory reserved for the address to zero is more convenient than setting the necessary fields to zero. 
3. In `.err_msg`, we used a single length which is `20` and this is wrong.

For the first part, let's write a [`htons`](https://linux.die.net/man/3/htons) function that converts a 2-byte integer (short) from host byte order to network byte order. To do that we just need to swap, the byte order.

In `socket.s`, on top of `socket_listen`:
```nasm
; htons(port)
;    Convert 'port' to network byte-order.
htons:
    ; Swap the first and the second byte of 'port'.
    mov dx, di
    mov ax, dx
    ; shift the least significant byte to left, so that it becomes the most significant byte.
    shl ax, 8
    ; shift the MSB of `dx` to right, so that it becomes the LSB.
    shr dx, 8
    ; mov the LSB of `rdx` to the LSB of `rax`.
    mov al, dl

    ret
```

You can see that we did not reserve a stack frame because we didn't use the stack at all. You might not understand what's going on at the first look, but please take your time and try to understand the function. I will not explain it :)

> *To ease things up, you can use `gdb` to debug the program. And run the function instruction by instruction.*

For the second part, let's write a function that imitates `memset`. This function will set a particular memory to a value.

In `helper.s`:
```nasm
global h_memset

; memset(dst, x, n)
;   starting from [dst], write 'x', to next 'n' bytes
h_memset:
    mov rax, rsi
    mov rcx, rdx
    ; Starting from `rdi`, write `al` to `BYTE [rdi]`, 
    ; and decrement `rcx`. Stop when `rcx` is zero.
    rep stosb
    ret
```

You can see that there is a weird instruction called `rep stosb`. Actually, it is not like ordinary instruction. It has two parts:

1. `rep` means `Repeat String Operation`. It takes a string operation and repeatedly executes that operation.
    - It repeats an operation the number of times specified in `rcx` or until the specified condition is met. There are conditional `rep`'s `REPE, REPNE and REPNZ`. You can check them from the intel's developer manual.
2. `stosb` means to store byte.
    - It stores `al`, in the memory location specified in `rdi`.

Our function gets the destination address from `rdi`, byte to write from `rsi` and how many bytes to write from `rdx`.

For the third part, let's write a `strlen` function to find the length of the null-terminated strings.

In `helper.s`:

```nasm
global h_memset
global h_strlen

; strlen(str)
;    loop until '\0' is seen and return length of 'str'
h_strlen:
    ; We don't want the caller to lose the given string.
    push rdi
    ; `rbx` should be preserved..
    push rbx
    mov rbx, rdi
    ; Set `rax` to zero as the null terminator.
    xor rax, rax
    ; Set `rcx` to zero and substract 1 from it, this makes 
    ; it get the largest value possible.
    xor rcx, rcx
    dec rcx
    ; This time we use `repne` and `scasb`. `repne` will execute
    ; the string operation while ZF = 1.
    ; `scasb` will compare the value stored in the memory address
    ; `rdi` with `rax` and set EFLAGS accordingly. 
    ; So if the destination byte is `rax` which is the null terminator,
    ; `repne` will stop executing.
    repne scasb
    ; Don't count the null terminator at the end of the string.
    sub rax, 2
    ; Check how many times `rcx` is decremented. And that gives us the
    ; length of the string.
    sub rax, rcx
    pop rbx
    pop rdi
    ret
```

> ***DIY: Use the helper functions in `socket_listen`. Then run and see if they work. If they do not work, don't give up and use `gdb` to see what's wrong. No pain, no gain.***

I really want you to integrate these functions into the program - and also I need a break :) - , so I will continue this post in the next part.

Hopefully we will talk about the stack alignment, and complete our program.
