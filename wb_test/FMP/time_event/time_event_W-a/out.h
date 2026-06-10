/*
 *  white-box: kernel/time_event.c tmevt_down (L234 no-right-sibling + L244 early break)
 *  branch   : child+1 > LAST_INDEX() — left child exists but no right sibling
 *             EVTTIM_LE(evttim, child->evttim) — replacement fits above child, early break
 *  route    : 5-alarm heap on PE1; cancel index-2 alarm; replacement (idx5, large) <= child (idx4, larger)
 *  kernel   : FMP3 3.4.0 (ASP time_event_W-a の FMP 版・ヒープ算法は同一)
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void time_event_W_a_alm_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
