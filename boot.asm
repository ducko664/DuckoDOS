[BITS 16]
[ORG 0x7C00]

; Boot sector - MUST be under 510 bytes
start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov [drive], dl
    
    ; Load 64 sectors
    mov ah, 0x02
    mov al, 64
    mov cx, 0x0002
    mov dh, 0
    mov dl, [drive]
    mov bx, 0x7E00
    int 0x13
    
    jmp 0x0000:0x7E00

drive db 0

times 510-($-$$) db 0
dw 0xAA55

; ===== STAGE 2 START =====

stage2:
    mov ax, 0x0003
    int 0x10
    
    ; Set green
    push es
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov cx, 2000
    mov ah, 0x0A
.green:
    inc di
    mov [es:di], ah
    inc di
    loop .green
    pop es
    
    mov si, logo
    call print

main_loop:
    mov si, prompt
    call print
    mov di, buffer
    
.read:
    xor ah, ah
    int 0x16
    cmp al, 0x0D
    je .process
    cmp al, 0x08
    je .back
    cmp al, 0x20
    jb .read
    
    mov cx, di
    sub cx, buffer
    cmp cx, 120
    jae .read
    
    stosb
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    jmp .read
    
.back:
    cmp di, buffer
    je .read
    dec di
    mov ax, 0x0E08
    mov bl, 0x0A
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read
    
.process:
    mov byte [di], 0
    mov si, nl
    call print
    
    cmp byte [buffer], 0
    je main_loop
    
    mov si, buffer
    mov di, cmd_help
    call strcmp
    jne .t1
    jmp .help
.t1:
    mov si, buffer
    mov di, cmd_fetch
    call strcmp
    jne .t2
    jmp .fetch
.t2:
    mov si, buffer
    mov di, cmd_cls
    call strcmp
    jne .t3
    jmp .cls
.t3:
    mov si, buffer
    mov di, cmd_echo
    call strcmp_prefix
    jne .t4
    jmp .echo
.t4:
    mov si, buffer
    mov di, cmd_snake
    call strcmp
    jne .t5
    jmp .snake
.t5:
    mov si, buffer
    mov di, cmd_quack
    call strcmp
    jne .t6
    jmp .quack
.t6:
    mov si, buffer
    mov di, cmd_duck
    call strcmp
    jne .t7
    jmp .duck
.t7:
    mov si, buffer
    mov di, cmd_beep
    call strcmp
    jne .t8
    jmp .beep
.t8:
    mov si, buffer
    mov di, cmd_time
    call strcmp
    jne .t9
    jmp .time
.t9:
    mov si, buffer
    mov di, cmd_calc
    call strcmp_prefix
    jne .t10
    jmp .calc
.t10:
    mov si, buffer
    mov di, cmd_edit
    call strcmp_prefix
    jne .t11
    jmp .edit
.t11:
    mov si, buffer
    mov di, cmd_cat
    call strcmp_prefix
    jne .t12
    jmp .cat
.t12:
    mov si, buffer
    mov di, cmd_dir
    call strcmp
    jne .t13
    jmp .dir
.t13:
    mov si, buffer
    mov di, cmd_rm
    call strcmp_prefix
    jne .t14
    jmp .rm
.t14:
    mov si, buffer
    mov di, cmd_ducksay
    call strcmp_prefix
    jne .unk
    jmp .ducksay
    
.unk:
    mov si, unknown
    call print
    jmp main_loop

.help:
    mov si, help_msg
    call print
    jmp main_loop

.fetch:
    mov si, fetch_msg
    call print
    jmp main_loop

.cls:
    mov ax, 0x0003
    int 0x10
    jmp main_loop

.echo:
    mov si, buffer
    add si, 5
    call print
    mov si, nl
    call print
    jmp main_loop

.snake:
    call snake_game
    mov ax, 0x0003
    int 0x10
    jmp main_loop

.quack:
    mov cx, 5
.ql:
    push cx
    mov si, qmsg
    call print
    call beep
    mov cx, 0x4000
.d:
    loop .d
    pop cx
    loop .ql
    jmp main_loop

.duck:
    call duck_anim
    jmp main_loop

.beep:
    call beep
    jmp main_loop

