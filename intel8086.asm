    .model small
    .stack

; ==================== DATA ====================
    .data

; ========== CONSTANTS:
CR 	equ 13 ; carriage return (Enter)
LF 	equ 10 ; line feed ('\n')
TB 	equ 9 ; tab
SB	equ 32 ; space bar
CM 	equ 44 ; comma

msg1 	db ".1.", CR, LF, 0
msg2 	db ".2.", CR, LF, 0
msg3 	db ".3.", CR, LF, 0
msg4 	db ".4.", CR, LF, 0

msgErrorOpen 	db "Erro na abertura do arquivo.", CR, LF, 0
msgErrorCreate	db "Erro na criacao do arquivo.", CR, LF, 0
msgErrorRead 	db "Erro na leitura do arquivo.", CR, LF, 0
msgErrorWrite	db "Erro na escrita do arquivo.", CR, LF, 0
msgErrorParam 	db "Parametros invalidos.", CR, LF, 0
msgErrorParamV 	db "Parametro da opcao [-v] deve ser 127 ou 220.", CR, LF, 0
msgErrorLine1 	db CR, LF, "Linha ", 0
msgErrorLine2 	db " invalida: ", 0

defaultNameIn 	db "a.in", 0
defaultNameOut 	db "a.out", 0

digitZero 			db "0", 0
colon 				db ":", 0
endString 			db CR, LF, 0
msgTotalTime 		db "Tempo total de medicoes: ", 0
msgTensionTime 		db "Tempo de tensao adequada: ", 0
msgNoTensionTime 	db "Tempo sem tensao: ", 0
msgNoParamI 		db "Opcao [-i] sem parametro.", CR, LF, 0
msgNoParamO 		db "Opcao [-o] sem parametro.", CR, LF, 0
msgNoParamV 		db "Opcao [-v] sem parametro.", CR, LF, 0

; ========== FLAGS:
newLine 	db 0 ; indicates when the "lineNumber" must be incremented

; ========== GENERAL VARIABLES:
FileBuffer  db 10  dup (?) ; buffer to read/write files
CMDLINE     db 256 dup (?) ; buffer to read command line
CMDsize 	db 0 ; cmd string size
fileHandle 	dw 0 ; general file handle
fileHandle2	dw 0 ; general file handle

counter		dw 0 ; general purpose counter
char		db 0 ; stores a character
number		db 5 	dup (0) ; stores 5 digits of a number

fileIn 		db 30	dup	(0)	; input file name
fileInSize	dw 0 ; input file name size
fileOut		db 30 	dup	(0) ; output file name
fileOutSize	dw 0 ; output file name size

tension			db 4 	dup (0) ; tension text
tensionOk 		dw 0 ; flag to verify if a tension was declared
tensionValue 	dw 0 ; tension value
lineNumber 		dw 0 ; number of the current line of the file
lineNumber2 	dw 0 ; lineNumber x 2
invalidLine 	dw 0 ; number of invalid lines
lineNumberBU 	dw 0 ; back up for lineNumber

tensionListOk 	db 8000 dup (0) ; indicates which lines are incorrect
tensionList1 	dw 8000 dup (0) ; first list of tension values
tensionList2 	dw 8000	dup (0) ; second list of tension values
tensionList3 	dw 8000	dup (0) ; third list of tension values
wire 			dw 1 ; indicates which is the current wire

tensionTime 	dw 0 ; the amount of time the tension was correct
noTensionTime 	dw 0 ; the amount of time the tension was 10 or below
noTensionQuant 	dw 0 ; the quantity of tensions 10 or below

seconds 	dw 0 ; tension seconds
minutes 	dw 0 ; tension minutes
hours 		dw 0 ; tension hours

secondsTXT 	db 4 	dup (0) ; seconds string
minutesTXT 	db 4 	dup (0) ; minutes string
hoursTXT 	db 4 	dup (0) ; hours string

; ========== FUNCTIONS VARIABLES:
itoa_n  dw 0
itoa_f  db 0
itoa_m  dw 0


; ==================== CODE  ====================
    .code

; ==================== STARTUP ====================
    .startup

