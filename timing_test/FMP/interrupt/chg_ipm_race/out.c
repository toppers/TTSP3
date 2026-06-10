/*
 *  FMP chg_ipm dispatch race — 案3（ストレスループ）
 *
 *  目的: interrupt.c chg_ipm の多コアレース分岐
 *        (1) retry 直後 `if (p_selftsk != p_schedtsk){release_glock;dispatch;goto retry;}`
 *        (2) ENAALL 内 `if (p_selftsk != p_schedtsk){release_glock;dispatch;...}`
 *        を、外部ツールなしの2コア・ストレスループで到達させる。
 *
 *  シナリオ:
 *    PE1 : MAIN_TASK : chg_ipm(TIPM_ENAALL) を LOOP_N 回密ループ
 *    PE2 : RACER_TASK: sus_tsk(MAIN_TASK)/rsm_tsk(MAIN_TASK) を done まで密ループ
 *
 *  停止トリガー（TIMING_TEST.md §7 案A）: MAIN は LOOP_N 回で確定終了し done=true、
 *  RACER は sus→rsm を対で回し done で break。ヒット判定はオフライン gcov。
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

#define LOOP_N      500000U
#define RACER_GUARD 200000000U

static volatile bool_t done = false;

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

void racer_task(intptr_t exinf)
{
	uint_t guard = 0;

	while (!done && guard < RACER_GUARD) {
		(void) sus_tsk(MAIN_TASK);
		(void) rsm_tsk(MAIN_TASK);
		guard++;
	}
}

void main_task(intptr_t exinf)
{
	uint_t i;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_chg_ipm_race: Start");

	ttsp_check_point(1);

	for (i = 0; i < LOOP_N; i++) {
		(void) chg_ipm(TIPM_ENAALL);
	}

	done = true;

	ttsp_check_point(2);

	syslog_0(LOG_NOTICE, "FMP_chg_ipm_race: loop done");
	ttsp_check_finish(3);
}
