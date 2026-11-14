; ModuleID = 'F:/kodi-rt/tests/stage0/eh-typeinfo-repro/eh.cpp'
source_filename = "F:/kodi-rt/tests/stage0/eh-typeinfo-repro/eh.cpp"
target datalayout = "e-m:w-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "thumbv7-pc-windows-msvc19.44.35228"

%rtti.TypeDescriptor7 = type { ptr, ptr, [8 x i8] }
%eh.CatchableType = type { i32, ptr, i32, i32, i32, i32, ptr }
%eh.CatchableTypeArray.1 = type { i32, [1 x ptr] }
%eh.ThrowInfo = type { i32, ptr, ptr, ptr }
%struct.E = type { i32 }

$"??_R0?AUE@@@8" = comdat any

$"_CT??_R0?AUE@@@84" = comdat any

$"_CTA1?AUE@@" = comdat any

$"_TI1?AUE@@" = comdat any

@"??_7type_info@@6B@" = external constant ptr
@"??_R0?AUE@@@8" = linkonce_odr global %rtti.TypeDescriptor7 { ptr @"??_7type_info@@6B@", ptr null, [8 x i8] c".?AUE@@\00" }, comdat
@"_CT??_R0?AUE@@@84" = linkonce_odr unnamed_addr constant %eh.CatchableType { i32 0, ptr @"??_R0?AUE@@@8", i32 0, i32 -1, i32 0, i32 4, ptr null }, section ".xdata", comdat
@"_CTA1?AUE@@" = linkonce_odr unnamed_addr constant %eh.CatchableTypeArray.1 { i32 1, [1 x ptr] [ptr @"_CT??_R0?AUE@@@84"] }, section ".xdata", comdat
@"_TI1?AUE@@" = linkonce_odr unnamed_addr constant %eh.ThrowInfo { i32 0, ptr null, ptr null, ptr @"_CTA1?AUE@@" }, section ".xdata", comdat

; Function Attrs: mustprogress sspstrong uwtable
define dso_local arm_aapcs_vfpcc void @"?f@@YAXH@Z"(i32 noundef %0) local_unnamed_addr #0 {
  %2 = alloca %struct.E, align 4
  %3 = icmp eq i32 %0, 0
  br i1 %3, label %5, label %4

4:                                                ; preds = %1
  store i32 %0, ptr %2, align 4
  call arm_aapcs_vfpcc void @_CxxThrowException(ptr nonnull %2, ptr nonnull @"_TI1?AUE@@") #2
  unreachable

5:                                                ; preds = %1
  ret void
}

declare dso_local arm_aapcs_vfpcc void @_CxxThrowException(ptr, ptr) local_unnamed_addr

; Function Attrs: mustprogress sspstrong uwtable
define dso_local arm_aapcs_vfpcc noundef i32 @"?g@@YAHH@Z"(i32 noundef %0) local_unnamed_addr #0 personality ptr @__CxxFrameHandler3 {
  %2 = alloca %struct.E, align 4
  %3 = alloca ptr, align 4
  call void @llvm.lifetime.start.p0(ptr nonnull %2)
  %4 = icmp eq i32 %0, 0
  br i1 %4, label %7, label %5

5:                                                ; preds = %1
  store i32 %0, ptr %2, align 4
  invoke arm_aapcs_vfpcc void @_CxxThrowException(ptr nonnull %2, ptr nonnull @"_TI1?AUE@@") #2
          to label %6 unwind label %8

6:                                                ; preds = %5
  unreachable

7:                                                ; preds = %1
  call void @llvm.lifetime.end.p0(ptr nonnull %2)
  br label %14

8:                                                ; preds = %5
  %9 = catchswitch within none [label %10] unwind to caller

10:                                               ; preds = %8
  %11 = catchpad within %9 [ptr @"??_R0?AUE@@@8", i32 8, ptr %3]
  %12 = load ptr, ptr %3, align 4, !nonnull !8, !align !9
  %13 = load i32, ptr %12, align 4
  catchret from %11 to label %14

14:                                               ; preds = %7, %10
  %15 = phi i32 [ %13, %10 ], [ 0, %7 ]
  ret i32 %15
}

declare dso_local arm_aapcs_vfpcc i32 @__CxxFrameHandler3(...)

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { mustprogress sspstrong uwtable "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="cortex-a9" "target-features"="+armv7-a,+d32,+dsp,+fp16,+fp64,+neon,+read-tp-tpidruro,+thumb-mode,+vfp2,+vfp2sp,+vfp3,+vfp3d16,+vfp3d16sp,+vfp3sp,-aes,-fp-armv8,-fp-armv8d16,-fp-armv8d16sp,-fp-armv8sp,-fp16fml,-fullfp16,-sha2,-vfp4,-vfp4d16,-vfp4d16sp,-vfp4sp" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { noreturn }

!llvm.dbg.cu = !{!0}
!llvm.linker.options = !{!2, !3}
!llvm.module.flags = !{!4, !5, !6}
!llvm.ident = !{!7}

!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus_14, file: !1, producer: "Varan clang version 23.1.1-rt2.2 (0462bd95317e650684c8dc5ea77dc37eacf59adb)", isOptimized: true, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "F:/kodi-rt/tests/stage0/eh-typeinfo-repro\\eh.cpp", directory: "F:\\kodi-rt\\tests\\stage0\\eh-typeinfo-repro")
!2 = !{!"/DEFAULTLIB:libcmt.lib"}
!3 = !{!"/DEFAULTLIB:oldnames.lib"}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"min_enum_size", i32 4}
!6 = !{i32 7, !"uwtable", i32 2}
!7 = !{!"Varan clang version 23.1.1-rt2.2 (0462bd95317e650684c8dc5ea77dc37eacf59adb)"}
!8 = !{}
!9 = !{i64 4}
