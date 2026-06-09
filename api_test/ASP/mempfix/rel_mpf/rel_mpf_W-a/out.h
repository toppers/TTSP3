/*
 *  white-box: kernel/mempfix.c L309 br[0] — rel_mpf: misaligned block pointer → E_PAR
 *  L309 br[0]: CHECK_PAR(blkoffset % blksz == 0U) — FALSE (blkoffset is not a multiple of blksz)
 *  route    : pget_mpf → blk=pool_base; rel_mpf(blk+1) → blkoffset=1, 1%256≠0 → E_PAR
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
