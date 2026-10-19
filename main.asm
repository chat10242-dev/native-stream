; NativeStream ASM
; Minimal terminal UI with Host and Client mode.
; x86_64 Linux, direct syscalls only.

global _start

section .rodata
    banner            db "NativeStream ASM", 10, 0
    banner_len        equ $ - banner - 1

    ui_clear_screen   db 27, "[2J", 27, "[H", 0
    ui_clear_len      equ $ - ui_clear_screen - 1

    ui_main_title     db "NativeStream ASM", 10, 0
    ui_main_title_len equ $ - ui_main_title - 1

    ui_box_top        db "+----------------------------------------+", 10, 0
    ui_box_top_len    equ $ - ui_box_top - 1

    ui_box_row        db "|                                        |", 10, 0
    ui_box_row_len    equ $ - ui_box_row - 1

    ui_menu_label     db "|  [1] Host       [2] Client            |", 10, 0
    ui_menu_label_len equ $ - ui_menu_label - 1

    ui_menu_label2    db "|  [3] Profile    [4] Remote           |", 10, 0
    ui_menu_label2_len equ $ - ui_menu_label2 - 1

    ui_menu_label3    db "|  [5] Exit                             |", 10, 0
    ui_menu_label3_len equ $ - ui_menu_label3 - 1

    ui_main_panel     db "+----------------------------------------+", 10
                      db "|  [1] Host       [2] Client            |", 10
                      db "|  [3] Profile    [4] Remote           |", 10
                      db "|  [5] Exit                             |", 10
                      db "+----------------------------------------+", 10, 0
    ui_main_panel_len equ $ - ui_main_panel - 1

    ui_prompt         db "> ", 0
    ui_prompt_len     equ $ - ui_prompt

    menu_title        db "Select mode:", 10
                      db "1) Host", 10
                      db "2) Client", 10
                      db "3) Profile Studio", 10
                      db "4) Remote Setup", 10
                      db "5) Exit", 10
                      db "> ", 0
    menu_len          equ $ - menu_title

    usage_msg         db "Usage: ./main [--host|--client]", 10, 0
    usage_len         equ $ - usage_msg - 1

    host_mode_title   db "HOST MODE", 10, 0
    host_mode_len     equ $ - host_mode_title - 1

    client_mode_title db "CLIENT MODE", 10, 0
    client_mode_len   equ $ - client_mode_title - 1

    profile_mode_title db "PROFILE STUDIO", 10, 0
    profile_mode_len  equ $ - profile_mode_title - 1

    profile_menu_title db "Controller profile menu:", 10
                     db "1) View profiles", 10
                     db "2) Create profile", 10
                     db "3) Back", 10
                     db "> ", 0
    profile_menu_len equ $ - profile_menu_title

    profile_name_prompt db "Profile name: ", 0
    profile_name_len equ $ - profile_name_prompt

    profile_aim_prompt db "Aim bind: ", 0
    profile_aim_len equ $ - profile_aim_prompt

    profile_jump_prompt db "Jump bind: ", 0
    profile_jump_len equ $ - profile_jump_prompt

    profile_move_prompt db "Move bind: ", 0
    profile_move_len equ $ - profile_move_prompt

    profile_saved_msg db "Profile saved.", 10, 0
    profile_saved_len equ $ - profile_saved_msg - 1

    no_profiles_msg db "No profiles configured.", 10, 0
    no_profiles_len equ $ - no_profiles_msg - 1

    profile_list_title db "Stored profiles:", 10, 0
    profile_list_len equ $ - profile_list_title - 1

    remote_mode_title db "REMOTE SETUP", 10, 0
    remote_mode_len equ $ - remote_mode_title - 1

    remote_menu_title db "Connection strategy:", 10
                     db "1) Local LAN", 10
                     db "2) Direct Internet", 10
                     db "3) Relay mode", 10
                     db "4) Back", 10
                     db "> ", 0
    remote_menu_len equ $ - remote_menu_title

    remote_saved_msg db "Remote mode saved.", 10, 0
    remote_saved_len equ $ - remote_saved_msg - 1

    remote_local_msg db "Mode: Local LAN", 10, 0
    remote_local_len equ $ - remote_local_msg - 1

    remote_direct_msg db "Mode: Direct Internet", 10, 0
    remote_direct_len equ $ - remote_direct_msg - 1

    remote_relay_msg db "Mode: Relay", 10, 0
    remote_relay_len equ $ - remote_relay_msg - 1

    prompt_1          db "Enter executable path 1: ", 0
    prompt_1_len      equ $ - prompt_1

    prompt_2          db "Enter executable path 2: ", 0
    prompt_2_len      equ $ - prompt_2

    prompt_3          db "Enter executable path 3: ", 0
    prompt_3_len      equ $ - prompt_3

    saved_msg         db "Host configuration saved.", 10, 0
    saved_len         equ $ - saved_msg - 1

    no_cfg_msg        db "No executable configured. Use Host mode first.", 10, 0
    no_cfg_len        equ $ - no_cfg_msg - 1

    client_list_msg   db "Configured executables:", 10, 0
    client_list_len   equ $ - client_list_msg - 1

    select_prompt     db "Choose executable (1-3): ", 0
    select_len        equ $ - select_prompt

    selected_msg      db "Selected: ", 0
    selected_len      equ $ - selected_msg

    invalid_msg       db "Invalid choice.", 10, 0
    invalid_len       equ $ - invalid_msg - 1

    config_path       db "native_stream_config.txt", 0
    profiles_path     db "native_stream_profiles.txt", 0
    remote_config_path db "native_stream_remote.txt", 0
    host_arg          db "--host", 0
    client_arg        db "--client", 0
    profile_arg       db "--profile", 0
    remote_arg        db "--remote", 0
    newline_char      db 10

    one_label         db "1) ", 0
    two_label         db "2) ", 0
    three_label       db "3) ", 0

