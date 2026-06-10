/*
 *  FMP_tepp1_W_b — time_event.c §5-c tmevtb_enqueue 転送(L546)
 *
 *  TOPPERS_TEPP_PRC=0x1（PRC1のみTEPP）。タイムアウト待ちのタスクを mig_tsk で
 *  非TEPP の PRC2 へ移送すると、task_manage.c の移送処理（タイムアウト待ち分岐）が
 *    L390 tmevtb_dequeue(p_my_pcb=PRC1)           … 自PE=TEPP なので local
 *    L392 tmevtb_enqueue(p_new_pcb=PRC2)           … PRC2=p_tevtcb==NULL → P_TM_PCB(L546)
 *  を実行する。
 *
 *  シナリオ:
 *    PRC1 TARGET(pri2・CLS_ALL_PRC1=affinity{1,2}): tslp_tsk(MOD) で時刻待ち→ブロック
 *    PRC1 MAIN(pri3): TARGET が待ちに入った後 mig_tsk(TARGET, PRC2) → L546。
 *                     その後 TARGET の timeout 満了(PRC2で E_TMOUT)を待って finish。
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

#define MOD_TMOUT  30000U
#define WAIT_GUARD 300000000U

static volatile bool_t target_slept = false;
static volatile bool_t target_done  = false;

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

/* PRC1: タイムアウト待ちに入る（mig_tsk の対象） */
void target_task(intptr_t exinf)
{
	target_slept = true;
	(void) tslp_tsk(MOD_TMOUT);     /* 時刻イベント登録。mig 後 PRC2 で timeout 満了 */
	target_done = true;
	ext_tsk();
}

/* PRC1: TARGET を PRC2 へ移送（L546 を踏む）→ 完了待ち→ finish */
void main_task(intptr_t exinf)
{
	ER ercd;
	uint_t guard = 0;

	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_tepp1_W_b: Start");

	ttsp_check_point(1);

	while (!target_slept && guard < WAIT_GUARD) { guard++; }
	ercd = mig_tsk(TARGET_TASK, PRC2);   /* → task_manage.c L392 tmevtb_enqueue → L546 */
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	guard = 0;
	while (!target_done && guard < WAIT_GUARD) { guard++; }
	check_value((int_t) target_done, (int_t) true);

	ttsp_check_point(3);
	syslog_0(LOG_NOTICE, "FMP_tepp1_W_b: OK");
	ttsp_check_finish(4);
}
