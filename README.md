This program provides a formatted listing of a BBC BASIC program, by splitting multiple statements out onto separate lines, indenting loops, etc. Assembly language also gets nicely formatted.

I was doing a lot of work on the BBC Micro in the late 80's, and recently managed to retrieve a lot of it from floppy discs. The discs were in relatively good condition, given that they were nearly 40 years old (!), but it was still a challenge reading them (they were shedding so much oxide, we had to clean the disk heads after each use :-)).

This program was incredibly useful, but we were only able to get a binary executable off the floppies, not the source code, so I disassembled it, annotated it, and have made it available here.

Working on the BBC Micro was not easy, since you only had, at best, 24&frac34;KB of memory (!) (5&frac34;KB if you were using hi-res graphics), so saving every byte of memory possible was really important. Since BASIC is an interpreted language, and each line had a 3-byte overhead, you could save quite a few bytes by cramming as many statements onto each line as possible, separated by a colon, thus saving 2 bytes for each statement.

Of course, this made the code very difficult to read, so I wrote this listing formatter, which converts something like this:
```
    807DEFPROCsp LOCALT%,I%,P%,S$:PROCblip(100):REPEATUNTILNOTINKEY-99:REPEAT:PRINTTAB(0,24)SPC10f$B$bk$Y$"Press  SPACE  "bb$SPC10;:PROCfx21:T%=INKEY500:IFT%=esc T%=FNesc(T%):GOTO810:ELSEIFT%=32ORT%<>-1ORRND(500)>1GOTO810
    809P%=msgs+1:FORI%=1TORND(?msgs):S$=$P%:P%=P%+LENS$+1:NEXT:prvb=prvb+1:PRINTTAB(0,24)CHR$(128+RND(7))SPC38;:I%=1:REPEAT:PRINTTAB(1,24)MID$(STRING$(39," ")+"Ancient proverb #"+STR$prvb+": "+S$+STRING$(50," "),I%,38);:I%=I%+1:UNTILI%=70+LENS$ORNOTINKEY20
    810UNTILT%=32:PRINTTAB(0,24)SPC39;:ENDPROC
```
into this:
```
  807 DEFPROCsp LOCALT%,I%,P%,S$
     :PROCblip(100)
     :REPEATUNTILNOTINKEY-99
     :REPEAT
     :  PRINTTAB(0,24)SPC10f$B$bk$Y$"Press  SPACE  "bb$SPC10;
     :  PROCfx21
     :  T%=INKEY500
     :  IFT%=esc T%=FNesc(T%)
     :  GOTO810
     :  ELSEIFT%=32ORT%<>-1ORRND(500)>1GOTO810
  809   P%=msgs+1
     :  FORI%=1TORND(?msgs)
     :    S$=$P%
     :    P%=P%+LENS$+1
     :  NEXT
     :  prvb=prvb+1
     :  PRINTTAB(0,24)CHR$(128+RND(7))SPC38;
     :  I%=1
     :  REPEAT
     :    PRINTTAB(1,24)MID$(STRING$(39," ")+"Ancient proverb #"+STR$prvb+": "+S$+STRING$(50," "),I%,38);
     :    I%=I%+1
     :  UNTILI%=70+LENS$ORNOTINKEY20
  810 UNTILT%=32
     :PRINTTAB(0,24)SPC39;
     :ENDPROC
```

To get the fully authentic Beeb experience, you can type the program in from the listing :-), but as a convenience, a `.ssd` file is provided with the source code, together with a binary executable.

Load the program into memory like this:
```
    *LST2
```

And then enter LIST commands as normal, but with a trailing period e.g.
```
    LIST 100,200.
    LIST ,200.
    LIST 100,.
    LIST.
```
