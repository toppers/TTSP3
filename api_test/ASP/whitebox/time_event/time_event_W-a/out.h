/*
 *  white-box: kernel/time_event.c  L221 br[1] + L231 br[0] — tmevt_down heap-down
 *  L221 br[1]: child+1 > LAST_INDEX() — left child exists but no right sibling
 *  L231 br[0]: EVTTIM_LE(evttim, child->evttim) — replacement fits above child, early break
 *  route    : 5-alarm heap; cancel index-2 alarm; replacement (index 5, large) ≤ child (index 4, larger)
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void time_event_W_a_alm_handler(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
