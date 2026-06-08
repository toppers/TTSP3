/*
 *  white-box: kernel/mempfix.c L310 br[0] — rel_mpf: block index >= unused → E_PAR
 *  L310 br[0]: CHECK_PAR(blkoffset/blksz < unused) — FALSE (blkidx >= unused high-water mark)
 *  route    : 2×pget_mpf → unused=2; rel_mpf(blk1+2*256) → blkidx=2, 2<2 FALSE → E_PAR
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
