; ------------------------------------------------------------------------------
; AssyBoot, Bootloader for ATMega 328 style processors 
; ------------------------------------------------------------------------------
; Author: J.F. Bron
; Date 31-05-2026
; Version 1.0
; ------------------------------------------------------------------------------
; Fuse settings for burning the Bootloader
; ------------------------------------------------------------------------------
; When burning the program the fuses must be set: (See notes below)
; Lock Bits,	Advised: Set to 0xFF	Bootloader will change this to 0xEF
; LFuse:		Advised: Set to 0xFF	Use Low Power X-Tal,no Prescaler, Low Power X-Tal.
; HFuse:		Advised: Set to 0xDE	Boot section 256 Words, Reset vector = boot section
; EFuse:		Advised: Set to 0xFD	Minimum voltage  2.7 Volt, Lower = Reset
;
; IMPORTANT: DO NOT SET TTHE LOCK Byte to 0x0F, this will disable the User Call Feature
; ------------------------------------------------------------------------------
;	Superfast serial speed settings, easy to change
;	Fast serial interface Speed: 1M (1000000) 
;   Compatible speed:		     115K2    		
;
;   The user writable code size is 31744 bytes
;
; Written in AVR Assembler for optimal performance, only 256 Words, 512 Bytes.
; Improved Code supports Flash, EEprom, Fuses, Lock bits, Processor ID
; Also allows User tor read/write Pages to/from Flash and EEProm using.   
; -----------------------------------------------------------------------------
; New Features in this Bootloader:
; - Programs both Flash  and EEProm
; - Uses a Smart-Write algorithm, ally overwrites Data when needed
;   This speeds-up programming, and expands the processor Lifetime
;   because tho total nr of writes is limited
; - Reads ID's an Fuses from the Processor chip, no simulated values
; - Sets the Lock bit to protect the Bootloader for modifications when not set
; - Alows a user program to use the Bootloaders Read and Write functions to
;   Read/rite Flash and EEprom Pages (128 Bytes for Flash, 4 Bytes for EEProm) 
; ------------------------------------------------------------------------------
; Compatible for all ATmega 328 variants, Bootloader reads ID's and Fuses
; from chip since to Processors ID is read from hardware, not pre-defined in Code  
; ------------------------------------------------------------------------------
; for optimal fault tolerance end Maximum speed performance.
; -------------------------------------------------------------------------------
; Compatibility
; -------------------------------------------------------------------------------
; The program is Backwards compatible with the Optiboot version as used in the
; current Arduino Uno and Arduino Nano bootloaders, using the STK500 protocol
; To take advantage of High speed, More Free user Flash, minor changes 
; must be made in the boards.txt file. Also read the Notes on the LOCK bits !!!!
; -------------------------------------------------------------------------------
;
; User Definitions: the Bootstart is set to "Smallbootstart" 
; When using a different processor (. e. ATMega128) thiscan be modified
;
; Definitions, for ATMega 328(P)(B). The Baudrate is specified in the next part.
; EEPromSize EEPromSize ans smallbootstart are taken from the processor .inc file

	.equ	FlashPageSize	= 2* PAGESIZE	; Max no of bytes for a Flash Write.
	.equ	EEpromSize		= 1<<EEADRBITS	; Size of the EEprom. 

	.equ	BootStart	= smallbootstart; loc Bootstart (Word addres)
	.equ	UserProg	= 0x0000		; Startvector for User Application

; For the Usart, the Clock devider in the UBBR Registers must be set, according to the chosen Baudrate.
; Values below reflect the values for a 16 MHz Clock at 2x Speed.
; So With a different Baudrate/Clock this also must be adjusted

	.equ	UBRR_115K	=	16			; Value near 115K2 speed (117.5) error 2.1 % with 2x speed
	.equ	UBRR_38K4	=	25			; Value near 38K4  speed (38.46) error 0.2 % with 2x speed       	
	.equ	UBRR_57K6	=	34			; Value near 57K6  speed (57.14) error 0.2 % with 2x speed
	.equ	UBRR_1M		=	1			; value for 1 Mhz speed at 2x speed

; Serial Interface Definitions 

	.equ	UCSRA_2x	=	0x02		; Value for Serial Interface at 2x speed
	.equ	UCSRB_On	=	0x18		; Value for enable Tx and Rx
	.equ	UCSRC_8N1	=	0x06		; Value for Async, no Parity, 8 data, 1 Stop

