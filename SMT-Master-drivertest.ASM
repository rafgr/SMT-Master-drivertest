
;
;
;
; Program:      MASTER.ASM
;
; Author:       D. Sebastian
;
; Date:         9 August 1991
;

;                            mode 2
;            2  20 Sep 91    Added mode 7 for real

;                            when message greater than line
;                            length is passed
;            5  30 Mar 93    Dont try to print control chars,
;                            stop losing msgs & clean up start
;                            of scroll. Add alternate capability
;            6  11 May 93    Dont send null msgs to boards
;
;            8   1 Feb 94    Throw out timed msgs when Write
;                            immediately comes in.  Add Serial
;                            reset and new page messages for
;                            extrusion scoreboard.  Add ability
;                            to set alternate time.
;
;            10 20 Dec 96    Decreased availiable buffers to 4
;                            increased lines to 16
;            2.0 1-15-20     This is the new version for the smt board with
;			 	 			 surface mount parts AND ALTERNATING BUFFER CHANGED FROM #7 TO #3
;
;			 2.1 10-4-23     Icreased the sioQsize fro 60 h to d0 h		
;            11/2/2026		 This is the modified master to use on the diode driver
;			 				 test stand to show scrolling message 	  		 		     	
;
; COPYRIGHT IST 1991 - 2023
;
;
;		CPU     "MC9s08gw64 "
;	
;
;
;
; =============================================================
; CONSTANTS
;
;

$Include 'SMT-Master.inc'





SIOBAUD:   EQU      0DH
SIOCR1:    EQU      0EH
SIOCR2:    EQU      0FH
SIOSTAT:   EQU      10H
XMTCMPL:   EQU      06H
XMTRDY:    EQU      07H
SIODATA:   EQU      11H

TSR:       EQU      13H
INPUTCAPH: EQU      14H
INPUTCAPL: EQU      15H
COMPAREH:  EQU      16H
COMPAREL:  EQU      17H
COUNTERH:  EQU      18H
COUNTERL:  EQU      19H
ALTCNTH:   EQU      1AH
ALTCNTL:   EQU      1BH
PROG:      EQU      1CH
COPRESET:  EQU      1DH
COPCTRL:   EQU      1EH
;                   1FH        ; UNUSED
;

;
;SIO CONTROL CHARS
;
STX:      EQU   02H
ETX:      EQU   03H
ENQ:      EQU   05H
ACK:      EQU   06H
NAK:      EQU   15H
CAN:      EQU   18H     ; INDICATES QUEUE OVERFLOW
ESC:      EQU   1BH     ; INDICATES NO DATA TO XMIT
;
; MISC CONSTANTS
;
LINELENGTH: EQU 10H
BUFSIZE:    EQU 03H
;
; VARIABLES beginning of 4k ram 
;
		ORG     RAMSTART 	 	;start of  ram
RAMADH:			DB	   0	  ;HIGH ADDRESS FOR RAM CLEAR
RAMADL:			DB	   0	  ;LOW ADDRESS FOR RAM CLEAR
FLAG:          DB      0
SIOINRDY:      EQU     0      ; SIO Data Present
SCROLL:        EQU     1      ; Flag to send next char to brds
HALFSEC:       EQU     2      ; Used to count display time
WRITENOW:      EQU     3      ; Indicates timed wr or immed wr
TMRRST:        EQU     4      ; Broadcast a timer reset
TMROFS:        EQU     5      ; Broadcast the timer offset
SHWTIM:        EQU     6      ; Show the time
NEWSCRL:       EQU     7 

FLAG2:		   DB	   0 	  ;MISCELLANEOUS FLAGS
OLVL:      	   EQU     0 	  ;TIMER OUPUT LEVEL

ALTFLAG:        DB     0
INCKROWS:      EQU     0
ALTMSG:        EQU     1      ; This msg is for alternate
ALTNXT:        EQU     2      ; Show Alt buffer on nxt zero cnt
ALTNOW:        EQU     3      ; Flag to signal time to alt
ALTLIN:        EQU     4      ; Indicates +/- Eight lanes 
SNDNWPG:       EQU     5      ; Flag to send new page to boards
VALCHR:        EQU     6      ; Is there a char for this bd
SETNWPG:       EQU     7

WROW:           DB     0      ; used by WriteRBC to determine
WCOL:           DB     0      ; address to write to
WBUFID:         DB     0
WRROWOF:		DB	   0	  ;HOLDS THE ROW ADDRESS OFFSET FOR WRITE TO FIXED LINE DATA
WRROWOFL:		DB	   0	  ;HOLDS THE LOW BYTE FOR WRITE TO FIXED LINE DATA
RROW:           DB     0      ; used by ReadRBC to determine
RCOL:           DB     0      ; address to read from
RBUFID:         DB     0
STARTCOL:       DB     0      ; Used to figure out which board
			      	   		   ; in a col to start with
RDROWOF:		DB	   0	  ;HOLDS THE READ ROW OFFSET FOR FIXED LINE DATA	
RDROWOFL:   	DB	   0	  ;HOLDS THE LOW BYTE FOR READ  FIXED LINE DATA 			   							   
ALTCOUNT:       DB     0      ; Timer to switch to alt page
WCHARCOUNT:     DB     0
INCHAR:         DB     0
BRDCNT:         DB     0
WRTEMP:         DB     0
CLRCNT:         DB     0
NEWPGCNT:       DB     0
BRDID:          DB     0
TBOARD:         DB     0
SCRLADH:        DB     0	  ;SCROLL ADDRESS HIGH BYTE
SCRLADL:        DB     0	  ;SCROLL ADDRESS LOW BYTE
SCROLCNT:       DB     0

TMROFFST:       DB     0
TICS:           DB     0

DISPTMDL:       DB     0      ; Value to set DispTime to

ALTTMDL:        DB     0      ; Value to delay ALTERNATE TO
ALTACTV:        DS     2
ALTTEMP:        DB     0
ALTTMPX:        DB     0
TEMP:           DB     0
TEMP2:          DB     0
TEMPX:          DB     0
TEMPBUFID:      DB     0
CHARIN:			DB	   0	  ;HOLDS CHAR FROM SIO READ
FIXEDADR:		DB	   0      ;HOLDS ADDRESS FOR FIXED MESSAGE

BOARDCHR:       DS     4
VAL:		DB	0	; length of tone
CROW:           DB     0       ; colon row
CCOL:           DB     0       ; colon column

IPTR1:           DW     0	   ;SIO1 BUFFER INPUT POINTER
OPTR1:           DW     0	   ;SIO1 BUFFER OUTPU POINTER
DISPTIME:       DS     15T      ; Countdown timer for line msg

;start of ram buffer  space  
;	   ORG RAMSTART	  	;BEGINNING OF DATA STORAGE

INBUF:          DS     15T      ; Where to put the next fixed msg
OUTBUF:         DS     15T      ; Where to get the next msg from

SCRLDTA:        DS     16T
SIOQUESIZE:     EQU    0D0H
SIOQUE:         DS     SIOQUESIZE

