        global notec
        extern debug

; Constants
        STACK_ALIGNER equ -16
        STORAGE_SIZE equ 48
        RBX_OFFSET equ -8
        RBP_OFFSET equ -16
        RDI_OFFSET equ -24
        RSI_OFFSET equ -32
        RSP_OFFSET equ -40
        RCX_OFFSET equ -48
        BLANK_STATE equ 0
        FLAG_OFFSET equ -4
        VALUE_OFFSET equ -8
        WRITE_MODE equ 1
        NORMAL_MODE equ 0

        align 4
        section .bss
        notec_flags resd N
        values resq N

        section .text
end:
        pop rax                                       ; Return number at the top of the stack.

        mov rsp, rbx                                  ; Restore registers that we need to preserve because of ABI.
        mov rbx, [rsp + RBX_OFFSET]
        mov rbp, [rsp + RBP_OFFSET]

        ret
notec:
.preprocess:
        push rbx                                      ; Save rbx register for later.
        lea rbx, [rsp + 8]                            ; To preserve the initial value of rsp, we move it to rbx.
        push rbp                                      ; Save rbp register for later.
        xor bpl, bpl                                  ; bpl is gonna hold a flag telling us if we are in the writing mode.
        sub rsp, STORAGE_SIZE                         ; Reserve space at the stack for storage for registers we want to save.

.loop:
        mov dl, [rsi]                                 ; Get next character in calc string.
        test dl, dl                                   ; Check if it's the end of the calculation.
        jz end
        inc rsi                                       ; Go to another byte.

.digit_0_9:
        cmp dl, '0'
        jb .plus
        cmp dl, '9'
        ja .digit_A_F

        sub dl, '0'                                   ; Convert a character into corresponding integer.
        xor ecx, ecx
        mov cl, dl
        test bpl, bpl                                 ; Test whether we are in the writing mode.
        jnz .digit_writing

        push rcx
        mov bpl, WRITE_MODE                           ; Enter the writing mode.

        jmp .loop

.digit_A_F:
        cmp dl, 'A'
        jb .plus
        cmp dl, 'F'
        ja .digit_a_f

        sub dl, ('A' - 10)                            ; Convert a character A-F into corresponding digit in hexadecimal.
        xor ecx, ecx
        mov cl, dl
        test bpl, bpl                                 ; Test whether we are in the writing mode.
        jnz .digit_writing

        push rcx
        mov bpl, WRITE_MODE                           ; Enter the writing mode.

        jmp .loop

.digit_a_f:
        cmp dl, 'a'
        jb .plus
        cmp dl, 'f'
        ja .plus

        xor ecx, ecx
        sub dl, ('a' - 10)                            ; Convert a character a-f into corresponding digit in hexadecimal.
        mov cl, dl
        test bpl, bpl                                 ; Test whether we are in the writing mode.
        jnz .digit_writing

        push rcx
        mov bpl, WRITE_MODE

        jmp .loop

.digit_writing:
        pop rax
        sal rax, 4
        add rax, rcx
        push rax

        jmp .loop

.plus:
        xor bpl, bpl                                  ; Exit the writing mode.
        cmp dl, '+'
        jne .equal

        pop rax
        pop rcx
        add rax, rcx
        push rax

        jmp .loop

.equal:
        cmp dl, '='
        je .loop

.mul:
        cmp dl, '*'
        jne .aneg

        pop rax
        pop rcx
        imul rax, rcx
        push rax

        jmp .loop

.aneg:
        cmp dl, '-'
        jne .and

        neg qword [rsp]
        jmp .loop

.and:
        cmp dl, '&'
        jne .or

        pop rax
        pop rcx
        and rax, rcx
        push rax

        jmp .loop

.or:
        cmp dl, '|'
        jne .xor

        pop rax
        pop rcx
        or rax, rcx
        push rax

        jmp .loop

.xor:
        cmp dl, '^'
        jne .bneg

        pop rax
        pop rcx
        xor rax, rcx
        push rax
        jmp .loop

.bneg:
        cmp dl, '~'
        jne .throw_away

        not qword [rsp]
        jmp .loop

.throw_away:
        cmp dl, 'Z'
        jne .clone

        pop rax
        jmp .loop

.clone:
        cmp dl, 'Y'
        jne .swap

        push qword [rsp]
        jmp .loop

.swap:
        cmp dl, 'X'
        jne .push_count

        pop rax
        pop rcx
        push rax
        push rcx

        jmp .loop

.push_count:
        cmp dl, 'N'
        jne .push_id

        push N
        jmp .loop

.push_id:
        cmp dl, 'n'
        jne .debug

        push rdi
        jmp .loop

.debug:
        cmp dl, 'g'
        jne .wait_n_chng

        mov [rbx + RSP_OFFSET], rsp                   ; We save scratch registers into storage allocated on the stack,
        mov [rbx + RDI_OFFSET], rdi                   ; because we will call a function that can modify them.
        mov [rbx + RSI_OFFSET], rsi
        mov [rbx + RCX_OFFSET], rdx

        mov rsi, rsp
        and rsp, STACK_ALIGNER                        ; We align stack to 0 mod 16 as in ABI.
        call debug                                    ; Call debug(n, rsp)

        mov rsp, [rbx + RSP_OFFSET]                   ; We restore saved registers.
        mov rdi, [rbx + RDI_OFFSET]
        mov rsi, [rbx + RSI_OFFSET]
        mov rdx, [rbx + RCX_OFFSET]
        imul rax, 8
        add rsp, rax

        jmp .loop

        align 8
.wait_n_chng:
        pop r11                                       ; Who to exchange with.
        pop rax                                       ; What to exchange.
        inc r11
        inc rdi                                       ; increase my index
; We are increasing indexes, because we use 0 as not initialized flag,
; because we know that N <= 2 ** 32 and n is less than 2 ** 32 - 1.
        lea r8, [rel values]                          ; Get address of value buffer.
        mov [r8 + rdi * 8 + VALUE_OFFSET], rax        ; Set my value that I want exchange.
        lea r9, [rel notec_flags]                     ; Get address of flag buffer.
        mov [r9 + rdi * 4 + FLAG_OFFSET], r11d        ; Set my flag to comrade that I want to exchange values with.

        align 8
.wait_for_comrade:                                    ; Wait for my comrade to initialize their flag and value.
        mov ecx, [r9 + r11 * 4 + FLAG_OFFSET]
        cmp ecx, edi
        jne .wait_for_comrade

.push_values:
        mov rax, [r8 + r11 * 8 + VALUE_OFFSET]        ; If I am here, then my comrade has initialized his value and flag.
        push rax
        mov dword [r9 + r11 * 4 + FLAG_OFFSET], BLANK_STATE

        align 8
.wait_for_comrade_again:
        mov ecx, [r9 + rdi * 4 + FLAG_OFFSET]
        test ecx, ecx
        jnz .wait_for_comrade_again

        dec rdi
        jmp .loop