.time:
    mov ah, 0x02
    int 0x1A
    mov si, time_msg
    call print
    mov al, ch
    call print_hex
    mov al, ':'
    call print_char
    mov al, cl
    call print_hex
    mov al, ':'
    call print_char
    mov al, dh
    call print_hex
    mov si, nl
    call print
    jmp main_loop

.calc:
    call calculator
    jmp main_loop

.edit:
    call text_editor
    mov ax, 0x0003
    int 0x10
    jmp main_loop

.cat:
    call cat_file
    jmp main_loop

.dir:
    call list_files
    jmp main_loop

.rm:
    call remove_file
    jmp main_loop

.ducksay:
    call ducksay
    jmp main_loop

; SNAKE GAME
snake_game:
    mov ax, 0x0003
    int 0x10
    
    mov word [sx], 40
    mov word [sy], 12
    mov word [sdx], 1
    mov word [sdy], 0
    mov word [score], 0
    mov word [fx], 60
    mov word [fy], 15
    
    mov si, snake_title
    call print
    
.lp:
    mov ah, 0x02
    mov bh, 0
    mov dh, [sy]
    mov dl, [sx]
    int 0x10
    mov ah, 0x0E
    mov al, 'O'
    mov bl, 0x0A
    int 0x10
    
    mov ah, 0x02
    mov bh, 0
    mov dh, [fy]
    mov dl, [fx]
    int 0x10
    mov ah, 0x0E
    mov al, '*'
    mov bl, 0x0A
    int 0x10
    
    mov ah, 0x01
    int 0x16
    jz .nk
    
    xor ah, ah
    int 0x16
    
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .dn
    cmp ah, 0x4B
    je .lf
    cmp ah, 0x4D
    je .rt
    cmp al, 'q'
    je .qt
    jmp .nk
    
.up:
    cmp word [sdy], 1
    je .nk
    mov word [sdx], 0
    mov word [sdy], -1
    jmp .nk
.dn:
    cmp word [sdy], -1
    je .nk
    mov word [sdx], 0
    mov word [sdy], 1
    jmp .nk
.lf:
    cmp word [sdx], 1
    je .nk
    mov word [sdx], -1
    mov word [sdy], 0
    jmp .nk
.rt:
    cmp word [sdx], -1
    je .nk
    mov word [sdx], 1
    mov word [sdy], 0
    
.nk:
    mov ax, [sx]
    add ax, [sdx]
    mov [sx], ax
    
    mov ax, [sy]
    add ax, [sdy]
    mov [sy], ax
    
    cmp word [sx], 0
    jle .over
    cmp word [sx], 79
    jge .over
    cmp word [sy], 3
    jle .over
    cmp word [sy], 24
    jge .over
    
    mov ax, [sx]
    cmp ax, [fx]
    jne .nf
    mov ax, [sy]
    cmp ax, [fy]
    jne .nf
    
    inc word [score]
    call beep
    
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    and ax, 0x3F
    add ax, 10
    mov [fx], ax
    
    shr dx, 8
    and dx, 0x0F
    add dx, 5
    mov [fy], dx
    
.nf:
    mov cx, 0x2000
.dl:
    loop .dl
    jmp .lp
    
.over:
    mov si, game_over
    call print
    mov ax, [score]
    call print_dec
    mov si, nl
    call print
    mov si, press_key
    call print
    xor ah, ah
    int 0x16
.qt:
    ret

duck_anim:
    mov cx, 10
.al:
    push cx
    mov ax, 0x0003
    int 0x10
    mov si, df1
    call print
    
    mov cx, 10
.o1:
    push cx
    mov cx, 0xFFFF
.d1:
    nop
    nop
    nop
    nop
    loop .d1
    pop cx
    loop .o1
    
    mov ax, 0x0003
    int 0x10
    mov si, df2
    call print
    
    mov cx, 10
.o2:
    push cx
    mov cx, 0xFFFF
.d2:
    nop
    nop
    nop
    nop
    loop .d2
    pop cx
    loop .o2
    
    pop cx
    loop .al
    mov ax, 0x0003
    int 0x10
    ret