;
;
; START OF FIXED LINE DATA BUFFER
; 		THERE ARE  4, 16 CAHRACTER BUFFERS (PAGES) PER LANE AND 16 LANES 4*16*16=1024 OR 400 HEX BYTE FOR FIXED DATA
;       BUFFER 0 TO 3 CONTAINS FIXED LINE MESSAGES AND BUFFER 3 IS THE ALTERNATE MESSAG
;       
FIXEDLEN:	 	EQU		0400H		 ;1024 BYTES	
SCROLLEN:		EQU		0400H		 ;1024 BYTES
FIXEDSTART:	 	DS		FIXEDLEN		 
SCROLSTART:		DS		SCROLLEN	

ENDOFDATA:		DB		1			;MARKS END OF DATA   		  

;
; endo of ram buffer space
	ORG     FLASHSTART
	
START:  SEI
		LDHX	#RAMEND   ; point stack one past RAM
		TXS                 ; SP<-(H:X-1)   
		JSR     INIT	  ; INITIALIZE THE CLOCKS AND I/O		
		CLI
;
;
MAINLOOP:
	JSR     SIOREAD           ; Wait for STX
	CMP     #STX
	BNE     MAINLOOP
	
	JSR     SIOREAD           ; Get Msg type

	CMP     #30H           ; Is it a Reset?
	BNE     ML1
	JSR     INIT
	BRA     MAINLOOP

ML1:    CMP     #31H           ; Is it Scroll Msg?
	BNE     ML2

	
	JSR     READSCROL
	BRA     MAINLOOP

ML2:    CMP     #32H           ; Is it new Fixed Data?
	BNE     ML3
	BSET    WRITENOW,FLAG
	BCLR    ALTMSG,ALTFLAG
	JSR     READDATA
	BRA     MAINLOOP


ML3:    CMP     #33H           ; Is it dump ram?
	BNE     ML4
;	JSR     DUMPRAM
	BRA     MAINLOOP

ML4:    CMP     #34H           ; Is it Timer Reset?
	BNE     ML5
	BSET    TMRRST,FLAG
	BRA     MAINLOOP

ML5:    CMP     #35H           ; Is it Set Timer Offset?
	BNE     ML6
	JSR     SIOREAD         ; What is the offset.
	STA     TMROFFST
	BSET    TMROFS,FLAG
	BRA     MAINLOOP

ML6:    CMP     #36H           ; Is it Show Time?
	BNE     ML7
	JSR     READTIMELOC
	BRA     MAINLOOP

ML7:    CMP     #37H           ; Is it Show For a While?
	BNE     ML8
	BCLR    WRITENOW,FLAG
	BCLR    ALTMSG,ALTFLAG
	JSR     READDATA
	BRA     MAINLOOP

ML8:    CMP     #38H           ; Is it New Page Time?
	BNE     ML9
	JSR     SIOREAD        ; What is the time, in 1/2 secs
	SUB     #30H
	STA     DISPTMDL
	JMP     MAINLOOP

ML9:    CMP     #39H           ; Is it New Scroll Speed?
	BNE     ML10
			       ; Speed changes not supported
			       ; need to advise slaves so they
			       ; can adj their timekeeping which
			       ; is based on row clock which
			       ; controls scroll speed
	JMP     MAINLOOP

ML10:   CMP     #41H           ; Is it an alternate?
	BNE     ML11
	BSET    ALTMSG,ALTFLAG
	BCLR    WRITENOW,FLAG
	JSR     READDATA
	JMP     MAINLOOP

ML11:   CMP     #42H           ; Is it alternate speed?
	BNE     ML12
	JSR     SIOREAD        ; What is the time, in 1/2 secs
	SUB     #31H
	BHI     ML11A
	LDA     #1
ML11A:  STA     ALTTMDL
	JMP     MAINLOOP

ML12:   CMP     #43H           ; Colon on
        BNE     ML13
        JSR     COLON
	JMP     MAINLOOP

ML13:   CMP     #44H           ; Colon off
	BNE     ML14
        JSR     COLOFF
	JMP     MAINLOOP

ML14:   CMP     #45H           ; Software Tone
	BNE     ML15
	JSR     SIOREAD        ; What is the time, in 1/2 secs
	STA     VAL 
	JSR     SIOREAD        ; ETX
	JSR     SENDTONE
	JMP     MAINLOOP

ML15:   JMP     MAINLOOP
;
; **************************************************************
;
READDATA:                       ; New data coming in
	JSR     SIOREAD         ; Where is this going
	SUB     #30H
	STA     WROW
	BNE     RDT1           ; Was this a write to top row?
	CLRH				   ;CLEAR THE H REGISTER FOR 16 BIT INDEX OPERATION
	CLR     SCROLCNT	   ;YES
	BCLR    SCROLL,FLAG

RDT1:   TAX                    ; x holds row
	CLRA
	BRSET   WRITENOW,FLAG,RDT1A ; Save in buf 0 if write now
	LDA     INBUF,X        ; get bufid
	BRCLR   ALTMSG,ALTFLAG,RDT1A
	LDA     #3		   ; ALTERNATE MESSAGE BUFFER IS 3		
	STA     WBUFID
	BRA     RDT1C

RDT1A:  STA     WBUFID
	BCLR    ALTLIN,ALTFLAG
	LDA     #1             ; Disable alternating row
			       ; X holds WROW
	CPX     #7
	BLS     RDT1B
	BSET    ALTLIN,ALTFLAG
	TXA     
	SUB     #08
	TAX
	LDA     #1

RDT1B:  DECX
	BMI     RDT1D
	LSLA                   ; Shift a bit over to this row
	BRA     RDT1B

RDT1D:  COMA
	BRSET   ALTLIN,ALTFLAG,RDT1E
	AND     ALTACTV
	STA     ALTACTV
	BRA     RDT1F

RDT1E:  AND     ALTACTV+1
	STA     ALTACTV+1
	
RDT1F:  BRSET   WRITENOW,FLAG,RDT3

RDT1C:  LDA     #16T            ; clear old row
	STA     WCOL
RDT2:   DEC     WCOL
	BMI     RDT3
	CLRA
	JSR     WRITERBC
	BRA     RDT2

RDT3:   
	JSR     SIOREAD        ; read column
	SUB     #30H
	STA     WCOL           ; used by RBC

	LDA     #0             ; Reset count of nbr of char
	STA     WCHARCOUNT

RDT4:   JSR     SIOREAD        ; Get next char rcvd
	CMP     #ETX           ; If ETX, done
	BEQ     RDT5

	JSR     WRITERBC       ; Else, write to ram

	LDA     WCOL           ; Check for past end of display
	CMP     #LINELENGTH
	BEQ     RDT4           ; If to long, dont point to next
			       ; row - write to same loc until
			       ; recv ETX
	INC     WCOL           ; Point to next locn in ram
	INC     WCHARCOUNT     ; Keep count of chars rcvd
	BRA     RDT4


RDT5:   BRSET   ALTMSG,ALTFLAG,RDT8A
	BRSET   WRITENOW,FLAG,RDT7
						   ; timed message store	  
	LDX     WROW           ; Point to next buffer
	LDA     INBUF,X        ; Get previous value
	INCA                   ; increment
	CMP     #BUFSIZE       ; is it to big
	BLO     RDT6           ;
	CLRA                   ; clear if less than buf size
	INCA                   ; point to buf1, not buf0
