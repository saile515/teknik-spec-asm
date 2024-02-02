global main

extern malloc, free

%include "print.asm"

section .data

fizz: db "fizz", 0
buzz: db "buzz", 0

section .text

main:
    mov rbp, rsp                ; 
    sub rsp, 16
    mov qword [rbp], 0
    .start:
        mov qword [rbp-8], 0
        mov rax, [rbp]
        inc rax
        mov [rbp], rax
        mov rdx, 0
        mov rcx, 3
        div rcx
        cmp rdx, 0
        je .fizz
        jmp .buzz
    .fizz:
        mov rdi, fizz
        call print_string
        mov qword [rbp-8], 1
        jmp .buzz
    .buzz:
        mov rdx, 0
        mov rax, [rbp]
        mov rcx, 5
        div rcx
        cmp rdx, 0
        jne .number
        mov rdi, buzz
        call print_string
        mov qword [rbp-8], 1
        jmp .number
    .number:
        cmp qword [rbp-8], 0
        jne .end
        mov rdi, [rbp]
        call print_int
        jmp .end
    .end:
        mov rdi, 10
        call print_char
        cmp qword [rbp], 100
        jne .start
        

            

    mov rax, 60
    mov rdi, 0
    syscall
