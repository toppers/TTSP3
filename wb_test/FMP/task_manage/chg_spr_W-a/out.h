/*
 *  white-box: kernel/task_manage.c chg_spr L603-608 (self-demote local dispatch)
 *  branch   : after change_subprio, p_selftsk != p_my_pcb->p_schedtsk → dispatch()
 *  route    : TASK_A(pri13,subpri1) running self-demotes via chg_spr(TSK_SELF,5);
 *             sibling TASK_B(pri13,subpri2) becomes schedtsk → local dispatch on PE1.
 *  why WB   : BB(TESRY)では actor が dispatch でCPUを失い，TTG生成の actor内 post 検証へ
 *             戻れずデッドロックする（SUBPRIO_TEST_PLAN.md §3.1）。手書きで切替先(TASK_B)が
 *             検証・解放(MAIN起床)を担い，制御移行を成立させる。
 *  kernel   : FMP3 3.4.0 (asp3_zybo 兄弟の fmp3・UPSTREAM_KERNEL.md 固定版)
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern STK_T ttg_stack_1[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
extern STK_T ttg_stack_2[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];

extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void chg_spr_W_a_task_a(intptr_t exinf);
extern void chg_spr_W_a_task_b(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