RDT6:   STA     INBUF,X        ;
	CMP     OUTBUF,X       ; did we catch outbuffer
	BNE     RDT6B          ;
	LDA     OUTBUF,X       ; If inbuffer catches outbuffer
	INCA                   ; throw away oldest
	CMP     #BUFSIZE
	BLO     RDT6A
	CLRA
	INCA
RDT6A:  STA     OUTBUF,X
RDT6B:  BRA     RDT9

RDT7:          ; if writenow, set to send immediately
	LDX     WROW
	LDA     #0FFH          ; set time to neg to write immed
	STA     DISPTIME,X
			       ; X holds row
	LDA     INBUF,X        ; Wipe out any timed messages
	STA     OUTBUF,X


	BRA     RDT9


RDT8A:  
	;TST     ALTACTV        ; Is anyone else active yet
	LDA     ALTACTV
	ADD     ALTACTV+1
	BEQ     RDT8C

	LDA     ALTTMDL        ; If not, initialize altcount
	STA     ALTCOUNT

RDT8C:  BCLR    ALTMSG,ALTFLAG
	BCLR    ALTLIN,ALTFLAG
	
	LDA     #1             ; Identify which row is alterntg
	LDX     WROW
	
	CPX     #7
	BLS     RDT8B
	BSET    ALTLIN,ALTFLAG
	TXA     
	SUB     #08
	TAX
	LDA     #1

RDT8B:  DECX
	BMI     RDT8D
	LSLA                   ; Shift a bit over to this row
	BRA     RDT8B

RDT8D:  BRSET   ALTLIN,ALTFLAG,RDT8E
	ORA     ALTACTV        ; Add this bit to others
	STA     ALTACTV
	BRA     RDT9

RDT8E:  ORA     ALTACTV+1        ; Add this bit to others
	STA     ALTACTV+1

RDT9:   RTS

;
;
; **************************************************************
;
; INITIALIZE
;
;

INIT:	SEI                     ; TURN OFF INTERRUPTS
	
	LDA		#0D0H
	STA		SOPT1         ; disable watchdog
	
*************************************************************
* Initialize the clock to the on board clock ext. x1        *
*************************************************************
;Initialize the main clock mode
;	    	#00101000Q
clkinit:LDA     #10100000Q       ;external clock @ 8.0mhz /2 4 bus clock is / 2 = 2mhz
;                ||||||\ _______LOC DISABLED
;                |||||\________ENABLE OSC. IN OFF MODE
;                ||||\_________SELF CLOCKED
;                |||\__________
;                ||\___________EXTERNAL CLOCK
;                |\____________OSC IN HIGH FREQ MODE P=1
;                \_____________OSC CONFIGURED FOR HIGH GAIN
;         STA     ICSC1

;         LDA    #01000000Q    ; divide by 2 to get 2 m.0 hz
;               ||||||\--______RFD=0
;               |||||\_________GENERATE INTERRUPT ON LOC
;               ||\--__________MFD=0
;               \______________GENERATE A LOL INTERUPT(LOC DISABLED)
        STA     ICSC2            ;SETUP BUSS CLOCK FOR 2MHZ MULTIPLY INTERNAL
				 ;CLOCK BY 8 DIVED BY 2
;	LDA	#000H		 
;	STA ICGFLTL 
;	LDA	#0FH
;	STA	ICGFLTU
	LDA	#0A0H   		 ;TRIM TO 2.0 MHZ ????
  STA	ICSTRM
;
          
		  
;
;		  Setup I/o
;
 		  
    LDA	  #00000000Q
	STA	  SIMCO
	LDA   #50H  			 ; ENABLE CLOCKS TO MUX CONTROL
	STA  SCGC4
;;; DISABLE THE IRTC CONTINUOUS INTERRUPT AFTER POWER UP	
	LDA	 #00H
	STA	 IRTC_IER+1
	LDA	 IRTC_IER+1
	
	LDA	 #011H 				 ; DISABLE THE IRTC CLOCK CONTROL
	STA	 SCGC5
	LDA  #00H
	STA	 IRTC_ISR+1
	LDA	 IRTC_ISR+1
	
	
	
	
	;;; dEFINE THE I/O PIN COFIGUARION
	LDA	  PTAPF4	   
		   	   	   	   	 ;PORT A IS SET FOR OTPUT ON RESET NO CHANGE REQURED
	LDA	  #044H			 ;ENABLE SIO0 ON PORT B 
	STA	  PTBPF2
	LDA	  #00H			 ;B4,B5	 UNUSED SET AS OUTPUT
	STA	  PTBPF3
	LDA	  #022H			 ;SELECT SIO2
	STA	  PTBPF4
;	LDA	  #10000000Q	 ;SET XD2 PULLUP ON
;	STA   PTBPE
	
;	STA	  PTCPF3		 ;SELECT SI01  C0..C3 NOT AVAILABLE ON CHIP
;	STA	  PTCPF4		 ;SELECT SIO3

	LDA	  #010H			 ;SELECT FTM CLOCKS ON F7
	STA	  PTFPF4
	
	LDA	  #00000010Q
	STA	  PTAPF2		 ;ENABLE FTMCH0 AS TOGLE ON A2 FOR ROW CLOCK
	
 	LDA   #01111001Q	 ;ENABLE PTA,D,E,G
	STA	  SCGC3	 		 ;Enables i/O mux gate control
	
	LDA	  #0FFH			 ;SET PORT A - H OUT HIGH INCASE THEY GET TURNED ON
	STA	  PTAD 
	STA	  PTBD
	STA	  PTCD
	STA	  PTDD
	STA	  PTED
	STA	  PTGD
	STA	  PTHD
	
 	LDA	  #11111111Q	 ; SET DATA DIRECTION OUT
	STA	  PTADD
	STA	  PTBDD
	STA	  PTCDD
	STA	  PTDDD
	STA	  PTEDD
	STA	  PTFDD
	LDA	  #00001111Q	 ; G4...G7 ARE FOR OPTION SWITCHES AND JUMPERS
	STA	  PTGDD
; SET PULLUPS
  	LDA	  #00000100Q
	STA	  PTAPE			 ;SET ROWCLOCK PULLUP	   	
	LDA   #11110000Q	 ;SET PULLUPS ON G4...7
	STA   PTGPE
	LDA	  PTGD
; set drive strenght on PTA
  	LDA	  00111111Q
	STA	  PTADS	  
	STA	  PTASE	
