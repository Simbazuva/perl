(-W1 -Od -Olt -DDEBUGGING -Gt2048
array.c cmd.c cons.c consarg.c doarg.c doio.c dolist.c dump.c form.c
hash.c perl.c perly.c regcomp.c regexec.c stab.c str.c util.c
)
(-W1 -Od -Olt -B2C2L -B3C3L -DDEBUGGING eval.c{evalargs.xc} toke.c)
(-W1 -Od -Olt -I.
os2\os2.c os2\popen.c os2\mktemp.c os2\director.c os2\suffix.c
)

setargv.obj
os2\perl.def
os2\perl.bad
perl.exe

-AL -LB -S0x8800