; ------------------------------------------------------------------------------
; set the desired speed settings below		 
; ------------------------------------------------------------------------------
	
	.equ	UCSRA_Value	=	UCSRA_2x	; Value used
	.equ	UCSRB_Value	=	UCSRB_On	; control
	.equ	UCSRC_Value	=	UCSRC_8N1	; Value for settings
	.equ	UBRR_Value 	=	UBRR_1M		; Selected Baudrate 1 Mbit/sec

; Watchdog and startup condition Definitions
; the watchdog timer is reset after every serial activity (Read or Write action)
; The selected time-out can be changed, 1 Sec is a safe value
; the watchdog is disabled before entering the user application

	.equ	MCUSR_Reset	=	0x00		; Value to reset all boot flags
	.equ	WDT_Off		=	0x00		; Value for Watchdog Disabled
	.equ	WDT_1Sec	=	0x0E		; Value for Enabled, 1 Sec
	.equ	WDT_2Sec	=	0x0f		; Value for Enabled, 2 Sec
	.equ	WDT_16mSec	=	0x08		; Value for Enabled, 16 mSec
	.equ	WDT_Select	=	WDT_1Sec	; Timeout Bootloader
	.equ	WDT_Unlock	=	0x18		; Value to change Watchdog settings

; control chars STK500 

	.equ	Char_Sync	=	0x14		; In Sync character
	.equ	Char_OK		=	0x10		; Ok, reply
	.equ	Char_EoP	=	0x20		; End of command char (Space)	

; Command and subcommands
	
	.equ	Cmd_Version	=	0x41		; 0x41 Version request: 'A'
	.equ	Cmd_Major	=	0x81		; 0x81 Request Major Version
	.equ	Cmd_Minor	=	0x82		; 0x82 Request Minor Version
	.equ	Cmd_Device	=	0x42		; 0x42 Set Device command 'B'
	.equ	Cmd_ExtDev	=	0x45		; 0x45 Set Extended Device command 'E'
	.equ	Cmd_Addr	=	0x55		; 0x55 Command Set Addres 'U'	
	.equ	Cmd_Uni		=	0x56		; 0x56 Universal command 'V'
	.equ	Cmd_WPage	=	0x64		; 0x64 Write Flash Page command 'd'
	.equ	Cmd_RPage	=	0x74		; 0x74 Read Flash command 't'	
	.equ	Cmd_Sign	=	0x75		; 0x75 Read Signature 'u'
	.equ	Cmd_Quit	=	0x51		; 0x51 Exit program mode and reboot 'Q'	
	.equ	Type_Flash	=	0x46		; Specifier for Flash  in Buffer 'F'	(only Bit 0 is used)
	.equ	Type_EEprom =	0x45		; Specifier for EEprom in Buffer 'E'	(only Bit 0 is used)

; Version number
	
   .equ		Vers_Minor	= 	0x04		
   .equ		Vers_Major	= 	0x03		

; Programming commands for SPM/LPM instruction

	.equ	Spm_Erase	= 	0x03		; Erase page command
	.equ	Spm_Write	= 	0x01		; Write to flash buffer
	.equ	Spm_Save	= 	0x05		; Save buffer to Flash
	.equ	Spm_Free	= 	0x11		; Release Flash for reading
	.equ	Spm_RdID	= 	0x21		; Read ID Locations
	.equ	Spm_RdFuse	= 	0x09		; Read Fuse locations

; Position of ID bytes and Calibration byte in ID Row
	
	.equ	Loc_Id1		=	0x00		; Location ID Byte 1 in Reading ID 			
	.equ	Loc_Id2		=	0x02		; Location ID Byte 2 in Reading ID 
	.equ	Loc_Id3		=	0x04		; Location ID Byte 3 in Reading ID 
	.equ	Loc_Tun		=	0x01		; Location Osc Tune  in Reading ID 	

; Position of Fuses and Lock

	.equ	L_Fuse		=   0x00		; Position LFUSE
	.equ	H_Fuse		=   0x03		; Position HFUSE
	.equ	E_Fuse		=   0x02		; Position EFUSE
	.equ	Lock_Fuse	=	0x01		; Position LOCK