; ========== READ COMMAND LINE:
    push    ds ; save segments
    push    es
    mov     ax,ds ; exchange ds with es
    mov     bx,es
    mov     ds,bx
    mov     es,ax
    mov     si,80h ; save size of string in cx
    mov     ch,0
    mov     cl,[si]
    mov     ax,cx ; save also in ax
    mov     si,81h ; initialize source pointer
    lea     di,CMDLINE ; initialize destination pointer
    rep 	movsb
    pop     es  ; return segments information
    pop     ds

; ========== INITIALIZATION:
	lea 	bx,CMDsize
	mov		[bx],ax
	mov		ax,@data ; prepare segments for copying the string
	mov		ds,ax
	mov		es,ax
	
; ========== SEPARATE FILES NAMES:
	mov 	di,-1
	lea 	bx,CMDsize
	mov		cx,[bx]
	inc 	cx

loopRead: ; read cmdLINE until find "-"
	inc 	di
	dec 	cx
	cmp		cx,0
	je 		adjustparameters
	lea 	bx,CMDLINE
	mov		dl,[bx+di]
	cmp 	dl,"-"
	jne		loopRead

	inc 	di
	dec 	cx
	call 	readParameter ; get the following parameter
	jnc		loopRead

errorParam: ; if the parameter is incorrect print a message
	lea  	bx,msgErrorParam
	call 	printf
	jmp 	endProgram

; ========== ADJUST PARAMETERS:
adjustParameters: ; verify if the parameters were declared 
	cmp		fileInSize,0 ; if the input file name wasn't declared, give it a default name
	jne		adjustOutput
	
	lea		si,defaultNameIn
	lea		di,fileIn
	cld
	call 	getSubString ; copy "a.in" to fileIn
	lea 	bx,msgNoParamI
	call 	printf

adjustOutput:
	cmp		fileOutSize,0 ; if the output file name wasn't declared, give it a default name
	jne		adjustTension

	lea		si,defaultNameOut
	lea		di,fileOut
	cld
	call 	getSubString ; copy "a.out" to fileOut
	lea 	bx,msgNoParamO
	call 	printf

adjustTension:
	cmp		tensionOk,0 ; if the tension wasn't declared, give it a default value
	jne		atoiTension

	mov		tensionValue,127
	lea 	bx,msgNoParamV
	call 	printf
	jmp		openInput

atoiTension: ; convert the tension text to an integer
	lea		bx,tension 
	call 	atoi
	mov		tensionValue,ax

	cmp		tensionValue,127
	je		openInput

	cmp		tensionValue,220
	je		openInput

	lea 	bx,msgErrorParamV ; if the tension parameter isn't 127 or 220 end the program
	call 	printf
	jmp 	errorParam

; ========== OPEN INPUT:
openInput:
	mov		counter,0
	mov		lineNumber,0
	lea		dx,fileIn ; open the input file
	call 	fopen
	mov		fileHandle,bx
	jnc		getCharLoop

	lea		bx,msgErrorOpen ; print an error message if there were any problems opening the file
	call 	printf
	jmp		endProgram

getCharLoop: ; read all characters from the file
	mov		bx,fileHandle
	call 	getChar ; get a char from the file
	cmp		ax,0 ; if there isn't a char, stop reading
	je		analyzeData

	cmp		dl,"f"
	je		analyzeData

	cmp		dl,"F"
	je		analyzeData

	call 	iseos ; verify if it is a relevant char
	jc		getCharLoop

	cmp		dl,CM ; if it is a comma, store the number and change the wire
	jne		testEnter
	jmp		storeNumber

testEnter:
	cmp		dl,CR ; if it is 'Enter', store the number and change the wire
	jne		testLineFeed

	cmp		counter,0 ; if the current number is empty get the next char
	je		getCharLoop

	cmp		wire,3 ; if the current wire isn't the third, the line of the file is invalid
	je		continueTestEnter

	mov 	di,lineNumber
	lea 	bx,tensionListOk
	mov 	[bx+di],1
	inc 	invalidLine

continueTestEnter:
	mov		newLine,1
	jmp		storeNumber

