/*
 *  white-box timing: sys_manage.c mrot_rdq — マルチコア dispatch レース
 *  branch : L273 `if (p_selftsk != p_schedtsk){release_glock;dispatch;goto unlock_and_exit;}`
 *           （rotate_ready_queue 後、別PEが p_schedtsk を変えたときのみ真。MAIN が単独
 *             優先度なら rotate では変わらず、レースでのみ到達）
 *  method : 案3（2コア・ストレスループ）。PE1=MAIN が mrot_rdq(1, TPRI_SELF) を密ループ、
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
