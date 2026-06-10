/*
 *  FMP_cyclic_W_a
 *
 *  [WB] cyclic.c call_cyclic: if (sense_lock()) → force_unlock_spin(p_my_pcb)
 *       周期通知ハンドラが iloc_cpu() を呼んで CPU ロック状態で返ったとき，
 *       call_cyclic は lock_cpu() ではなく force_unlock_spin() を実行する．
 *
 *  シナリオ:
 *    1. MAIN_TASK が sta_cyc → slp_tsk で待機（HRT 動作中）
 *    2. 周期ハンドラ発火: call_cyclic が release_glock()/unlock_cpu() → ハンドラ呼出
 *    3. ハンドラが iwup_tsk(MAIN_TASK) で MAIN を起床可能にし iloc_cpu() で返る
 *    4. call_cyclic: sense_lock() == TRUE → force_unlock_spin(p_my_pcb)
 *    5. MAIN_TASK が slp_tsk から復帰; stp_cyc で停止
 *
 *  ASP の cyclic_W-a の FMP 版．FMP では対応コードが force_unlock_spin に置換．
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

void cyclic_W_a_handler(intptr_t exinf)
{
	iwup_tsk(MAIN_TASK);
	iloc_cpu();
}

void main_task(intptr_t exinf)
{
	ER ercd;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_cyclic_W_a: Start");

	ttsp_check_point(1);

	ttsp_target_start_tick();
	ercd = sta_cyc(FMP_cyclic_W_a_CYC1);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	ercd = slp_tsk();
	check_ercd(ercd, E_OK);

	ercd = stp_cyc(FMP_cyclic_W_a_CYC1);
	check_ercd(ercd, E_OK);

	ttsp_check_point(3);

	syslog_0(LOG_NOTICE, "FMP_cyclic_W_a: OK");
	ttsp_check_finish(4);
}