testLineFeed:
	cmp		dl,LF ; if it is '\n', increment line number, store the number and change the wire
	jne		storeChar

	cmp		counter,0 ; if the current number is empty get the next char
	je		getCharLoop

	cmp 	wire,3 ; if the current wire isn't the third, the line of the file is invalid
	je 		continueTestFeed

	mov 	di,lineNumber
	lea 	bx,tensionListOk
	mov 	[bx+di],1
	inc 	invalidLine

continueTestFeed:
	mov		newLine,1
 
storeNumber: ; convert the number to an integer
	lea		bx,number
	call 	atoi
	cmp 	ax,500 ; if the tension is 500 or higher, the line of the file is invalid
	jb 		continueStore

	mov 	di,lineNumber
	lea 	bx,tensionListOk
	mov 	[bx+di],1
	inc 	invalidLine

continueStore:	
	cmp		wire,1 ; verify in which wire it have to be stored
	je		storeWire1

	cmp		wire,2
	je		storeWire2

	lea		bx,tensionList3 ; store tension in list 3
	mov		di,lineNumber2
	mov		[bx+di],ax
	jmp		changeWire

storeWire1:
	lea		bx,tensionList1 ; store tension in list 1
	mov		di,lineNumber2
	mov		[bx+di],ax
	jmp		changeWire

storeWire2:
	lea		bx,tensionList2 ; store tension in list 2
	mov		di,lineNumber2
	mov		[bx+di],ax

changeWire:
	cmp		newLine,1 ; if newLine is equal to 1, change the line and prepare to read again
	jne		continueChangeWire ; if not, just prepare to read again

	inc		lineNumber
	mov		ax,lineNumber
	add		ax,lineNumber
	mov		lineNumber2,ax
	mov		newLine,0
	mov		counter,0
	mov		wire,1
	call 	clearNumber 	
	jmp		getCharLoop

continueChangeWire: ; change wire
	mov		counter,0
	inc		wire
	call 	clearNumber 
	jmp		getCharLoop

storeChar: ; store the current character in "number"
	call 	isNumber ; if it's not a number, the line of the file is invalid
	jc		continueStoreChar

	mov 	di,lineNumber
	lea 	bx,tensionListOk
	mov 	[bx+di],1
	inc 	invalidLine

continueStoreChar:
	mov		char,dl ; store char in "number"
	lea		si,char
	mov 	di,counter
	lea		di,[number+di]
	cld
	movsb
	inc		counter
	jmp		getCharLoop

; ========== ANALYZE DATA:
analyzeData:
	mov 	bx,fileHandle
	call 	fclose
	mov		di,0
	mov 	counter,0
	mov		cx,lineNumber
	mov		si,tensionValue

analyzeTensionLoop: ; analyze every item of the tension lists
	lea 	bx,tensionListOk
	push 	di
	mov 	di,counter
	cmp		[bx+di],1 ; if the line is invalid, skip it
	jne 	continueAnalyze

	pop 	di
	inc 	counter
	add 	di,2
	dec		cx
	cmp 	cx,0
	je 		screenReport
	jmp 	analyzeTensionLoop

continueAnalyze:
	pop 	di
	lea		bx,tensionList1 ; analyze the first wire
	mov		ax,[bx+di]
	cmp		ax,10 ; if the tension is 10 or below, increment noTensionQuant
	ja		continue1 ; if not, check if the wire is in the correct range

	inc		noTensionQuant
	jmp		nextTension1

continue1:
	sub		si,10
	cmp		ax,si
	jb		incorrect

	add		si,20
	cmp		ax,si
	ja		incorrect

nextTension1:
	lea		bx,tensionList2 ; analyze the second wire
	mov		ax,[bx+di]
	cmp		ax,10 ; if the tension is 10 or below, increment noTensionQuant
	ja 		continue2 ; if not, check if the wire is in the correct range

	inc		noTensionQuant
	jmp		nextTension2		

continue2:
	sub		si,20
	cmp		ax,si
	jb		incorrect

	add		si,20
	cmp		ax,si
	ja		incorrect

