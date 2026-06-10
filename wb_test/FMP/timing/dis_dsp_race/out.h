/*
 *  white-box timing prototype: sys_manage.c dis_dsp L603-606
 *  branch : if (p_selftsk != p_my_pcb->p_schedtsk) → release_glock/dispatch/retry
 *           （dis_dsp 自身はスケジュールを変えないため、別PEが p_schedtsk を
 *             変更したときのみ真。純マルチコアレース分岐）
 *  method : 案3（2コア・ストレスループ）。PE1=MAIN が dis_dsp/ena_dsp を密ループ、
 *           PE2=RACER が sus_tsk/rsm_tsk(MAIN_TASK) で MAIN の p_schedtsk を反復書換。
 *  kernel : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void racer_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