section .bss
    input_buf      resb 256
    cfg_1          resb 256
    cfg_2          resb 256
    cfg_3          resb 256
    profile_name_buf resb 128
    profile_aim_buf resb 128
    profile_jump_buf resb 128
    profile_move_buf resb 128
    profile_1       resb 256
    profile_2       resb 256
    profile_3       resb 256
    remote_mode_buf resb 64
    file_buffer    resb 2048

section .text
print_str:
    mov rax, 1
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, 1
    syscall
    ret

draw_main_ui:
    lea rdi, [rel ui_clear_screen]
    mov rsi, ui_clear_len
    call print_str

    lea rdi, [rel ui_main_title]
    mov rsi, ui_main_title_len
    call print_str

    lea rdi, [rel ui_main_panel]
    mov rsi, ui_main_panel_len
    call print_str

    lea rdi, [rel ui_prompt]
    mov rsi, ui_prompt_len
    call print_str
    ret

read_line:
    ; rdi = buffer, rsi = maxlen
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rcx, r13
    mov rdi, r12
    xor al, al
    cld
    rep stosb

    mov rax, 0
    xor rdi, rdi
    mov rsi, r12
    mov rdx, r13
    syscall
    test rax, rax
    jle .done
    mov rcx, rax
    mov r8, r12
    add r8, rcx
    dec r8
    cmp byte [r8], 10
    je .strip
    cmp byte [r8], 13
    je .strip
    mov byte [r12 + rax], 0
    pop r13
    pop r12
    ret
.strip:
    mov byte [r8], 0
.done:
    mov byte [r12], 0
    pop r13
    pop r12
    ret

strcmp_arg:
    mov al, byte [rdi]
    mov dl, byte [rsi]
    cmp al, dl
    jne .no
    cmp al, 0
    je .yes
    inc rdi
    inc rsi
    jmp strcmp_arg
.no:
    xor rax, rax
    ret
.yes:
    mov rax, 1
    ret

copy_string:
    ; rdi = dst, rsi = src
.loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    cmp al, 0
    je .done
    inc rdi
    inc rsi
    jmp .loop
.done:
    ret

strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret

write_config:
    push r12
    push rbx
    mov rax, 2
    lea rdi, [rel config_path]
    mov rsi, 577
    mov rdx, 420
    syscall
    mov r12, rax
    cmp r12, 0
    jl .done

    mov rbx, 0
.write_loop:
    cmp rbx, 3
    je .close

    cmp rbx, 0
    je .slot1
    cmp rbx, 1
    je .slot2
    lea rsi, [cfg_3]
    jmp .check_slot
.slot1:
    lea rsi, [cfg_1]
    jmp .check_slot
.slot2:
    lea rsi, [cfg_2]
.check_slot:
    cmp byte [rsi], 0
    je .next

    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, r12
    mov rsi, rsi
    syscall

    lea rsi, [rel newline_char]
    mov rdx, 1
    mov rax, 1
    mov rdi, r12
    syscall

