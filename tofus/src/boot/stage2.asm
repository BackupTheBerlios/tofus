[BITS 16]
[ORG 0x0000]

; Bootloader
; Definizioni utili

BSt1		equ	0x07c0
BSt2		equ	0x1080
KSeg		equ	0xffff
SSeg		equ	0x01d0

	jmp	onTheMoon

; GDT
GDTR:
GDTsize DW GDT_END-GDT-1
GDTbase DD 0x500

GDT:
NULL_SEL         EQU $-GDT  ; descrittore nullo (64bit per entry)
      DD 0x0
      DD 0x0
CODESEL          EQU $-GDT    ; 4GB Flat Code a 0x0 con limite 0xFFFFF
      DW     0xFFFF           ; Limit(2):0xFFFF
      DW     0x0              ; Base(3)
      DB     0x0              ; Base(2)
      DB     0x9A             ; Tipo: present,ring0,code,exec/read/accessed (10011000)
      DB     0xCF             ; Limit(1):0xF | Flags:4Kb inc,32bit (11001111)
      DB     0x0              ; Base(1)
DATASEL          EQU $-GDT    ; 4GB Flat Data a 0x0 con limite 0xFFFFF
      DW     0xFFFF           ; Limit(2):0xFFFF
      DW     0x0              ; Base(3)
      DB     0x0              ; Base(2)
      DB     0x92             ; Tipo: present,ring0,data/stack,read/write (10010010)
      DB     0xCF             ; Limit(1):0xF | Flags:4Kb inc,32bit (11001111)
      DB     0x0              ; Base(1)
GDT_END:


; ---Procedure varie------------------------------------------------------------

wkc:
; Attende finché la tastiera è libera
	xor	al,al
	in	al, 0x64		; legge lo stato
	test	al, 2			; il bit 1 è a 0?
	jnz 	wkc			; se non è a 0 cicla
	ret

wkf:
; Attende finché la tastiera è occupata
	xor	cx,cx
	in	al, 0x64		; legge lo stato
	test	al, 1			; il bit 0 è a 0?
	jz	wkf			; se non è a 0 cicla
	ret

kill_motor:
; Ferma il motore del floppy
	mov	al, 0x0c
	mov	dx, 0x3f2
	out	dx, al
	ret

print:
; Stampa una stringa in modalità TeleType
;  Input: DS:SI punta al primo carattere della stringa. L'ultimo carattere
;         dev'essere 0x00
; Output: La stringa a video
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

ReadS:
; Legge cx settori dal disco a partire dal settore ax e li carica in es:bx
;  Input: cx = settori da leggere; ax = settore di partenza
; Output: es:bx <- i settori letti
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
	mov	si, hash
	call	print
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

FAT2LBA:
; Calcola l'indirizzo LBA dato il cluster FAT
; LBA = ((Cluster - 2) * SectorsPerCluster ) + DataStart
;  Input: ax = cluster, FAT e l'indirizzo del settore dati
; Output: ax = LBA
	sub	ax, 2
	xor	cx, cx
	mov	cl, byte [SectorsPerCluster]
	mul	cx
	add	ax, word [DataStart]
	ret

NextCluster:
; Moltiplica per 3, divide per 2 o ottieni 1.5 dividendo per 2 e aggiungendo 1.
; Legge la word all'indirizzo risultante mantenendo i 12 byte bassi. Se dispari
; shifta di 4 bit a destra
;  Input = ax = cluster corrente
; Output = ax = prossimo cluster
	mov	cx, ax
	mov	dx, ax
	shr	dx, 1
	add	cx, dx
	mov	bx, 0x1000
	add	bx, cx
	mov	dx, word [bx]

	; pari o dispari?
	test	ax, 1
	jnz	.Odd
.Even:
	and dx, 0x0FFF
	jmp	.Done
.Odd:
	shr	dx, 4
.Done:
	mov	ax, dx
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

getkey:						; attende un tasto e ritorna.
	and	ah, 0
	int	16h
	ret

BadCluster:
	mov	si, badcluster
	call	print
	call	newline
	jmp	reboot

ClusterEmpty:
	mov	si, emptycluster
	call	print
	call	newline
	jmp	reboot

