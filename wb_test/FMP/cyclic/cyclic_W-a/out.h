/*
 *  white-box: kernel/cyclic.c — call_cyclic: force_unlock_spin path
 *  branch   : if (sense_lock()) — TRUE — cyclic handler left CPU locked via iloc_cpu()
 *             → call_cyclic calls force_unlock_spin(p_my_pcb) instead of lock_cpu()
 *  route    : start cyclic; handler calls iwup_tsk then iloc_cpu(); returns CPU-locked
 *  kernel   : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void cyclic_W_a_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