.next:
    inc rbx
    jmp .write_loop
.close:
    mov rax, 3
    mov rdi, r12
    syscall
.done:
    ret

read_config_file:
    push r12
    push r13
    mov rax, 2
    lea rdi, [rel config_path]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .not_found
    mov r12, rax

    mov rax, 0
    mov rdi, r12
    lea rsi, [file_buffer]
    mov rdx, 2047
    syscall
    mov r13, rax
    mov rax, 3
    mov rdi, r12
    syscall

    test r13, r13
    jle .not_found
    pop r13
    pop r12
    mov rax, 1
    ret
.not_found:
    pop r13
    pop r12
    xor rax, rax
    ret

copy_line_from_buffer:
    ; r13 = source ptr, r14 = dest ptr
    xor rcx, rcx
.loop:
    cmp byte [r13 + rcx], 0
    je .done
    cmp byte [r13 + rcx], 10
    je .done
    mov al, byte [r13 + rcx]
    mov byte [r14 + rcx], al
    inc rcx
    jmp .loop
.done:
    mov byte [r14 + rcx], 0
    cmp byte [r13 + rcx], 10
    jne .finish
    inc rcx
.finish:
    lea r13, [r13 + rcx]
    ret

clear_slots:
    mov rcx, 256
    lea rdi, [cfg_1]
    xor al, al
    rep stosb
    mov rcx, 256
    lea rdi, [cfg_2]
    rep stosb
    mov rcx, 256
    lea rdi, [cfg_3]
    rep stosb
    ret

print_line:
    ; rdi = ptr to string
    mov rsi, rdi
    xor rcx, rcx
.len_loop:
    cmp byte [rsi + rcx], 0
    je .len_done
    inc rcx
    jmp .len_loop
.len_done:
    mov rdx, rcx
    mov rax, 1
    mov rdi, 1
    syscall
    lea rsi, [rel newline_char]
    mov rdx, 1
    mov rax, 1
    mov rdi, 1
    syscall
    ret

save_profiles:
    ; Save the in-memory profile slots to native_stream_profiles.txt
    push r12
    push rbx
    mov rax, 2
    lea rdi, [rel profiles_path]
    mov rsi, 577
    mov rdx, 420
    syscall
    mov r12, rax
    cmp r12, 0
    jl .done

    mov rbx, 0
.profile_loop:
    cmp rbx, 3
    je .close
    cmp rbx, 0
    je .slot1
    cmp rbx, 1
    je .slot2
    lea rsi, [profile_3]
    jmp .output
.slot1:
    lea rsi, [profile_1]
    jmp .output
.slot2:
    lea rsi, [profile_2]
.output:
    cmp byte [rsi], 0
    je .next
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, r12
    syscall
    lea rsi, [rel newline_char]
    mov rdx, 1
    mov rax, 1
    mov rdi, r12
    syscall
.next:
    inc rbx
    jmp .profile_loop
.close:
    mov rax, 3
    mov rdi, r12
    syscall
.done:
    ret

read_profiles:
    ; Load the first three profile rows from native_stream_profiles.txt
    push r12
    push r13
    push r14
    mov rax, 2
    lea rdi, [rel profiles_path]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .not_found
    mov r12, rax

    mov rax, 0
    mov rdi, r12
    lea rsi, [file_buffer]
    mov rdx, 2047
    syscall
    mov r13, rax
    mov rax, 3
    mov rdi, r12
    syscall

    test r13, r13
    jle .not_found

    mov r13, file_buffer
    mov r14, profile_1
    call copy_line_from_buffer
    cmp byte [r13], 0
    je .done
    mov r14, profile_2
    call copy_line_from_buffer
    cmp byte [r13], 0
    je .done
    mov r14, profile_3
    call copy_line_from_buffer
.done:
    pop r14
    pop r13
    pop r12
    mov rax, 1
    ret
.not_found:
    pop r14
    pop r13
    pop r12
    xor rax, rax
    ret

clear_profiles:
    mov rcx, 256
    lea rdi, [profile_1]
    xor al, al
    rep stosb
    mov rcx, 256
    lea rdi, [profile_2]
    rep stosb
    mov rcx, 256
    lea rdi, [profile_3]
    rep stosb
    ret