nextTension2:
	lea		bx,tensionList3 ; analyze the third wire
	mov		ax,[bx+di]
	cmp		ax,10 ; if the tension is 10 or below, increment noTensionQuant
	ja		continue3 ; if not, check if the wire is in the correct range

	inc		noTensionQuant
	jmp		endTensionLoop

continue3:
	sub		si,20
	cmp		ax,si
	jb		incorrect

	add		si,20
	cmp		ax,si
	ja		incorrect

endTensionLoop:
	cmp		noTensionQuant,3 ; it all wires were 10 or below, increment noTensionTime and prepare to read the next values
	jne		correct ; if not, increment tensionTime and prepare to read the next values

	mov		si,tensionValue
	mov		noTensionQuant,0
	inc		noTensionTime
	inc 	counter
	add		di,2
	dec		cx
	cmp		cx,0
	je 		screenReport

	jmp		analyzeTensionLoop

correct:
	mov		si,tensionValue
	mov		noTensionQuant,0
	inc		tensionTime
	inc 	counter
	add		di,2
	dec		cx
	cmp		cx,0
	je 		screenReport

	jmp		analyzeTensionLoop

incorrect: ; don't increment any timers and prepare to read the next values
	mov		si,tensionValue
	mov		noTensionQuant,0
	inc 	counter
	add		di,2
	dec		cx
	cmp		cx,0
	je		screenReport

	jmp		analyzeTensionLoop

; ========== REPORT:
screenReport: ; print in screen the total time of valid tensions
	mov 	bx,lineNumber
	mov 	lineNumberBU,bx
	mov 	bx,invalidLine
	sub 	lineNumber,bx
	mov		si,lineNumber
	call 	computeTime
	lea		bx,msgTotalTime
	call 	printf
	call 	convertTime
	call 	printTime

fileReport: ; create/open a file in print the essencial information
	lea 	dx,fileOut
	call 	fcreate
	mov		fileHandle,bx
	jnc		makeReport

	lea		bx,msgErrorOpen ; print an error message if there were any problems opening the file
	call 	printf
	jmp		endProgram

makeReport:
	cmp 	fileInSize,0 ; if the input file name wasn't declared, print this information
	jne 	checkOutput

	lea 	si,msgNoParamI
	call 	fprintf

checkOutput:
	cmp 	fileOutSize,0 ; if the output file name wasn't declared, print this information
	jne 	checkTension

	lea 	si,msgNoParamO
	call 	fprintf

checkTension:
	cmp 	tensionOk,0 ; if the tension value wasn't declared, print this information
	jne		reportTime

	lea 	si,msgNoParamV
	call 	fprintf

reportTime: ; convert the seconds to "xx:xx:xx" format and print all time information
	mov		si,lineNumber ; convert and print the total valid time
	call 	computeTime
	lea 	si,msgTotalTime
	call 	fprintf
	call 	convertTime
	call 	fprintTime
	mov		si,tensionTime ; convert and print the time the tension was correct
	call 	computeTime
	lea 	si,msgTensionTime
	call 	fprintf
	call 	convertTime
	call 	fprintTime
	mov		si,noTensionTime ; convert and print the time there wasn't tension
	call 	computeTime
	lea 	si,msgNoTensionTime
	call 	fprintf
	call 	convertTime
	call 	fprintTime
	mov 	di,-1 ; prepare to print all invalid lines
	mov 	cx,lineNumberBU
	lea		dx,fileIn
	call 	fopen
	mov		fileHandle2,bx
	jnc 	loopLineError

	lea		bx,msgErrorOpen ; print an error message if there were any problems opening the file
	call 	printf
	jmp		endProgram
loopLineError:
	inc 	di
	cmp 	cx,0
	je 		endprogram

	dec 	cx
	lea 	bx,tensionListOk
	cmp 	[bx+di],1 ; if the position of the tensionListOk was active (1) print the error message corresponding to that line
	jne		loopLineError

	lea 	si,msgErrorLine1 ; print the message and the position of the line
	call 	fprintf
	mov 	ax,di
	inc 	ax
	lea 	bx,number
	call 	itoa
	lea 	si,number
	call 	fprintf
	lea 	si,msgErrorLine2
	call 	fprintf

	mov 	counter,0
