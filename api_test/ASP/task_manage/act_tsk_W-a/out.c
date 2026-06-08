/*
 *  ASP_task_manage_act_tsk_W_a
 *
 *  [WB] task_manage.c L137 br[1]: (tskatr & TA_NOACTQUE) != 0U, short-circuit TRUE
 *  NGKI3528: TA_NOACTQUE属性タスクが非休止状態でact_tskを呼び出すとE_QOVRが返ること
 *
 *  TTG (YAML pre_condition) ではTASKのtskatrを設定できないため,
 *  TA_NOACTQUE|TA_ACT属性タスクを静的cfg (out.cfg) で直接定義する方式2テスト.
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

STK_T ttg_stack_1[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
STK_T ttg_stack_2[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];

void asp_task_manage_act_tsk_W_a_main(void)
{
	ER ercd;

	/* TASK1を起動. MAIN(優先度1) > TASK1(優先度10) なのでMAINが継続 */
	ercd = act_tsk(ASP_task_manage_act_tsk_W_a_TASK1);
	check_ercd(ercd, E_OK);

	/* MAINをスリープしてTASK1に実行を渡す.
	 * TASK1(10) > TASK2(11, TA_ACT) なのでTASK1が先に実行 */
	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	/* TASK1からwup_tsk(MAIN)されてMAINが再開. 優先度1で最高優先 */
	ttsp_check_point(4);

	/* 後片付け: TASK1(ready状態), TASK2(TA_ACT, ready状態) を終了 */
	ercd = ter_tsk(ASP_task_manage_act_tsk_W_a_TASK1);
	check_ercd(ercd, E_OK);
	ercd = ter_tsk(ASP_task_manage_act_tsk_W_a_TASK2);
	check_ercd(ercd, E_OK);
}

void asp_task_manage_act_tsk_W_a_task1(intptr_t exinf)
{
	ER ercd;
	T_TTSP_RTSK rtsk;

	ttsp_check_point(1);

	/* pre_condition: TASK1=running(10), TASK2=ready(TA_NOACTQUE|TA_ACT, 11) */
	ercd = ttsp_ref_tsk(ASP_task_manage_act_tsk_W_a_TASK1, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.tskstat, TTS_RUN);
	check_value(rtsk.tskpri, 10);
	ercd = ttsp_ref_tsk(ASP_task_manage_act_tsk_W_a_TASK2, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.tskstat, TTS_RDY);
	check_value(rtsk.tskpri, 11);
	check_value(rtsk.actcnt, 0);
	ttsp_check_point(2);

	/* do: act_tsk(TASK2) → E_QOVR
	 * L137 br[1]: (tskatr & TA_NOACTQUE) != 0U が TRUE → short-circuit → E_QOVR */
	ercd = act_tsk(ASP_task_manage_act_tsk_W_a_TASK2);
	check_ercd(ercd, E_QOVR);

	/* post_condition: TASK2は変化なし(ready, priority 11, actcnt 0) */
	ercd = ttsp_ref_tsk(ASP_task_manage_act_tsk_W_a_TASK2, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.tskstat, TTS_RDY);
	check_value(rtsk.tskpri, 11);
	check_value(rtsk.actcnt, 0);
	ttsp_check_point(3);

	/* MAINを起床. MAIN(優先度1) > TASK1(優先度10) → dispatchしてMAIN再開 */
	ercd = wup_tsk(MAIN_TASK);
	check_ercd(ercd, E_OK);

	/* ここには到達しない: MAINへdispatch後, MAINがter_tsk(TASK1)を呼ぶ */
	ttsp_check_point(0);
}

void asp_task_manage_act_tsk_W_a_task2(intptr_t exinf)
{
	/* TA_ACT|TA_NOACTQUEタスク: TASK1(10) < TASK2(11) なので実行されず
	 * MAINがter_tsk(TASK2)で終了させる */
	ttsp_check_point(0);
}

void main_task(intptr_t exinf)
{
	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();

	syslog_0(LOG_NOTICE, "ASP_task_manage_act_tsk_W_a: Start");
	asp_task_manage_act_tsk_W_a_main();
	ttg_check_main_task();
	syslog_0(LOG_NOTICE, "ASP_task_manage_act_tsk_W_a: OK");
	ttsp_check_finish(5);
}

void ttg_check_main_task(void)
{
	T_TTSP_RTSK rtsk;
	ER ercd;

	ercd = ttsp_ref_tsk(MAIN_TASK, &rtsk);
	check_ercd(ercd, E_OK);
	check_value(rtsk.tskstat, TTS_RUN);
	check_value(rtsk.tskpri, 1);
	check_value(rtsk.itskpri, 1);
	check_value(rtsk.actcnt, 0);
	check_value(rtsk.wupcnt, 0);
}
