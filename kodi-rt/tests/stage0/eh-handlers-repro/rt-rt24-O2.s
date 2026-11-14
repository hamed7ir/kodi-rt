	.syntax	unified
	.def	"@feat.00";
	.scl	3;
	.type	0;
	.endef
	.globl	"@feat.00"
"@feat.00" = 0
	.file	"rt.cpp"
	.def	"?g@@YAHXZ";
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,"?g@@YAHXZ",unique,0
	.globl	"?g@@YAHXZ"                     @ -- Begin function ?g@@YAHXZ
	.p2align	1
	.code	16
	.thumb_func
"?g@@YAHXZ":                            @ @"?g@@YAHXZ"
$Mfunc_begin0:
.seh_proc "?g@@YAHXZ"
	.seh_handler __CxxFrameHandler3, %unwind, %except
@ %bb.0:
	push	{r6, lr}
	.seh_save_regs	{r6, lr}
	sub	sp, #24
	.seh_stackalloc	24
	.seh_endprologue
	mov	r6, sp
	mvn	r12, #1
	str.w	r12, [r6]
	str.w	r12, [r6, #4]
$Mtmp0:                                 @ EH_LABEL
	bl	"?f@@YAXXZ"
$Mtmp1:                                 @ EH_LABEL
@ %bb.1:
	movs	r0, #0
	str	r0, [r6, #12]                   @ 4-byte Spill
	b	$MBB0_3
$MBB0_3:                                @ Block address taken
$ehgcr_0_2:
	ldr	r0, [r6, #12]                   @ 4-byte Reload
	.seh_startepilogue
	add	sp, #24
	.seh_stackalloc	24
	pop	{r6, pc}
	.seh_save_regs	{r6, lr}
	.seh_endepilogue
	.seh_handlerdata
	.long	"$cppxdata$?g@@YAHXZ"@imgrel
	.section	.text,"xr",one_only,"?g@@YAHXZ",unique,0
	.seh_endproc
	.def	"?catch$3@?0??g@@YAHXZ@4HA";
	.scl	3;
	.type	32;
	.endef
	.p2align	1
"?catch$3@?0??g@@YAHXZ@4HA":
.seh_proc "?catch$3@?0??g@@YAHXZ@4HA"
	.seh_handler __CxxFrameHandler3, %unwind, %except
$MBB0_30:
	push	{r6, lr}
	.seh_save_regs	{r6, lr}
	sub	sp, #24
	.seh_stackalloc	24
	.seh_endprologue
	ldr	r0, [r6, #16]
	ldr	r0, [r0]
	str	r0, [r6, #12]                   @ 4-byte Spill
	movw	r0, :lower16:$MBB0_3
	movt	r0, :upper16:$MBB0_3
	.seh_startepilogue
	add	sp, #24
	.seh_stackalloc	24
	pop.w	{r6, lr}
	.seh_save_regs_w	{r6, lr}
	bx	lr
	.seh_nop
	.seh_endepilogue
	.seh_handlerdata
	.long	"$cppxdata$?g@@YAHXZ"@imgrel
	.section	.text,"xr",one_only,"?g@@YAHXZ",unique,0
	.seh_endproc
	.def	"?catch$4@?0??g@@YAHXZ@4HA";
	.scl	3;
	.type	32;
	.endef
	.p2align	1
"?catch$4@?0??g@@YAHXZ@4HA":
.seh_proc "?catch$4@?0??g@@YAHXZ@4HA"
	.seh_handler __CxxFrameHandler3, %unwind, %except
$MBB0_4:
	push	{r6, lr}
	.seh_save_regs	{r6, lr}
	sub	sp, #24
	.seh_stackalloc	24
	.seh_endprologue
	ldr	r0, [r6, #20]
	ldr	r1, [r0]
	adds	r1, #100
	str	r1, [r0]
$Mtmp2:                                 @ EH_LABEL
	movs	r0, #0
	movs	r1, #0
	bl	_CxxThrowException
$Mtmp3:                                 @ EH_LABEL
@ %bb.5:
$Mfunc_end0:
	.seh_handlerdata
	.long	"$cppxdata$?g@@YAHXZ"@imgrel
	.section	.text,"xr",one_only,"?g@@YAHXZ",unique,0
	.seh_endproc
	.section	.xdata,"dr",associative,"?g@@YAHXZ",unique,0
	.p2align	2, 0x0
"$cppxdata$?g@@YAHXZ":
	.long	429065506                       @ MagicNumber
	.long	4                               @ MaxState
	.long	"$stateUnwindMap$?g@@YAHXZ"@imgrel @ UnwindMap
	.long	2                               @ NumTryBlocks
	.long	"$tryMap$?g@@YAHXZ"@imgrel      @ TryBlockMap
	.long	5                               @ IPMapEntries
	.long	"$ip2state$?g@@YAHXZ"@imgrel    @ IPToStateXData
	.long	-32                             @ UnwindHelp
	.long	0                               @ ESTypeList
	.long	1                               @ EHFlags
"$stateUnwindMap$?g@@YAHXZ":
	.long	-1                              @ ToState
	.long	0                               @ Action
	.long	0                               @ ToState
	.long	0                               @ Action
	.long	0                               @ ToState
	.long	0                               @ Action
	.long	-1                              @ ToState
	.long	0                               @ Action
"$tryMap$?g@@YAHXZ":
	.long	1                               @ TryLow
	.long	1                               @ TryHigh
	.long	2                               @ CatchHigh
	.long	1                               @ NumCatches
	.long	"$handlerMap$0$?g@@YAHXZ"@imgrel @ HandlerArray
	.long	0                               @ TryLow
	.long	2                               @ TryHigh
	.long	3                               @ CatchHigh
	.long	1                               @ NumCatches
	.long	"$handlerMap$1$?g@@YAHXZ"@imgrel @ HandlerArray
"$handlerMap$0$?g@@YAHXZ":
	.long	8                               @ Adjectives
	.long	"??_R0?AUE@@@8"@imgrel          @ Type
	.long	-12                             @ CatchObjOffset
	.long	"?catch$4@?0??g@@YAHXZ@4HA"@imgrel @ Handler
"$handlerMap$1$?g@@YAHXZ":
	.long	8                               @ Adjectives
	.long	"??_R0?AUE@@@8"@imgrel          @ Type
	.long	-16                             @ CatchObjOffset
	.long	"?catch$3@?0??g@@YAHXZ@4HA"@imgrel @ Handler
"$ip2state$?g@@YAHXZ":
	.long	$Mfunc_begin0@imgrel            @ IP
	.long	-1                              @ ToState
	.long	$Mtmp0@imgrel                   @ IP
	.long	1                               @ ToState
	.long	$Mtmp1@imgrel                   @ IP
	.long	-1                              @ ToState
	.long	"?catch$3@?0??g@@YAHXZ@4HA"@imgrel @ IP
	.long	3                               @ ToState
	.long	"?catch$4@?0??g@@YAHXZ@4HA"@imgrel @ IP
	.long	2                               @ ToState
	.section	.text,"xr",one_only,"?g@@YAHXZ",unique,0
                                        @ -- End function
	.section	.data,"dw",discard,"??_R0?AUE@@@8"
	.globl	"??_R0?AUE@@@8"                 @ @"??_R0?AUE@@@8"
	.p2align	2, 0x0
"??_R0?AUE@@@8":
	.long	"??_7type_info@@6B@"
	.long	0
	.asciz	".?AUE@@"

	.section	.drectve,"yni"
	.ascii	" /DEFAULTLIB:libcmt.lib"
	.ascii	" /DEFAULTLIB:oldnames.lib"
	.section	.debug$S,"dr"
	.p2align	2, 0x0
	.long	4                               @ Debug section magic
	.long	241
	.long	$Mtmp5-$Mtmp4                   @ Subsection size
$Mtmp4:
	.short	$Mtmp7-$Mtmp6                   @ Record length
$Mtmp6:
	.short	4353                            @ Record kind: S_OBJNAME
	.long	0                               @ Signature
	.byte	0                               @ Object name
	.p2align	2, 0x0
$Mtmp7:
	.short	$Mtmp9-$Mtmp8                   @ Record length
$Mtmp8:
	.short	4412                            @ Record kind: S_COMPILE3
	.long	16385                           @ Flags and language
	.short	244                             @ CPUType
	.short	23                              @ Frontend version
	.short	1
	.short	1
	.short	0
	.short	23011                           @ Backend version
	.short	0
	.short	0
	.short	0
	.asciz	"Varan clang version 23.1.1-rt2.4 (f4d1c31170af3fd72e09fdc3e675971a008abba5)" @ Null-terminated compiler version string
	.p2align	2, 0x0
$Mtmp9:
$Mtmp5:
	.p2align	2, 0x0
	.addrsig
	.addrsig_sym __CxxFrameHandler3
	.addrsig_sym "??_7type_info@@6B@"
	.addrsig_sym "??_R0?AUE@@@8"
