[BITS 16]
[ORG 0x7C00]

; Bootloader
; Definizioni utili

BSt1		equ	0x07c0
BSt2		equ	0x1080
KSeg		equ	0xffff
SSeg		equ	0x01d0

; ---Inizio del bootsector (come da specifiche ufficiali Microsoft :)-----------
	jmp	short onTheMoon
	nop

; ---FAT (come da specifiche ufficiali Microsoft :)-----------------------------

OEM			db	"MSWIN4.1"
BytesPerSector		dw	512
SectorsPerCluster	db	1
ReservedSectors		dw	4
NumberOfFATs		db	2
RootEntries		dw	224
TotalSectors16		dw	2880
Media			db	0xF0
SectorsPerFAT		dw	9		; FATSize16
SectorsPerTrack		dw	18
NumberOfHeads		dw	2
HiddenSectors		dd	0
TotalSectors32		dd	0
DriveNumber		db	0
Reserved1		db	0
BootSignature		db	0x29
VolumeID		dd	7051983
VolumeLabel		db	"NO NAME    "
FSType			db	"FAT12   "

; ---Inizio effettivo del codice------------------------------------------------
onTheMoon:
	mov	[drive], dl
	mov	ax, 0
	mov	ds, ax
	cli
	mov	ax, SSeg
	mov	ss, ax
	mov	sp, 0xFFFF
	sti
	mov	si, loadss
	call	print

; Leggiamo il second stage e carichiamolo in 0x1080
	mov	ax, 1
	mov	cx, 3
	mov	bx, BSt2
	mov	es, bx
	xor	bx, bx
	call	ReadS

	mov	si, OK
	call	print
	call	newline

	mov	dl, [drive]
	mov	ax, BSt2
	mov	ds, ax
	jmp	BSt2:0x0000

; Qui ci si dovrebbe arrivare solo in casi eccezionali. Dovrebbe servire come
; una specie di Boot Panic...
Panic:
	jmp	$

; ---Procedure varie------------------------------------------------------------
; Stampa una stringa in modalità TeleType
;  Input: DS:SI punta al primo carattere della stringa. L'ultimo carattere
;         dev'essere 0x00
; Output: La stringa a video
print:
	push	ax
	push	bx
	push	cx
	push	dx
	mov	ah, 0x0E
	mov	bh, 0x00
	mov	bl, 0x07
nc:
	lodsb			; mov al, si; inc si
	or	al, al
	jz	finish
	int	0x10
	jmp	nc
finish:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

; Va accapo
newline:
	mov	si, crlf
	call	print
	ret

; Legge cx settori dal disco a partire dal settore ax e li carica in es:bx
;  Input: cx = settori da leggere; ax = settore di partenza
; Output: es:bx <- i settori letti
ReadS:
RSMain:
	mov	di, 5
RSLoop:
	push	ax
	push	bx
	push	cx
	push	bx
	call	LBA2CHS
	mov	ch, cl
	mov	cl, al
	mov	dh, bl
	mov	dl, byte [drive]
	mov	ah, 0x02
	mov	al, 0x01
	pop	bx
	int	13h
	jnc	RSOk
	dec	di
	pop	cx
	pop	bx
	pop	ax
	jnz	RSLoop
	jmp	RSErr
RSOk:
	pop	cx
	pop	bx
	pop	ax
	add	bx, WORD [BytesPerSector]	; prossimo settore da leggere
	inc	ax
	loop	RSMain
RSEnd:
	ret

; Calcola l'indirizzo assoluto CHS a partire dall'indirizzo logico LBA
;  Input: ax = LBA; FAT
; Output: ax = settore (s); bx = testina (h); cx = cilindro (c)
LBA2CHS:
	push	dx
	xor	dx, dx
	mov	bx, [SectorsPerTrack]
	div	bx
	inc	dx
	push	dx
	xor	dx, dx
	mov	bx, [NumberOfHeads]
	div	bx
	mov	cx, ax
	mov	bx, dx
	pop	ax
	pop	dx
	ret

; Mostra un messaggio di errore lettura dal disco
RSErr:
	mov	si, FAIL
	call	print
	call	newline
	mov	si, RSErrm
	call	print
	call	newline
	jmp	reboot

reboot:
	mov	si, rebootm
	call	print
	call	getkey
	db	0EAh				; reboot
	dw	0x0000
	dw	0xFFFF

getkey:						; attende un tasto e poi ritorna.
	and	ah, 0
	int	16h
	ret

; ---Dati vari------------------------------------------------------------------
; ---STRINGHE-------------------------------------------------------------------
crlf			db	13,10,0
FAIL			db	' FALLITO',0
OK			db	' OK',0
RSErrm			db	'Errore di lettura dal disco',0
rebootm			db	'Premi un tasto per riavviare',0
loadss			db	'Sto caricando il secondo stadio:',0

; ---NUMERI---------------------------------------------------------------------
RootDirSize		dw	0
RootBaseSect		dw	0
FirstDataSector		dw	0
drive			db	0

; ---BootSign-------------------------------------------------------------------
	TIMES 510-($-$$) db 0
	dw	0xAA55