calculator:
    mov si, buffer
    add si, 5
    
    lodsb
    cmp al, ' '
    je calculator
    cmp al, '0'
    jb .err
    cmp al, '9'
    ja .err
    sub al, '0'
    mov bl, al
    
    lodsb
    cmp al, ' '
    je calculator+10
    mov dl, al
    
    lodsb
    cmp al, ' '
    je calculator+18
    cmp al, '0'
    jb .err
    cmp al, '9'
    ja .err
    sub al, '0'
    mov cl, al
    
    cmp dl, '+'
    je .add
    cmp dl, '-'
    je .sub
    cmp dl, '*'
    je .mul
    cmp dl, '/'
    je .div
    jmp .err
    
.add:
    add bl, cl
    jmp .show
.sub:
    sub bl, cl
    jmp .show
.mul:
    mov al, bl
    mul cl
    mov bl, al
    jmp .show
.div:
    test cl, cl
    jz .err
    mov al, bl
    xor ah, ah
    div cl
    mov bl, al
    
.show:
    mov si, result
    call print
    xor ah, ah
    mov al, bl
    call print_dec
    mov si, nl
    call print
    ret
    
.err:
    mov si, calc_err
    call print
    ret

text_editor:
    mov si, buffer
    add si, 5
    mov di, temp_filename
.copy_name:
    lodsb
    cmp al, 0
    je .name_done
    cmp al, ' '
    je .name_done
    stosb
    jmp .copy_name
.name_done:
    mov byte [di], 0
    
    cmp byte [temp_filename], 0
    je .no_file
    
    mov ax, 0x0003
    int 0x10
    
    mov si, editor_title
    call print
    mov si, temp_filename
    call print
    mov si, nl
    call print
    mov si, editor_help
    call print
    
    mov di, edit_buffer
    xor cx, cx
    
.edit_loop:
    xor ah, ah
    int 0x16
    
    cmp al, 0x1B
    je .save_file
    
    cmp al, 0x0D
    je .newline
    
    cmp al, 0x08
    je .backspace
    
    cmp cx, 500
    jae .edit_loop
    
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    jmp .edit_loop
    
.newline:
    mov al, 0x0D
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    mov al, 0x0A
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    jmp .edit_loop
    
.backspace:
    test cx, cx
    jz .edit_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    mov bl, 0x0A
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .edit_loop
    
.save_file:
    mov byte [di], 0
    
    mov si, file_table
    xor bx, bx
.find_slot:
    cmp bx, 32
    jae .no_space
    cmp byte [si], 0
    je .found_slot
    add si, 512
    inc bx
    jmp .find_slot
    
.found_slot:
    push si
    mov di, si
    mov si, temp_filename
.copy_fname:
    lodsb
    stosb
    test al, al
    jnz .copy_fname
    pop si
    
    add si, 32
    mov di, si
    mov si, edit_buffer
    mov cx, 500
.copy_content:
    lodsb
    stosb
    test al, al
    jz .saved
    loop .copy_content
    
.saved:
    mov si, save_msg
    call print
    mov si, press_key
    call print
    xor ah, ah
    int 0x16
    ret
    
.no_space:
    mov si, no_space_msg
    call print
    mov si, press_key
    call print
    xor ah, ah
    int 0x16
    ret
    
.no_file:
    mov si, no_filename_msg
    call print
    ret

cat_file:
    mov si, buffer
    add si, 4
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    dec si
    
    mov di, temp_filename
.copy_name2:
    lodsb
    cmp al, 0
    je .find_file
    cmp al, ' '
    je .find_file
    stosb
    jmp .copy_name2
    
.find_file:
    mov byte [di], 0
    
    mov si, file_table
    xor bx, bx
.search:
    cmp bx, 32
    jae .not_found
    
    push si
    mov di, temp_filename
.cmp_name:
    lodsb
    mov cl, [di]
    inc di
    cmp al, cl
    jne .next_file
    test al, al
    jz .found
    jmp .cmp_name
    
.next_file:
    pop si
    add si, 512
    inc bx
    jmp .search
    
.found:
    pop si
    add si, 32
    call print
    mov si, nl
    call print
    ret
    
.not_found:
    mov si, file_not_found
    call print
    ret

list_files:
    mov si, dir_header
    call print
    
    mov si, file_table
    xor bx, bx
    xor dx, dx
    
.list_loop:
    cmp bx, 32
    jae .done_list
    
    cmp byte [si], 0
    je .next
    
    inc dx
    push si
    call print
    mov si, nl
    call print
    pop si
    