loopFindLine: ; find the corresponding line and print it
	cmp 	counter,di
	je 		printLine

	mov 	char,0
	call 	nextLine ; read the next line of the file
	inc 	counter
	jmp 	loopFindLine

printLine:
	call 	fprintLine ; print the line
	jmp 	loopLineError

endFindLine:
	mov 	bx,fileHandle2 ; close input file
	call 	fclose

endProgram:
	mov 	bx,fileHandle ; close output file
	call 	fclose
    .exit


; ==================== FUNCOES ====================

print1 	proc near
	lea 	bx,msg1
	call 	printf
	ret
print1 	endp

print2 	proc near
	lea 	bx,msg2
	call 	printf
	ret
print2 	endp

print3 	proc near
	lea 	bx,msg3
	call 	printf
	ret
print3 	endp

print4 	proc near
	lea 	bx,msg4
	call 	printf
	ret
print4 	endp

; ========== ATOI:
; String (DS:BX) -> Int (AX)
; converts a string to a integer

atoi 	proc near
	mov		ax,0
		
atoi_loop:
	cmp		byte ptr[bx], 0
	jz		atoi_endString

	mov		cx,10
	mul		cx
	mov		ch,0
	mov		cl,[bx]
	add		ax,cx
	sub		ax,'0'
	inc		bx
	jmp		atoi_loop

atoi_endString:
	ret
atoi 	endp


; ========== ITOA:
; Int (AX) -> String (DS:BX)
; converts a integer to a string

itoa 	proc near
	mov		itoa_n,ax
	mov		cx,5
	mov		itoa_m,10000
	mov		itoa_f,0
	
itoa_do:
	mov		dx,0
	mov		ax,itoa_n
	div		itoa_m
	cmp		al,0
	jne		itoa_store

	cmp		itoa_f,0
	je		itoa_continue

itoa_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	mov		itoa_f,1

itoa_continue:
	mov		itoa_n,dx
	mov		dx,0
	mov		ax,itoa_m
	mov		bp,10
	div		bp
	mov		itoa_m,ax
	dec		cx
	cmp		cx,0
	jnz		itoa_do

	cmp		itoa_f,0
	jnz		itoa_end

	mov		[bx],'0'
	inc		bx

itoa_end:
	mov		byte ptr[bx],0
	ret
itoa 	endp


; ========== PRINTF:
; String (DS:BX)
; prints a string in command line

printf 	proc near
	mov		dl,[bx]
	cmp		dl,0
	je		printf_endString

	push	bx
	mov		ah,2
	int		21H
	pop		bx
	inc		bx
	jmp		printf
		
printf_endString:
	ret
printf 	endp


; ========== FOPEN:
; String (DS:DX) -> File Handle (BX), Int (CF)
; opens the file and returns 0 if there was no errors
fopen   proc near
    mov     al,0
	mov		ah,3dh
	int		21h
	mov		bx,ax
	ret
fopen 	endp


; ========== FCREATE:
; String (DS:DX) -> File Handle (BX), Int (CF)
; creates a file and returns 0 if there was no erros
fcreate     proc near
	mov		cx,0
	mov		ah,3ch
	int		21h
	mov		bx,ax
	ret
fcreate 	endp


; ========== FCLOSE:
; File Handle (BX) -> Int (CF)
; closes the file and returns 0 if there was no erros
fclose 	proc near
	mov     ah,3eh
	int		21h
	ret
fclose 	endp


; ========== GETCHAR:
; File Handle (BX) -> Char (DL), Int (AL), Int (CF)
; reads a char from the file, returns the number of read characters and returns 0 if there was no erros
getChar 	proc near
	mov		ah,3fh
	mov		cx,1
	lea		dx,FileBuffer
	int		21h
	mov		dl,FileBuffer
	ret
getChar 	endp


; ========== SETCHAR:
; File Handle (BX), Char (DL) -> Int (AL), Int (CF)
; writes the character(s) on the file, returns the number of written characters and returns 0 if there was no erros
setChar 	proc near
	mov		ah,40h
	mov		cx,1
	mov		FileBuffer,dl
	lea		dx,FileBuffer
	int		21h
	ret
