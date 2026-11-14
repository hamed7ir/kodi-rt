	.syntax	unified
	.def	"@feat.00";
	.scl	3;
	.type	0;
	.endef
	.globl	"@feat.00"
"@feat.00" = 0
	.file	"nr.cpp"
	.def	"?f@@YAHH@Z";
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,"?f@@YAHH@Z",unique,0
	.globl	"?f@@YAHH@Z"                    @ -- Begin function ?f@@YAHH@Z
	.p2align	1
	.code	16
	.thumb_func
"?f@@YAHH@Z":                           @ @"?f@@YAHH@Z"
.seh_proc "?f@@YAHH@Z"
@ %bb.0:
	push.w	{r11, lr}
	.seh_save_regs_w	{r11, lr}
	.seh_endprologue
	cmp	r0, #8
	bge	$MBB0_2
@ %bb.1:
	add.w	r0, r0, r0, lsl #1
	.seh_startepilogue
	pop.w	{r11, pc}
	.seh_save_regs_w	{r11, lr}
	.seh_endepilogue
$MBB0_2:
	bl	"?die@@YAXH@Z"
	.seh_endproc
                                        @ -- End function
	.def	"?g@@YAXH@Z";
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,"?g@@YAXH@Z",unique,1
	.globl	"?g@@YAXH@Z"                    @ -- Begin function ?g@@YAXH@Z
	.p2align	1
	.code	16
	.thumb_func
"?g@@YAXH@Z":                           @ @"?g@@YAXH@Z"
.seh_proc "?g@@YAXH@Z"
@ %bb.0:
	push.w	{r11, lr}
	.seh_save_regs_w	{r11, lr}
	.seh_endprologue
	adds	r0, #1
	bl	"?die@@YAXH@Z"
	.seh_endproc
                                        @ -- End function
	.section	.drectve,"yni"
	.ascii	" /DEFAULTLIB:libcmt.lib"
	.ascii	" /DEFAULTLIB:oldnames.lib"
	.section	.debug$S,"dr"
	.p2align	2, 0x0
	.long	4                               @ Debug section magic
	.long	241
	.long	$Mtmp1-$Mtmp0                   @ Subsection size
$Mtmp0:
	.short	$Mtmp3-$Mtmp2                   @ Record length
$Mtmp2:
	.short	4353                            @ Record kind: S_OBJNAME
	.long	0                               @ Signature
	.byte	0                               @ Object name
	.p2align	2, 0x0
$Mtmp3:
	.short	$Mtmp5-$Mtmp4                   @ Record length
$Mtmp4:
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
$Mtmp5:
$Mtmp1:
	.p2align	2, 0x0
	.addrsig
