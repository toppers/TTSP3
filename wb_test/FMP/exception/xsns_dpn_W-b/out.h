/*
 *  white-box: kernel/exception.c xsns_dpn — p_my_pcb->p_runtsk == NULL
 *  branch   : check_tskctx()==true 内の && p_my_pcb->p_runtsk != NULL が偽 → state=true
 *  route    : MAIN_TASK を PE1 のみに割り当て、PE2 は実行可能タスクなし → アイドル
 *             （p_runtsk==NULL）→ custom idle フック（xsns_dpn_W_b_idle, PE2 限定）が
 *             CPU 例外を発生 → CPU 例外ハンドラ（xsns_dpn_W_b_exc, PE2）で
 *             xsns_dpn(p_excinf)==true を確認
 *  注入     : COPTS に -include ttsp_custom_idle.inc（fmp3 無改変・禁則②非抵触）
 *  note     : 残る kerflg_table==false 分岐は check_tskctx() ガードにより構造的到達不能
 *             （kerflg_table は start_dispatch 前に true 化、例外コンテキスト時は常に true）
 *  kernel   : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void ttsp_test_lib_init(intptr_t exinf);
extern void xsns_dpn_W_b_idle(void);
extern void xsns_dpn_W_b_exc(void *p_excinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
