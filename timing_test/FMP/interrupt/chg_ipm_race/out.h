/*
 *  white-box timing: interrupt.c chg_ipm — マルチコア dispatch レース
 *  branch : retry 直後 `if (p_selftsk != p_schedtsk){release_glock;dispatch;goto retry;}`（§2-a）
 *           および ENAALL 内 `if (p_selftsk != p_schedtsk){...dispatch...}`
 *           （chg_ipm 自身はスケジュールを変えないため、別PEが p_schedtsk を変えたときのみ真）
 *  method : 案3（2コア・ストレスループ）。PE1=MAIN が chg_ipm(TIPM_ENAALL) を密ループ、
 *           PE2=RACER が sus_tsk/rsm_tsk(MAIN_TASK) で p_schedtsk を反復書換。
 *  kernel : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void racer_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
