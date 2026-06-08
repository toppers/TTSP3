/*
 *  white-box: kernel/alarm.c L241 br[1] — call_alarm: CPU re-lock skipped
 *  L241 br[1]: !sense_lock() is FALSE — alarm handler left CPU locked via iloc_cpu()
 *  route    : start alarm; handler calls iwup_tsk then iloc_cpu(); call_alarm skips lock_cpu()
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void alarm_W_a_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
