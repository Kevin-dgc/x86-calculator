%macro save 0
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
%endmacro

%macro load 0
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

%macro cout 2 ; 1=str 2=len(str)
    mov rax, 1
    mov rdi, 1
    mov rsi, %1 ; param #1 str to print
    mov rdx, %2  ; param #2 size of str
    syscall
%endmacro

%macro cin 2 ; 1=saveTo 2=saveTo(Len)
    mov rax, 0
    mov rdi, 0
    mov rsi, %1 ; param #1 where input is stored
    mov rdx, 100 ; max 100 bytes to read
    syscall

    mov qword[%2], rax ; param #2 stores how long input is
    dec qword[%2]
%endmacro

%macro itos 3 ; op16 ; 1=short 2=SaveToString 3=lengthOfString
    mov rax, [%1]
    mov rbx, 10
    xor rcx, rcx ; count var

    cmp rax, 0
    je %%zero

    %%IntToStack:
        xor rdx, rdx
        idiv rbx ; remainder in dl
        add dl, "0" ; byte[int] to char 

        push rdx
        inc rcx

        cmp rax, 0
        jne %%IntToStack

    xor rdi, rdi
    %%StackToStr:
        pop rdx
        mov byte[%2 + rdi], dl
    
        inc rdi
        cmp rcx, rdi
        jne %%StackToStr

    mov [%3], rcx
    jmp %%done

    %%zero:
        mov byte[%2], '0'
        mov word[%3], 1
    %%done
%endmacro

%macro do_math 3 ; op64 ; 1=byte[opType] 2=qword[a] 3=qword[b] a?=b
    save
    mov bl, byte[%1]
    cmp bl, "+"
    je %%Wadd
    cmp bl, "-"
    je %%Wsub
    cmp bl, "*"
    je %%Wmul
    cmp bl, "/"
    je %%Wdiv
    cmp bl, "^"
    je %%Wexp

    jmp %%done

    %%Wadd:
        mov rax, [%2]
        add rax, [%3]
        adc rax, 0
        mov [%2], rax

        jmp %%done

    %%Wsub:
       mov rax, [%2]
        sub rax, [%3]
        mov [%2], rax

        jmp %%done

    %%Wmul:
        mov rax, [%2]
        imul qword[%3]
        mov [%2], rax

        jmp %%done

    %%Wdiv:
        mov rax, [%2]
        cqo ; dx:ax
        idiv qword[%3]
        mov [%2], rax

        jmp %%done
    %%Wexp:
        mov rdi,  qword[%3] ; exp == 0 return 1
        cmp rdi, 0
        je %%zeroExp

        cmp rdi, 1 ; exp == 1 return base
        je %%done
    
        mov rsi, 1 ; counter3
        mov rcx, [%2]
        cmp qword[%3], rsi
        ja %%loopExp
        jbe %%done

    %%loopExp:
        mov rax, [%2]
        imul rcx
        mov [%2], rax
        ; b > index ->start
        inc rsi
        cmp qword[%3], rsi
        jb %%loopExp
        jmp %%done

    %%zeroExp:
        mov qword[%2], 1
        jmp %%done

    %%done:
        load
%endmacro

%macro getDigits 3 ; op64 ; 1=startIndex 2=string 3=int
    ; total+=cur, total*=10
    save
    mov rbx, 10 ; save dividor
    mov rsi, %1
    
    mov rax, 0
    ; !0-9 should result in jump
    %%loop:
        movzx rcx, byte[%2 + rsi]

        cmp cl, '0'
        jb %%end
        cmp cl, '9'
        ja %%end

        sub cl, '0'
        imul rax, rbx
        ;movzx rcx, cl
        add rax, rcx
    
        inc rsi
        jmp %%loop

    %%end:
    mov %1, rsi
    mov [%3], rax
    load
%endmacro

section .data
    ; Cin and Cout
    instructions db "Symbols allowed =+-/*^, any pos number, enter q to exit"
    len_instructions equ $ - instructions

    prompt db "Calc: ", ; 25
    len_prompt equ $ - prompt

    new_line db 10                        ; 1
    len_new_line equ $ - new_line

    equals_text db " = "                  ; 3
    len_equals_text equ $ - equals_text

    len_user_input dq 0

    ; Math
    output dq 0
    len_output_string dw 0

    second_op dq 0
    op_type db 0

section .bss
    ; Cin and Cout
    user_input resb 100 ; max user input
    
    ; Math
    output_string resb 8

section .text
    global _start


_start:
    ; prompt user
    cout instructions, len_instructions
    cout new_line, len_new_line

_realStart:
    cout new_line, len_new_line
    cout prompt, len_prompt

    ; take in user input
    cin user_input, len_user_input
    cmp byte[user_input], 'q'
    je _end

    ; Math, loop len_user_input times
    mov rsi, 0 ; index
    mov rcx, 0 ; sum
    mov rax, 0 ; op_tyep

    ; do
    getDigits rsi, user_input, output ; moves rsi to delimnator

_while: ; while (rsi < len_user_input)

    mov al, byte[user_input+rsi] ; grabs delimnator
    mov [op_type], al

    inc rsi ; next number start
    getDigits rsi, user_input, second_op ; moves rsi to delimnator
    do_math op_type, output, second_op

    cmp rsi, [len_user_input]
    jb _while
    jae _finish

_finish:
    ; print user input
    cout user_input, [len_user_input]
    ; equals
    cout equals_text, len_equals_text
    ; prints answer
    itos output, output_string, len_output_string
    cout output_string, [len_output_string]

    cout new_line, len_new_line

    jmp _realStart

_end:
    mov rax, 60
    mov rdi, 0
    syscall