append_profile_field:
    ; rdi = target buffer, rsi = source string, dl = separator char
    mov r8, rdi
    call strlen
    mov r9, rax
    add r8, r9
    mov byte [r8], dl
    inc r8
    mov r9, rsi
.loop:
    mov al, byte [r9]
    mov byte [r8], al
    cmp al, 0
    je .done
    inc r8
    inc r9
    jmp .loop
.done:
    ret

store_profile_slot:
    ; rdi = target slot, rsi = name, rdx = aim, rcx = jump, r8 = move
    mov r9, rdi
    call copy_string
    mov rdi, r9
    call strlen
    mov r10, rax
    add r9, r10
    mov byte [r9], '|'
    inc r9
    mov rdi, r9
    mov rsi, rdx
    call copy_string
    mov rdi, r9
    call strlen
    mov r10, rax
    add r9, r10
    mov byte [r9], '|'
    inc r9
    mov rdi, r9
    mov rsi, rcx
    call copy_string
    mov rdi, r9
    call strlen
    mov r10, rax
    add r9, r10
    mov byte [r9], '|'
    inc r9
    mov rdi, r9
    mov rsi, r8
    call copy_string
    ret

profile_mode:
    lea rdi, [rel banner]
    mov rsi, banner_len
    call print_str

    lea rdi, [rel profile_mode_title]
    mov rsi, profile_mode_len
    call print_str

.profile_loop:
    lea rdi, [rel profile_menu_title]
    mov rsi, profile_menu_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 31
    call read_line

    cmp byte [input_buf], '1'
    je .view_profiles
    cmp byte [input_buf], '2'
    je .create_profile
    cmp byte [input_buf], '3'
    je .exit_profile
    jmp .profile_loop

.view_profiles:
    call read_profiles
    lea rdi, [rel profile_list_title]
    mov rsi, profile_list_len
    call print_str
    lea rdi, [profile_1]
    cmp byte [rdi], 0
    je .no_profiles
    call print_line
    lea rdi, [profile_2]
    cmp byte [rdi], 0
    je .profile_loop
    call print_line
    lea rdi, [profile_3]
    cmp byte [rdi], 0
    je .profile_loop
    call print_line
    jmp .profile_loop
.no_profiles:
    lea rdi, [rel no_profiles_msg]
    mov rsi, no_profiles_len
    call print_str
    jmp .profile_loop

.create_profile:
    lea rdi, [rel profile_name_prompt]
    mov rsi, profile_name_len
    call print_str
    lea rdi, [profile_name_buf]
    mov rsi, 127
    call read_line
    cmp byte [profile_name_buf], 0
    je .profile_loop

    lea rdi, [rel profile_aim_prompt]
    mov rsi, profile_aim_len
    call print_str
    lea rdi, [profile_aim_buf]
    mov rsi, 127
    call read_line

    lea rdi, [rel profile_jump_prompt]
    mov rsi, profile_jump_len
    call print_str
    lea rdi, [profile_jump_buf]
    mov rsi, 127
    call read_line

    lea rdi, [rel profile_move_prompt]
    mov rsi, profile_move_len
    call print_str
    lea rdi, [profile_move_buf]
    mov rsi, 127
    call read_line

    lea rdi, [profile_1]
    cmp byte [rdi], 0
    jne .slot2
    mov rdi, profile_1
    lea rsi, [profile_name_buf]
    lea rdx, [profile_aim_buf]
    lea rcx, [profile_jump_buf]
    lea r8, [profile_move_buf]
    call store_profile_slot
    jmp .saved
.slot2:
    lea rdi, [profile_2]
    cmp byte [rdi], 0
    jne .slot3
    mov rdi, profile_2
    lea rsi, [profile_name_buf]
    lea rdx, [profile_aim_buf]
    lea rcx, [profile_jump_buf]
    lea r8, [profile_move_buf]
    call store_profile_slot
    jmp .saved
.slot3:
    lea rdi, [profile_3]
    cmp byte [rdi], 0
    jne .overwrite_first
    mov rdi, profile_3
    lea rsi, [profile_name_buf]
    lea rdx, [profile_aim_buf]
    lea rcx, [profile_jump_buf]
    lea r8, [profile_move_buf]
    call store_profile_slot
    jmp .saved
.overwrite_first:
    mov rdi, profile_1
    lea rsi, [profile_name_buf]
    lea rdx, [profile_aim_buf]
    lea rcx, [profile_jump_buf]
    lea r8, [profile_move_buf]
    call store_profile_slot
