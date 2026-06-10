/*
 *  white-box: time_event.c §5-c の残 — tmevtb_enqueue 転送(L546)
 *  build : -DTOPPERS_TEPP_PRC=0x1（PRC1のみTEPP）
 *  route : タイムアウト待ちタスクを mig_tsk で非TEPP PE(PRC2)へ移送
 *          → task_manage.c L392 tmevtb_enqueue(p_new_pcb=PRC2) → p_tevtcb==NULL → P_TM_PCB(L546)
 *  kernel: FMP3 3.4.0（要 TOPPERS_TEPP_PRC #ifndef ガード）
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER
#include "ttsp_target_test.h"
extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void target_task(intptr_t exinf);
#endif /* TOPPERS_TTG_HEADER */
