/*
 *  white-box: kernel/task.c queue_insert_subprio_head L235-241 (loop traverse + break)
 *  branch   : change_priority(mtxmode=true) → L384 queue_insert_subprio_head；その内部ループ
 *             for(...) if (subpri <= current_subpri(entry)) break;  の continue/break 両アーム
 *  route    : TASK_X(pri13,subpri2) が ceiling=13 ミューテックスで boosted 化 → 兄弟
 *             TASK_P(subpri1)/TASK_Q(subpri3) を用意 → unl_mtx で boosted 解除。
 *             mutex_drop_priority(L281) → change_priority(mtxmode=true) → queue_insert_subprio_head
 *             に非boosted な current_subpri=2 を渡し，P(1)を走査(continue)→Q(3)で break。
 *  why WB   : F-e-4(BB) は boosted(current_subpri=0) で即 break する経路のみ到達。ループ走査
 *             （非boosted 挿入）は mutex unlock 経由でしか起きず BB 表現が難しい（§4・§4-c）。
 *  kernel   : FMP3 3.4.0
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern STK_T ttg_stack_1[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
extern STK_T ttg_stack_2[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
extern STK_T ttg_stack_3[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];

extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void subprio_head_W_a_task_x(intptr_t exinf);
extern void subprio_head_W_a_task_p(intptr_t exinf);
extern void subprio_head_W_a_task_q(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
