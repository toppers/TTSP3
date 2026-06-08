/*
 *  white-box: kernel/task_manage.c:137  branch br[1] — (tskatr & TA_NOACTQUE) != 0U, short-circuit TRUE
 *  category : (ii) 特殊内部状態要  TA_NOACTQUEはcfgの静的属性; TTGのTASK pre_conditionでは設定不可
 *  route    : act_tsk(TASK2)  TASK2 = TA_NOACTQUE|TA_ACT (非休止状態) → E_QOVR
 *  kernel   : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

#define TTSP_STACK_SHARE
extern STK_T ttg_stack_1[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
extern STK_T ttg_stack_2[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];
extern void asp_task_manage_act_tsk_W_a_main(void);
extern void asp_task_manage_act_tsk_W_a_task1(intptr_t exinf);
extern void asp_task_manage_act_tsk_W_a_task2(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void ttg_check_main_task(void);

#endif /* TOPPERS_TTG_HEADER */