;SETUP F  N`EW PAGE RESET
	LDA	  #00H 
	STA	  PTFD
	LDA	  #0FFH
	STA	  PTFD   	
	
;;; BLUE TOOTH CONTROL LINES ON D0...D4 SET TO OUT TEMPORARILY

;;;LEDS ARE DEFINED FROM RESET ON D5..D7 & E4,E5  E6,E7 NOT USED
;;;F1,F6 NOT USED F7 IS TIMER FOR ROW CLOCK

;;; G5..G7  H0,H1  NOT USED SET TO OUTPUT
;  READ THE OPTION SWITCHES
   	LDA		PTGD	
;TURN ON THE LEDS
	LDA	  #00H  
	STA	  PTAD
	
	BSET  1,PTAD	;WATCH DOG
	;BSET  2,PTAD	;ROW CLOCK
	BSET  3,PTAD	;BT1C
	BSET  4,PTAD	;BT1C
	BSET  5,PTAD	;SPARE

	LDA	   #00H
	STA    PTDD
	
	LDA	   #00H
	STA	   PTED
;	BSET   5,PTED
	
	BCLR   1,PTFD	;CLEAR brdRESET
	BCLR   6,PTFD	;CLEAR NEW PAGE
	BSET   INCKROWS,ALTFLAG
;;; DATA INITIALIZATION
	
	
	JSR	 RAMCLR		   	   ;CLEAR THE RAM	
	JSR	 DATAINIT		   ;CLEAR
;;** ALL SERIAL BUFFERS	
	LDA     #0
	STA     IPTR1           ; CLEAR SIO BUFFER POINTERS IN
	STA     OPTR1           ; HIGH RAM

	LDA     #$E             ; Default values
	STA     DISPTMDL       ; Show for 7 seconds
	LDA     #$E
	STA     ALTTMDL        ; Delay for 7 seconds
	BCLR	0,PTAD		   ;TURN ON DATA LED TO INDICATE MEMORY INITIALIZED

	JSR     SERINIT
	JSR		SERINIT2	   ;fixed line out
	JSR     TMRINIT

	BSET    RESET,PTFD    ; Clear reset bit

	LDA     #STX           ; Send reset to remote boards
	JSR     SIOWRITE
	LDA     #0FFH          ; FFH is the global address
	JSR     SIOWRITE
	LDA     #30H           ; Indicate this is a newpage cmd
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	CLI
	RTS	
;
; **************************************************************
; Turn ON colon
;
; **************************************************************
;

COLON:

        JSR     GTBRDID

	LDA     #STX           ;
	JSR     SIOWRITE

	LDA     BRDID
	JSR     SIOWRITE

        LDA     #43H           ; Indicate this is a data write
	JSR     SIOWRITE
        LDA     #ETX           ;
	JSR     SIOWRITE
        RTS
;
; **************************************************************
; Turn off colon
;
; **************************************************************
;

COLOFF:
        JSR     GTBRDID

	LDA     #STX           ;
	JSR     SIOWRITE

	LDA     BRDID
	JSR     SIOWRITE

        LDA     #44H           ; Indicate this is a data write
	JSR     SIOWRITE
        LDA     #ETX           ;
	JSR     SIOWRITE
        RTS
		
;
; **************************************************************
;
GTBRDID:
        JSR     SIOREAD        ; Board Row
        STA     CROW
        JSR     SIOREAD        ; Board Column
        STA     CCOL
        JSR     SIOREAD        ; etx
        LDA     CROW
        SUB     #30H
        BEQ     GTB1
        ROLA
        BEQ     GTB1
        ROLA
GTB1:   ADD     #30H
        STA     BRDID
        LDA     CCOL
        SUB     #30H
        BEQ     GTB2
        RORA
        BEQ     GTB2
        RORA
GTB2:   ADD     BRDID
        STA     BRDID
        RTS	
;
;
;
; External ram is separated into 16 lanes of 16 characters by 4 buffers 
; in the first 16x16x4 locations in memory.  The remainder of memory is
; used by the top line for scrolling memory.  WRITERBC and
; READRBC are used by the fixed message commands only.
; **************************************************************
; WRITERBC - Write a character into the row, buffer and col
;            indicated by WROW and WCOL
;
;
WRITERBC:
		 STA	 	CHARIN         ; Save value to RAM
		 CLRA	
		 STA		 WRROWOF
		 STA		 WRROWOFL
		 LDX		 WROW
		 LSLX		 	 	   ; MULTIPLY ROW BY 16	   
		 LSLX
		 LSLX
		 LSLX
		 BCC 		 WRI0
		 INC		 WRROWOF
WRI0:	 STX 		 WRROWOFL
	
	     LDA 	WBUFID         ; Multiply buffer by 100HEX (16 LANES BY 16 CHARACTERS)
WRI1:	 DECA
		 BMI 	WRI2
		 INC	WRROWOF
		 BRA	WRI1
WRI2:	 LDA	WRROWOFL
		 ADD    WCOL           ; Add col offset
		 STA	WRROWOFL
		 LDHX	WRROWOF
		 LDA 	CHARIN
		 STA	FIXEDSTART,X
	
		 RTS
		 
		 
; **************************************************************
;
; READRBC
;
; READRBC - READS a character FROM the row, buffer and col
;            indicated by WROW and WCOL
;
READRBC:
		 CLRA	
		 STA	 RDROWOF
		 STA	 RDROWOFL
		 LDX	 RROW
		 LSLX	 	 	 		 ; MULTIPLY ROW BY 16	 
		 LSLX
		 LSLX
		 LSLX
		 BCC 	 RR0
		 INC	 RDROWOF	 
RR0:  	 STX	 RDROWOFL	
 
 	  	 LDA     RBUFID          ;Multiply buffer by 100HEX (16 LANES BY 16 CHARACTERS)
RR1:	 DECA
		 BMI 	 RR2
		 INC	 RDROWOF
		 BRA	 RR1
RR2:	 LDA	 RDROWOFL
		 ADD     RCOL           ; Add col offset
		 STA     RDROWOFL
 		 LDHX	 RDROWOF
		 LDA     FIXEDSTART,X
		 RTS		 
;
; **************************************************************
; Read in comming scoll data 
;
; **************************************************************
;
READSCROL:
	CLR     SCROLCNT       ; Make sure old scroll msg doesnt
	BCLR    SCROLL,FLAG    ; interfere
	LDA     ALTACTV        ; Make sure row 0 doesn't try
	AND     #7EH           ; to alternate
	STA     ALTACTV
	LDX     #00
	LDA     INBUF,X        ; Wipe out any timed messages
	STA     OUTBUF,X
;	LDA     #0C0H           ; Point to first scroll ram 600H
;	STA     SCRLADH        ; Which is at 400H or 1024
;	LDA     #0             ;
;	STA     SCRLADL
	LDHX	#0
	STHX	SCRLADH
RS1:
    JSR     SIOREAD        ; Read data
	STA     INCHAR
	LDHX	SCRLADH
	STA		SCROLSTART,X
;	JSR     NEXTSCRLADR
	INCX
	STHX	SCRLADH		
	BNE		RS2
	INC		SCRLADH
	
RS2:
	LDA     INCHAR
	CMP     #ETX           ; Is it end of message
	BEQ     RS4            ; if yes, done
	BRA     RS1

RS4:
    BSET    NEWSCRL,FLAG
	RTS
	
	;




;
; **************************************************************
;

READTIMELOC:
	JSR     SIOREAD        ; Where should we show the time?
	SUB     #30H
	STA     WROW
	TAX                    ; X holds row
	LDA     INBUF,X        ; Wipe out any timed messages
	STA     OUTBUF,X

	BCLR    ALTLIN,ALTFLAG
	LDA     #1             ; Disable alternating row
			       ; X holds WROW
	CPX     #3
	BLS     RTL1
	BSET    ALTLIN,ALTFLAG
	TXA     
	SUB     #04
	TAX
	LDA     #1


RTL1:   DECX
	BMI     RTL2
	LSLA                   ; Shift a bit over to this row
	BRA     RTL1

RTL2:   COMA                   ; All bits except cur row = 1
	
	BRSET    ALTLIN,ALTFLAG,RTL2A
	AND     ALTACTV
	STA     ALTACTV
	BRA     RTL2B

RTL2A:  AND     ALTACTV+1
	STA     ALTACTV+1

RTL2B:  LDA     WROW
	BNE     RTL3

	CLR     SCROLCNT       ; Make sure row 0 doesn't scroll
	BCLR    SCROLL,FLAG

RTL3:   LSLA                   ; Mult by 4 boards per row
	LSLA
	STA     TBOARD

	JSR     SIOREAD        ; This is the column
	STA     WCOL
	SUB     #30H
	AND     #0FCH          ; Remove lower 2 bits so at start
	STA     WCOL           ; of a board
	LSRA                   ; Divide by 4 to determine board
	LSRA                   ; within row
	ADD     TBOARD         ; add the row offset
	ADD     #30H
	STA     TBOARD         ; board id now

	BSET    SHWTIM,FLAG

	CLR     WBUFID         ; Clear out stuff in buff 0
	LDA     #8
	STA     CLRCNT         ; Set up count of bytes to clear
RTL4:   CLRA
	JSR     WRITERBC
	INC     WCOL
	DEC     CLRCNT
	BNE     RTL4

	RTS
; **************************************************************
;
SENDTONE:
	LDA     #STX           ; Send reset to remote boards
	JSR     SIOWRITE
	LDA     #0FFH          ; FFH is the global address
	JSR     SIOWRITE
	LDA     #45H           ; Indicate this is a newpage cmd
	JSR     SIOWRITE
	LDA     VAL            ; Indicate this is a newpage cmd
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	RTS

;
; **************************************************************
;
; SIOREAD
;
;
SIOREAD:
	BRSET   SIOINRDY,FLAG,RD7
	JSR     CHKSTUF
	BRA     SIOREAD


RD7:LDHX     OPTR1           ; Get output pointer
	LDA     SIOQUE,X       ; Get char from queue
	INCX                   ; point to next char
	CPX     #SIOQUESIZE    ; are we at top of buffer?
	BNE     RD8
	CLRX                   ; wrap to bottom
RD8:STHX    OPTR1

	LDHX    IPTR1           ; is the buffer empty?
	CPHX    OPTR1
	BNE     RD9
	BCLR    SIOINRDY,FLAG  ; if empty, clear the flag
RD9:    RTS                    ; return with char in A

;
;
; **************************************************************
;
; CHECK WHILE WAITING TO READ
;
CHKSTUF:
	BRCLR   NEWSCRL,FLAG,CS1 ; is it time to scroll a char
	BCLR    NEWSCRL,FLAG
	JSR     STARTSCROLL

CS1:    BRCLR   SCROLL,FLAG,CS1A ; is it time to scroll a char
	BCLR    SCROLL,FLAG
	JSR     SHFTCHAR

CS1A:   BRCLR   TMRRST,FLAG,CS1B
	BCLR    TMRRST,FLAG
	JSR     TMRSTRT

CS1B:   BRCLR   TMROFS,FLAG,CS1C
	BCLR    TMROFS,FLAG
	JSR     SETOFFSET

CS1C:   BRCLR   SHWTIM,FLAG,CS1D
	BCLR    SHWTIM,FLAG
	JSR     SHOWTIME

CS1D:   LDA     SCROLCNT       ; do we have time to write a msg
	BEQ     CS2            ; before next scroll update
	CMP     #040T           ; if scrolcnt = 0, not scrolling
	BMI     CS8A
	BRSET   SCROLL,FLAG,CS8A ; is it time to scroll a char

CS2:    LDHX     #0
CS3:    TST     DISPTIME,X     ; Is it negative? Write immediate
	BMI     CS8            ; Send the new message
	INCX
	CPX     #15             
;        CPX     #7             
	BMI     CS3
	BRA     CS4


CS8:    CLR     RBUFID
	LDA     DISPTMDL
	STA     DISPTIME,X
	JSR     NEWMSG
CS8A:   JMP     CS9



CS4:

	BRCLR   HALFSEC,FLAG,CS8A ; test for msg timeout?

	BRSET   INCKROWS,ALTFLAG,CS4F  ; Is this 1st time thru
				  ; yes
	BSET    INCKROWS,ALTFLAG  ; Reset 1st time thru flag

	;TST     ALTACTV        ; Is any row in alt mode?
	LDA     ALTACTV
	ADD     ALTACTV+1
	BEQ     CS4B
	DEC     ALTCOUNT     		 ; When altcount flag gets to
	BPL     CS4B           ; 0, reset count and set flags

	LDA     ALTTMDL        ; reset count
	STA     ALTCOUNT

	BSET    ALTNOW,ALTFLAG ; set flag so know to try every
			       ; line

;        LDA     ALTACTV        ; Only send msgs for active rows
;        STA     ALTTEMP

	BRSET   ALTNXT,ALTFLAG,CS4A
	BSET    ALTNXT,ALTFLAG  ; Show Alt msg or last msg
	BRA     CS4B
CS4A:   BCLR    ALTNXT,ALTFLAG  ; Show last msg
CS4B:

CS4F:
    INC     TEMPX          ; Have we done rows 0..15
	LDA     TEMPX
	CMP     #15T 		   ;CHECK ALL ROWS
	BNE     CS5            ; if not, keep going

	BCLR    HALFSEC,FLAG   ; if yes, reset
	BCLR    ALTNOW,ALTFLAG
	CLR     TEMPX
	DEC     TEMPX          ; back up one so next pass do 0
	BCLR    INCKROWS,ALTFLAG  ; Reset 1st time thru flag

	BRA     CS9

CS5:   
	LDHX	#0    		   ; CLEAR HX REGISTER	  
	LDX     TEMPX          ; Get row to check
    CLRH
	TST     DISPTIME,X     ; Were we at 0? go on
	BEQ     CS5B
	DEC     DISPTIME,X     ; Are we now at 0? go on
	BNE     CS9
			       ; Just now got to 0
CS5B:   LDA     INBUF,X        ; Is there a new timed message?
	CMP     OUTBUF,X
	BEQ     CS5A           ; If not, see if altng msg for
			       ; this row

CS5C:   LDA     OUTBUF,X       ; find the buffer to use
	STA     TEMP

	INCA                   ; point to next
	CMP     #BUFSIZE       ; time to wrap?
	BLO     CS5X           ;
	CLRA                   ; clear if less than buf size
	INCA
CS5X:   STA     OUTBUF,X       ;

	JSR     XFRTIMED

	LDX     TEMPX          ; Get row
	LDA     DISPTMDL       ; reset message tmr to 7 seconds
	STA     DISPTIME,X

	CLR     RBUFID
	JSR     NEWMSG
	BRA     CS9

CS5A:   BRCLR   ALTNOW,ALTFLAG,CS9 ; Altnow set if a row is altg

	LDX     TEMPX          ; Is this row altg
	INCX                   ; For 0..6 shr & dec 1 to 7 times
			       ; For 0..15 shr & dec 1 to 16 times
	LDA     ALTACTV+1      ; Who is altg? Roll into carry
	STA     ALTTEMP
	LSR     ALTTEMP
	LDA     ALTACTV        ; Who is altg? Roll into carry
CSF1:   RORA
	DECX
	BEQ     CSF2
	LSR     ALTTEMP
	BRA     CSF1
CSF2:

	;LSR     ALTTEMP        ; should we send this row?
	BCC     CS9

	LDX     TEMPX          ; get row now working on
	BRCLR   ALTNXT,ALTFLAG,CS5D
	LDA     #03            ; Get data from alt buffer
	BRA     CS5E

CS5D:   CLRA                   ; ALTNXT clear, get last buffer
CS5E:   STA     RBUFID         ; save which buffer to pull from

	JSR     NEWMSG

CS9:    BRCLR   SNDNWPG,ALTFLAG,CS9A
	JSR     SENDNWPG


CS9A: 
	    RTS

;
;
; **************************************************************
;
;
SENDNWPG:
	BCLR    SNDNWPG,ALTFLAG
	LDA     #STX           ;
	JSR     SIOWRITE
	LDA     #0FFH          ; FFH is the global address
	JSR     SIOWRITE
	LDA     #38H           ; Indicate this is a newpage cmd
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	RTS
;
;
; **************************************************************
; MOVE NEXT BUFFER INTO 0???
;
XFRTIMED:
	STX     RROW
	STX		WROW
	LDA     #0
	STA     RCOL
	STA		WBUFID
	LDA     TEMP
	STA     RBUFID

XT0:JSR     READRBC	   ; READ FROM BUFFER IN TEMP	
;???
	BEQ     XT5            ; If read a null, dont overwrite

	TAX                    ; Save value to X

	LDA     RCOL           ; Add col offset BUFID=0
	STA		WCOL
	TXA
	JSR		WRITERBC	   ;WRITE TO BUFFER 0 TO DISPLAY

XT5:    INC     RCOL           ; Point to next col
	LDA     RCOL
	CMP     #LINELENGTH    ; are we at end of line?
	BNE     XT0

	RTS
;
; **************************************************************
;

;
; **************************************************************
;
; Send the message in row indicated by X
;
NEWMSG: STX     RROW           ; Save row to read

	LDA     #0             ; start with col 0
	STA     RCOL

	TXA                    ; determine which brd to send to
	LSLA                   ; multiply row by 4 to get first
	LSLA                   ; board in row
	STA     BRDID

NM4:    BCLR    VALCHR,ALTFLAG
	LDA     #4             ; send 4 data bytes
	STA     TEMP
NM4A:   JSR     READRBC
	BEQ     NM4B           ; Is this a valid char?
	BSET    VALCHR,ALTFLAG
NM4B:   LDX     TEMP
	STA     BOARDCHR-1,X
	INC     RCOL
	DEC     TEMP
	BNE     NM4A
	BRCLR   VALCHR,ALTFLAG,NM6

	LDA     #STX           ;
	JSR     SIOWRITE

	LDA     BRDID
	ADD     #30H
	JSR     SIOWRITE

	LDA     #32H           ; Indicate this is a data write
	JSR     SIOWRITE

	LDA     #4             ; send 4 data bytes
	STA     TEMP
NM5:    LDX     TEMP
	LDA     BOARDCHR-1,X
	JSR     SIOWRITE
	DEC     TEMP
	BNE     NM5

	LDA     #ETX
	JSR     SIOWRITE

NM6:    INC     BRDID          ; Point to next board

	BRCLR   SCROLL,FLAG,NM7 ; is it time to scroll a char
	BCLR    SCROLL,FLAG
	JSR     SHFTCHAR

NM7:    LDA     BRDID
	AND     #03H           ; Get mod 4
	CMP     #00            ; 4 boards in a row
	BNE     NM4
	BSET    SNDNWPG,ALTFLAG
	;BCLR    NEWPAGE,PORTA  ; Clear newpage indicator
	;LDA     #10H           ; Set up to Set newpage indicator
	;STA     NEWPGCNT       ; in four counts

NM9:    RTS

;
;
; **************************************************************
;
STARTSCROLL:
	LDX     #08             ; Put spaces in 1st 8 positions
	STX     TEMP            ; Set up to then get 8 to 16 chr
	DECX

SS3:
    LDA     #20H
	STA     SCRLDTA,X
	DECX
	BPL     SS3
	JSR		FRSTSCRLADR

SS4:
    JSR     SCRLREAD       ; Read the next char from
	CMP     #ETX           ; external ram. If it is an ETX
	BEQ     SS8  
	CLRH		           ; load first row,
	LDX     TEMP           ; otherwise save char in
	STA     SCRLDTA,X      ; the array to send it out
	INC     TEMP           ; set up to save at next locn
	LDA     TEMP           ;
	CMP     #16T            ; if done 16 chars in 1st row
	BEQ     SS8            ; done otherwise
	JSR     NEXTSCRLADR    ; get the next char from ext ram
	BRA     SS4

SS8:    JSR     FSTSHFTROW
	LDA     #32T            ; Set up to scroll in next char
	STA     SCROLCNT       ; relatively quickly

	RTS




;
; **************************************************************
;
SHFTCHAR:
	CLRX
	CLRH
SC1:    LDA     SCRLDTA+1,X
	STA     SCRLDTA,X
	INCX
	CPX     #15T
	BNE     SC1

	JSR     NEXTSCRLADR
	JSR     SCRLREAD
	CMP     #ETX
	BNE     SC2

	JSR     FRSTSCRLADR
	JSR     SCRLREAD

	; WHAT TO DO? NEED TO SCROLL SOME 20'S IN

SC2:    STA     SCRLDTA+15T

	LDA     SCRLDTA+3
	LDX     #0
	JSR     SNDSCRL

	LDA     SCRLDTA+7
	LDX     #1
	JSR     SNDSCRL

	LDA     SCRLDTA+11T
	LDX     #2
	JSR     SNDSCRL

	LDA     SCRLDTA+15T
	LDX     #3
	JSR     SNDSCRL

	BSET    SETNWPG,ALTFLAG
	;BCLR    NEWPAGE,PORTA  ; Clear newpage indicator
	;LDA     #10H           ; Set up to Set newpage indicator
	;STA     NEWPGCNT       ; in four counts
SC9:    RTS
;
; **************************************************************
;
SNDSCRL:
	STA     TEMP
	STX     TEMP2
	LDA     #STX
	JSR     SIOWRITE
	LDA     TEMP2
	ADD     #30H
	JSR     SIOWRITE
	LDA     #31H           ; Identify as a scroll command
	JSR     SIOWRITE
	LDA     TEMP
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	RTS
;
; **************************************************************
; Reads from address in scrladh & scrladl previously stored  by 'readscroll' in ram @ STARTSCROLL. Returns with
; data in A
;
SCRLREAD:
	LDHX    SCRLADH   	 
	LDA     ,x
	RTS

;
; **************************************************************
;
FRSTSCRLADR:
	LDHX	#SCROLSTART          ; POINT TO FIRST SCROLL RAM SCROLL			               
	STHX    SCRLADH        ; Which is at 400H or 1024
	RTS
;
; **************************************************************
;
NEXTSCRLADR:
	LDA     SCRLADH
	INC     SCRLADL         ; Set up ram address
	BNE     NR1
	ADD     #1H
	STA     SCRLADH

NR1:
    LDA     SCRLADL
	RTS
;
; **************************************************************
;
FSTSHFTROW:
	CLR     BRDID
	CLRX
FSR1:   LDA     #STX
	JSR     SIOWRITE
	LDA     BRDID
	ADD     #30H
	JSR     SIOWRITE
	LDA     #32H
	JSR     SIOWRITE
FSR2:   LDA     SCRLDTA,X
	JSR     SIOWRITE
	INCX
	TXA
	AND     #00000011Q
	BNE     FSR2
	LDA     #ETX
	JSR     SIOWRITE
	INC     BRDID
	LDA     BRDID
	CMP     #4
	BNE     FSR1

	BSET    SETNWPG,ALTFLAG
	;BCLR    NEWPAGE,PORTA
	;LDA     #10H
	;STA     NEWPGCNT
	RTS




;
; **************************************************************
;
;
; **************************************************************
;
TMRSTRT:
	LDA     #STX
	JSR     SIOWRITE
	LDA     #0FFH
	JSR     SIOWRITE
	LDA     #34H
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	RTS
;
; **************************************************************
;
SETOFFSET:
	LDA     #STX
	JSR     SIOWRITE
	LDA     #0FFH
	JSR     SIOWRITE
	LDA     #35H
	JSR     SIOWRITE
	LDA     TMROFFST
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE
	RTS
;
; **************************************************************
;
SHOWTIME:
	LDA     #STX
	JSR     SIOWRITE
	LDA     TBOARD
	JSR     SIOWRITE
	LDA     #37H           ; Indicates high part of time
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE

	LDA     #STX
	JSR     SIOWRITE
	LDA     TBOARD
	INCA
	JSR     SIOWRITE
	LDA     #36H           ; Indicates low part of time
	JSR     SIOWRITE
	LDA     #ETX
	JSR     SIOWRITE

	RTS


;
; **************************************************************
;
; SIOWRITE
;
;
; XDATA0 GOES TO SCROLL LINE P4 & FIXED P5,P6,P7
; XDATA1 GOES TO RIGHT SCROLL LINE P3 & FIXED P1,P2
; XDATA2 GOES TO P12 THE BLUETOOTH RADIO SOCKET
; XDATA3 NOT USED  
;;;
; SEND XDATA0 SCROLL AND FIXED
;;;

SIOWRITE:
	STA     WRTEMP
WR1:BRSET   XMTRDY,SCI0S1,WR2
	BRA     WR1

WR2:LDA     WRTEMP
	STA     SCI0D

; Make sure done xmtg is so that we don't toggle newpage before
; entire message has been rcvd by slave and it is looking for
; newpage
WR3:BRSET   XMTCMPL,SCI0S1,WR4
	BRA     WR3
	
	RTS
;;;
; SEND XDATA2 RADIO
;;;	
SIOWRITE2:
	STA     WRTEMP
WR4:LDA SCI2S1
		LSLA
		BCS	  WR5
	BRA     WR4

WR5:LDA     WRTEMP
	STA     SCI2D

; Make sure done xmtg is so that we don't toggle newpage before
; entire message has been rcvd by slave and it is looking for
; newpage
WR6:	 LDA SCI2S1
		 LSLA
		 LSLA
		 BCC WR6
WR9:    RTS
;
; **************************************************************
;
;








;
;
; Subroutine to initialize serial port 0
;  SIO FOR RECEIVING DATA FROM THE CTI
;  9600 BAUD, 8 DATA, 1 STOP , NO PARITY 
;
SERINIT:
	
	LDA 	#00000101Q		;ENABLE SIO 0 BY TURNING ON THE BUSS CLOCK 
	STA		SCGC1	
	LDA		#00H			;BAUD RATE HIGH BYTE
	STA		SCI0BDH			;BUSS CLK 8MHZ/(16X9600)
	LDA		#01AH
	STA 	SCI0BDL		   	;BAUD RATE LOW BYTE
	LDA		#00H			
	STA		SCI0C1			; 8 DATA 1 STOP NO PARITY
	LDA		#00101100Q		;RECIEVER ON XMIT ON
	STA		SCI0C2
	LDA		#00000000Q		;IN VERT TRANSMIT
	STA		SCI0C3
				  			;SCI0C3 NOT NEEDED ALL 0 AT RESET		
	RTS	
;;;
; Subroutine to initialize serial port 2
;  SIO FOR RECEIVING DATA FROM THE CTI
;  9600 BAUD, 8 DATA, 1 STOP , NO PARITY 	
;;;
SERINIT2:
	
;	LDA 	#00000101Q		;ENABLE SIO 2 BY TURNING ON THE BUSS CLOCK 
;	STA		SCGC1	
	LDA		#00H			;BAUD RATE HIGH BYTE
	STA		SCI2BDH			;BUSS CLK 8MHZ/(16X9600)
	LDA		#01AH
	STA 	SCI2BDL		   	;BAUD RATE LOW BYTE
	LDA		#00H			
	STA		SCI2C1			; 8 DATA 1 STOP NO PARITY
	LDA		#00001100Q		;RECIEVER ON XMIT ON
	STA		SCI2C2
	LDA		#00000000Q		;INVERT TRANSMIT
	STA		SCI2C3
				  			;SCI0C3 NOT NEEDED ALL 0 AT RESET		
	RTS	
;
;
; Subroutine to initialize timer FOR ROW CLOCK
;
TMRINIT:                        ; Initialize timer
	 LDA    #00001101Q      ; Set up to interrupt on output
;	 		  |||||||
;			  |||||||
;			  ||||\_________;DIVIDE BY 32 BITS 0,1,2
;		      ||||
;			  ||\ __________;cLK SOURCE = SYSTEM BITS 3,4 
;			  ||	
;			  |	\___________;CPWMS =0 COUNT UP
;			  \_____________;TOIE =0 INTERRUPTS OFF FOR TOF 	  
;				   
	 STA    FTMSC             ; SAVE FTM SETTING
	 LDA	#000H
	 STA    FTMMODH
	 LDA	#0B2H  			;2.85 MS WITH THESE SETTINGS 350HZ FOR ROW CLOCK
	 STA    FTMMODL			;
	 
	 LDA	#01010100Q		;SET CHAN 0 TO OUT COMPARE AND TOGLE TEST ON PTA2
	 STA 	FTMC0SC				

	 RTS
	 
;
;
;CLEAR THE RAM
;
;

RAMCLR:
	   	LDHX     #RAMSTART+2
		STHX	 RAMADH
		LDA		 #00	
RAMIN1:	STA    ,X             ; CLEAR RAM FROM C0 UP TO END OF RAM
		INC	   RAMADL
		BNE	   RAMIN2
		INC	   RAMADH	   
RAMIN2:	LDHX   RAMADH
		CPHX   #ENDOFDATA
		BEQ    RAMIN4 
		BRA	   RAMIN1
RAMIN4: RTS	
		  
;
;
;  DATAINIT Initializes  ram to space characters FOR SCROLL AND LANES
;
DATAINIT:
	 LDHX	#FIXEDSTART		
	 STHX	SCRLADH	 
	 LDA    #20H	 		;lOAD SPACES IN FIXED AND SCROLL MEMOR
ERI1:    
	 STA	 ,X
	 INC	 SCRLADL		;INCREMENT THE LOW ADDRESS
	 BNE	 ERI2			
	 INC	 SCRLADH		;IF LOW GOES TO 0 INCREMENT THE HIGH ADD
ERI2:
	 LDHX	 SCRLADH
	 CMPHX	 #ENDOFDATA		;COMPARE FOR SCROLL + 1024 BYTES
	 BEQ    ERI9
	 BRA    ERI1

ERI9:    RTS

;
; **************************************************************
;
; SERIAL INTERRUPT HANDLER
;
; Occurs when new char rcvd by SIO.  Gets character and puts
; into the SIOQUE
;

SI0RINT:
	LDA		 SCI0S1	   		  ; CLEAR THE READ FLAG
	LDA		 SCI0S2			  ; CLEAR THE INTERRUPT
	LDA		 SCI0D			  ; READ THE DATA
	BSET    SIOINRDY,FLAG     ; Set data read flag
	LDHX    IPTR1
	STA     SIOQUE,X          ; store new CHAR IN SIOQUE
	INCX
	CPX     #SIOQUESIZE
	BNE     SI9
	CLRX
SI9:STHX     IPTR1
	BRSET	 0,PTAD,S0R1	  ;TOGGLE THE DATA IN LED
	BSET	 0,PTAD
	BRA		 S0R2
S0R1:	
		BCLR	 0,PTAD	
S0R2:
	 	
		RTI
;
; **************************************************************
;
; TIMER INTERRUPT HANDLER
;
;
;TIMINT: 
;;;;
; TIMER INTERRUPT
;;;;
TIMINT: 
		LDA		FTMC0SC
		BCLR	7,FTMC0SC
		LDA		FTMC0SC	 		; CHECK IF INTERRUPT IS OFF								
		BRSET   OLVL,FLAG2,TI1   ; toggle output level bit so that
		BSET    OLVL,FLAG2      ; on the next interrupt, it goes
		BRA     TI2            ; to opposite state
TI1:    BCLR    OLVL,FLAG2

		DEC     TICS           ; On the transition from high to
		BNE     TI2            ; low, count down
		LDA     #0C8            ; *changed from #200 to #20
;		LDA		#20
		STA     TICS
		BSET    HALFSEC,FLAG
		BRSET	5,PTAD,TCLR		; TURN SPARE LED ON AND OFF FOR TESTING THEN REMOVE
		BSET	5,PTAD
		BRA 	TI2
TCLR:	BCLR	5,PTAD
TI2:    BRCLR    SETNWPG,ALTFLAG,TI2A
		BCLR    SETNWPG,ALTFLAG
		BSET    SNDNWPG,ALTFLAG ; Tell all brds
		BCLR	NEWPAGE,PTFD	; CLEAR THE NEW PAGE FLAG
		LDA     #04H           ; Set up to Set newpage indicator
		STA     NEWPGCNT       ; in four counts


TI2A:   TST     NEWPGCNT       ; Check to see if need to dec
		BEQ     TI3
		DEC     NEWPGCNT
		BNE     TI3            ; Is it zero yet?
		BSET    NEWPAGE,PTFD  ; If yes, make it zero

TI3:    TST     SCROLCNT       ; Do we need to check to see if
		BEQ     TI9            ; it is time to scroll?
		DEC     SCROLCNT       ; If maybe, dec
		BNE     TI9            ; If at zero, time to scroll
		;LDA     #96            ; Set up to scroll in 8 x 6 x 2 OLD BOARDS
		LDA     #$54            ; Set up to scroll in 7 x 6 x 2 =84
		STA     SCROLCNT       ; timer interrupts
		BSET    SCROLL,FLAG    ; Flag to send next char to brds
TI9:    RTI




;
; **************************************************************
;
; EXTERNAL INTERUPT
;       Occurs from row clock every 25 mS used to update row
; and keep time.

EXTINT:  LDA	IRQSC
		 LDA	SRS
		 
		 BRA	EXTINT			  		;RTI
;
; **************************************************************
;
; SET UP MASK OPTION REGISTER
;	ORG     1FDFH              ;MC68HC705C8

;OPT:       DB      11001000B      ; 7- 1 = RAM 30H - 4FH
				   ; 6- 1 = RAM 100H-15FH
				   ; 3- 1 = SECURE

; --------------------------------------------------------------
;
; SET INTERRUPT VECTORS
;
	ORG     $FF80	   		;Unused vector space(available for user)
;
    ORG    $FF96           ; Start of the vectors
	DW	   EXTINT ;PDB
	DW	   EXTINT;PDBERR
	DW	   EXTINT;LCD
	DW	   EXTINT;IRTC
	DW	   EXTINT;KBI
	
	org $FFBD
	DB  1
	ORG $FFBF
	DB	00000010Q	   ; TURNS OFF SECURITY FOR FLASH SO CAN DEBUG
	
	org	$FFC0			   
	DW	   EXTINT;PCNT
	DW	   EXTINT;PRACMP2
	DW	   EXTINT;PRACMP1		   
	DW	   EXTINT;PRACMP0
	DW	   EXTINT;ADC1
	DW	   EXTINT;ADC0
	DW	   EXTINT;MTIM2
	DW	   EXTINT;MTIM1
	DW	   EXTINT;MTIM0
	DW	   EXTINT;FTMOF
	DW	   TIMINT;FTMCH0
	DW	   EXTINT;FTMCH1
	DW	   EXTINT;IIC
	DW	   EXTINT;SPI2
	DW	   EXTINT;SPI1
	DW	   EXTINT;SPI0
	DW	   EXTINT;SCI3TX **serial channels
	DW	   EXTINT;SCI3RX **
	DW	   EXTINT;SCI3ERR **
	DW	   EXTINT;SCI2TX **
	DW	   EXTINT;SCI2RX **
	DW	   EXTINT;SCI2ERR **
	DW	   EXTINT;SCI1TX **
	DW 	   EXTINT;SCI1RX **
	DW	   EXTINT;SCI1ERR **
	DW	   EXTINT;SCI0TX **
	DW	   SI0RINT;SCI0RX **
	DW	   EXTINT;SCI0ERR **
	DW	   EXTINT;LVD **
	DW	   EXTINT;IRQ **
	DW	   START ;SWI
	DW	   START ;RESET
	
	
;
; **************************************************************
	END
;


