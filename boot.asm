[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov [boot_drive], dl
    
    ; Load Stage 2
    mov ah, 0x02
    mov al, 20
    mov cx, 0x0002
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x7E00
    int 0x13
    jc disk_error
    
    ; Load file table
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 10
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, file_table
    int 0x13
    jc disk_error
    
    jmp 0x0000:0x7E00

disk_error:
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
    
    mov si, disk_err_msg
    call print
    jmp $

disk_err_msg db ":(",13,10,0
boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55

; ===== STAGE 2 =====

stage2:
    mov ax, 0x0003
    int 0x10
    
    call set_green
    
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
    
    ; Check commands
    mov si, buffer
    mov di, cmd_help
    call strcmp
    jne .t1
    mov si, help_msg
    call print
    jmp main_loop
    
.t1:
    mov si, buffer
    mov di, cmd_cls
    call strcmp
    jne .t2
    mov ax, 0x0003
    int 0x10
    call set_green
    jmp main_loop
    
.t2:
    mov si, buffer
    mov di, cmd_fetch
    call strcmp
    jne .t3
    mov si, fetch_msg
    call print
    jmp main_loop
    
.t3:
    mov si, buffer
    mov di, cmd_beep
    call strcmp
    jne .t4
    call beep
    jmp main_loop
    
.t4:
    mov si, buffer
    mov di, cmd_echo
    call strcmp_prefix
    jne .t5
    mov si, buffer
    add si, 5
    call print
    mov si, nl
    call print
    jmp main_loop
    
.t5:
    mov si, buffer
    mov di, cmd_calc
    call strcmp_prefix
    jne .t6
    call calculator
    jmp main_loop
    
.t6:
    mov si, buffer
    mov di, cmd_edit
    call strcmp_prefix
    jne .t7
    call text_editor
    mov ax, 0x0003
    int 0x10
    call set_green
    jmp main_loop
    
.t7:
    mov si, buffer
    mov di, cmd_cat
    call strcmp_prefix
    jne .t8
    call cat_file
    jmp main_loop
    
.t8:
    mov si, buffer
    mov di, cmd_dir
    call strcmp
    jne .t9
    call list_files
    jmp main_loop
    
.t9:
    mov si, buffer
    mov di, cmd_rm
    call strcmp_prefix
    jne .t10
    call remove_file
    jmp main_loop
    
.t10:
    mov si, buffer
    mov di, cmd_gui
    call strcmp
    jne .t11
    call gui_mode
    mov ax, 0x0003
    int 0x10
    call set_green
    jmp main_loop
    
.t11:
    mov si, buffer
    mov di, cmd_panic
    call strcmp
    jne .t12
    ; Show :( and freeze forever
    mov ax, 0x0003
    int 0x10
    call set_green
    mov si, panic_msg
    call print
    cli
    hlt
    
.t12:
    mov si, buffer
    mov di, cmd_reboot
    call strcmp
    jne .t13
    ; Triple fault reboot (classic method)
    mov si, reboot_msg
    call print
    mov cx, 0x8000
.delay:
    loop .delay
    ; Load invalid IDT and cause interrupt = reboot
    lidt [invalid_idt]
    int 3
    
.t13:
    mov si, unknown
    call print
    jmp main_loop

set_green:
    push es
    push ax
    push cx
    push di
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov cx, 2000
    mov ah, 0x0A
.loop:
    inc di
    mov [es:di], ah
    inc di
    loop .loop
    pop di
    pop cx
    pop ax
    pop es
    ret

; ===== SIMPLE GUI =====
gui_mode:
    mov ax, 0x0013
    int 0x10
    
    mov word [cursor_x], 160
    mov word [cursor_y], 100
    
    call gui_redraw
    
.loop:
    xor ah, ah
    int 0x16
    
    cmp al, 'q'
    je .exit
    cmp al, 27
    je .exit
    
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right
    
    jmp .loop
    
.up:
    cmp word [cursor_y], 5
    jle .loop
    sub word [cursor_y], 5
    call gui_redraw
    jmp .loop
    
.down:
    cmp word [cursor_y], 195
    jge .loop
    add word [cursor_y], 5
    call gui_redraw
    jmp .loop
    
.left:
    cmp word [cursor_x], 5
    jle .loop
    sub word [cursor_x], 5
    call gui_redraw
    jmp .loop
    
.right:
    cmp word [cursor_x], 315
    jge .loop
    add word [cursor_x], 5
    call gui_redraw
    jmp .loop
    
.exit:
    ret

gui_redraw:
    push es
    push ax
    push bx
    push cx
    push di
    
    ; Gray background
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov al, 0x08
    mov cx, 64000
    rep stosb
    
    ; Files window
    mov bx, 10
    mov dx, 10
    mov si, 120
    mov di, 80
    mov al, 0x07
    call draw_box
    
    ; Files title bar
    mov bx, 10
    mov dx, 10
    mov si, 120
    mov di, 10
    mov al, 0x01
    call draw_box
    
    ; Calc window
    mov bx, 150
    mov dx, 50
    mov si, 100
    mov di, 90
    mov al, 0x07
    call draw_box
    
    ; Calc title bar
    mov bx, 150
    mov dx, 50
    mov si, 100
    mov di, 10
    mov al, 0x01
    call draw_box
    
    ; Taskbar
    mov bx, 0
    mov dx, 190
    mov si, 320
    mov di, 10
    mov al, 0x08
    call draw_box
    
    ; DUCK button
    mov bx, 2
    mov dx, 192
    mov si, 30
    mov di, 7
    mov al, 0x07
    call draw_box
    
    ; Cursor
    mov bx, [cursor_x]
    mov dx, [cursor_y]
    mov si, 5
    mov di, 5
    mov al, 0x0F
    call draw_box
    
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_box:
    ; BX=x, DX=y, SI=width, DI=height, AL=color
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov cx, 0xA000
    mov es, cx
    
    mov cx, di  ; height
.row:
    push cx
    push bx
    
    ; Calculate position
    mov ax, dx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov bx, ax
    
    ; Draw row
    mov cx, si
    mov al, [esp+18]
.pixel:
    mov [es:bx], al
    inc bx
    loop .pixel
    
    pop bx
    inc dx
    pop cx
    loop .row
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
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
    push ax
    push cx
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
    pop cx
    pop ax
    ret

calculator:
    mov si, buffer
    add si, 5
    
    ; Skip spaces
.skip1:
    lodsb
    cmp al, ' '
    je .skip1
    cmp al, 0
    je .err
    
    ; Parse first number
    xor bx, bx
.num1:
    cmp al, '0'
    jb .got_num1
    cmp al, '9'
    ja .got_num1
    sub al, '0'
    mov cl, al
    mov ax, bx
    mov dx, 10
    mul dx
    add ax, cx
    mov bx, ax
    lodsb
    jmp .num1
    
.got_num1:
    push bx
    
    ; Skip spaces to operator
.skip2:
    cmp al, ' '
    jne .got_op
    lodsb
    jmp .skip2
    
.got_op:
    mov byte [operator], al
    
    ; Skip spaces
.skip3:
    lodsb
    cmp al, ' '
    je .skip3
    cmp al, 0
    je .err2
    
    ; Parse second number
    xor bx, bx
.num2:
    cmp al, '0'
    jb .got_num2
    cmp al, '9'
    ja .got_num2
    sub al, '0'
    mov cl, al
    mov ax, bx
    mov dx, 10
    mul dx
    add ax, cx
    mov bx, ax
    lodsb
    jmp .num2
    
.got_num2:
    pop ax
    mov cx, bx
    
    mov dl, [operator]
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
    add ax, cx
    jmp .show
.sub:
    sub ax, cx
    jmp .show
.mul:
    mul cx
    jmp .show
.div:
    test cx, cx
    jz .div_zero
    xor dx, dx
    div cx
    
.show:
    mov si, result_msg
    call print
    call print_dec
    mov si, nl
    call print
    ret
    
.div_zero:
    mov si, div_zero_msg
    call print
    ret
    
.err2:
    pop ax
.err:
    mov si, calc_err
    call print
    ret

print_dec:
    push ax
    push bx
    push cx
    push dx
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
    pop dx
    pop cx
    pop bx
    pop ax
    ret

text_editor:
    mov si, buffer
    add si, 5
.skip_sp:
    lodsb
    cmp al, ' '
    je .skip_sp
    dec si
    
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
    
    cmp cx, 480
    jae .edit_loop
    
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .edit_loop
    
.newline:
    mov al, 0x0D
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    mov al, 0x0A
    stosb
    inc cx
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .edit_loop
    
.backspace:
    test cx, cx
    jz .edit_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    mov bl, 0x07
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .edit_loop
    
.save_file:
    mov byte [di], 0
    
    ; Find empty slot
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
    ; Copy filename
    push si
    mov di, si
    mov si, temp_filename
.copy_fname:
    lodsb
    stosb
    test al, al
    jnz .copy_fname
    pop si
    
    ; Copy content
    add si, 32
    mov di, si
    mov si, edit_buffer
    mov cx, 480
.copy_content:
    lodsb
    stosb
    test al, al
    jz .do_save
    loop .copy_content
    
.do_save:
    ; Write to disk
    mov ah, 0x03
    mov al, 32
    mov ch, 0
    mov cl, 10
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, file_table
    int 0x13
    jc .save_error
    
    mov si, save_msg
    call print
    mov si, press_key
    call print
    xor ah, ah
    int 0x16
    ret
    
.save_error:
    mov si, save_error_msg
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
    
    ; Save to disk
    mov ah, 0x03
    mov al, 32
    mov ch, 0
    mov cl, 10
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, file_table
    int 0x13
    
    mov si, deleted_msg
    call print
    ret
    
.not_found_rm:
    mov si, file_not_found
    call print
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

logo:
    db "        ____             __         ____  ____  _____",13,10
    db "       / __ \__  _______/ /______  / __ \/ __ \/ ___/",13,10
    db "      / / / / / / / ___/ //_/ __ \/ / / / / / /\__ \ ",13,10
    db "     / /_/ / /_/ / /__/ ,< / /_/ / /_/ / /_/ /___/ / ",13,10
    db "    /_____/\__,_/\___/_/|_|\____/_____/\____//____/  ",13,10
    db 13,10
    db "       The Quackiest DOS v0.4 - PERSISTENT STORAGE!",13,10
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
    db "  beep           - Beep sound",13,10
    db "  calc X+Y       - Calculator (+ - * /)",13,10
    db "  edit FILENAME  - Text editor (ESC=save)",13,10
    db "  cat FILENAME   - View file",13,10
    db "  dir            - List files",13,10
    db "  rm FILENAME    - Delete file",13,10
    db "  panic          - Kernel panic :(",13,10
    db "  reboot         - Reboot system",13,10
    db "  gui            - Launch GUI (WASD/Arrows, Q=exit)",13,10,0

fetch_msg:
    db "     __               user@duckodos",13,10
    db " __(o )>    -----------------------",13,10
    db " \ <_. )    OS: DuckoDOS v0.4",13,10
    db "  `---'     Kernel: Bootloader only Lol",13,10
    db "            Shell: Bootloader",13,10
    db "            Resolution: 320 x 320",13,10
    db "            Memory: i dont know go check",13,10
    db "            Disk: Persistent!",13,10
    db "            Files: 32 max, ~480 chars",13,10
    db "            Storage: Sectors 10-41",13,10
    db "            Theme: Hackerboi69 green",13,10
    db 13,10,0

result_msg db "= ",0
calc_err db ":( Usage: calc 5+3",13,10,0
div_zero_msg db ":( Division by zero",13,10,0
operator db 0

editor_title db "=== TEXT EDITOR: ",0
editor_help db "ESC to save and exit",13,10,13,10,0
save_msg db 13,10,"File saved!",13,10,0
save_error_msg db 13,10,":(",13,10,0
no_space_msg db 13,10,":( Max 32 files",13,10,0
no_filename_msg db ":( Usage: edit FILENAME",13,10,0
file_not_found db ":( File not found",13,10,0
dir_header db "Files:",13,10,0
no_files_msg db "No files saved.",13,10,0
deleted_msg db "File deleted!",13,10,0
press_key db "Press any key...",13,10,0
panic_msg db ":(",13,10,0
reboot_msg db "Rebooting...",13,10,0

cmd_help db "help",0
cmd_fetch db "fetch",0
cmd_cls db "cls",0
cmd_echo db "echo",0
cmd_beep db "beep",0
cmd_calc db "calc",0
cmd_edit db "edit",0
cmd_cat db "cat",0
cmd_dir db "dir",0
cmd_rm db "rm",0
cmd_panic db "panic",0
cmd_reboot db "reboot",0
cmd_gui db "gui",0

invalid_idt:
    dw 0
    dd 0

buffer times 128 db 0
temp_filename times 32 db 0
edit_buffer times 512 db 0
cursor_x dw 160
cursor_y dw 100

file_table times 16384 db 0

times (65536-($-$$)) db 0