; ---Dati vari------------------------------------------------------------------
; ---STRINGHE-------------------------------------------------------------------
crlf			db	13,10,0
FAIL			db	' FALLITO',0
OK			db	' OK',0
hash			db	'.',0
RSErrm			db	'Errore di lettura dal disco',0
rebootm			db	'Premi un tasto per riavviare',0
welcome2st		db	"Benvenuto, sono il secondo stadio per l'avvio di tOfuS",0
loadingroot		db	"Sto caricando la root in memoria...",0
searchingkernel		db	"Sto cercando il kernel...",0
kernelfound		db	"Sto caricando il kernel...",0
kernelnotfound		db	"Non riesco a trovare il kernel nel disco, controlla di avercelo copiato",0
badcluster		db	"Cluster danneggiato, mannaggia...",0
emptycluster		db	"Cluster vuoto, com'e' possibile?",0
A20msg			db	"Abilito il gate A20...",0
GDTm			db	"Sposto il Global Descriptor in 0x500...",0
GDTm2			db	"Carico il Global Descriptor...",0
PModem			db	"Entro in PMode...",0

KernelImageName		db	"KERNEL     ",0

; ---NUMERI---------------------------------------------------------------------
RootSize		dw	0
RootStart		dw	0
DataStart		dw	0
KernelAddress		dw	0
KernelAddressLBA	dw	0

FATSize			dw	0
drive			db	0

; ---Roba della FAT-------------------------------------------------------------
BytesPerSector		dw	512
SectorsPerCluster	db	1
ReservedSectors		dw	4
NumberOfFATs		db	2
RootEntries		dw	224
;TotalSectors16		dw	2880
;Media			db	0xF0
SectorsPerFAT		dw	9		; FATSize16
SectorsPerTrack		dw	18
NumberOfHeads		dw	2
;HiddenSectors		dd	0
;TotalSectors32		dd	0

; ---Inizio reale del programma-------------------------------------------------

onTheMoon:
	mov	[drive], dl
	cli
	mov	ax, BSt2	; setta il segmento di codice
	mov	ds, ax
	mov	es, ax
	mov	ax, SSeg	; setta lo stack...
	mov	ss, ax
	mov	sp, 0x200	; ... di lunghezza 512 byte
	mov	ax, 0xB800	; segmento video
	mov	gs, ax
	sti

	jmp	init

init:
; Salutiamo l'utente e, contemporaneamente, facciamo anche un piccolo test sul
; corretto funzionamento dello stack :) Ok, sprechera' qualche ciclo macchina ma
; e' sempre meglio controllare, no?
	mov	si, welcome2st
	push	si
	pop	si
	call	print
	call	newline

a20:
; Abilitiamo il gate A20 per poter accedere a più di un mega di RAM.
	mov	si, A20msg
	call	print
	cli

	call	wkc
	mov	al, 0xD1	; diciamo alla tastiera che le vogliamo scrivere
	out	0x64, al	; sopra... divertente, no? :)
	call	wkc
	mov	al, 0xDF	; il dato da scrivere
	out	0x60, al	; scriviamocelo
	call	wkc

	mov	cx, 0x10	; aspettiamo che la tastiera accetti la cosa...
kbdwait:
	xor	ax, ax
	out	0xE0, ax
	loop	kbdwait
				; controlliamo se effettivamente l'A20 e' aperto
	mov	al, 0xD0	; leggiamo dalla tastiera
	out	0x64, al
	call	wkf		; aspettiamo che il dato arrivi
	in	al, 0x60	; e poi prendiamolo
	test	al, 2		; controlliamo se l'A20 è aperto
	jnz	a20_ok
	mov	si, FAIL
	call	print
	jmp	reboot

a20_ok:
	sti
	mov	si, OK
	call	print
	call	newline

; Cominciamo con un po' di calcoli:
; Dimensione della root
; (RootEntries * 32) / BytesPerSector
	xor	ax, ax
	mov	ax, [RootEntries]
	mov	cx, 32
	mul	cx
	div	word [BytesPerSector]
	mov	[RootSize], ax

; Inizio della root
; ReservedSectors + (NumberOfFATs * SectorsPerFAT)
	xor	ax, ax
	mov	al, byte [NumberOfFATs]
	mul	word [SectorsPerFAT]
	add	ax, word [ReservedSectors]
	mov	[RootStart], ax

