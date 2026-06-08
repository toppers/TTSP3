/*
 *  ASP_alarm_W_a
 *
 *  [WB] alarm.c L241 br[1]: !sense_lock() — FALSE path（CPUロック済み）
 *       通知ハンドラが iloc_cpu() を呼んで CPU ロック状態で返ったとき，
 *       call_alarm は重複 lock_cpu() を行わない（br[1]）．
 *
 *  シナリオ:
 *    1. MAIN_TASK が sta_alm → slp_tsk で待機（HRT 動作中）
 *    2. アラーム発火: call_alarm が unlock_cpu() → alarm_W_a_handler を呼出
 *    3. ハンドラが iwup_tsk(MAIN_TASK) で MAIN を起床可能にし，
 *       続いて iloc_cpu() を呼んで CPU ロック状態で返る
 *    4. call_alarm: sense_lock() == TRUE → L241 br[1]（lock_cpu() をスキップ）
 *    5. MAIN_TASK が slp_tsk から復帰
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void alarm_W_a_handler(intptr_t exinf)
{
	/*
	 *  MAIN_TASK を起床可能にする（CPU アンロック割込みコンテキスト）
	 *  iloc_cpu() で CPU をロック状態で返る → L241 br[1] をカバー
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
	syslog_0(LOG_NOTICE, "ASP_alarm_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  HRT を開始してアラームを設定する．
	 *  slp_tsk で待機; ハンドラが iwup_tsk で起床させる．
	 *  タイミング競合でアラームが slp_tsk 前に発火した場合，
	 *  wupcnt が加算されて slp_tsk は即座に E_OK で返る．
	 */
	ttsp_target_start_tick();
	ercd = sta_alm(ASP_alarm_W_a_ALM1, 100U);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	ttsp_check_point(3);

	syslog_0(LOG_NOTICE, "ASP_alarm_W_a: OK");
	ttsp_check_finish(4);
}
