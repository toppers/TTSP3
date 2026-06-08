/*
 *  ASP_time_event_W_b
 *
 *  [WB] time_event.c L302 br[0]: EVTTIM_LT(event_evttim, parent->evttim)
 *       → 削除ノードの親より小さいlastノードを上方へ挿入（go-up path in tmevtb_delete）
 *
 *  ヒープ配置（1始端インデックス）:
 *    6アラームを下記順に sta_alm して1-basedヒープを構築:
 *      index1=ALM1(reltim=100000), index2=ALM2(reltim=300000),
 *      index3=ALM3(reltim=200000), index4=ALM4(reltim=400000),
 *      index5=ALM5(reltim=350000), index6=ALM6(reltim=250000)
 *    ALM4(index4)を stp_alm でキャンセル → tmevtb_delete(index=4):
 *      last_index=6, event_evttim=ALM6.evttim≈T0+250000
 *      index=4 > ROOT_INDEX=1, parent(4)=2, ALM2.evttim≈T0+300000
 *      EVTTIM_LT(250000, 300000)=TRUE → L302 br[0]（go-up）
 *      → ALM2をindex4へ移動，tmevt_up(2, 250000): stop at index2 (parent=ALM1(100000))
 *      → ALM6(250000) placed at index2
 *
 *  ALM6(250000)のinsert確認: parent(6)=3=ALM3(reltim=200000), 250000>200000 → 移動なし ✓
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void time_event_W_b_alm_handler(intptr_t exinf)
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
	syslog_0(LOG_NOTICE, "ASP_time_event_W_b: Start");

	ttsp_check_point(1);

	/*
	 *  6アラームを挿入順に sta_alm → 1-basedヒープ:
	 *    [1=ALM1(100000), 2=ALM2(300000), 3=ALM3(200000),
	 *     4=ALM4(400000), 5=ALM5(350000), 6=ALM6(250000)]
	 *  挿入時の sift-up: 各値が親より大きいため移動なし
	 */
	ercd = sta_alm(ASP_time_event_W_b_ALM1, 100000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_b_ALM2, 300000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_b_ALM3, 200000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_b_ALM4, 400000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_b_ALM5, 350000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ASP_time_event_W_b_ALM6, 250000U);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/*
	 *  ALM4(index=4)をキャンセル → tmevtb_delete(index=4):
	 *    last_index=6, event_evttim=ALM6.evttim≈T0+250000
	 *    parent(4)=2, ALM2.evttim≈T0+300000
	 *    EVTTIM_LT(250000, 300000)=TRUE → L302 br[0]（go-up）
	 *    ALM2 → index4; tmevt_up(2, 250000): parent(2)=1=ALM1(100000) → stay at 2
	 *    ALM6(250000) → index2
	 */
	ercd = stp_alm(ASP_time_event_W_b_ALM4);
	check_ercd(ercd, E_OK);

	/* ALM4が停止していることを確認 */
	ercd = ttsp_ref_alm(ASP_time_event_W_b_ALM4, &ralm);
	check_ercd(ercd, E_OK);
	check_value(ralm.almstat, TALM_STP);

	ttsp_check_point(3);

	/* 残アラームをキャンセルして後片付け */
	ercd = stp_alm(ASP_time_event_W_b_ALM1);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_b_ALM2);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_b_ALM3);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_b_ALM5);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(ASP_time_event_W_b_ALM6);
	check_ercd(ercd, E_OK);

	syslog_0(LOG_NOTICE, "ASP_time_event_W_b: OK");
	ttsp_check_finish(4);
}