.saved:
    call save_profiles
    lea rdi, [rel profile_saved_msg]
    mov rsi, profile_saved_len
    call print_str
    jmp .profile_loop

.exit_profile:
    ret

write_remote_config:
    mov rax, 2
    lea rdi, [rel remote_config_path]
    mov rsi, 577
    mov rdx, 420
    syscall
    mov r12, rax
    cmp r12, 0
    jl .done

    mov rdi, r12
    lea rsi, [remote_mode_buf]
    mov rdx, 63
    mov rax, 1
    syscall

    lea rsi, [rel newline_char]
    mov rdx, 1
    mov rax, 1
    mov rdi, r12
    syscall

    mov rax, 3
    mov rdi, r12
    syscall
.done:
    ret

read_remote_config:
    mov rax, 2
    lea rdi, [rel remote_config_path]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .not_found
    mov r12, rax

    mov rax, 0
    mov rdi, r12
    lea rsi, [file_buffer]
    mov rdx, 2047
    syscall
    mov r13, rax
    mov rax, 3
    mov rdi, r12
    syscall

    test r13, r13
    jle .not_found

    mov r13, file_buffer
    mov r14, remote_mode_buf
    call copy_line_from_buffer
    mov rax, 1
    ret
.not_found:
    xor rax, rax
    ret

remote_mode:
    lea rdi, [rel banner]
    mov rsi, banner_len
    call print_str

    lea rdi, [rel remote_mode_title]
    mov rsi, remote_mode_len
    call print_str

.remote_loop:
    lea rdi, [rel remote_menu_title]
    mov rsi, remote_menu_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 31
    call read_line

    cmp byte [input_buf], '1'
    je .local
    cmp byte [input_buf], '2'
    je .direct
    cmp byte [input_buf], '3'
    je .relay
    cmp byte [input_buf], '4'
    je .exit_remote
    jmp .remote_loop

.local:
    lea rdi, [remote_mode_buf]
    lea rsi, [rel remote_local_msg]
    call copy_string
    lea rdi, [rel remote_local_msg]
    mov rsi, remote_local_len
    call print_str
    call write_remote_config
    jmp .remote_loop

.direct:
    lea rdi, [remote_mode_buf]
    lea rsi, [rel remote_direct_msg]
    call copy_string
    lea rdi, [rel remote_direct_msg]
    mov rsi, remote_direct_len
    call print_str
    call write_remote_config
    jmp .remote_loop

.relay:
    lea rdi, [remote_mode_buf]
    lea rsi, [rel remote_relay_msg]
    call copy_string
    lea rdi, [rel remote_relay_msg]
    mov rsi, remote_relay_len
    call print_str
    call write_remote_config
    jmp .remote_loop

.exit_remote:
    ret

host_mode:
    lea rdi, [rel banner]
    mov rsi, banner_len
    call print_str

    lea rdi, [rel host_mode_title]
    mov rsi, host_mode_len
    call print_str

    call clear_slots

    mov rbx, 1
.host_loop:
    cmp rbx, 1
    je .prompt1
    cmp rbx, 2
    je .prompt2
    cmp rbx, 3
    je .prompt3
    jmp .save
.prompt1:
    lea rdi, [rel prompt_1]
    mov rsi, prompt_1_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 255
    call read_line
    cmp byte [input_buf], 0
    je .save
    lea rdi, [cfg_1]
    lea rsi, [input_buf]
    call copy_string
    inc rbx
    jmp .host_loop
.prompt2:
    lea rdi, [rel prompt_2]
    mov rsi, prompt_2_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 255
    call read_line
    cmp byte [input_buf], 0
    je .save
    lea rdi, [cfg_2]
    lea rsi, [input_buf]
    call copy_string
    inc rbx
    jmp .host_loop
.prompt3:
    lea rdi, [rel prompt_3]
    mov rsi, prompt_3_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 255
    call read_line
    cmp byte [input_buf], 0
    je .save
    lea rdi, [cfg_3]
    lea rsi, [input_buf]
    call copy_string
    inc rbx
    jmp .save
.save:
    call write_config
    lea rdi, [rel saved_msg]
    mov rsi, saved_len
    call print_str
    ret

