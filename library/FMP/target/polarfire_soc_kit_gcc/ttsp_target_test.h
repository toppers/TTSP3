/*
 *  TTSP3 適合性テスト：ターゲット依存定義（polarfire_soc_kit_gcc / RV64GC, FMP3）
 *
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  PolarFire SoC（U54 / RV64GC）FMP3 向け TTSP3 ターゲットテスト定義．
 *  RISC-V 部分は asp3_core/target/polarfire_soc_kit_gcc/ttsp3 を，FMP 固有部
 *  （IPI・非タスクスタック・プロセッサクラス）は zybo_z7_gcc を基に作成．
 *
 *  本ファイルは TTSP3 library/FMP/test 系から include される．
 *  kernel.h / sil.h / polarfire_soc.h は include 側で取り込み済み．
 *
 *  カバー範囲（初版）：純カーネル系 API（task/sem/flg/dtq/pdq/mtx/mpf/
 *  sys_manage 等）．HWタイマ早送り（FUNC_TIME=false）・割込み発生
 *  （FUNC_INTERRUPT=false：PLIC のソフト発生手段なし）・CPU例外
 *  （FUNC_EXCEPTION=false）は本版では対象外．各マクロは out.cfg の
 *  コンパイルのために定義しておく．
 */

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

/*
 *  FMP3 3.4.0 は acquire_glock_wo_preempt を持たず acquire_glock のみ．
 *  TTSP3 の FMP テストライブラリ（ttsp_test_lib.c）は acquire_glock_wo_preempt
 *  を参照するため，本ヘッダ（ttsp_test_lib.c の末尾で include される）で
 *  acquire_glock への別名を与えてリンクを通す．giant lock は同一で，
 *  プリエンプション禁止の有無の差はテスト用途では許容される．
 */
#ifndef acquire_glock_wo_preempt
#define acquire_glock_wo_preempt  acquire_glock
#endif

/*
 *  CPU例外を発生させる命令（RISC-V：未定義命令）
 *  rv64gc は圧縮命令ありのため __riscv_compressed で分岐．
 */
#ifdef __riscv_compressed
#define RAISE_CPU_EXCEPTION     Asm(".short 0x0000")
#else
#define RAISE_CPU_EXCEPTION     Asm(".word 0x00000000")
#endif

/*
 *  タスク／非タスクコンテキストのスタックサイズ（RV64＝64bit）
 */
#define TTSP_TASK_STACK_SIZE      4096
#define TTSP_NON_TASK_STACK_SIZE  4096

/*
 *  各種異常値
 */
#define TTSP_INVALID_FUNC_ADDRESS  0x123456
#define TTSP_INVALID_STK_ADDRESS   0x123456
#define TTSP_INVALID_MPF_ADDRESS   0x123456
#define TTSP_INVALID_VAR_ADDRESS   0x123456
#define TTSP_INVALID_STACK_SIZE    0x01

/*
 *  プロセッサクラス（FMP）．本ターゲットは PRC1/PRC2 をサポート．
 *  TTSP_INVALID_PRC_CLASS は存在しないクラス番号．
 */
#define TTSP_INVALID_PRC_CLASS  5

/*
 *  割込み優先度
 */
#define TTSP_TMIN_INTPRI       TMIN_INTPRI
#define TTSP_GE_TIMER_INTPRI   TMIN_INTPRI
#define TTSP_HIGH_INTPRI       -5
#define TTSP_MID_INTPRI        -4
#define TTSP_LOW_INTPRI        -3

/*
 *  割込み番号（interrupt モジュールは SKIP のため値はコンパイル用．
 *  PLIC 割込み源＝1〜）
 */
#define TTSP_INTNO_A   1
#define TTSP_INTNO_B   2
#define TTSP_INTNO_C   3
#define TTSP_INTNO_D   4
#define TTSP_INTNO_E   5
#define TTSP_INTNO_F   6
#define TTSP_INTNO_PE2_A  (0x20000|1)   /* PE2割込み番号A（interrupt は SKIP） */
#define TTSP_INVALID_INTNO  0x400
#define TTSP_NOT_SET_INTNO  16

/* 割込みトリガ属性（PLIC＝レベルトリガ相当．SKIP のため TA_NULL でよい） */
#define TTSP_INT_TRIGGER_ATTR  TA_NULL

#define TTSP_INHNO_A   TTSP_INTNO_A
#define TTSP_INHNO_B   TTSP_INTNO_B
#define TTSP_INHNO_C   TTSP_INTNO_C
#define TTSP_INHNO_PE2_A  TTSP_INTNO_PE2_A
#define TTSP_INVALID_INHNO  TTSP_INVALID_INTNO

/*
 *  プロセッサ間割込み（IPI）番号・優先度
 *  本版は FUNC_TIME=false のためティック更新IPIは登録しないが，
 *  互換のため定義は残す（CLINT MSI を想定）．
 */
#define TTSP_IPI_INTPRI -16
#define TTSP_IPI_INTNO 0x0004
#define TTSP_IPI_INTNO_PRC1 (0x10000|TTSP_IPI_INTNO)
#define TTSP_IPI_INTNO_PRC2 (0x20000|TTSP_IPI_INTNO)

/*
 *  CPU例外ハンドラ番号（exception モジュールは SKIP）
 *  RISC-V：mcause 例外コード 2＝未定義（不正）命令．
 */
#define TTSP_EXCNO_A   2                /* 未定義（不正）命令 EXCNO_IINST */
#define TTSP_EXCNO_B   3                /* ブレークポイント EXCNO_BREAKPOINT */
#define TTSP_EXCNO_C   5                /* フェイタル相当：ロードアクセスフォルト EXCNO_FAULT_LOAD */
#define TTSP_EXCNO_PE2_A  (0x20000|2)
#define TTSP_EXCNO_PE2_B  (0x20000|3)
#define TTSP_INVALID_EXCNO  100

/*
 *  タイムアウト用変数・fch_hrt 係数
 */
#define TTSP_SIL_DLY_NSE_TIME  100000
#define TTSP_LOOP_COUNT        500000
#define TTSP_MOD_FCH_CNT       1

/*
 *  非タスクコンテキスト用スタック（実体は ttsp_target_test.c）
 */
extern STK_T nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];
extern STK_T nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];

/*
 *  TTSP3用の関数（実体は ttsp_target_test.c）
 */
extern void ttsp_target_stop_tick(void);
extern void ttsp_target_start_tick(void);
extern void ttsp_target_gain_tick(void);
extern void ttsp_target_gain_tick_ipi(void);
extern void ttsp_int_raise(INTNO intno);
extern void ttsp_cpuexc_raise(EXCNO excno);
extern void ttsp_cpuexc_hook(EXCNO excno, void* p_excinf);
extern void ttsp_clear_int_req(INTNO intno);

#endif /* TTSP_TARGET_TEST_H */
