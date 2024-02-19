global main

extern malloc, free

%include "print.asm"

section .data

width: dq 80
height: dq 40
; cells that are filled in the beginning of the simulation, format: [x1, y1, x2, y2, ...] (0 indexed)
initial_cells: db 7, 5, 6, 6, 7, 6, 8, 6
initial_cells_length: dq 8

clear: db 27, "[2J", 0
move: db 27, "[;H", 0

section .bss

; allocate memory for pointer to cell map and backbuffer.
cell_map: resb 8
cell_map_backbuffer: resb 8

map_size: resb 8

section .text

main:
    mov rdi, clear                          ; clear screen
    call print_string
    mov rax, [width]                        ; calculate map size
    mov rdx, [height]
    mul rdx
    mov qword [map_size], rax
    mov rdi, [map_size]                     ; allocate memory for map
    call malloc
    mov [cell_map], rax
    mov rdi, [map_size]                     ; allocate memeory for map backbuffer
    call malloc
    mov [cell_map_backbuffer], rax

    mov r8, 0                               ; loop variable
    .init_cells:
    mov rdi, 0                          ; clear parameter registers
    mov rsi, 0
    mov dil, [initial_cells+r8]          ; x
    mov sil, [initial_cells+r8+1]        ; y
    call coordinates_to_index
    mov rbx, [cell_map]
    add rbx, rax
    mov byte [rbx], 1          ; turn on cell
    add r8, 2                           ; increment once for x and once for y
    cmp r8, [initial_cells_length]
    jne .init_cells

    call print_frame
    
    call evaluate_next_frame

    mov rax, 60
    mov rdi, 0
    syscall

evaluate_next_frame:
    push rbp                                ; create new stack frame
    mov rbp, rsp
    sub rsp, 8
    mov qword [rbp-8], 0                    ; map index

    push qword [cell_map_backbuffer]                ; switch map and backbuffer
    mov rax, [cell_map]
    mov qword [cell_map_backbuffer], rax
    pop rax
    mov qword [cell_map], rax

    .evaluate_cell:
    sub rsp, 24                         ; allocate local variables
    mov qword [rbp-16], 0               ; x
    mov qword [rbp-24], 0               ; y
    mov qword [rbp-32], 0               ; neighbouring cells on count
    mov rdi, [rbp-8]                    ; get coordinates
    call index_to_coordinates
    mov dword [rbp-24], eax
    shr rax, 32
    mov dword [rbp-16], eax
    mov r8, -1                          ; loop variable x
    mov r9, -1                          ; loop variable y
    .for_x:
    .for_y:
    cmp r8, 0           ; check if cell offset is 0, 0
    jne .start_increment
    cmp r9, 0
    jne .start_increment
    jmp .end_increment
    .start_increment:
    mov rdi, [rbp-16]               ; get cell value of neighbouring cells
    add rdi, r8
    mov rsi, [rbp-24]
    add rsi, r9
    call get_cell_value
    add [rbp-32], rax
    .end_increment:
    inc r9
    cmp r9, 1
    jbe .for_y
    jmp .end_y
    .end_y:
    mov r9, -1
    inc r8
    cmp r8, 1
    jbe .for_x
    jmp .end_x
    .end_x:
    mov rax, [rbp-8]
    add rax, [cell_map]
    push rax
    mov rbx, [rbp-32]
    cmp qword [rbp-32], 2
    jb .off
    cmp qword [rbp-32], 3
    ja .off
    je .on
    mov rdi, [rbp-16]
    mov rsi, [rbp-24]
    call get_cell_value
    cmp rax, 1
    jb .off
    jmp .on
    .on:
    pop rax
    mov byte [rax], 1
    jmp .end_evaluate_cell
    .off:
    pop rax
    mov byte [rax], 0
    .end_evaluate_cell:
    add rsp, 24
    mov rax, [rbp-8]
    inc rax
    mov qword [rbp-8], rax
    mov rax, [map_size]
    cmp qword [rbp-8], rax
    jb .evaluate_cell
    call print_frame

    add rsp, 8
    pop rbp

    mov rax, 35
    push qword 1
    mov rdi, rsp
    mov rsi, 0
    syscall
    pop qword rax

    call evaluate_next_frame

print_frame:
    mov rdi, move
    call print_string
    mov r8, 0
    .print_y:
    mov r9, 0
    .print_x:
    mov rdi, r9
    mov rsi, r8
    call coordinates_to_index
    mov rdi, 0
    add rax, [cell_map]
    mov dil, [rax]
    add rdi, 32
    call print_char
    inc r9
    cmp r9, [width]
    jb .print_x
    mov rdi, 10
    call print_char
    inc r8
    cmp r8, [height]
    jne .print_y
    ret

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
    jae .gt
    jmp .end
    .gt:
    cmp qword [rbp-8], map_size
    jb .lt
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
    mov rax, rdi
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
    add rax, [cell_map_backbuffer]
    cmp byte [rax], 1
    jb .end
    mov rax, 1
    ret
    .end:
    mov rax, 0
    ret
