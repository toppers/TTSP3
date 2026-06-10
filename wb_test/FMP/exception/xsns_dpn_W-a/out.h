/*
 *  white-box: kernel/exception.c xsns_dpn — check_tskctx()==false else branch
 *  branch   : check_tskctx() == false (task context) → state = true [NGKI3152]
 *  route    : MAIN_TASK calls xsns_dpn(NULL) directly from task context
 *             (excpt_nest_count == 0 → sense_context() false → else branch)
 *  note     : FMP の kerflg_table=false 分岐は check_tskctx() ガードにより構造的到達不能
 *             （kerflg_table は start_dispatch 前に true 化、例外コンテキスト時は常に true）。
 *             ASP xsns_dpn_W-a（kerflg=false 経路）とは対象分岐が異なる FMP 固有設計。
 *  kernel   : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