setChar 	endp


; ========== GETSUBSTRING:
; String (DS:SI) -> String (DS:DI)
; returns the first substring, separated by spaces
getSubString 	proc near
	inc 	counter
	mov		dl,[si]
	cmp		dl,0
	je		getSubString_end

	cmp		dl,SB
	je		getSubString_end

	cmp		dl,TB
	je		getSubString_end

	movsb
	jmp		getSubString

getSubString_end:
	ret
getSubString 	endp


; ========== ISEOS:
; Char (DL) -> Int (CF)
; returns 1 if the char is '\0', 'Space' or 'Tab'
iseos 	proc near
	clc
	cmp		dl,0
	je		setCarry

	cmp		dl,SB
	je		setCarry

	cmp		dl,TB
	je		setCarry

	jmp		iseos_end

setCarry:
	stc

iseos_end:
	ret
iseos 	endp


; ========== ISNUMBER:
; Char (DL) -> Int (CF)
; returns 1 if the char is a number
isNumber 	proc near
	cmp 	dl,"1"
	je 		setCarryNumber

	cmp 	dl,"2"
	je 		setCarryNumber

	cmp 	dl,"3"
	je 		setCarryNumber

	cmp 	dl,"4"
	je 		setCarryNumber

	cmp 	dl,"5"
	je 		setCarryNumber

	cmp 	dl,"6"
	je 		setCarryNumber

	cmp 	dl,"7"
	je 		setCarryNumber

	cmp 	dl,"8"
	je 		setCarryNumber

	cmp 	dl,"9"
	je 		setCarryNumber

	cmp 	dl,"0"
	je 		setCarryNumber

	clc
	ret

setCarryNumber:
	stc
	ret
isNumber 	endp


; ========== COMPUTETIME:
; Int (SI)
; counts how many minutes/hours the seconds make
computeTime 	proc near
	cmp 	si,60
	jae 	computeMinutes

	mov 	seconds,si
	mov 	minutes,0
	mov 	hours,0
	ret

computeMinutes:
	cmp 	si,3600
	jae 	computeHours
	mov		ax,0

loopMinutes:
	cmp		si,60
	jb		endLoopMinutes

	sub		si,60
	inc		ax
	jmp		loopMinutes

endLoopMinutes:
	mov 	seconds,si
	mov 	minutes,ax
	mov		hours,0
	ret

computeHours:
	mov 	ax,0

loopHours:
	cmp		si,3600
	jb 		endLoopHours

	sub		si,3600
	inc 	ax
	jmp 	loopHours

endLoopHours:
	mov		hours,ax
	cmp		si,60
	jae		computeMinutes

	mov 	seconds,si
	mov		minutes,0
	ret
computeTime 	endp


; ========== PRINTTIME:
; print what is in hours, minutes, seconds
printTime 	proc near
	cmp 	hours,10
	jae 	continuePrintTime1

	lea 	bx,digitZero
	call 	printf	

continuePrintTime1:
	lea		bx,hoursTXT
	call 	printf
	lea 	bx,colon
	call 	printf
	cmp 	minutes,10
	jae 	continuePrintTime2

	lea 	bx,digitZero
	call 	printf

continuePrintTime2:
	lea		bx,minutesTXT
	call 	printf
	lea 	bx,colon
	call 	printf
	cmp 	seconds,10
	jae 	continuePrintTime3

	lea 	bx,digitZero
	call 	printf

continuePrintTime3:
	lea		bx,secondsTXT
	call 	printf
	ret
printTime 	endp


; ========== CONVERTTIME:
; converts to string the ints seconds, minutes and hours
convertTime 	proc near
	lea 	bx,secondsTXT
	mov		ax,seconds
	call 	itoa
	lea 	bx,minutesTXT
	mov 	ax,minutes
	call 	itoa
	lea 	bx,hoursTXT
	mov 	ax,hours
	call 	itoa
	ret
convertTime 	endp