; Register Usage:

	.def	SmpL		=	r0			; Data for SMP Write LSB Byte
	.def	SmpH		=	r1			; Data for SMP Write MSB Byte

	.def	DataByte	=	r16		    ; Input/Output/Data Byte
	.def	Command		= 	r17			; Command

	.def	MemType		=	r18			; Flash or EEprom (Even=Flash, Odd=EEprom)
	.def	Temp		=	r19		    ; General Temp 

	.def	Count		=	r20			; Counter
	.def	CountS		=	r21			; Counter Bacbup
	
	.def	SBufL		=	r22			; Ram Buffer LSB	
	.def	SBufH		=	r23			; Ram Buffer MSB
 	
	.def	SAddrL		=	r24			; Save Page Addres Low  for Flash Erase/Save
	.def	SAddrH		=	r25			; Save Page Addres High for Flash Erase/Save

	
;	X Pointer to RAM 	
;	Z Pointer to Flash / EEprom, also used to read Fuses, lock bits and ID

; ------------------------------------------------------------------------------
;	Data Segment
; ------------------------------------------------------------------------------

	.dseg

	RamBuf:	.byte	256					; Reserve Ram Bytes for Buffer

; ------------------------------------------------------------------------------
;	Code Segment
; ------------------------------------------------------------------------------

	.cseg
	.org	Bootstart					; Start Bootloader	

Start_Boot:

; test Lockbits, Bootsector must be protected

	ldi		ZL,			Lock_Fuse		; Select Lock Fuse
	ldi		Command,	Spm_RdFuse		; Read/Write-Fuse command
	rcall	Read_ID

	sbrs	DataByte,	BLB11			; Skip if not programmed
	breq	Test_Boot					; fuse bits programmed, continue
	
	ldi		DataByte,	0xEF			; Desired Fuse setting	
	mov		SmpL,		DataByte		; Save in SmpL (r0)
	rcall   Spm_Cmd						; Write Lock Byte

; Get boot status to determ the cause of entering the Boot Sector

Test_Boot:

	in		r0,			MCUSR			; Read status
	out		MCUSR,		ZH				; Clr boot flags (ZH is zero after Read_ID)
	sbrc	r0		,	EXTRF			; boot caused by Extern Reset input ?
	rjmp	Bootloader					; Yes, start Bootloader
	
	ldi		Command,	WDT_Off			; command stop WDT			
	rcall	Set_WDT						; Stop Watchdog Timer
	jmp		UserProg					; Start User program

Bootloader:
	
;  // Set up watchdog to trigger after +/- 1 Sec

	ldi		Command,	WDT_Select		; Watchdog Selected Time-out
	rcall	Set_Wdt						; Set

; Init Serial Interface

Init_Serial:

	ldi		Temp,		High(UBRR_Value);	
	sts		UBRR0H,		Temp			; Set MSB Baudrate	
	ldi		Temp,		Low(UBRR_Value)	;
	sts		UBRR0L,		Temp			; Set LSB Baudrate	
	ldi		Temp,		UCSRA_Value		 
	sts		UCSR0A,		Temp			; Set 2x Speed	
	ldi		Temp,		UCSRC_Value		
	sts		UCSR0C,		Temp			; Set Format 8N1
	ldi		Temp,		UCSRB_Value		
	sts		UCSR0B,		Temp			; Enable Rx and TX

; -----------------------------------------------------------------------------
; Set RAM Buffer Addres for Bootloader.
; When using external Calls, this pointer will point to the User Buffer 
; Max 3 chars. First received command will be lost 
; -----------------------------------------------------------------------------

Main_Init:

	ldi		SBufL,		Low( Rambuf)	; Pointer to RAM Buffer			
	ldi		SBufH,		High(RamBuf)	; MSB Pointer		

// Start Comms by waiting for a <EoP> cahracter
	
	ldi		Count,		3				; Max 3 attempts

Main_Init_Loop:

	rcall	Read_Byte					; get char 
	cpi		DataByte,	Char_EoP		; compare
	breq	Main_loop					; Yes, start bootloader
	dec		Count						; Dec Counter
	brne	Main_Init_Loop				; Loop if not zero
	rjmp	Reboot_Cmd					; not found, reboot

Main_Loop:

; get character from Serial Interface

	rcall	Read_Byte					; Get Character
	mov		Command,	DataByte

