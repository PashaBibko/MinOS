org 0x7C00

; Emits 16-bit code for BIOS
bits 16

; Macro for end of line character
%define ENDL 0x0D, 0x0A

start:
	jmp main

; Print a string to the console.
; Parameters:
; - ds:si Points to string
puts:
	; Save registers to modify
	push si
	push ax

.loop:
	lodsb 					; Loads next character in al
	or al, al 				; Checks if the next character is null
	jz .done				; Conditional jump to done if at the end of a string

	mov ah, 0x0e
	mov bh, 0
	int 0x10				; Calls BIOS interupt to print character

	jmp .loop				; Loops to the next iteration

.done:
	pop ax
	pop si
	ret

main:
	; Setup data segments
	mov ax, 0				; Cannot write to ds/es directly
	mov ds, ax
	mov es, ax
	
	; Setup stack
	mov ss, ax
	mov sp, 0x7C00 				; Stack grows downwards from where we are located in memory

	; Prints the message to the console
	mov si, msg
	call puts

	; Enters infinite loop
	hlt

.halt:
	jmp .halt				; Continues infinite loop if it escapes

msg: db "Hello world!", ENDL, 0

; Fills the rest of the sector with 0's and marks it as bootable (0AA55h)
times 510-($-$$) db 0
dw 0AA55h