; ========== FPRINTF:
; String(DS:SI)
; prints a string in the file
fprintf 	proc near
	mov 	bx,fileHandle
	mov		dl,[si]
	cmp		dl,0
	je 		fprintf_end

	call 	setChar
	inc		si
	jmp 	fprintf

fprintf_end:
	ret
fprintf 	endp


; ========== FPRINTTIME:
; File Handle (BX)
; prints in the file what is in hours, minutes, seconds
fprintTime 	proc near
	cmp 	hours,10
	jae 	continuefPrintTime1

	lea 	si,digitZero
	call 	fprintf

continuefPrintTime1:
	lea		si,hoursTXT
	call 	fprintf
	lea 	si,colon
	call 	fprintf
	cmp 	minutes,10
	jae 	continuefPrintTime2

	lea 	si,digitZero
	call 	fprintf

continuefPrintTime2:
	lea		si,minutesTXT
	call 	fprintf
	lea 	si,colon
	call 	fprintf
	cmp 	seconds,10
	jae 	continuefPrintTime3

	lea 	si,digitZero
	call 	fprintf

continuefPrintTime3:
	lea		si,secondsTXT
	call 	fprintf
	lea 	si,endString
	call 	fprintf
	ret
fprintTime 	endp


; ========== READPARAMETER:
; String (DS:BX) -> Int (CF)
; reads the parameter from cmd line and returns 0 if the parameter was correct
readParameter 	proc near
	mov 	counter,0
	mov		al,[bx+di]
	mov 	char,al
	add 	di,2
	push 	di
	lea 	si,[bx+di]
	cmp 	char,"i"
	jne		testOutput

	lea 	di,fileIn
	cld
	call 	getSubString
	mov 	ax,counter
	mov 	fileInSize,ax
	pop 	di
	clc
	ret

testOutput:
	cmp 	char,"o"
	jne		testTension

	lea 	di,fileOut
	cld
	call 	getSubString
	mov 	ax,counter
	mov 	fileOutSize,ax
	pop 	di
	clc
	ret

testTension:
	cmp 	char,"v"
	jne 	errorParameter

	lea 	di,tension
	cld
	call 	getSubString
	mov 	tensionOk,1
	pop 	di
	clc
	ret

errorParameter:
	pop 	di
	stc
	ret
readParameter 	endp


; ========== NEXTLINE:
; reads a full line of the file
nextLine 	proc near
	mov		bx,fileHandle2
	call 	getChar
	cmp 	al,0
	je 		endNextLine

	cmp 	dl,CR
	je 		nextLineLoop

	cmp 	dl,LF
	je 		nextLineLoop

nextLineLoop:
	mov		bx,fileHandle2
	call 	getChar
	cmp 	al,0
	je 		endNextLine

	cmp 	dl,CR
	jne 	checkLineFeed

	ret

checkLineFeed:
	cmp 	dl,LF
	jne 	nextLineLoop

endNextLine:
	ret
nextLine 	endp


; ========== FPRINTLINE:
; prints the line in the file
fprintLine 	proc near
	mov 	bx,fileHandle2
	call 	getChar
	cmp 	al,0
	je 		endFindLine

	cmp 	dl,CR
	je 		printLoop

	cmp 	dl,LF
	je 		printLoop

	mov		bx,fileHandle
	call 	setChar

printLoop:
	mov 	bx,fileHandle2
	call 	getChar
	cmp 	al,0
	je 		endPrintLoop

	cmp 	dl,"f"
	je		endPrintLoop

	cmp 	dl,"F"
	je 		endPrintLoop

	cmp 	dl,CR
	je 		endPrintLoop

	cmp 	dl,LF
	je 		endPrintLoop

	mov 	bx,fileHandle
	call 	setChar
	jmp 	printLoop

endPrintLoop:
	ret

fprintLine 	endp

; ========== CLEARNUMBER:
; clears variable number
clearNumber 	proc near
	lea 	si,number
	mov 	cx,5

loopClearNumber:
	mov 	byte ptr [si],0
	inc 	si
	loop 	loopClearNumber

	ret
clearNumber 	endp


; ==================== END OF PROGRAM ====================
    end