; ------------------------------------------------------------------------------
; Command = Send version
; read next char in R16; This must be followed by a <EoP> char   
;
; command = <0x41> <Type> <EoP>
; respons with Type = <0x81> or <0x82>: <Sync> <0x04> <OK>
; respons for other values				<Sync> <0x03> <OK>
;
; Continues with Send_Reply and Send_Ok
; ------------------------------------------------------------------------------

	cpi		Command,	Cmd_Version		; Compare with Versie request 0x41
	brne	Device_Cmd					; if not, next command

	rcall	Read_Byte					; Get next char
	mov		Command,	DataByte		; parameter requested in Command
	rcall	Get_EoP						; check for a valid record
	
; Check second char, the parameter 	
; If Major version is requested, reply Major Version,
; Else reply Minor Version

	ldi		DataByte,	Vers_Major
	cpi		Command,	Cmd_Major		; Request for Major Version ?
	breq	Send_Reply					; Yes, Send 
	ldi		DataByte,	Vers_Minor		; Version Minor

; ------------------------------------------------------------------------------
; Send_Reply sends the char in DataByte, followed by a char_Ok
; after completions returne to the Mainloop
; Continues with Send_OK
;
; Critical : This function is placed direct after_Cmd_Version
; do not move without adding a rjump instruction to Cmd_Verion
; ------------------------------------------------------------------------------

Send_Reply:

	rcall	Write_Byte					; Send reply byte

; ------------------------------------------------------------------------------
; Send_OK sends a OK Char
; Then returns to the MainLoop.
; This is the last part for every command, except for the Quit command
;
; Critical : This function is placed direct after Send_Reply
; do not move without adding a rjump instruction to Send_Reply
; ------------------------------------------------------------------------------

Send_OK:

	ldi		DataByte,	Char_OK			; OK Char
	rcall	Write_Byte					; send
	rjmp	Main_Loop

; ------------------------------------------------------------------------------
; cmd B: Set Device is ignored
; Cmd E: Set Extended is ignored
; Format Cmd Device 	<0x42> <20 Ignored Bytes> <EoP>
; Format Cmd ExtDev		<0x45> <cnt> < Cnt-1 Ignored Bytes> <EoP>
; Respons				<sync> <OK>
; No action taken with these commands
;
; Continues with Send_Ok
;
; Critical : This function is placed direct after Send_OK
; do not move without adding a rjump instruction to Send_OK
; ------------------------------------------------------------------------------- 	

Device_Cmd:				
		
	cpi		Command,	Cmd_Device		; test for 'B' Set Device command	
	brne	Extended_Cmd				; If not, next test
	
; Ignore 20 chars, then test for space
	
	ldi		Count,		20				; No of chars = 20
	rjmp	Cmd_Ignore					; ignore chars + <EoP>, send OK 	
	
Extended_Cmd:
	
	cpi		Command,	Cmd_ExtDev		; Test for 'E' Set Extended Device
	brne	Addr_Cmd					; If not, next test 

	rcall	Read_Byte					; get char with no of bytes to be ignored
	mov		Count,		DataByte		; Ignore the no of bytes 
	dec		Count						; The byte itselve is included, so minus 1
		
Cmd_Ignore:

	rcall	Ignore_Bytes				; Ignore bytes, test for <EoP> to follow	
	rjmp	Send_OK						; Finish Command

; ------------------------------------------------------------------------------
; CMD U	load Addres
; format <0x55 <Low Addr Byte> <High Addr Byte> <EoP>
; reply	<Sync> <OK> 
; addres in the Z,  with with conversion for word to byte addres
;
; continues with Cmd_Other to check for <E0P> and send a <Ok>
; ------------------------------------------------------------------------------

Addr_Cmd:

	cpi		Command,	Cmd_Addr		; Test for address Command set Addres 
	brne	Universal_Cmd				; If not, try next command			
 
Get_Address:
 									
	rcall	Read_Byte					; get Addres LSB
	mov		ZL,			DataByte		; Addres Low byte
	rcall	Read_Byte					; Get Addres MSB 	
	mov		ZH,			DataByte		; Address High Byte
	lsl		ZL							; convert word to byte addres
	rol		ZH							; by shifting one bit left
	rjmp	Cmd_Other					; Finish with Check, Sync, OK 

