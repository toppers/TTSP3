/*
 *  white-box: kernel/time_event.c tmevtb_delete go-up path (L315)
 *  branch   : EVTTIM_LT(event_evttim, parent->evttim) — replacement < parent → go up
 *  route    : 6-alarm heap on PE1; cancel index-4 alarm; last element (250000) < parent at index-2 (300000)
 *  kernel   : FMP3 3.4.0 (ASP time_event_W-b の FMP 版・ヒープ算法は同一)
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void time_event_W_b_alm_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