.next:
    add si, 512
    inc bx
    jmp .list_loop
    
.done_list:
    test dx, dx
    jnz .has_files
    mov si, no_files_msg
    call print
.has_files:
    ret

remove_file:
    mov si, buffer
    add si, 3
.skip_sp:
    lodsb
    cmp al, ' '
    je .skip_sp
    dec si
    
    mov di, temp_filename
.cp_name:
    lodsb
    cmp al, 0
    je .find_rm
    cmp al, ' '
    je .find_rm
    stosb
    jmp .cp_name
    
.find_rm:
    mov byte [di], 0
    
    mov si, file_table
    xor bx, bx
.search_rm:
    cmp bx, 32
    jae .not_found_rm
    
    push si
    mov di, temp_filename
.cmp_rm:
    lodsb
    mov cl, [di]
    inc di
    cmp al, cl
    jne .next_rm
    test al, al
    jz .found_rm
    jmp .cmp_rm
    
.next_rm:
    pop si
    add si, 512
    inc bx
    jmp .search_rm
    
.found_rm:
    pop si
    mov di, si
    xor al, al
    mov cx, 512
    rep stosb
    mov si, deleted_msg
    call print
    ret
    
.not_found_rm:
    mov si, file_not_found
    call print
    ret

ducksay:
    mov si, buffer
    add si, 7
    
    push si
    xor cx, cx
.count:
    lodsb
    test al, al
    jz .draw_cow
    inc cx
    jmp .count
    
.draw_cow:
    pop si
    
    mov al, ' '
    call print_char
    mov al, '_'
    push cx
    add cx, 2
.top:
    call print_char
    loop .top
    pop cx
    mov si, nl
    call print
    
    mov al, '<'
    call print_char
    mov al, ' '
    call print_char
    mov si, buffer
    add si, 7
    call print
    mov al, ' '
    call print_char
    mov al, '>'
    call print_char
    mov si, nl
    call print
    
    mov al, ' '
    call print_char
    mov al, '-'
    add cx, 2
.bot:
    call print_char
    loop .bot
    mov si, nl
    call print
    
    mov si, cow_duck
    call print
    ret

strcmp:
    push si
    push di
.loop:
    lodsb
    mov bl, [di]
    inc di
    
    cmp al, 'a'
    jb .s1
    cmp al, 'z'
    ja .s1
    sub al, 0x20
.s1:
    cmp bl, 'a'
    jb .s2
    cmp bl, 'z'
    ja .s2
    sub bl, 0x20
.s2:
    cmp al, bl
    jne .ne
    test al, al
    jz .eq
    jmp .loop
.eq:
    pop di
    pop si
    xor ax, ax
    ret
.ne:
    pop di
    pop si
    mov ax, 1
    ret

strcmp_prefix:
    push si
    push di
.loop:
    mov bl, [di]
    test bl, bl
    jz .chk
    lodsb
    inc di
    
    cmp al, 'a'
    jb .s1
    cmp al, 'z'
    ja .s1
    sub al, 0x20
.s1:
    cmp bl, 'a'
    jb .s2
    cmp bl, 'z'
    ja .s2
    sub bl, 0x20
.s2:
    cmp al, bl
    jne .ne
    jmp .loop
.chk:
    lodsb
    cmp al, ' '
    je .eq
    test al, al
    jne .ne
.eq:
    pop di
    pop si
    xor ax, ax
    ret
.ne:
    pop di
    pop si
    mov ax, 1
    ret

beep:
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov cx, 0x3000
.w:
    loop .w
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret

print:
    lodsb
    test al, al
    jz .d
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    jmp print
.d:
    ret

print_char:
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    ret

print_hex:
    push ax
    shr al, 4
    call .nib
    pop ax
    and al, 0x0F
.nib:
    cmp al, 10
    jb .dig
    add al, 'A'-10
    jmp .p
.dig:
    add al, '0'
.p:
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    ret

print_dec:
    xor cx, cx
    mov bx, 10
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.pd:
    pop ax
    add al, '0'
    mov ah, 0x0E
    mov bl, 0x0A
    int 0x10
    loop .pd
    ret