; ------------------------------------------------------------------------------
; Universal command, used for direct commands
; is used to send fuses and other data specs
; Format	<0x56> < 4 Bytes> <EoP>	 	
; Respons	<sync> <Reply> <OK>	
;
; Always respons, no check on invalid requests
;
; LFUSE:	<0x56> <0x50> <0x00> <0x00> <0x00> <EoP>	location : 0
; EFUSE:	<0x56> <0x50> <0x08> <0x00> <0x00> <EoP>	location : 2
; Lock:		<0x56> <0x58> <0x00> <0x00> <0x00> <EoP>	Location : 1
; HFUSE:	<0x56> <0x58> <0x08> <0x00> <0x00> <EoP>	Location : 3
;
; We are only interested in the first two Bytes,
; Because it is only used to read fuses 
; we don't check all possible values
; ------------------------------------------------------------------------------	

Universal_Cmd:

	cpi		Command,	Cmd_Uni			; Compare with Universal Command
	brne	WritePage_Cmd				; if not, Next
	
; Read 4 chars, test for valid record

	clr		ZL
	rcall	Read_Byte					; First byte contains bit o of the fuse selected
	sbrc	DataByte,	3				; skip if not Lock or High Fuse
	sbr		ZL,			0x01			; Lock or High fuse

	rcall	Read_Byte					; Second Byte contains bit 1 of the selected Fuse
	sbrc	DataByte,	3				; Skip if not Extended or High Fuse
	sbr		ZL,			0x02			; Extended or High Fuse	

	rcall	Read_Byte					; Ignore Byte 3
	rcall	Read_Byte					; Ignore Byte 4

; Test for <Eop> 

	rcall	Get_EoP

	ldi		Command,	Spm_RdFuse		; Command for reading Fuses
	rcall	Send_ID						; Send requested Fuse/lock
	rjmp	Send_OK						; Finish

; ------------------------------------------------------------------------------
; Write Page buffer Flash / EEprom
; write Page to Flash or EEprom memory
; Format:	<0x64> <CntH> <CntL> <Type> <cnt Data Bytes> <EoP>
; Reply:	<Sync> <OK> 
; Type 'F' (Even)  = Flash, 'E' (Odd)  = Eeprom
;
; On completion, the function continues with Send_Ok
; ------------------------------------------------------------------------------

WritePage_Cmd: 									
	
	cpi		Command,		Cmd_WPage	; Write Page Command ?
	brne	ReadPage_Cmd				; If not, next command

	rcall	Read_BufSpecs				; get count and memory type

; now copy input data to RamBuf

	movw	X,			SbufL			; Set X to RAM buffer
	mov		CountS,		Count			; Backup Count

; read bytes and store in RAM 
	
WritePage_Read:
		
	rcall	Read_Byte					; get byte to program
	st		X+,			DataByte		; save in Ram
	dec		Count						; Dec counter 
	brne	WritePage_Read				; Next until Counter = 0

; Restore ByteCount 	

	mov		Count,		CountS			; Restore Count

; all chars in buffer, check for valid record

	rcall	Get_EoP						; check

	call	WritePage					; Call Actual Write routine
	rjmp	Send_OK						; Finish command

; ------------------------------------------------------------------------------
; Read Page
; format:	<0x74> <CntH> <CntL> <Type> <EoP>
; Type 'E' = EEprom, 'F' = Flash
; (We only look at Bit 0)
; Reply:	<Sync> <Cnt Data Bytes> <OK>
;
; Continues with Send_Ok
; ------------------------------------------------------------------------------

ReadPage_Cmd:
  
	cpi		Command,		Cmd_RPage	; Read Page command ?
	brne	Signature_Cmd				; If not, next command

	rcall	Read_BufSpecs				; Read in no of bytes and type
	rcall	Get_EoP						; check for valid record

ReadByte_Loop:							; Reading Flash or EEprom

	rcall	Get_Byte					;
	rcall	Write_Byte					; Send char to serial interface
	dec		Count						; Dec Bytecount
	brne	ReadByte_Loop				; repeat until all bytes done
	rjmp	Send_OK

Get_Byte:								; Also used in External Call

	sbrs	MemType,		0			; skip if Odd (EEprom)
	lpm		DataByte, 		Z 			; Read from Flash
	sbrc	MemType,		0			; Skip if Even (Flash)
	rcall	EE_Read						; Read EEProm
	adiw	Z,				1			; Inc Z Pointer to next byte
	ret

; ------------------------------------------------------------------------------
; Command Read Signature 
; function will read the ID Bytes from the processor
;
; Format:	<0x75> <EoP>
; Reply:	<Sync> <ID Byte 1> <ID Byte 2> <ID Byte 3> <OK>
;
; Function continues with Send_Ok
; ------------------------------------------------------------------------------

