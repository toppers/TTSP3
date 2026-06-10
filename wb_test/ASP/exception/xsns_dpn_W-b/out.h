/*
 *  white-box: kernel/exception.c L102 br[2] — xsns_dpn: p_runtsk==NULL
 *  L102 br[2]: p_runtsk == NULL → state=true（短絡評価の最終条件）
 *  route    : ext_tsk() → 実行可能タスクなし → アイドル（p_runtsk==NULL）
 *             → custom idle hook（xsns_dpn_W_b_idle）が CPU 例外を発生
 *             → CPU 例外ハンドラ（xsns_dpn_W_b_exc）で xsns_dpn(p_excinf)==true
 *  注入     : COPTS に -include ttsp_custom_idle.inc（カーネル無改変）
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void xsns_dpn_W_b_idle(void);
extern void xsns_dpn_W_b_exc(void *p_excinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
