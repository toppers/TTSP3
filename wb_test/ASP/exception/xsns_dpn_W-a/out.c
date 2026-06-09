/*
 *  ASP_xsns_dpn_W_a
 *
 *  [WB] exception.c L101 br: kerflg==false 短絡評価パス
 *       初期化ルーチンから xsns_dpn(NULL) を呼び出す．
 *       この時点で kerflg==false（startup.c L125 の kerflg=true より前）
 *       → 短絡評価 → state=true が返る（L101 br[0] をカバー）．
 *
 *  シナリオ:
 *    1. sta_ker() → 初期化ルーチン呼び出し（startup.c L112-113）
 *    2. xsns_dpn_W_a_init: xsns_dpn(NULL) を呼び出す
 *       kerflg==false のため最初の &&（L101 br[0]）で短絡評価 → state=true
 *    3. sta_ker() → kerflg=true（startup.c L125）→ スケジューラ起動
 *    4. MAIN_TASK: 初期化ルーチンの結果（true）を検証
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

static bool_t init_result;

void xsns_dpn_W_a_init(intptr_t exinf)
{
	/* kerflg == false: sta_ker が kerflg=true を設定する前（startup.c L125 より前） */
	init_result = xsns_dpn(NULL);
}

void main_task(intptr_t exinf)
{
	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_xsns_dpn_W_a: Start");

	ttsp_check_point(1);

	/* 初期化ルーチンで kerflg==false 時に xsns_dpn を呼んだ結果は true */
	check_value((int_t)init_result, (int_t)true);

	ttsp_check_point(2);

	syslog_0(LOG_NOTICE, "ASP_xsns_dpn_W_a: OK");
	ttsp_check_finish(3);
}