Signature_Cmd:

	cpi		Command,	Cmd_Sign		; Test for Signature command
	brne	Quit_Cmd					; If not, next command

; Check for valid record, send ID bytes 
	  
	rcall	Get_EoP						; check for valid record

	ldi		Command,	Spm_RdID		; Read ID Row command
	ldi		ZL,			Loc_Id1			; loc ID Byte 1
	rcall	Send_ID						; Send
	ldi		ZL,			Loc_Id2			; Loc ID Byte 2
	rcall	Send_ID						; Send
	ldi		ZL,			Loc_Id3			; Loc ID Byte 3
	rcall	Send_ID						; Send
	rjmp	Send_Ok						; finish with OK byte

; ------------------------------------------------------------------------------
; Quit:	exit program mode, reboot to user app
;
; Format <0x51> <EoP>
; Reply	 <Sync> <OK>	
;
; continues with Reboot_Cmd
; ------------------------------------------------------------------------------

Quit_Cmd:

	cpi		Command,	Cmd_Quit		; compare with Exit Program command
	brne	Cmd_Other					; if not, other command

	Rcall	Get_EoP			

	ldi		DataByte,	Char_OK			; send OK to confirm
	rcall	Write_Byte					; send

; ------------------------------------------------------------------------------
; CMD Reboot
; Reboot by causing a WDT timeout
;
; Critical : This function is placed direct after CMD_Quit
; do not move without adding a rjump instruction to CMD_Quit
; ------------------------------------------------------------------------------

; set WDT to shortest value, this will cause a fast reset 

Reboot_Cmd:								; Error or Reboot Command, reboot
										
	ldi		Command,	WDT_16mSec		; Value for shortest WDT
	rcall	Set_Wdt						; Set

Reboot_Wait:

	rjmp	Reboot_Wait					; Wait for WDT Reset, causing a reboot

; ------------------------------------------------------------------------------
; Cmd_Other:  handles all other commands without parameters
; Format:	<Cmd> <EoT>
; Reply:	<Sync> <OK>
; Just acknowledge, no action taken
;
; This must be the last command in the command chain
; ------------------------------------------------------------------------------

Cmd_Other:

	rcall	Get_EoP						; test record to be valid
	rjmp	Send_OK						; if single byte cmd, ignore command

; ------------------------------------------------------------------------------
; EE_REad: Read one byte from EEprom. Result DataByte
; Z holds the address to the EEprom addres
; After Writing, the write routine waits for the EE write to finish
; so we don't have to wait here 
; ------------------------------------------------------------------------------

EE_Read:

	sbic	EEcr,		EEpe			; Wait until ready
	rjmp	EE_READ						; Keep waiting if not
	out		EEARH,		ZH				; Addres High
	out		EEARL,		ZL				; Addres Low			
	sbi		EECR,		EERE			; Read
	in		DataByte,	EEDR			; load byte from EEprom 
	ret

; ------------------------------------------------------------------------------
; subroutine to send a command in Command to SPM
; This requires a specific timing and sequence.
; The bootloader doesn,t use interrupts, so this part is ommitted  
; The SPM command Uses the Z register for adressing the data
; and the SmpH:SmpL registers (R1:R0) to transfer Data 
; ------------------------------------------------------------------------------

Spm_Cmd:

	in		Temp,	SPMCSR				; Get status
	sbrc	Temp,	SPMEN				; Check busy flag	
	rjmp	Spm_Cmd						; Wait until free
										; Critical sequence, do not change
	out		SPMCSR,		Command			; Get command
	spm									; execute command
	ret									; Return

; ------------------------------------------------------------------------------
; Subroutine for Read Page and Write Page
; Only read the LSB in Count and the record type is placed in Command 
; ------------------------------------------------------------------------------

Read_BufSpecs:

	rcall	Read_Byte					; MSB Counter (Ignore), 
	rcall	Read_Byte					; LSB Counter (zero is handled as 256 Bytes)
	mov		Count,		DataByte		; SaveCount
	rcall	Read_Byte					; Memory type
	mov		MemType,	DataByte		; Store Type in Memtype
	ret

; ------------------------------------------------------------------------------
; Ignore_Bytes skip n chars, next char must be a EoP char
; XL holds the no of chars to be skipped. Is zero after completion
; 
; Continues with Get_EoP
; ------------------------------------------------------------------------------