logo:
    db "        ____             __         ____  ____  _____",13,10
    db "       / __ \__  _______/ /______  / __ \/ __ \/ ___/",13,10
    db "      / / / / / / / ___/ //_/ __ \/ / / / / / /\__ \ ",13,10
    db "     / /_/ / /_/ / /__/ ,< / /_/ / /_/ / /_/ /___/ / ",13,10
    db "    /_____/\__,_/\___/_/|_|\____/_____/\____//____/  ",13,10
    db 13,10
    db "       The Quackiest DOS v0.1 - 256KB",13,10
    db "                   Quackin' since 2025!",13,10
    db 13,10
    db "    Type 'help' for commands",13,10
    db 13,10,0

prompt db "DUCK> ",0
nl db 13,10,0
unknown db "Quack? Try 'help'",13,10,0

help_msg:
    db "=== Commands ===",13,10
    db "  help           - Show this",13,10
    db "  fetch          - System info",13,10
    db "  cls            - Clear screen",13,10
    db "  echo TEXT      - Echo text",13,10
    db "  snake          - Snake game",13,10
    db "  quack          - Quack!",13,10
    db "  duck           - Duck animation",13,10
    db "  beep           - Beep sound",13,10
    db "  time           - Show time",13,10
    db "  calc X+Y       - Calculator",13,10
    db "  edit FILENAME  - Text editor",13,10
    db "  cat FILENAME   - View file",13,10
    db "  dir            - List files",13,10
    db "  rm FILENAME    - Delete file",13,10
    db "  ducksay TEXT    - Duck says...",13,10,0

fetch_msg:
    db "     __               user@duckodos",13,10
    db " __(o )>    -----------------------",13,10
    db " \ <_. )    OS: DuckoDOS v0.1",13,10
    db "  `---'     Kernel: x86 Real Mode",13,10
    db "            Shell: DuckoSH",13,10
    db "            Resolution: 80x25",13,10
    db "            Memory: 640KB",13,10
    db "            Disk: 256KB",13,10
    db "            Files: 32 max, ~480 chars",13,10
    db "            Theme: Matrix Green",13,10
    db 13,10,0

qmsg db "QUACK! ",0
time_msg db "Time: ",0
result db "= ",0
calc_err db "Error! Use: calc 5+3",13,10,0

snake_title db "=== SNAKE ===",13,10,"Arrows=move Q=quit",13,10,0
game_over db "Game Over! Score: ",0
press_key db "Press any key...",13,10,0

df1:
    db "         __  ",13,10
    db "     __(o )> ",13,10
    db "     \ <_. ) ",13,10
    db "      `---'  ",13,10,0

df2:
    db "      __     ",13,10
    db "  <(o )__    ",13,10
    db "  ( ._> /    ",13,10
    db "   `---'     ",13,10,0

editor_title db "=== TEXT EDITOR: ",0
editor_help db "ESC to save and exit",13,10,13,10,0
save_msg db 13,10,"File saved!",13,10,0
no_space_msg db 13,10,"No space! (max 32 files)",13,10,0
no_filename_msg db "Usage: edit FILENAME",13,10,0
file_not_found db "File not found!",13,10,0
dir_header db "Files:",13,10,0
no_files_msg db "No files saved.",13,10,0
deleted_msg db "File deleted!",13,10,0

cow_duck:
    db "        \\",13,10
    db "         \\   __",13,10
    db "          __(o )>",13,10
    db "          \ <_. )",13,10
    db "           `---'",13,10,0

cmd_help db "help",0
cmd_fetch db "fetch",0
cmd_cls db "cls",0
cmd_echo db "echo",0
cmd_snake db "snake",0
cmd_quack db "quack",0
cmd_duck db "duck",0
cmd_beep db "beep",0
cmd_time db "time",0
cmd_calc db "calc",0
cmd_edit db "edit",0
cmd_cat db "cat",0
cmd_dir db "dir",0
cmd_rm db "rm",0
cmd_ducksay db "ducksay",0

buffer times 128 db 0
temp_filename times 32 db 0
edit_buffer times 512 db 0

file_table times 16384 db 0

sx dw 0
sy dw 0
sdx dw 0
sdy dw 0
fx dw 0
fy dw 0
score dw 0

times (262144-($-$$)) db 0
