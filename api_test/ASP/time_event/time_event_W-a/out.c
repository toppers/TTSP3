/*
 *  ASP_time_event_W_a
 *
 *  [WB] time_event.c L221 br[1]: child+1 > LAST_INDEX() (no right sibling in tmevt_down)
 *       time_event.c L231 br[0]: EVTTIM_LE(evttim, child->evttim) — early break in tmevt_down
 *
 *  ヒープ配置（1始端インデックス）:
 *    5アラームを下記順に sta_alm して1-basedヒープを構築:
 *      index1=ALM1(reltim=100000), index2=ALM2(reltim=200000),
 *      index3=ALM3(reltim=300000), index4=ALM4(reltim=500000), index5=ALM5(reltim=400000)
 *    ALM2(index2)を stp_alm でキャンセル → tmevtb_delete(index=2):
 *      last_index=5, event_evttim=ALM5.evttim≈T0+400000
 *      parent(2)=1=ALM1(T0+100000), event_evttim > parent.evttim → go down
 *      tmevt_down(2, event_evttim):
 *        LCHILD(2)=4 ≤ LAST_INDEX()=4 → enter loop
 *        child+1=5 ≤ 4? NO → L221 br[1]（右兄弟なし）
 *        child=4=ALM4(T0+500000)
 *        EVTTIM_LE(400000, 500000)=TRUE → L231 br[0]（早期break）
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void time_event_W_a_alm_handler(intptr_t exinf)
{
	/* アラームは stp_alm で事前キャンセルするため，ここには到達しない */
	ttsp_check_point(0);
}

void main_task(intptr_t exinf)
{
	ER ercd;
	T_TTSP_RALM ralm;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_time_event_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  5アラームを挿入順に sta_alm → 1-basedヒープ:
	 *    [1=ALM1(100000), 2=ALM2(200000), 3=ALM3(300000),
	 *     4=ALM4(500000), 5=ALM5(400000)]
	 *  挿入時の sift-up: 各値が親より大きいため移動なし
	 */
	ercd = sta_alm(ASP_time_event_W_a_ALM1, 100000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_a_ALM2, 200000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_a_ALM3, 300000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_a_ALM4, 500000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_a_ALM5, 400000U);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/*
	 *  ALM2(index=2)をキャンセル → tmevtb_delete(index=2):
	 *    last_index=5, event_evttim=ALM5.evttim
	 *    parent(2)=1=ALM1, event_evttim > ALM1.evttim → go down
	 *    tmevt_down(2, event_evttim):
	 *      LCHILD(2)=4 ≤ LAST_INDEX()=4 → enter
	 *      child+1=5 ≤ 4? NO → L221 br[1]（右兄弟なし）
	 *      child=4=ALM4, EVTTIM_LE(400k, 500k)=TRUE → L231 br[0]（早期break）
	 */
	ercd = stp_alm(ASP_time_event_W_a_ALM2);
	check_ercd(ercd, E_OK);

	/* ALM2が停止していることを確認 */
	ercd = ttsp_ref_alm(ASP_time_event_W_a_ALM2, &ralm);
	check_ercd(ercd, E_OK);
	check_value(ralm.almstat, TALM_STP);

	ttsp_check_point(3);

	/* 残アラームをキャンセルして後片付け */
	ercd = stp_alm(ASP_time_event_W_a_ALM1);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_a_ALM3);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_a_ALM4);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_a_ALM5);
	check_ercd(ercd, E_OK);

	syslog_0(LOG_NOTICE, "ASP_time_event_W_a: OK");
	ttsp_check_finish(4);
}
