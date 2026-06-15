/*
 *  TTSP3 適合性テスト：ターゲット依存処理（polarfire_soc_kit_gcc / RV64GC, FMP3）
 *
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  PolarFire SoC（U54 / RV64GC）FMP3 向け TTSP3 ターゲットテスト処理．
 *
 *  純カーネル系モジュールのカバーが目的．
 *  - stop_tick/start_tick/gain_tick/gain_tick_ipi は no-op
 *    （HWタイマ早送りに依存するテストは FUNC_TIME=false で生成されない）．
 *  - int_raise は PLIC のソフト発生手段がないため no-op
 *    （FUNC_INTERRUPT=false で interrupt 系テストは生成されない）．
 *  - cpuexc_raise は未定義命令で CPU 例外を発生（FUNC_EXCEPTION 有効時用）．
 */

#include "kernel/kernel_impl.h"
#include "kernel/time_event.h"
#include "kernel/pcb.h"
#include <sil.h>
#include "polarfire_soc.h"
#include "ttsp_target_test.h"

/*
 *  非タスクコンテキスト用スタック
 */
STK_T nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];
STK_T nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];

/*
 *  システム時刻の進みを止める（no-op）
 */
void
ttsp_target_stop_tick(void)
{
}

/*
 *  システム時刻の進みを再開する（no-op）
 */
void
ttsp_target_start_tick(void)
{
}

/*
 *  システム時刻を進める（no-op）
 */
void
ttsp_target_gain_tick(void)
{
}

/*
 *  システム時刻を進める（IPI版・no-op）
 */
void
ttsp_target_gain_tick_ipi(void)
{
}

/*
 *  割込みの発生（PLIC のソフト発生手段がないため no-op）
 */
void
ttsp_int_raise(INTNO intno)
{
    (void) intno;
}

/*
 *  CPU例外の発生（未定義命令）
 */
void
ttsp_cpuexc_raise(EXCNO excno)
{
    if ((excno == TTSP_EXCNO_A) || (excno == TTSP_EXCNO_PE2_A)) {
        RAISE_CPU_EXCEPTION;
    }
}

/*
 *  CPU例外発生時のフック処理（no-op）
 */
void
ttsp_cpuexc_hook(EXCNO excno, void* p_excinf)
{
    (void) excno;
    (void) p_excinf;
}

/*
 *  割込み要求のクリア（no-op）
 */
void
ttsp_clear_int_req(INTNO intno)
{
    (void) intno;
}
