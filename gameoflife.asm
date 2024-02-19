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
    mov rdi, 0                              ; clear parameter registers
    mov rsi, 0
    mov dil, [initial_cells+r8]             ; x
    mov sil, [initial_cells+r8+1]           ; y
    call coordinates_to_index
    mov rbx, [cell_map]
    add rbx, rax
    mov byte [rbx], 1                       ; turn on cell
    add r8, 2                               ; increment once for x and once for y
    cmp r8, [initial_cells_length]
    jne .init_cells

    call print_frame
    
    call evaluate_next_frame

    mov rax, 60
    mov rdi, 0
    syscall

; void evaluate_next_frame()
evaluate_next_frame:
    push rbp                                ; create new stack frame
    mov rbp, rsp
    sub rsp, 8
    mov qword [rbp-8], 0                    ; map index

    push qword [cell_map_backbuffer]        ; switch map and backbuffer
    mov rax, [cell_map]
    mov qword [cell_map_backbuffer], rax
    pop rax
    mov qword [cell_map], rax

    .evaluate_cell:
    sub rsp, 24                             ; allocate local variables
    mov qword [rbp-16], 0                   ; x
    mov qword [rbp-24], 0                   ; y
    mov qword [rbp-32], 0                   ; count of neighbouring cells with on state
    mov rdi, [rbp-8]                        ; get coordinates
    call index_to_coordinates
    mov dword [rbp-24], eax                 ; move lower 32 bits to y
    shr rax, 32                             ; move upper 32 bits to x
    mov dword [rbp-16], eax
    mov r8, -1                              ; loop variable x (offset from cell coordinate)
    mov r9, -1                              ; loop variable y (offset from cell coordinate)
    .for_x:
    .for_y:
    cmp r8, 0                               ; check if cell offset is 0, 0
    jne .start_increment
    cmp r9, 0
    jne .start_increment
    jmp .end_increment                      ; skip current cell
    .start_increment:
    mov rdi, [rbp-16]                       ; get cell value of neighbouring cell
    add rdi, r8
    mov rsi, [rbp-24]
    add rsi, r9
    call get_cell_value
    add [rbp-32], rax                       ; add value to count
    .end_increment:
    inc r9
    cmp r9, 1                               ; loop between -1 and 1
    jbe .for_y
    jmp .end_y
    .end_y:
    mov r9, -1
    inc r8
    cmp r8, 1                               ; loop between -1 and 1
    jbe .for_x
    jmp .end_x
    .end_x:
    mov rax, [rbp-8]                        ; store cell address in stack
    add rax, [cell_map]
    push rax
    cmp qword [rbp-32], 2                   ; turn off cell if less than 2 neighbours
    jb .off
    cmp qword [rbp-32], 3                   ; turn off cell if more than 3 neighbours
    ja .off
    je .on                                  ; turn on cell if 3 neighbours
    mov rdi, [rbp-16]                       ; turn off cell if currently on and 2 neighbours
    mov rsi, [rbp-24]
    call get_cell_value
    cmp rax, 1
    jb .off
    jmp .on
    .on:
    pop rax                                 ; turn on cell
    mov byte [rax], 1
    jmp .end_evaluate_cell
    .off:
    pop rax                                 ; turn off cell
    mov byte [rax], 0
    .end_evaluate_cell:
    add rsp, 24                             ; restore stack pointer
    mov rax, [rbp-8]                        ; increment loop variable
    inc rax
    mov qword [rbp-8], rax
    mov rax, [map_size]                     ; run again if not last cell
    cmp qword [rbp-8], rax
    jb .evaluate_cell

    call print_frame

    add rsp, 8                              ; restore stack pointer
    pop rbp                                 ; restore stack frame

    mov rax, 35                             ; delay one second before next frame
    push qword 1
    mov rdi, rsp
    mov rsi, 0
    syscall
    pop qword rax

    call evaluate_next_frame

; void print_frame()
print_frame:
    mov rdi, move                           ; move cursor to start of terminal
    call print_string
    mov r8, 0                               ; loop variable y
    .print_y:
    mov r9, 0                               ; loop variable x
    .print_x:
    mov rdi, r9                             ; get cell index
    mov rsi, r8
    call coordinates_to_index
    mov rdi, 0                              ; print cell value
    add rax, [cell_map]
    mov dil, [rax]
    add rdi, 32                             ; 0+32 = [Space], 1+32 = '!'
    call print_char
    inc r9
    cmp r9, [width]                         ; run again if less than width
    jb .print_x
    mov rdi, 10                             ; print new line
    call print_char
    inc r8
    cmp r8, [height]                        ; run again if less than height
    jne .print_y
    ret

; int coordinates_to_index(int x, int y)    
coordinates_to_index:
    push rbp                                ; create new stack frame
    mov rbp, rsp
    sub rsp, 8
    mov [rbp-8], rdi                        ; index variable start at x
    mov rax, rsi                            ; y * width
    mov rdx, [width]
    mul rdx
    add [rbp-8], rax                        ; add cells from previous rows to index
    cmp qword [rbp-8], 0                    ; end if before grid
    jae .gt
    jmp .end
    .gt:
    cmp qword [rbp-8], map_size             ; end if after grid
    jb .lt
    jmp .end
    .lt:
    mov rax, [rbp-8]                        ; return index if exists
    add rsp, 8
    pop rbp
    ret
    .end:                                   ; return -1 if not exists
    mov rax, -1
    add rsp, 8
    pop rbp
    ret


; upper 32 bits of return is x, lower 32 bits is y
; int index_to_coordinates(int index)
index_to_coordinates:
    push rbp                                ; create new stack frame
    mov rbp, rsp
    sub rsp, 16                             ; allocate memory for local variables
    mov qword [rbp-8], 0                    ; x
    mov qword [rbp-16], 0                   ; y
    
    mov rdx, 0                              ; index / width
    mov rax, rdi
    mov rcx, [width]
    div rcx
    mov qword [rbp-8], rdx                  ; x = rest
    mov qword [rbp-16], rax                 ; y = quotient

    mov rax, [rbp-8]                        ; add x to upper 32 bits
    shl rax, 32                             
    add rax, [rbp-16]                       ; add y to lower 32 bits 
    add rsp, 16                             ; restore stack pointer
    pop rbp                                 ; restore stack frame
    ret

; bool get_cell_value(int x, int y)
get_cell_value:
    call coordinates_to_index               ; get cell index
    cmp rax, -1                             ; return 0 if outside grid
    je .end
    add rax, [cell_map_backbuffer]          ; add map base pointer to index
    cmp byte [rax], 1
    jb .end                                 ; end if cell is 0
    mov rax, 1                              ; return 1 if cell is on
    ret
    .end:
    mov rax, 0                              ; return 0 if cell is off
    ret
