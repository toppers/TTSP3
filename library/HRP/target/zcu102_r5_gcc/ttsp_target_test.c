/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2009-2019 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  本ファイルはTTSP3ライセンスに従って利用できる．詳細は配布物に含まれ
 *  る利用条件を参照のこと．
 *
 *  [改変] 2026-06-12: zybo_z7_gcc版をベースに，HRP3のZynqMP Cortex-R5
 *  （zcu102_r5_gcc）ターゲット向けに新規作成．時刻制御（FUNC_TIME）を
 *  MPCoreグローバルタイマからTTCベースの高分解能タイマ（ttc_hrt.cの
 *  TTSP支援関数）に変更した．
 */

/*
 *		ターゲット依存のテストサポート関数（ZynqMP Cortex-R5用）
 */

#include "kernel/kernel_impl.h"
#include <sil.h>
#include "ttsp_target_test.h"
#include "chip_timer.h"

/*
 *  スタック領域の定義
 */
TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack");
#ifdef TTSP_STACK_SHARE_HRP
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section");
#endif /* TTSP_STACK_SHARE_HRP */

/*
 *  タイマを停止する
 */
void
ttsp_target_stop_tick(void)
{
	ttc_hrt_ttsp_stop_tick();
}

/*
 *  タイマを動作させる
 */
void
ttsp_target_start_tick(void)
{
	ttc_hrt_ttsp_start_tick();
}

/*
 *  タイマの時刻を進める（1μ秒）
 */
void
ttsp_target_gain_tick(void)
{
	ttc_hrt_ttsp_gain_tick();
}

/*
 *  割込みを発生させる
 */
void
ttsp_int_raise(INTNO intno)
{
	raise_int(intno);
}

/*
 *  CPU例外を発生させる
 */
void
ttsp_cpuexc_raise(EXCNO excno)
{
	if (excno == TTSP_EXCNO_A) {
		RAISE_CPU_EXCEPTION;
	}
}

/*
 *  CPU例外発生時のフック処理
 */
void
ttsp_cpuexc_hook(EXCNO excno, void *p_excinf)
{
}

/*
 *  割込み要求のクリア
 */
void
ttsp_clear_int_req(INTNO intno)
{
}