Ignore_Bytes:	

	rcall	Read_Byte					; (next) char
	dec		Count						; Decrement Counter
	brne	Ignore_Bytes				; Repeat until Cnt=0
		
; ------------------------------------------------------------------------------
; Get_EoP reads a char and compares it with EoP, Acknoledge with <Sync>
; If Equal a SYNC char is transmitted
; If not found, program exits (Reboot) via Reboot_Cmd
; continues with Write_Byte
;
; Format:	<Eot>	
; Reply:	<Sync>
; Any other input char : Reboot
;
; Critical : This function is placed direct after Ignore_Bytes
; do not move without adding a rjump instruction to Ignore_Bytes
; ------------------------------------------------------------------------------s

Get_EoP:
	
	rcall	Read_Byte					; Get char, must be EoP 
	cpi		DataByte,		Char_EoP	; EoP char ?
	brne	Reboot_Cmd					; If not, exit bootloader
	ldi		DataByte,		Char_Sync	; Else send a sync char to acknowledge

; ------------------------------------------------------------------------------	
; Write_Byte	 
; Send a char to the serial interface and reset the Watchdog Timer
; Input : DataByte
;
; Critical : This function is placed direct after Get_EoP
; do not move without adding a rjump instruction to Get_EoP
; ------------------------------------------------------------------------------

Write_Byte:								; Send char to serial interface
									
	lds		Temp,			UCSR0A		; Get transmitter status	
	sbrs	Temp,			UDRE0		; Test Transmit buffer available flag
	rjmp	Write_Byte					; Repeat until free
	sts		UDR0,			DataByte	; Send Char to serial interface
	wdr									; Reset Watchdog
	ret									; Return

; ------------------------------------------------------------------------------
; Read_Byte: Read a byte from the serial interface
; Returns char received Char in DataByte
; if buffer valid, the watchdog timer is cleared
; Uses Temp
; ------------------------------------------------------------------------------	

Read_Byte:								; Get Byte from serial interface
	
	lds		Temp,		UCSR0A			; Read status	
	sbrs	Temp,		RXC0			; Test for char in buffer
	rjmp	Read_Byte					; wait for char	

	lds		DataByte,	UDR0			; Get char from interface

	sbrc	Temp,		FE0				; Framing Error Detected ?
	rjmp	Read_Byte					; Yes, ignore char			

	wdr									; clr watchdog timer
	ret									; Return

; ------------------------------------------------------------------------------
; Put ID send the requested Hardware ID Byte or Fuse the serial interface
; Input:	Command holds the Read ID or Read_Fuse command to select the Row
;			ZL holds the requested byte	
; Output:	DataByte
;
; Locations in Row ID:
;	0 = Id Byte 1,	2= ID Byte 2,	4 = ID Byte 3,	1 = Calibration Osccal
; Locations in Row Fuses	 
;	0 = LFuse		2 = EFuse,		3 = HFuse,		1 = Lock bits
;
; Continues with Write_Byte
; ------------------------------------------------------------------------------
	
Send_ID:

	rcall	Read_ID						; Get ID Byte Selected
	rjmp	Write_Byte					; Send

Read_ID:								; Also called for Reading Fuses 

	clr		ZH							; must be zero
	out		SPMCSR,		Command			; ID Row or Fuse Row
	lpm		DataByte,	Z				; Read into DataByte
	ret

; Extern entry

Extern_Entry:							; Start for call from userprogram

; on entry SaddrL holds the page nr	
; and Count the Page Size
; SBufH:SbufL holds the pointer to the RAM buffer
; Memtype hold a even nr for Flash, and aa Odd nr for EEPROM 
; So we have to calculate the PAge addres
; On Entry Memtype holds: (only bits 0 and 1 are tested, so bits 2..7 are irrelevant)
; 0x00 = Flash Write,	0x01 = EEprom Write
; 0x02 = Flash Read,	0x03 = EEprom Read	
; 
; start Addres (in Bytes) is Page nr * Page Size

  mul	Count,		SaddrL				; Page addres = PageNr*PageSize
  movw	Z,			r0					; Move result to Z pointer
  sbrc	MemType,	1					; skip if write
  rjmp	Readpage						; Read Page	

WritePage:

; set x back to start of RAM and Z with Flash/EEprom addres
; and load Counter in X, Address in Z, Buffer pointer in Y;
 