; Inizio dei dati
; RootSize + RootStart
	mov	cx, [RootSize]
	add	ax, cx
	mov	[DataStart], ax

; Finiti i conti, carichiamo e scorriamo la root.
; Intanto leggiamo la root e mettiamola all'offset 0x1000
	mov	si, loadingroot
	call	print
	mov	ax, [RootStart]
	mov	cx, [RootSize]
	mov	bx, 0x1000
	call	ReadS
	mov	si, OK
	call	print
	call	newline

; Ora scorriamola per vedere se ci troviamo il kernel.
;  Input: FAT e qualche altro valore
; Output: di = l'indirizzo
	mov	si, searchingkernel
	call	print

	mov	cx, word [RootEntries]
	mov	di, 0x1000
SKloop:
	push	cx
	mov	cx, 11
	mov	si, KernelImageName
	push	di
	rep	cmpsb
	pop	di
	je	SKfound
	pop	cx
	add	di, 32
	mov	si, hash
	call	print
	loop	SKloop
	jmp	SKnotfound

; Kernel non trovato
SKnotfound:
	mov	si, FAIL
	call	print
	call	newline
	mov	si, kernelnotfound
	call	print
	call	newline
	jmp	reboot

; Ora si carica il kernel...
SKfound:
	mov	si, OK
	call	print
	call	newline
	mov	si, kernelfound
	call	print
	mov	dx, word [di + 0x001A]
	mov	word [KernelAddress], dx

; FATSize = NumberOfFATs * SectorsPerFAT
	xor	ax, ax
	mov	al, byte [NumberOfFATs]
	mul	word [SectorsPerFAT]
	mov	word [FATSize], ax

; Inizio della FAT
	xor	ax, ax
	mov	ax, word [ReservedSectors]

; Schiaffa la FAT in ram
	mov	cx, word [FATSize]
	mov	bx, 0x1000
	call	ReadS

; Carica il kernel in memoria a 1MB fisico
	push	es
	mov	bx, KSeg
	mov	es, bx
	mov	bx, 0x10
	push	bx

LoadKernel:
	xor	ax, ax
	mov	ax, word [KernelAddress]
	pop	bx
	call	FAT2LBA
	mov	[KernelAddressLBA], ax

	xor	cx, cx
	mov	cl, byte [SectorsPerCluster]
	call	ReadS
	push	bx

; Calcola il prossimo settore
	xor	ax, ax
	mov	ax, word [KernelAddress]
	call	NextCluster
	mov	word [KernelAddress], ax

	cmp	ax, 0
	je	.ClusterEmpty
	cmp	ax, 0x0FF7
	je	.BadCluster

; Fine del file?
	cmp	ax, 0x0FFF
	je	endLoading
	jmp	LoadKernel

.ClusterEmpty:
	jmp	ClusterEmpty
.BadCluster:
	jmp	BadCluster

endLoading:
	call	kill_motor

	mov	si, OK
	call	print
	call	newline

	; spostiamo il GDT a 0x500
	mov	si, GDTm
	call	print
	xor	ax, ax
	mov	es, ax
	mov	si, GDT
	mov	di, [GDTbase]
	xor	ecx, ecx
	mov	cx, [GDTsize]
	cld				; manda a 0 il flag di direzione
gdtciclo:
	movsb
	loop	gdtciclo

	mov	si, OK
	call	print
	call	newline

	mov	si, GDTm2
	call	print
	cli

; Carichiamo il GDT
	lgdt	[GDTR]

	sti
	mov	si, OK
	call	print
	call	newline
	mov	si, PModem
	call	print
	cli

; Ora la parte emozionante: entrare in PMode...
	mov	eax, cr0
	or	al, 1
	mov	cr0, eax		; ta-daaah!

; Puliamo un po' di registri: cs, ip ed eip
	jmp	CODESEL:FLUSH		; settiamo il cs al selettore del codice

[bits 32]	; 32 bit! Sempre più difficile!
FLUSH:
	jmp	$
; risistemiamo tutti i registri di segmento
	mov	eax, DATASEL
	mov	ds,eax
	mov	es,eax
	mov	fs,eax
	mov	gs,eax
	mov	ss,eax
	mov	esp,0xffff

;jump to k_init.asm
	jmp	CODESEL:0x100000

	hlt
