/*
 *  white-box: kernel/cyclic.c L259 br[1] — call_cyclic: CPU re-lock skipped
 *  L259 br[1]: !sense_lock() is FALSE — cyclic handler left CPU locked via iloc_cpu()
 *  route    : start cyclic; handler calls iwup_tsk then iloc_cpu(); call_cyclic skips lock_cpu()
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void cyclic_W_a_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
