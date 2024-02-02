global main

extern malloc, free

%include "print.asm"

section .data

width: dq 10
height: dq 10
; cells that are filled in the beginning of the simulation, format: [x1, y1, x2, y2, ...] (0 indexed)
initial_cells: db 4, 2, 3, 3, 4, 3, 5, 3

section .bss

; allocate memory for pointer to cell map and backbuffer.
cell_map: resb 8
cell_map_backbuffer: resb 8

map_size: resb 8

section .text

main:
    mov rax, [width]
    mov qword rdx, [height]
    mul rdx
    mov qword [map_size], rax
    mov rdi, [map_size]
    call malloc
    mov qword [cell_map], rax
    mov rdi, [map_size]
    call malloc
    mov qword [cell_map_backbuffer], rax
    
    call evaluate_next_frame

    mov rax, 60
    mov rdi, 0
    syscall

evaluate_next_frame:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    mov qword [rbp-8], 0  ; map index

    push cell_map_backbuffer
    mov qword [cell_map_backbuffer], cell_map
    pop rax
    mov qword [cell_map], rax

    .evaluate_cell:
        mov rdi, [rbp-8]
        sub rsp, 24
        mov qword [rbp-16], 0
        mov qword [rbp-24], 0
        mov qword [rbp-32], 0
        call index_to_coordinates
        mov dword [rbp-24], eax
        shr rax, 32
        mov dword [rbp-16], eax
        mov r8, -1
        mov r9, -1
        .for_x:
        .for_y:
            mov rdi, [rbp-16]
            add rdi, r8
            mov rsi, [rbp-24]
            add rsi, r9
            call get_cell_value
            add rax, [rbp-32]
            mov [rbp-32], rax
            cmp r9, 1
            inc r9
            jne .for_y
            jmp .end_y
            .end_y:
                mov r9, -1
                cmp r8, 1
                inc r8
                jne .for_x
                jmp .end_x
        .end_x:
        cmp qword [rbp-32], 1
        mov rax, [rbp-8]
        jb .off
        mov byte [cell_map+rax], 1
        jmp .end_evaluate_cell
        .off:
        mov byte [cell_map+rax], 0
        .end_evaluate_cell:
        add rsp, 24
        cmp qword [rbp-8], map_size
        jne .evaluate_cell
        
    add rsp, 8
    pop rbp
    call evaluate_next_frame

; int coordinates_to_index(int x, int y)
coordinates_to_index:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    mov [rbp-8], rdi
    mov rax, rsi
    mov rdx, [width]
    mul rdx
    add [rbp-8], rax
    cmp qword [rbp-8], 0
    jge .gt
    jmp .end
    .gt:
        cmp qword [rbp-8], map_size
        jl .lt
        jmp .end
    .lt:
        mov rax, [rbp-8]
        add rsp, 8
        pop rbp
        ret
    .end:
        mov rax, -1
        add rsp, 8
        pop rbp
        ret


; first 32 bits is x, last 32 bits is y
; int index_to_coordinates(int index)
index_to_coordinates:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rbp-8], 0          ; x
    mov qword [rbp-16], 0        ; y
    
    mov rdx, 0
    mov rax, [rbp-8]
    mov rcx, [width]
    div rcx
    mov qword [rbp-8], rdx
    mov qword [rbp-16], rax

    mov rax, [rbp-8]
    shl rax, 32
    add rax, [rbp-16]
    add rsp, 16
    pop rbp
    ret

; bool get_cell_value(int x, int y)
get_cell_value:
    call coordinates_to_index
    cmp rax, -1
    je .end
    mov rax, [cell_map_backbuffer+rax]
    ret
    .end:
        mov rax, 0
        ret
