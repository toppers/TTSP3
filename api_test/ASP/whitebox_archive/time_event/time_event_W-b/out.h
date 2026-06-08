/*
 *  white-box: kernel/time_event.c  L302 br[0] — tmevtb_delete go-up path
 *  L302 br[0]: EVTTIM_LT(event_evttim, parent->evttim) — replacement < parent → go up
 *  route    : 6-alarm heap; cancel index-4 alarm; last element (250000) < parent at index-2 (300000)
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void time_event_W_b_alm_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
