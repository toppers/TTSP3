/*
 *  FMP_chg_spr_W_a
 *
 *  [WB] task_manage.c chg_spr L599-608 (self-demote local dispatch / NGKI3673):
 *       L600-602: subprio_primap & PRIMAP_BIT(pri) && !boosted → change_subprio
 *       L603    : p_selftsk != p_my_pcb->p_schedtsk → TRUE
 *       L605    : dispatch()  ← BB では到達不能（SUBPRIO_TEST_PLAN.md §3.1）
 *
 *  シナリオ（全タスク PE1 / 専用優先度 TSK_PRI_SUBPRI=13・ENA_SPR(13)）:
 *    MAIN(pri1) が TASK_A(subpri1)・TASK_B(subpri2) を pri13 に用意（MAIN は走行継続）
 *    → MAIN slp_tsk → TASK_A(head) 走行 → chg_spr(TSK_SELF,5) で自己降格
 *      → TASK_B(subpri2) が schedtsk となり dispatch() で TASK_B へ切替（L603-608 到達）
 *    → TASK_B が並び替え(porder)を検証 → wup_tsk(MAIN) → MAIN(pri1) が finish
 *    TASK_A は dispatch 内で停留し本テスト中は復帰しない（チェックポイント順序が証拠）。
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

STK_T ttg_stack_1[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
STK_T ttg_stack_2[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

/*
 *  TASK_A: 自己降格タスク。MAIN の slp_tsk 後に走行する。
 *  chg_spr(TSK_SELF,5) が内部で dispatch() を呼び TASK_B へ制御が移る（戻らない）。
 */
void chg_spr_W_a_task_a(intptr_t exinf)
{
	ER ercd;

	ttsp_check_point(3);
	/*
	 *  自己降格：subpri 1→5。TASK_B(subpri2) が schedtsk となり dispatch（L603-605）。
	 *  ここで TASK_B へ制御が移る。TASK_B が slp_tsk すると本タスクが再び schedtsk と
	 *  なり dispatch() が戻り，L606(ercd=E_OK)→L607(goto) を経て chg_spr が E_OK で返る。
	 */
	ercd = chg_spr(TSK_SELF, 5);
	check_ercd(ercd, E_OK);		/* L606 経由で E_OK 復帰したことの確認 */

	ttsp_check_point(6);
	ercd = wup_tsk(MAIN_TASK);	/* MAIN(pri1) を起こす → 即 preempt して finish へ */
	check_ercd(ercd, E_OK);
	(void) slp_tsk();
}

/*
 *  TASK_B: 切替先タスク。dispatch が起きた証拠（CP4）＋並び替え検証＋MAIN 起床。
 */
void chg_spr_W_a_task_b(intptr_t exinf)
{
	ER ercd;
	T_TTSP_RTSK rtsk;

	ttsp_check_point(4);	/* TASK_A の chg_spr による dispatch が起きた証拠 */

	/* 並び替え検証：TASK_B が先頭(porder1)、TASK_A は subpri5 で末尾(porder2) */
	ercd = ttsp_ref_tsk(FMP_chg_spr_W_a_TASK_B, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.tskstat, TTS_RUN);
	check_value(rtsk.porder, 1);

	ercd = ttsp_ref_tsk(FMP_chg_spr_W_a_TASK_A, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.subpri, 5);
	check_value(rtsk.porder, 2);

	ttsp_check_point(5);

	/*
	 *  ここで slp_tsk すると TASK_A(subpri5) が再び schedtsk となり，
	 *  TASK_A の chg_spr 内 dispatch() が戻る（L606-607 を踏む）。
	 *  その後 TASK_A が MAIN を起こし MAIN が finish する。
	 */
	(void) slp_tsk();
}

void main_task(intptr_t exinf)
{
	ER ercd;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_chg_spr_W_a: Start");

	ttsp_check_point(1);

	/* TASK_A, TASK_B を pri13 に起動（ready）。MAIN は pri1 で走行継続 */
	ercd = act_tsk(FMP_chg_spr_W_a_TASK_A);
	check_ercd(ercd, E_OK);
	ercd = act_tsk(FMP_chg_spr_W_a_TASK_B);
	check_ercd(ercd, E_OK);

	/* subpri 設定：TASK_A=1（先頭）、TASK_B=2（後方） */
	ercd = chg_spr(FMP_chg_spr_W_a_TASK_A, 1);
	check_ercd(ercd, E_OK);
	ercd = chg_spr(FMP_chg_spr_W_a_TASK_B, 2);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/* MAIN をブロック → TASK_A(head) が走行し自己降格→dispatch */
	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	/* TASK_A の wup_tsk で復帰（dispatch 検証＆L606-607 到達後） */
	ttsp_check_point(7);
	syslog_0(LOG_NOTICE, "FMP_chg_spr_W_a: OK");
	ttsp_check_finish(8);
}
