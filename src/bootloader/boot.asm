org 0x7C00

; Emits 16-bit code for BIOS
bits 16

; Macro for end of line character
%define ENDL 0x0D, 0x0A

; FAT12 Header
jmp short start 				; BIOS Parameter block
nop

bdb_oem: 			db "MSWIN4.1"	; OEM Identifier block
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster: 	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:		dw 2280		; 2880 * 512 = 1.44MB (Size of floppy disk)
bdb_media_descriptor_type: 	db 0F0h		; F0 = 3.5 inch floppy disk
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:			dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0

ebr_drive_number:		db 0		; Extended boot record block
				db 0
ebr_signature:			db 29h
ebr_volume_id:			db 00h
				db 00h
				db 00h
				db 00h
ebr_volume_label:		db "MinOS      "; 11 bytes, padded with spaces
ebr_system_id:			db "Fat12   "	; 8 bytes, padded with spaces

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


	; Reads data from the floppy disk
	mov [ebr_drive_number], dl

	mov ax, 1				; LBA = 1, Second sector from disk
	mov cl, 1				; 1 Sector to read
	mov bx, 0x7E00				; Data should be after bootloader

	; Prints the message to the console
	mov si, msg
	call puts

	; Enters infinite loop
	cli					; Disables interrupts to stop the processor "escaping"
	hlt

; Error handlers

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h					; Wait for keypress
	jmp 0FFFFh:0				; Jump to beginning of BIOS (Should reboot)

.halt:
	cli					; Disable interupts to stop escape of "halt" state
	jmp .halt				; Continues infinite loop

; Converts an LBA address to a CHS address
; Parameters:
; - ax: LBA address
; Returns:
; cx [bits  0-5]: sector number
; cx [bits 6-15]: cylinder
; dh		: head
lba_to_chs:
	push ax
	push dx

	xor dx, dx				; dx = 0
	div word[bdb_sectors_per_track]		; ax = LBA / SectorsPerTrack
						; dx = LBA % SectorsPerTrack

	inc dx					; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx				; cx = sector

	xor dx, dx				; dx = 0
	div word[bdb_heads]			; ax = (LBA / SectorsPerTrack) / Heads = cylinder
						; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl				; dh = head
	shl ah, 6
	or cl, ah				; Puts upper 2 bits of cylinder in CL

	pop ax
	mov dl, al				; Restores dl
	pop ax
	ret

; Read sectors from a disk
; Parameters:
; - ax: LBA address
; - cl: Number of sectors to read (capped at 128)
; - dl: Drive number
; - es:bx: Memory address to store the data
disk_read:
	push ax					; Saves registers that get modified
	push bx
	push cx
	push dx
	push di

	push cx					; Saves CL (Number of sectors to read)
	call lba_to_chs				; Computes CHS
	pop ax					; AL = Number of sectors to read

	mov ah, 02h
	mov di, 3				; Retry count

.retry:
	pusha					; Saves all registers (What the BIOS modifies is unknown)
	stc					; Sets the carry flag
	int 13h					; Carry flag cleared = success
	jnc .done				; Jump if carry not set

	; Read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; All attempts failed
	hlt

.done:
	popa

	pop di					; Restores registers
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; Resets disk controller
; Parameters:
; - dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

; Messages
msg: 				db "Hello world!", ENDL, 0
msg_read_failed: 		db "Failed to read from disk!", ENDL, 0

; Fills the rest of the sector with 0's and marks it as bootable (0AA55h)
times 510-($-$$) db 0
dw 0AA55h

