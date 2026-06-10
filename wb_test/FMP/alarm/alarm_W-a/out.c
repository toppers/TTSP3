/*
 *  FMP_alarm_W_a
 *
 *  [WB] alarm.c call_alarm: if (sense_lock()) → force_unlock_spin(p_my_pcb)
 *       通知ハンドラが iloc_cpu() を呼んで CPU ロック状態で返ったとき，
 *       call_alarm は lock_cpu() ではなく force_unlock_spin() を実行する．
 *
 *  シナリオ:
 *    1. MAIN_TASK が sta_alm → slp_tsk で待機（HRT 動作中）
 *    2. アラーム発火: call_alarm が release_glock()/unlock_cpu() → ハンドラ呼出
 *    3. ハンドラが iwup_tsk(MAIN_TASK) で MAIN を起床可能にし，
 *       続いて iloc_cpu() を呼んで CPU ロック状態で返る
 *    4. call_alarm: sense_lock() == TRUE → force_unlock_spin(p_my_pcb)
 *       （保持スピンロックがあれば解放; ここでは p_locspn==NULL）
 *    5. MAIN_TASK が slp_tsk から復帰
 *
 *  ASP の alarm_W-a（!sense_lock() FALSE 分岐）の FMP 版．FMP では
 *  対応コードが force_unlock_spin 呼出しに置き換わっている．
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

void alarm_W_a_handler(intptr_t exinf)
{
	/*
	 *  MAIN_TASK を起床可能にする（CPU アンロック割込みコンテキスト）
	 *  iloc_cpu() で CPU をロック状態で返る → force_unlock_spin パスをカバー
	 */
	iwup_tsk(MAIN_TASK);
	iloc_cpu();
}

void main_task(intptr_t exinf)
{
	ER ercd;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_alarm_W_a: Start");

	ttsp_check_point(1);

	ttsp_target_start_tick();
	ercd = sta_alm(FMP_alarm_W_a_ALM1, 100U);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	ttsp_check_point(3);

	syslog_0(LOG_NOTICE, "FMP_alarm_W_a: OK");
	ttsp_check_finish(4);
}
