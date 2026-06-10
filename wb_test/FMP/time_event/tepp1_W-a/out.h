/*
 *  white-box: kernel/time_event.c §5-c 非TM-processorの時刻イベント転送パス
 *  build   : -DTOPPERS_TEPP_PRC=0x1（PRC1のみTEPP, PRC2はp_tevtcb==NULL）
 *  branch  : initialize_tmevt L168(else: p_tevtcb=NULL)
 *            tmevtb_enqueue_reltim L582 / tmevtb_dequeue L626（p_pcb->p_tevtcb==NULL → P_TM_PCB）
 *  route   : PRC2タスクが tslp_tsk(tmout)/dly_tsk で相対タイムアウト登録、wup_tsk で待ち解除
 *  kernel  : FMP3 3.4.0（要 target_kernel.h の TOPPERS_TEPP_PRC #ifndef ガード）
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER
#include "ttsp_target_test.h"
extern void ttsp_test_lib_init(intptr_t exinf);
extern void main_task(intptr_t exinf);
extern void tepp_task(intptr_t exinf);
extern void tepp_waker(intptr_t exinf);
#endif /* TOPPERS_TTG_HEADER */
