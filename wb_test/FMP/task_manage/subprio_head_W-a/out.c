/*
 *  FMP_subprio_head_W_a
 *
 *  [WB] task.c queue_insert_subprio_head L235-241 のループ（continue/break）:
 *       change_priority(mtxmode=true) → L382 subprio有効 → L383 mtxmode → L384
 *       queue_insert_subprio_head。その内部ループ
 *         for(p_entry...) if (subpri <= current_subpri(entry)) break;
 *       を「非boosted（current_subpri=実subpri）」挿入で走査させる。
 *
 *  シナリオ（全 PE1 / 専用 TSK_PRI_SUBPRI=13・ENA_SPR(13)）:
 *    MAIN(pri1) が TASK_X を pri13・subpri2 で起動 → slp_tsk
 *    TASK_X 走行 → loc_mtx(ceiling=13) で boosted（current_subpri=0・先頭維持）
 *      → 兄弟 TASK_P(subpri1)・TASK_Q(subpri3) を起動（pri13 ready）
 *      → unl_mtx で boosted 解除：mutex_drop_priority → change_priority(mtxmode=true)
 *        → queue_insert_subprio_head に current_subpri=2 を渡す：
 *           P(1): 2<=1? no（continue）, Q(3): 2<=3? yes（break）→ P と Q の間へ挿入
 *      → TASK_X は subpri2 で porder2 となり schedtsk=P へ dispatch
 *    TASK_P 走行 → MAIN 起床 → MAIN が pri13 並び（P1,X2,Q3）を検証して finish
 *
 *  F-e-4(BB) は boosted（current_subpri=0）で即 break する経路のみ。本 WB は非boosted の
 *  ループ走査（continue→break）を補完する。
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
STK_T ttg_stack_3[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

/*
 *  TASK_X: ceiling ミューテックスで boosted 化 → 兄弟を用意 → unl_mtx で
 *  queue_insert_subprio_head のループ走査を誘発する。
 */
void subprio_head_W_a_task_x(intptr_t exinf)
{
	ER ercd;

	ttsp_check_point(3);

	/* boosted 化（ceiling=13・同優先度）。current_subpri=0 で先頭を維持し走行継続 */
	ercd = loc_mtx(FMP_subprio_head_W_a_MTX1);
	check_ercd(ercd, E_OK);

	/* 兄弟を pri13 に用意（boosted な TASK_X が先頭のままなので走行は継続） */
	ercd = act_tsk(FMP_subprio_head_W_a_TASK_P);
	check_ercd(ercd, E_OK);
	ercd = act_tsk(FMP_subprio_head_W_a_TASK_Q);
	check_ercd(ercd, E_OK);
	ercd = chg_spr(FMP_subprio_head_W_a_TASK_P, 1);
	check_ercd(ercd, E_OK);
	ercd = chg_spr(FMP_subprio_head_W_a_TASK_Q, 3);
	check_ercd(ercd, E_OK);

	ttsp_check_point(4);

	/*
	 *  boosted 解除：current_subpri が 0→2(実subpri) となり change_priority(mtxmode=true)
	 *  → queue_insert_subprio_head が P(1) を走査(continue)→Q(3)で break。
	 *  TASK_X は porder2 へ落ち schedtsk=P となるため，本呼出し後 TASK_P へ dispatch。
	 */
	ercd = unl_mtx(FMP_subprio_head_W_a_MTX1);
	check_ercd(ercd, E_OK);

	/* ここへは（再 schedtsk 化まで）戻らない。戻った場合に備え停留のみ */
	(void) slp_tsk();
}

/* TASK_P: unl_mtx 後の先頭(subpri1)。MAIN を起こす */
void subprio_head_W_a_task_p(intptr_t exinf)
{
	ttsp_check_point(5);
	(void) wup_tsk(MAIN_TASK);
	(void) slp_tsk();
}

/* TASK_Q: 本テスト中は走行しない */
void subprio_head_W_a_task_q(intptr_t exinf)
{
	(void) slp_tsk();
}

void main_task(intptr_t exinf)
{
	ER ercd;
	T_TTSP_RTSK rtsk;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_subprio_head_W_a: Start");

	ttsp_check_point(1);

	/* TASK_X のみ起動し subpri=2 に設定（pri13 唯一→次に走行する） */
	ercd = act_tsk(FMP_subprio_head_W_a_TASK_X);
	check_ercd(ercd, E_OK);
	ercd = chg_spr(FMP_subprio_head_W_a_TASK_X, 2);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/* TASK_X へ譲る */
	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	/* TASK_P の wup_tsk で復帰。pri13 の並びを検証：P(1,porder1) X(2,porder2) Q(3,porder3) */
	ttsp_check_point(6);

	ercd = ttsp_ref_tsk(FMP_subprio_head_W_a_TASK_P, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.subpri, 1);
	check_value(rtsk.porder, 1);

	ercd = ttsp_ref_tsk(FMP_subprio_head_W_a_TASK_X, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.subpri, 2);
	check_value(rtsk.porder, 2);

	ercd = ttsp_ref_tsk(FMP_subprio_head_W_a_TASK_Q, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.subpri, 3);
	check_value(rtsk.porder, 3);

	syslog_0(LOG_NOTICE, "FMP_subprio_head_W_a: OK");
	ttsp_check_finish(7);
}
