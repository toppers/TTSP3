/*
 *  FMP_time_event_W_a
 *
 *  [WB] time_event.c tmevt_down:
 *       L234: child+1 > LAST_INDEX() (右兄弟なし)
 *       L244: EVTTIM_LE(evttim, child->evttim) — 早期 break
 *
 *  ヒープ配置（1始端インデックス, PE1 の p_tmevt_heap）:
 *    5アラームを下記順に sta_alm して1-basedヒープを構築:
 *      index1=ALM1(100000), index2=ALM2(200000), index3=ALM3(300000),
 *      index4=ALM4(500000), index5=ALM5(400000)
 *    ALM2(index2)を stp_alm でキャンセル → tmevtb_delete(index=2):
 *      last_index=5, event_evttim=ALM5.evttim≈T0+400000
 *      parent(2)=1=ALM1(100000), event_evttim > parent.evttim → go down
 *      tmevt_down(2, event_evttim):
 *        LCHILD(2)=4 ≤ LAST_INDEX()=4 → enter loop
 *        child+1=5 ≤ 4? NO → 右兄弟なし分岐
 *        child=4=ALM4(500000)
 *        EVTTIM_LE(400000, 500000)=TRUE → 早期break
 *
 *  ASP time_event_W-a の FMP 版．ヒープ算法が同一のため配置・推論は不変．
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

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
	syslog_0(LOG_NOTICE, "FMP_time_event_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  5アラームを挿入順に sta_alm → 1-basedヒープ:
	 *    [1=ALM1(100000), 2=ALM2(200000), 3=ALM3(300000),
	 *     4=ALM4(500000), 5=ALM5(400000)]
	 */
	ercd = sta_alm(FMP_time_event_W_a_ALM1, 100000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(FMP_time_event_W_a_ALM2, 200000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(FMP_time_event_W_a_ALM3, 300000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(FMP_time_event_W_a_ALM4, 500000U);
	check_ercd(ercd, E_OK);
	ercd = sta_alm(FMP_time_event_W_a_ALM5, 400000U);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/*
	 *  ALM2(index=2)をキャンセル → tmevtb_delete(index=2) →
	 *  tmevt_down で「右兄弟なし」+「早期break」を同時にカバー
	 */
	ercd = stp_alm(FMP_time_event_W_a_ALM2);
	check_ercd(ercd, E_OK);

	ercd = ttsp_ref_alm(FMP_time_event_W_a_ALM2, &ralm);
	check_ercd(ercd, E_OK);
	check_value(ralm.almstat, TALM_STP);

	ttsp_check_point(3);

	/* 残アラームをキャンセルして後片付け */
	ercd = stp_alm(FMP_time_event_W_a_ALM1);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(FMP_time_event_W_a_ALM3);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(FMP_time_event_W_a_ALM4);
	check_ercd(ercd, E_OK);
	ercd = stp_alm(FMP_time_event_W_a_ALM5);
	check_ercd(ercd, E_OK);

	syslog_0(LOG_NOTICE, "FMP_time_event_W_a: OK");
	ttsp_check_finish(4);
}