; Write to Flash or EEprom, depending on Command
; Flash = 'F' (0x46), EEprom = 'E'(0x45).
; we only test for bit 0,
; so even = Flash, Odd = EEProm 
  
    movw	X,			SBufL			; Set X to (user) Ram Buffer
 
    sbrc	MemType,	0				; if even WriteFlash				
	rjmp	WriteEEProm;				; Else WriteEEprom

; The T bit is used to decide for writing or skip write
; Initial this bit is set so zero
; if any new byte differts from the old one, this bit is set
; So if the bit is stilla zero after filling all latches
; the Erase and Write can be skipped, because old Data = New Data.
; However the Free command must be executed to clear the Latches

WriteFlash:
    
	movw	SADDRL,		Z				; Backup Z pointer for ERASE/WRITE/FREE
	clt									; Clear T-Bit
	
WriteFlash_Loop:	

	ld		SmpL,		X+				; Read 1st byte from RAM
	dec		Count						; Dec Bytecount
	breq	WriteFlash_Out				; All bytes received (Odd count)
	ld		SmpH,		X+				; Get second Byte from RAM
	dec		Count						; Dec Bytecount
	
WriteFlash_Out:	

	lpm		Temp,		Z+				; Read old LSB
	cpse	Temp,		SmpL			; different ? Skip Next
	set									; Set Flag : different
	lpm		Temp,		Z+				; Read Old MSB
	cpse	Temp,		SmpH			; different ? Skip Next
	set									; Set Flag : different
	sbiw	Z,			2				; Set Z register back to start position		
		
	ldi		Command,	SPM_Write		; Write to Latches command
	rcall	Spm_Cmd						; Execute
	
	adiw	Z,			2				; Adjust Z pointer to next word
	tst		Count						; All Bytes written to latches ?
	brne	WriteFlash_Loop				; No, loop back

; Load page number

	movw	Z,			SAddrL			; Restore original Addres
	brtc	WriteFlash_Free				; Skip erase/Write if nothing has changed
	
	ldi		Command,	SPM_Erase		; erase command
	rcall	SPM_Cmd						; execute

	ldi		Command,	Spm_Save		; command to write the Latches to Flash		
	rcall	Spm_Cmd						; execute

WriteFlash_Free:

	ldi		Command,	SPM_Free		; Needed to re-enable access to RWW
	rcall	Spm_Cmd						; execute
	
WriteFlash_End:
		
 	ret									; return

WriteEEProm:							; Writing outside boubdary is not allowed
										; Otherwise undesired data can be overwritten
	cpi		ZH,		High(EEPromSize)	; compare with End EEprom
	brsh	WritePage_End				; Skip if outside EEprom
	
	rcall	EE_Read						; Read old value
	mov		Temp,		Databyte		; save old
	ld		DataByte,	X+				; New value
	cp		DataByte,	Temp			; are the same ?
	breq	WriteEEprom_Next			; No action required

WriteEEProm_Out:
		
	out		EEdr,		DataByte		; Save
	sbi		EEcr,		EEmpe			; Unlock Write
	sbi		EEcr,		EEpe			; Write
		
WriteEEprom_Wait:						; Wait until write is done

	sbic	EEcr,		EEpe			; Wait until ready
	rjmp	WriteEEprom_Wait			; Keep waiting if not

WriteEEprom_Next:

	adiw	Z,			1				; Inc Pointer to EEprom 
	dec		Count						; Dec Byte Count 
	brne	WriteEEprom					; until all Bytes written

WritePage_End:

	ret									; return

ReadPage:

   movw		X,		SBufL				; Set X to (user) Ram Buffer

ReadPage_Loop:
 
	rcall	Get_Byte					; Get Byte (Flash or EEprom)
	st		X+,			DataByte		; Store in Buffer
	dec		Count						; dec Counter
	brne	ReadPage_Loop				; Until Done
	ret									; return

; ------------------------------------------------------------------------------
; Set_Wdt
; Set watchdog timer to value specified in Command
; uses Temp
; ------------------------------------------------------------------------------

Set_Wdt:	

	ldi		Temp,		WDT_Unlock		; Value for change
	sts		WDTCSR,		Temp			; Enable Write	
	sts		WDTCSR,		Command			; Value desired
	ret									; Done

.org FLASHEND

	rjmp	Extern_Entry				; jumo for User Program to Resd/Write

; ------------------------------------------------------------------------------
; End of program
; ------------------------------------------------------------------------------
	