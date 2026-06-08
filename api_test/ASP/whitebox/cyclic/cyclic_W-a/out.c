/*
 *  ASP_cyclic_W_a
 *
 *  [WB] cyclic.c L259 br[1]: !sense_lock() — FALSE path（CPUロック済み）
 *       通知ハンドラが iloc_cpu() を呼んで CPU ロック状態で返ったとき，
 *       call_cyclic は重複 lock_cpu() を行わない（br[1]）．
 *
 *  シナリオ:
 *    1. MAIN_TASK が sta_cyc → slp_tsk で待機（HRT 動作中）
 *    2. 周期ハンドラ発火: call_cyclic が unlock_cpu() → cyclic_W_a_handler を呼出
 *    3. ハンドラが iwup_tsk(MAIN_TASK) で MAIN を起床可能にし，
 *       続いて iloc_cpu() を呼んで CPU ロック状態で返る
 *    4. call_cyclic: sense_lock() == TRUE → L259 br[1]（lock_cpu() をスキップ）
 *    5. MAIN_TASK が slp_tsk から復帰; stp_cyc で周期ハンドラを停止
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void cyclic_W_a_handler(intptr_t exinf)
{
	/*
	 *  MAIN_TASK を起床可能にする（CPU アンロック割込みコンテキスト）
	 *  iloc_cpu() で CPU をロック状態で返る → L259 br[1] をカバー
	 *  unl_cpu() を呼ばずに返る
	 */
	iwup_tsk(MAIN_TASK);
	iloc_cpu();
}

void main_task(intptr_t exinf)
{
	ER ercd;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_cyclic_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  HRT を開始して周期ハンドラを起動する．
	 *  slp_tsk で待機; ハンドラが iwup_tsk で起床させる．
	 */
	ttsp_target_start_tick();
	ercd = sta_cyc(ASP_cyclic_W_a_CYC1);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	/*
	 *  起床後すみやかに周期ハンドラを停止して多重発火を防ぐ
	 */
	ercd = stp_cyc(ASP_cyclic_W_a_CYC1);
	check_ercd(ercd, E_OK);

	ttsp_check_point(3);

	syslog_0(LOG_NOTICE, "ASP_cyclic_W_a: OK");
	ttsp_check_finish(4);
}
