10REM This program provides a formatted listing of a BASIC program,
11REM in particular, indenting loops and splitting multiple statements
12REM out onto separate lines.
13REM Since it calls into the BASIC ROM, it requires BASIC 2.
14 
20REM It lives at &08D0-0AFF, which is normally used for the following:
21REM   800-8FF: sound workspace & buffers, printer buffer, envelope storage
22REM   900-9FF: envelope storage, RS423/speech/cassette output buffers
23REM   A00-AFF: cassette/RS423 input buffers
24 
30REM Run this program to assemble it, and save the generated machine code.
31 
40REM Enter LIST commands as normal, but with a trailing period e.g.
41REM   LIST 100,200.
42REM   LIST ,200.
43REM   LIST 100,.
44REM   LIST.
45 
50REM NOTE: Page references in the source code are for "The BBC Micro
51REM Compendium", by Jeremy Ruston.
52 
100REM === VARIABLES =======================================================
101 
102REM We borrow some zero-page locations normally used by BASIC (p170).
103 
110REM When when we're parsing the input command, this points into
111REM the keyboard buffer (&0700-07FF), then we switch to the program code
112REM when we start printing the listing.
113pinput = &4B : REM and &4C
114 
120REM This points into the program code being listed (only while
121REM we're parsing the input command).
122pcode = &3B : REM and &3C
123REM After parsing the input command, we use these bytes as temp storage.
124temp1 = &3B : temp2 = &3C
125 
130REM This holds the current line# being listed.
131curr_lineno = &2A : REM and &2B
132 
140REM This holds the last line# to be listed.
141last_lineno = &2E : REM and &2F
142 
150REM This holds the current indent.
151REM The first 5 columns are used for the line#, followed by a space,
152REM then the code itself starts at col.6
153curr_indent = &30
154 
160REM This flags if we are in a REM statement.
161in_rem = &31
162 
170REM This flags if we are in a double-quoted string.
171in_quotes = &32
172 
180REM This flags if we are in BASIC code (0 means we are in assembly code).
181in_basic = &33
182 
190REM This flags if we are in an assembly label.
191in_asm_label = &34
192 
200REM This flags if the current line has not been indented yet.
201indent_pending = &35
202 
900osbyte = &FFF4 : oswrch = &FFEE : osnewl = &FFE7
910 
1000FOR opt = 0 TO 3 STEP 3
1010BASE = &08D0 : P% = BASE
1020[ OPT opt
1030 
1100\ === MAIN ENTRY POINT ====================================================
1101 
1102\ Adding a trailing "." to a LIST command will generate a syntax error,
1103\ so we replace the default BRK error handler with ours, so that we can
1104\ check for this.
1105 
1110\ install our custom BRK handler
1120LDA #(brkHandler MOD 256)
1130STA &0202
1140LDA #(brkHandler DIV 256)
1150STA &0203
1160 
1170\ beep, then exit
1180LDA #7
1190JMP oswrch
1200 
1500\ === CUSTOM ERROR HANDLER ================================================
1501 
1502\ We check for our special LIST command here.
1503 
1510.brkHandler
1520\ check for a "Bad program"
1530JSR &BE6F
1540 
1550\ if the error was not "Syntax error" (error code 16), then jump to
1551\ the normal BRK handler
1560LDY #0
1570LDA (&FD),Y
1580CMP #16
1590BEQ P%+5
1600.defaultBRK
1610JMP &B402
1620 
2000\ initialize our variables
2001\   PINPUT <- &0700
2002\   PCODE <- PAGE
2003\   CURR_INDENT <- 6
2004\   IN_BASIC <- &FF
2005\   LAST_LINENO <- &7FFF (in case a line# isn't explicitly set)
2010STY pinput
2020STY pcode
2030LDA &18
2040STA pcode+1
2050LDX #7
2060STX pinput+1
2070DEX
2080STX curr_indent
2090DEY
2100STY in_basic
2110STY last_lineno
2120LDY #&7F
2130STY last_lineno+1
2140 
2150\ if the next non-space byte in the keyboard buffer is not the LIST keyword,
2151\ then jump to the normal BRK handler
2160JSR skipSpaces
2170CMP #&C9
2180BNE defaultBRK
2190 
2200\ if the next non-space byte is a ".", then skip parsing line numbers (the user
2201\ wants to "LIST." the entire program)
2210JSR skipSpaces
2220CMP #&2C
2230BEQ parseEndLineNo
2240 
2250\ if the byte is &8D (pseudo-keyword for a line#), then decode the line#
2251\ into CURR_LINENO
2260CMP #&8D
2270BNE endParseInput
2280JSR decodeLineNo
2290 
2300\ find the start of the specified line in the program code
2301\ NOTE - Program lines are stored as follows
2302\   &0D
2303\   line# (MSB, LSB)
2304\   line length (1 byte, the count includes the 3 leading bytes)
2305\ The end of the program is stored as
2306\   &0D &FF
2310.checkNextLine
2320\ check if we've found the first line to be listed (i.e. the line# of
2321\ the line pointed to by PCODE is >= CURR_LINENO)
2330LDY #2
2340LDA (pcode),Y   \ this is the LSB of the current line#
2350SEC
2360SBC curr_lineno
2370DEY
2380LDA (pcode),Y   \ this is the MSB of the current line#
2390BPL P%+5   \ negative line# MSB = end-of-program marker
2400JMP done
2410SBC curr_lineno+1
2420BPL foundFirstLine
2430\ nope - move to the next line
2440LDY #3
2450LDA (pcode),Y   \ this is the line length
2460CLC
2470ADC pcode
2480STA pcode
2490BCC P%+4
2500INC pcode+1
2510JMP checkNextLine
2520 
2530.foundFirstLine
2540\ if the next non-space byte in the keyboard buffer is ",", then parse
2541\ the end line#
2550JSR skipSpaces
2560CMP #&2C
2570BEQ parseEndLineNo
2580 
2590\ if the byte is not ".", then jump to the normal BRK handler
2600CMP #&2E
2610BNE defaultBRK
2620 
2630\ the input was of the form "LIST 12345.", so set the last line#
2631\ to be the same as the first line#
2640LDA curr_lineno
2650STA last_lineno
2660LDA curr_lineno+1
2670STA last_lineno+1
2680JMP parseEOL
2690 
2700.parseEndLineNo
2710\ if the next non-space byte in the keyboard buffer is &8D (pseudo-keyword
2711\ for a line#), then decode the line# into LAST_LINENO
2712\ NOTE - While decodeLineNo stores the result in CURR_LINENO (thus
2713\ corrupting it), the main loop extracts the line# each time it starts
2714\ a new line of program code, and so will restore it when it starts
2715\ processing the first line.
2720JSR skipSpaces
2730CMP #&8D
2740BNE endParseInput
2750JSR decodeLineNo
2760STA last_lineno+1
2770LDA curr_lineno
2780STA last_lineno
2790JSR skipSpaces
2800 
2810.endParseInput
2820\ check for the trailing "."
2830CMP #&2E
2840BEQ P%+5
2850JMP defaultBRK
2860 
2870.parseEOL
2880\ check for the terminating CR
2890JSR skipSpaces
2900CMP #&0D
2910BEQ P%+5
2920JMP defaultBRK
2930 
2940\ start taking input from the program code i.e. PINPUT <- PCODE
2950LDA pcode
2960STA pinput
2970LDA pcode+1
2980STA pinput+1
2990 
5000\ === MAIN LOOP ===========================================================
5001 
5002\ We now start printing the listing, by stepping through each byte of
5003\ the program code, deciding how to print it out, until we go past LAST_LINENO.
5004 
5010.processNextByte
5020\ check if we're at the start of a line in the program code
5030JSR getNextByte
5040CMP #&0D
5050BNE printCode
5060 
5070\ yup - print a newline, save the line# in CURR_LINENO
5080JSR osnewl
5090JSR getNextByte
5100STA curr_lineno+1
5110JSR getNextByte
5120STA curr_lineno
5130 
5140\ skip over the line length byte
5150JSR getNextByte
5160 
5170\ check if we're done (CURR_LINENO > LAST_LINENO)
5180LDA last_lineno
5190SEC
5200SBC curr_lineno
5210LDA last_lineno+1
5220SBC curr_lineno+1
5230BMI done
5240 
5390\ print the current line# (with a field width of 5)
5400JSR &9923
5410 
5420\ print a space
5430LDA #&20
5440JSR oswrch
5450 
5460.startNextLine
5470\ initialize for the next line of program code, then loop back for the next byte
5471\   IN_REM <- 0
5472\   IN_QUOTES <- 0
5473\   IN_ASM_LABEL <- 0
5474\   INDENT_PENDING <- &FF
5480LDX #0
5490STX in_rem
5500STX in_quotes
5510STX in_asm_label
5520DEX
5530STX indent_pending
5540BMI processNextByte
5550 
5560.done
5570\ we're all done - warm-start BASIC
5580JSR osnewl
5590JMP &8AF3
5600 
5670\ we now print out the next byte of program code (in A)
5671 
5680.printCode
5690 
5700\ if we have a line# (pseudo-keyword &8D), then decode and print it out
5710CMP #&8D
5720BNE P%+11
5730JSR decodeLineNo
5740JSR &991F   \ this prints the IAC as a 16-bit number
5750JMP processNextByte
5760 
5770\ if we have a double-quote, then toggle the IN_QUOTES flag
5780CMP #&22
5790BNE P%+10
5800LDA in_quotes
5810EOR #&FF
5820STA in_quotes
5830LDA #&22
5840 
5850\ if we are currently in a quoted string or a REM statement,
5851\ then output the current byte verbatim
5860BIT in_rem
5870BMI P%+6
5880BIT in_quotes
5890BPL P%+5
5900JMP outputByte
5910 
5920\ if we have a colon, then print a newline, indent, print a colon
5930CMP #&3A
5940BNE P%+18
5950JSR osnewl
5960LDX #5
5970JSR indent
5980LDA #&3A
5990JSR oswrch
6000JMP startNextLine
6010 
6020\ if we are currently in assembly code, then jump to handle that
6030BIT in_basic
6040BPL checkAssembly
6050 
6060\ if we have a REM token, then update the flag
6070CMP #&F4
6080BNE P%+6
6090LDX #&FF
6100STX in_rem
6110 
6120\ check if we have a NEXT or UNTIL token
6130CMP #&ED
6140BEQ P%+6
6150CMP #&FD
6160BNE postNextUntil
6170\ yup - decrease the current level of indentation
6180JSR dedent
6190\ if we have a NEXT token, and the next program byte is a ",", then dedent again
6191\ NOTE - We peek ahead at the program bytes, and don't consume them.
6200CMP #&FD
6210BEQ postNextUntil
6220LDY #0
6230.checkForComma
6240LDA (pinput),Y
6250INY
6260CMP #&2C
6270BNE P%+5
6280JSR dedent
6290\ if we don't have a colon or the start of the next program line,
6291\ then loop back to check for another ","
6300CMP #&3A
6310BEQ P%+6
6320CMP #&0D
6330BNE checkForComma
6340LDA #&ED   \ restore the NEXT token
6350 
6360.postNextUntil
6370\ if the byte is "[" (start assembly code), then indent to col.24, flag that
6371\ we are not in BASIC code
6380CMP #&5B
6390BNE P%+11
6400LDX #24
6410JSR indent
6420LDX #0
6430STX in_basic
6440 
6450\ if we need to indent, then make it so
6460BIT indent_pending
6470BPL P%+7
6480LDX curr_indent
6490JSR indent
6500 
6510\ if we have a FOR or REPEAT token, then increase the indent
6520CMP #&E3
6530BEQ P%+6
6540CMP #&F5
6550BNE outputByte
6560INC curr_indent
6570INC curr_indent
6580BNE outputByte
6590 
6600.checkAssembly
6610 
6620\ if we haven't indented yet, and we have a ".", then flag that we are
6621\ in an assembly label
6630LDY indent_pending   \ remember this flag
6631STY temp2
6640BPL P%+10
6650CMP #&2E
6660BNE P%+6
6670LDX #&FF
6680STX in_asm_label
6690 
6700\ if we haven't indented yet, and are in a label, and we've found
6701\ the end of the label, then update the "in label" flag
6710BIT indent_pending
6720BPL postAsmPrefix
6730BIT in_asm_label
6740BPL P%+10
6750CMP #&20
6760BNE postAsmPrefix
6770LDX #0
6780STX in_asm_label
6790 
6800\ if we have something other than a space, then indent to col.24
6810CMP #&20
6820BEQ postAsmPrefix
6830LDX #24
6840JSR indent
6850 
6860.postAsmPrefix
6870\ if we have a "\" (start of comment), and it's not stand-alone,
6871\ then show it at col.50
6880CMP #&5C
6890BNE P%+11
6891BIT temp2
6892BMI P%+7
6894LDX #50
6895JSR indent
6920 
6930\ if we have a "]" (end of assembly code), then flag that we are in BASIC code
6940CMP #&5D
6950BNE outputByte
6960LDX #&FF
6970STX in_basic
6980 
6990.outputByte
7000JSR &B50E   \ this prints the character or token in A
7010JMP processNextByte
7020 
8000\ === SUPPORT ROUTINES ====================================================
8010 
8020\ get the next byte from PINPUT (keyboard buffer or program code)
8030 
8040.getNextByte
8050LDY #0
8060LDA (pinput),Y
8070INC pinput
8080BNE P%+4
8090INC pinput+1
8100 
8110\ check for Escape
8120BIT &FF
8130BPL P%+14
8140BRK
8150EQUB &17
8160EQUB &0A : EQUB &0D : EQUS "Escape." : EQUB 0
8170 
8180RTS
8190 
8200\ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
8201 
8202\ print spaces until the cursor is at the column specified in X
8210 
8220.indent
8230PHA
8240\ NOTE - PCODE is only used when parsing the keyboard input,
8241\ and we re-use that byte here.
8250STX pcode
8260 
8270\ get the current text cursor position
8280LDA #&86
8290JSR osbyte
8300 
8310\ subtract the requested column position to get the number of spaces
8311\ we need to print (this won't work properly if the indent is so large,
8312\ it wraps).
8320TXA
8330SEC
8340SBC pcode
8350BPL indentDone
8360 
8370\ print the spaces
8380TAX
8390LDA #&20
8400JSR oswrch
8410INX
8420BNE P%-4
8430 
8440.indentDone
8450\ flag that the current line has been indented
8460LDA #0
8470STA indent_pending
8480 
8490PLA
8500RTS
8510 
8520\ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
8521 
8522\ get the next non-space byte from PINPUT (keyboard buffer or program code)
8530 
8540.skipSpaces
8550JSR getNextByte
8560CMP #&20
8570BEQ skipSpaces
8580 
8590RTS
8600 
8610\ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
8611 
8612\ decode a line number in the 3 bytes at PINPUT, and store it in CURR_LINENO.
8613\ Adapted from the BBC BASIC ROM &97EB (p334). See p174 for details
8614\ on how these are encoded.
8620 
8630.decodeLineNo
8640JSR getNextByte
8650ASL A
8660ASL A
8670TAX
8680JSR getNextByte
8690STA curr_lineno
8700JSR getNextByte
8710STA curr_lineno+1
8720TXA
8730AND #&C0
8740EOR curr_lineno
8750STA curr_lineno
8760TXA
8770ASL A
8780ASL A
8790EOR curr_lineno+1
8800STA curr_lineno+1
8810 
8820RTS
8830 
8840\ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
8841 
8842\ decrease the level of indentation (to a minimum of 6)
8850 
8860.dedent
8870DEC curr_indent
8880DEC curr_indent
8890 
8900LDX #6
8910CPX curr_indent
8920BCC P%+4
8930STX curr_indent
8940 
8950RTS `
8960 
10000] : NEXT opt
10010PRINT
10020PRINT "To save the generated machine code:"
10030PRINT "  *SAVE lst2 " + STR$~(BASE) + " " + STR$~(P%)
10040PRINT
10050PRINT "To activate it now:"
10060PRINT "  CALL &" + STR$~(BASE)
10070PRINT "Or to reload it at a later time:"
10080PRINT "  *lst2"

