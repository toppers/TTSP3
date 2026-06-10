/*
 *  FMP_tepp1_W_a — time_event.c §5-c 非TM-processor 時刻イベント転送パス
 *
 *  TOPPERS_TEPP_PRC=0x1（PRC1のみTEPP）でビルドすると PRC2 は p_tevtcb==NULL となり，
 *  PRC2 から登録/解除する時刻イベントは P_TM_PCB(=PRC1) へ転送される。
 *    - initialize_tmevt L168 else: p_my_pcb->p_tevtcb = NULL   ← PRC2 起動時
 *    - tmevtb_enqueue_reltim L582: if(p_tevtcb==NULL) p_pcb=P_TM_PCB ← PRC2 の tslp_tsk/dly_tsk
 *    - tmevtb_dequeue L626       : 同上                          ← wup_tsk による待ち解除(PRC2発行)
 *
 *  シナリオ:
 *    PE2 TEPP_TASK(pri2): tslp_tsk(BIG) で相対タイムアウト登録(L582)→ WAKER に起こされ(L626)→
 *                         dly_tsk(D) で再登録(L582)→満了→ tepp_done=true
 *    PE2 TEPP_WAKER(pri3): TEPP_TASK が tslp で待ちに入った後に wup_tsk(TEPP_TASK)(→L626)
 *    PE1 MAIN(pri1)      : tepp_done を待って finish（tick は止めない）
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

#define DLY_TIME   10000U      /* dly_tsk 相対時間 */
#define BIG_TMOUT  1000000U    /* tslp_tsk タイムアウト（wup が先に来る想定） */
#define WAIT_GUARD 300000000U

static volatile bool_t tepp_slept = false;  /* TEPP_TASK が tslp に入った合図 */
static volatile bool_t tepp_done  = false;

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

/* PE2: 相対タイムアウトの登録(L582)と待ち解除(L626)を非TEPP PEから発行 */
void tepp_task(intptr_t exinf)
{
	ER ercd;

	tepp_slept = true;
	ercd = tslp_tsk(BIG_TMOUT);     /* L582 enqueue_reltim（PRC2→P_TM_PCB） */
	check_ercd(ercd, E_OK);         /* WAKER に起こされ E_OK（タイムアウト前） */

	ercd = dly_tsk(DLY_TIME);       /* L582 enqueue_reltim、満了で復帰 */
	check_ercd(ercd, E_OK);

	tepp_done = true;
	ext_tsk();
}

/* PE2: TEPP_TASK の tslp 待ちを wup で解除 → tmevtb_dequeue(L626) を PRC2 から */
void tepp_waker(intptr_t exinf)
{
	uint_t guard = 0;
	while (!tepp_slept && guard < WAIT_GUARD) { guard++; }
	(void) dly_tsk(DLY_TIME);       /* TEPP_TASK が確実に tslp に入るのを待つ */
	(void) wup_tsk(TEPP_TASK);      /* → task_manage.c tmevtb_dequeue(L626) */
	ext_tsk();
}

/* PE1: 完了待ち→finish。tick は止めない（dly/tslp のため） */
void main_task(intptr_t exinf)
{
	uint_t guard = 0;

	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_tepp1_W_a: Start");

	ttsp_check_point(1);

	while (!tepp_done && guard < WAIT_GUARD) { guard++; }
	check_value((int_t) tepp_done, (int_t) true);

	ttsp_check_point(2);
	syslog_0(LOG_NOTICE, "FMP_tepp1_W_a: OK");
	ttsp_check_finish(3);
}