client_mode:
    lea rdi, [rel banner]
    mov rsi, banner_len
    call print_str

    lea rdi, [rel client_mode_title]
    mov rsi, client_mode_len
    call print_str

    call read_config_file
    test rax, rax
    jz .no_config

    ; parse config file into slots with stable pointer updates
    mov r13, file_buffer
    mov r14, cfg_1
    call copy_line_from_buffer
    cmp byte [r13], 0
    je .print_entries

    mov r14, cfg_2
    call copy_line_from_buffer
    cmp byte [r13], 0
    je .print_entries

    mov r14, cfg_3
    call copy_line_from_buffer

.print_entries:
    lea rdi, [rel client_list_msg]
    mov rsi, client_list_len
    call print_str

    mov rbx, 1
.print_loop:
    cmp rbx, 1
    je .show1
    cmp rbx, 2
    je .show2
    cmp rbx, 3
    je .show3
    jmp .prompt_choice
.show1:
    lea rdi, [rel one_label]
    mov rsi, 4
    call print_str
    lea rdi, [cfg_1]
    cmp byte [rdi], 0
    je .next_item
    call print_line
    jmp .next_item
.show2:
    lea rdi, [rel two_label]
    mov rsi, 4
    call print_str
    lea rdi, [cfg_2]
    cmp byte [rdi], 0
    je .next_item
    call print_line
    jmp .next_item
.show3:
    lea rdi, [rel three_label]
    mov rsi, 4
    call print_str
    lea rdi, [cfg_3]
    cmp byte [rdi], 0
    je .next_item
    call print_line
.next_item:
    inc rbx
    cmp rbx, 4
    jne .print_loop

.prompt_choice:
    lea rdi, [rel select_prompt]
    mov rsi, select_len
    call print_str
    lea rdi, [input_buf]
    mov rsi, 31
    call read_line

    cmp byte [input_buf], '1'
    je .sel1
    cmp byte [input_buf], '2'
    je .sel2
    cmp byte [input_buf], '3'
    je .sel3
    jmp .invalid
.sel1:
    mov r13, cfg_1
    jmp .confirm
.sel2:
    mov r13, cfg_2
    jmp .confirm
.sel3:
    mov r13, cfg_3
.confirm:
    cmp byte [r13], 0
    je .invalid
    lea rdi, [rel selected_msg]
    mov rsi, selected_len
    call print_str
    mov rdi, r13
    call print_line
    mov rax, 60
    xor rdi, rdi
    syscall
.invalid:
    lea rdi, [rel invalid_msg]
    mov rsi, invalid_len
    call print_str
    mov rax, 60
    mov rdi, 1
    syscall
.no_config:
    lea rdi, [rel no_cfg_msg]
    mov rsi, no_cfg_len
    call print_str
    mov rax, 60
    mov rdi, 1
    syscall

_start:
    pop rcx
    cmp rcx, 1
    je .interactive
    cmp rcx, 2
    jl .usage

    mov r12, rsp
    mov rdi, qword [r12 + 8]
    lea rsi, [rel host_arg]
    call strcmp_arg
    test rax, rax
    jnz .host_mode

    mov rdi, qword [r12 + 8]
    lea rsi, [rel client_arg]
    call strcmp_arg
    test rax, rax
    jnz .client_mode

    mov rdi, qword [r12 + 8]
    lea rsi, [rel profile_arg]
    call strcmp_arg
    test rax, rax
    jnz .profile_mode

    mov rdi, qword [r12 + 8]
    lea rsi, [rel remote_arg]
    call strcmp_arg
    test rax, rax
    jnz .remote_mode

.interactive:
    call draw_main_ui
    lea rdi, [input_buf]
    mov rsi, 31
    call read_line

    cmp byte [input_buf], '1'
    je .start_host
    cmp byte [input_buf], '2'
    je .start_client
    cmp byte [input_buf], '3'
    je .start_profile
    cmp byte [input_buf], '4'
    je .start_remote
    cmp byte [input_buf], '5'
    je .exit
    jmp .exit

.start_host:
    call host_mode
    jmp .interactive

.start_client:
    call client_mode
    jmp .interactive

.start_profile:
    call profile_mode
    jmp .interactive

.start_remote:
    call remote_mode
    jmp .interactive

.host_mode:
    call host_mode
    jmp .exit

.client_mode:
    call client_mode
    jmp .exit

.profile_mode:
    call profile_mode
    jmp .exit

.remote_mode:
    call remote_mode
    jmp .exit

.usage:
    lea rdi, [rel usage_msg]
    mov rsi, usage_len
    call print_str
    mov rax, 60
    mov rdi, 1
    syscall

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall
