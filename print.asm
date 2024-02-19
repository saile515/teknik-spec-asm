%ifndef PRINT_ASM
    %define PRINT_ASM

extern malloc, free
                                            ; rdi
print_char:                                 ; char character
    push qword rdi                          ; push character to stack
    mov rdx, 1                              ; set rdx to length (1)
    mov rsi, rsp                            ; set rsi to stack pointer
    mov rdi, 1                              ; rdi is output stream
    mov rax, 1                              ; write syscall
    syscall
    add rsp, 8
    ret

                                            ; rdi
print_string:                               ; char* string
    call length                             ; no need to set rdi since print and length share first paramater
    mov rdx, rax                            ; set rdx to length of string
    mov rsi, rdi                            ; rsi is root of string
    mov rdi, 1                              ; rdi is output stream
    mov rax, 1                              ; write syscall
    syscall
    ret

                                            ; rdi
length:                                     ; char* string
    mov rbx, rdi                            ; rbx is root address of string
    mov rax, 0                              ; rax is character count
    .count:
    mov rcx, rbx                            ; rcx is current character address 
    add rcx, rax
    inc rax
    cmp byte [rcx], 0                       ; check if current character is null
    jnz .count
    dec rax                                 ; don't count null
    ret

                                            ; rdi
print_int:                                  ; int number
    call int_to_string                      ; convert parameter to string
    push rax                                ; save string address
    mov rdi, rax                            ; print string
    call print_string
    pop rdi                                 ; restore address
    call free                               ; free string from memory
    ret

                                            ; rdi
int_to_string:                              ; int number
    push rdi                                ; save parameter
    mov rdi, 21                             ; allocate 64-bit int max length + null
    call malloc
    mov r8, rax                             ; save memory address of string in r8
    mov rbx, 0                              ; rbx is counting characters
    pop rax                                 ; restore parameter to rax
    .first_char_of_int:
    mov rdx, 0                              ; calculate first digit
    mov rcx, 10 
    div rcx
    add rdx, 48                             ; add ascii digit offset
    mov rcx, 20                             ; append characters backwards
    sub rcx, rbx
    add rcx, r8
    mov [rcx], dl
    inc rbx
    cmp rax, 0                              ; repeat label if more digits are present
    jne .first_char_of_int
    mov rcx, r8                             ; count offset for trimming
    .trim:
    mov rax, r8                             ; start loop from first digit
    add rax, 21
    sub rax, rbx
    mov dl, [rax]                           ; move digit to beginning of string
    mov byte [rcx], dl
    mov byte [rax], 0                       ; null-write old location
    inc rcx
    dec rbx                                 ; count how many characters have been moved
    cmp rbx, 0                              ; repeat label if more digits are present
    jne .trim
    mov rax, r8                             ; return string address
    ret

%endif
