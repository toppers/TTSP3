/*
 *  white-box: kernel/alarm.c — call_alarm: force_unlock_spin path
 *  branch   : if (sense_lock()) — TRUE — alarm handler left CPU locked via iloc_cpu()
 *             → call_alarm calls force_unlock_spin(p_my_pcb) instead of lock_cpu()
 *  route    : start alarm; handler calls iwup_tsk then iloc_cpu(); returns CPU-locked
 *  kernel   : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void alarm_W_a_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
