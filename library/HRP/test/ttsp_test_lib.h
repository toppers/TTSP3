/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2020 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2010-2011 by Industrial Technology Institute,
 *								Miyagi Prefectural Government, JAPAN
 *
 *  上記著作権者は，以下の(1)～(4)の条件を満たす場合に限り，本ソフトウェ
 *  ア（本ソフトウェアを改変したものを含む．以下同じ）を使用・複製・改
 *  変・再配布（以下，利用と呼ぶ）することを無償で許諾する．
 *  (1) 本ソフトウェアをソースコードの形で利用する場合には，上記の著作
 *      権表示，この利用条件および下記の無保証規定が，そのままの形でソー
 *      スコード中に含まれていること．
 *  (2) 本ソフトウェアを，ライブラリ形式など，他のソフトウェア開発に使
 *      用できる形で再配布する場合には，再配布に伴うドキュメント（利用
 *      者マニュアルなど）に，上記の著作権表示，この利用条件および下記
 *      の無保証規定を掲載すること．
 *  (3) 本ソフトウェアを，機器に組み込むなど，他のソフトウェア開発に使
 *      用できない形で再配布する場合には，次のいずれかの条件を満たすこ
 *      と．
 *    (a) 再配布に伴うドキュメント（利用者マニュアルなど）に，上記の著
 *        作権表示，この利用条件および下記の無保証規定を掲載すること．
 *    (b) 再配布の形態を，別に定める方法によって，TOPPERSプロジェクトに
 *        報告すること．
 *  (4) 本ソフトウェアの利用により直接的または間接的に生じるいかなる損
 *      害からも，上記著作権者およびTOPPERSプロジェクトを免責すること．
 *      また，本ソフトウェアのユーザまたはエンドユーザからのいかなる理
 *      由に基づく請求からも，上記著作権者およびTOPPERSプロジェクトを
 *      免責すること．
 *
 *  本ソフトウェアは，無保証で提供されているものである．上記著作権者お
 *  よびTOPPERSプロジェクトは，本ソフトウェアに関して，特定の使用目的
 *  に対する適合性も含めて，いかなる保証も行わない．また，本ソフトウェ
 *  アの利用により直接的または間接的に生じたいかなる損害に関しても，そ
 *  の責任を負わない．
 *
 *  $Id: ttsp_test_lib.h 72 2020-03-19 08:08:03Z fujisft-shigihara $
 */

/*
 *		テストプログラム用ライブラリ
 */

#ifndef TTSP_TEST_LIB_H
#define TTSP_TEST_LIB_H

#include <t_stddef.h>
#include <queue.h>

#include <kernel/kernel_impl.h>
#include <kernel/check.h>
#include <kernel/task.h>
#include <kernel/wait.h>
#include <kernel/semaphore.h>
#include <kernel/eventflag.h>
#include <kernel/dataqueue.h>
#include <kernel/pridataq.h>
#include <kernel/mempfix.h>
#include <kernel/time_event.h>
#include <kernel/alarm.h>
#include <kernel/cyclic.h>
#include <kernel/mutex.h>
#include <kernel/messagebuf.h>

#define TTSP_HRP

/*
 *  ターゲット依存の定義
 */
#include "ttsp_target_test.h"

/*
 *  TTSP3ライブラリSVC用の定義
 */
#define TTSP_FN_BASE				20
#define TTSP_FN_CHECK_POINT			(TTSP_FN_BASE + 0)
#define TTSP_FN_WAIT_CHECK_POINT	(TTSP_FN_BASE + 1)
#define TTSP_FN_CHECK_FINISH		(TTSP_FN_BASE + 2)
#define TTSP_FN_STOP_TICK			(TTSP_FN_BASE + 3)
#define TTSP_FN_START_TICK			(TTSP_FN_BASE + 4)
#define TTSP_FN_GAIN_TICK			(TTSP_FN_BASE + 5)
#define TTSP_FN_INT_RAISE			(TTSP_FN_BASE + 6)
#define TTSP_FN_CPUEXC_RAISE		(TTSP_FN_BASE + 7)
#define TTSP_FN_REF_TSK				(TTSP_FN_BASE + 8)
#define TTSP_FN_REF_LOC_MTX			(TTSP_FN_BASE + 9)
#define TTSP_FN_REF_ALM				(TTSP_FN_BASE + 10)
#define TTSP_FN_REF_CYC				(TTSP_FN_BASE + 11)
#define TTSP_FN_REF_DTQ				(TTSP_FN_BASE + 12)
#define TTSP_FN_REF_DATA			(TTSP_FN_BASE + 13)
#define TTSP_FN_REF_SWAIT_DTQ		(TTSP_FN_BASE + 14)
#define TTSP_FN_REF_RWAIT_DTQ		(TTSP_FN_BASE + 15)
#define TTSP_FN_REF_PDQ				(TTSP_FN_BASE + 16)
#define TTSP_FN_REF_PRI_DATA		(TTSP_FN_BASE + 17)
#define TTSP_FN_REF_SWAIT_PDQ		(TTSP_FN_BASE + 18)
#define TTSP_FN_REF_RWAIT_PDQ		(TTSP_FN_BASE + 19)
#define TTSP_FN_REF_SEM				(TTSP_FN_BASE + 20)
#define TTSP_FN_REF_WAIT_SEM		(TTSP_FN_BASE + 21)
#define TTSP_FN_REF_MPF				(TTSP_FN_BASE + 22)
#define TTSP_FN_REF_WAIT_MPF		(TTSP_FN_BASE + 23)
#define TTSP_FN_REF_FLG				(TTSP_FN_BASE + 24)
#define TTSP_FN_REF_RWAIT_FLG		(TTSP_FN_BASE + 25)
#define TTSP_FN_REF_MTX				(TTSP_FN_BASE + 26)
#define TTSP_FN_REF_WAIT_MTX		(TTSP_FN_BASE + 27)
#define TTSP_FN_REF_MBF				(TTSP_FN_BASE + 28)
#define TTSP_FN_REF_MBF_MSG			(TTSP_FN_BASE + 29)
#define TTSP_FN_REF_SWAIT_MBF		(TTSP_FN_BASE + 30)
#define TTSP_FN_REF_RWAIT_MBF		(TTSP_FN_BASE + 31)
#define TTSP_FN_GET_IPM				(TTSP_FN_BASE + 32)
#define TTSP_FN_SET_TIM				(TTSP_FN_BASE + 33)
#define TTSP_FN_GET_TIM				(TTSP_FN_BASE + 34)
#define SVC_FN_ADJ_TIM				(TTSP_FN_BASE + 35)
#define SVC_FN_SET_TIM				(TTSP_FN_BASE + 36)
#define SVC_FN_GET_TIM				(TTSP_FN_BASE + 37)
#define SVC_FN_STA_ALM				(TTSP_FN_BASE + 38)
#define SVC_FN_STP_ALM				(TTSP_FN_BASE + 39)
#define SVC_FN_REF_ALM				(TTSP_FN_BASE + 40)
#define SVC_FN_STA_CYC				(TTSP_FN_BASE + 41)
#define SVC_FN_STP_CYC				(TTSP_FN_BASE + 42)
#define SVC_FN_REF_CYC				(TTSP_FN_BASE + 43)
#define SVC_FN_DIS_INT				(TTSP_FN_BASE + 44)
#define SVC_FN_ENA_INT				(TTSP_FN_BASE + 45)
#define SVC_FN_RAS_INT				(TTSP_FN_BASE + 46)
#define SVC_FN_CLR_INT				(TTSP_FN_BASE + 47)
#define SVC_FN_PRB_INT				(TTSP_FN_BASE + 48)
#define SVC_FN_LOC_CPU				(TTSP_FN_BASE + 49)
#define SVC_FN_UNL_CPU				(TTSP_FN_BASE + 50)
#define SVC_FN_DIS_DSP				(TTSP_FN_BASE + 51)
#define SVC_FN_ENA_DSP				(TTSP_FN_BASE + 52)
#define SVC_FN_CHG_IPM				(TTSP_FN_BASE + 53)
#define SVC_FN_GET_IPM				(TTSP_FN_BASE + 54)
#define SVC_FN_ROT_RDQ				(TTSP_FN_BASE + 55)
#define SVC_FN_GET_LOD				(TTSP_FN_BASE + 56)
#define SVC_FN_GET_NTH				(TTSP_FN_BASE + 57)
#define SVC_FN_ACT_TSK				(TTSP_FN_BASE + 58)
#define SVC_FN_CAN_ACT				(TTSP_FN_BASE + 59)
#define SVC_FN_CHG_PRI				(TTSP_FN_BASE + 60)
#define SVC_FN_GET_PRI				(TTSP_FN_BASE + 61)
#define SVC_FN_GET_TST				(TTSP_FN_BASE + 62)
#define SVC_FN_REF_TSK				(TTSP_FN_BASE + 63)
#define SVC_FN_WUP_TSK				(TTSP_FN_BASE + 64)
#define SVC_FN_CAN_WUP				(TTSP_FN_BASE + 65)
#define SVC_FN_SUS_TSK				(TTSP_FN_BASE + 66)
#define SVC_FN_RSM_TSK				(TTSP_FN_BASE + 67)
#define SVC_FN_REL_WAI				(TTSP_FN_BASE + 68)
#define SVC_FN_TER_TSK				(TTSP_FN_BASE + 69)
#define SVC_FN_RAS_TER				(TTSP_FN_BASE + 70)
#define SVC_FN_DIS_TER				(TTSP_FN_BASE + 71)
#define SVC_FN_ENA_TER				(TTSP_FN_BASE + 72)
#define SVC_FN_WAI_SEM				(TTSP_FN_BASE + 73)
#define SVC_FN_POL_SEM				(TTSP_FN_BASE + 74)
#define SVC_FN_TWAI_SEM				(TTSP_FN_BASE + 75)
#define SVC_FN_SIG_SEM				(TTSP_FN_BASE + 76)
#define SVC_FN_INI_SEM				(TTSP_FN_BASE + 77)
#define SVC_FN_REF_SEM				(TTSP_FN_BASE + 78)
#define SVC_FN_WAI_FLG				(TTSP_FN_BASE + 79)
#define SVC_FN_POL_FLG				(TTSP_FN_BASE + 80)
#define SVC_FN_TWAI_FLG				(TTSP_FN_BASE + 81)
#define SVC_FN_SET_FLG				(TTSP_FN_BASE + 82)
#define SVC_FN_CLR_FLG				(TTSP_FN_BASE + 83)
#define SVC_FN_INI_FLG				(TTSP_FN_BASE + 84)
#define SVC_FN_REF_FLG				(TTSP_FN_BASE + 85)
#define SVC_FN_SND_DTQ				(TTSP_FN_BASE + 86)
#define SVC_FN_PSND_DTQ				(TTSP_FN_BASE + 87)
#define SVC_FN_TSND_DTQ				(TTSP_FN_BASE + 88)
#define SVC_FN_FSND_DTQ				(TTSP_FN_BASE + 89)
#define SVC_FN_RCV_DTQ				(TTSP_FN_BASE + 90)
#define SVC_FN_PRCV_DTQ				(TTSP_FN_BASE + 91)
#define SVC_FN_TRCV_DTQ				(TTSP_FN_BASE + 92)
#define SVC_FN_INI_DTQ				(TTSP_FN_BASE + 93)
#define SVC_FN_REF_DTQ				(TTSP_FN_BASE + 94)
#define SVC_FN_SND_PDQ				(TTSP_FN_BASE + 95)
#define SVC_FN_PSND_PDQ				(TTSP_FN_BASE + 96)
#define SVC_FN_TSND_PDQ				(TTSP_FN_BASE + 97)
#define SVC_FN_RCV_PDQ				(TTSP_FN_BASE + 98)
#define SVC_FN_PRCV_PDQ				(TTSP_FN_BASE + 99)
#define SVC_FN_TRCV_PDQ				(TTSP_FN_BASE + 100)
#define SVC_FN_INI_PDQ				(TTSP_FN_BASE + 101)
#define SVC_FN_REF_PDQ				(TTSP_FN_BASE + 102)
#define SVC_FN_LOC_MTX				(TTSP_FN_BASE + 103)
#define SVC_FN_PLOC_MTX				(TTSP_FN_BASE + 104)
#define SVC_FN_TLOC_MTX				(TTSP_FN_BASE + 105)
#define SVC_FN_UNL_MTX				(TTSP_FN_BASE + 106)
#define SVC_FN_INI_MTX				(TTSP_FN_BASE + 107)
#define SVC_FN_REF_MTX				(TTSP_FN_BASE + 108)
#define SVC_FN_SND_MBF				(TTSP_FN_BASE + 109)
#define SVC_FN_TSND_MBF				(TTSP_FN_BASE + 110)
#define SVC_FN_RCV_MBF				(TTSP_FN_BASE + 111)
#define SVC_FN_TRCV_MBF				(TTSP_FN_BASE + 112)
#define SVC_FN_INI_MBF				(TTSP_FN_BASE + 113)
#define SVC_FN_GET_MPF				(TTSP_FN_BASE + 114)
#define SVC_FN_PGET_MPF				(TTSP_FN_BASE + 115)
#define SVC_FN_TGET_MPF				(TTSP_FN_BASE + 116)
#define SVC_FN_REL_MPF				(TTSP_FN_BASE + 117)
#define SVC_FN_INI_MPF				(TTSP_FN_BASE + 118)
#define SVC_FN_REF_MPF				(TTSP_FN_BASE + 119)
#define SVC_FN_EXT_KER				(TTSP_FN_BASE + 120)
/* 【改変】タイマドライバシミュレータ(simt)で時刻を任意量進める拡張SVC */
#define TTSP_FN_SIMT_ADVANCE		(TTSP_FN_BASE + 121)

/*
 *  メモリ保護向けの抽象化マクロ
 */

#define TTSP_ADJ_TIM(adjtim)									cal_svc(SVC_FN_ADJ_TIM, (adjtim), 0, 0, 0, 0)
#define TTSP_SET_TIM(systim)									cal_svc(SVC_FN_SET_TIM, (systim), 0, 0, 0, 0)
#define TTSP_GET_TIM(p_systim)									cal_svc(SVC_FN_GET_TIM, (intptr_t)(p_systim), 0, 0, 0, 0)
#define TTSP_STA_ALM(almid, almtim)								cal_svc(SVC_FN_STA_ALM, (almid), (almtim), 0, 0, 0)
#define TTSP_STP_ALM(almid)										cal_svc(SVC_FN_STP_ALM, (almid), 0, 0, 0, 0)
#define TTSP_REF_ALM(almid, pk_ralm)							cal_svc(SVC_FN_REF_ALM, (almid), (intptr_t)(pk_ralm), 0, 0, 0)
#define TTSP_STA_CYC(cycid)										cal_svc(SVC_FN_STA_CYC, (cycid), 0, 0, 0, 0)
#define TTSP_STP_CYC(cycid)										cal_svc(SVC_FN_STP_CYC, (cycid), 0, 0, 0, 0)
#define TTSP_REF_CYC(cycid, pk_rcyc)							cal_svc(SVC_FN_REF_CYC, (cycid), (intptr_t)(pk_rcyc), 0, 0, 0)
#define TTSP_DIS_INT(intno)										cal_svc(SVC_FN_DIS_INT, (intno), 0, 0, 0, 0)
#define TTSP_ENA_INT(intno)										cal_svc(SVC_FN_ENA_INT, (intno), 0, 0, 0, 0)
#define TTSP_RAS_INT(intno)										cal_svc(SVC_FN_RAS_INT, (intno), 0, 0, 0, 0)
#define TTSP_CLR_INT(intno)										cal_svc(SVC_FN_CLR_INT, (intno), 0, 0, 0, 0)
#define TTSP_PRB_INT(intno)										cal_svc(SVC_FN_PRB_INT, (intno), 0, 0, 0, 0)
#define TTSP_LOC_CPU()											cal_svc(SVC_FN_LOC_CPU, 0, 0, 0, 0, 0)
#define TTSP_UNL_CPU()											cal_svc(SVC_FN_UNL_CPU, 0, 0, 0, 0, 0)
#define TTSP_DIS_DSP()											cal_svc(SVC_FN_DIS_DSP, 0, 0, 0, 0, 0)
#define TTSP_ENA_DSP()											cal_svc(SVC_FN_ENA_DSP, 0, 0, 0, 0, 0)
#define TTSP_CHG_IPM(intpri)									cal_svc(SVC_FN_CHG_IPM, (intpri), 0, 0, 0, 0)
#define TTSP_GET_IPM(p_intpri)									cal_svc(SVC_FN_GET_IPM, (intptr_t)(p_intpri), 0, 0, 0, 0)
#define TTSP_ROT_RDQ(tskpri)									cal_svc(SVC_FN_ROT_RDQ, (tskpri), 0, 0, 0, 0)
#define TTSP_GET_LOD(tskpri, p_load)							cal_svc(SVC_FN_GET_LOD, (tskpri), (intptr_t)(p_load), 0, 0, 0)
#define TTSP_GET_NTH(tskpri, nth, p_tskid)						cal_svc(SVC_FN_GET_NTH, (tskpri), (nth), (intptr_t)(p_tskid), 0, 0)
#define TTSP_ACT_TSK(tskid)										cal_svc(SVC_FN_ACT_TSK, (tskid), 0, 0, 0, 0)
#define TTSP_CAN_ACT(tskid)										cal_svc(SVC_FN_CAN_ACT, (tskid), 0, 0, 0, 0)
#define TTSP_CHG_PRI(tskid, tskpri)								cal_svc(SVC_FN_CHG_PRI, (tskid), (tskpri), 0, 0, 0)
#define TTSP_GET_PRI(tskid, p_tskpri)							cal_svc(SVC_FN_GET_PRI, (tskid), (intptr_t)(p_tskpri), 0, 0, 0)
#define TTSP_GET_TST(tskid, p_tskstat)							cal_svc(SVC_FN_GET_TST, (tskid), (intptr_t)(p_tskstat), 0, 0, 0)
#define TTSP_REF_TSK(tskid, pk_rtsk)							cal_svc(SVC_FN_REF_TSK, (tskid), (intptr_t)(pk_rtsk), 0, 0, 0)
#define TTSP_WUP_TSK(tskid)										cal_svc(SVC_FN_WUP_TSK, (tskid), 0, 0, 0, 0)
#define TTSP_CAN_WUP(tskid)										cal_svc(SVC_FN_CAN_WUP, (tskid), 0, 0, 0, 0)
#define TTSP_SUS_TSK(tskid)										cal_svc(SVC_FN_SUS_TSK, (tskid), 0, 0, 0, 0)
#define TTSP_RSM_TSK(tskid)										cal_svc(SVC_FN_RSM_TSK, (tskid), 0, 0, 0, 0)
#define TTSP_REL_WAI(tskid)										cal_svc(SVC_FN_REL_WAI, (tskid), 0, 0, 0, 0)
#define TTSP_TER_TSK(tskid)										cal_svc(SVC_FN_TER_TSK, (tskid), 0, 0, 0, 0)
#define TTSP_RAS_TER(tskid)										cal_svc(SVC_FN_RAS_TER, (tskid), 0, 0, 0, 0)
#define TTSP_DIS_TER()											cal_svc(SVC_FN_DIS_TER, 0, 0, 0, 0, 0)
#define TTSP_ENA_TER()											cal_svc(SVC_FN_ENA_TER, 0, 0, 0, 0, 0)
#define TTSP_WAI_SEM(semid)										cal_svc(SVC_FN_WAI_SEM, (semid), 0, 0, 0, 0)
#define TTSP_POL_SEM(semid)										cal_svc(SVC_FN_POL_SEM, (semid), 0, 0, 0, 0)
#define TTSP_TWAI_SEM(semid, tmout)								cal_svc(SVC_FN_TWAI_SEM, (semid), (tmout), 0, 0, 0)
#define TTSP_SIG_SEM(semid)										cal_svc(SVC_FN_SIG_SEM, (semid), 0, 0, 0, 0)
#define TTSP_INI_SEM(semid)										cal_svc(SVC_FN_INI_SEM, (semid), 0, 0, 0, 0)
#define TTSP_REF_SEM(semid, pk_rsem)							cal_svc(SVC_FN_REF_SEM, (semid), (intptr_t)(pk_rsem), 0, 0, 0)
#define TTSP_WAI_FLG(flgid, waiptn, wfmode, p_flgptn)			cal_svc(SVC_FN_WAI_FLG, (flgid), (waiptn), (wfmode), (intptr_t)(p_flgptn), 0)
#define TTSP_POL_FLG(flgid, waiptn, wfmode, p_flgptn)			cal_svc(SVC_FN_POL_FLG, (flgid), (waiptn), (wfmode), (intptr_t)(p_flgptn), 0)
#define TTSP_TWAI_FLG(flgid, waiptn, wfmode, p_flgptn, tmout)	cal_svc(SVC_FN_TWAI_FLG, (flgid), (waiptn), (wfmode), (intptr_t)(p_flgptn), (tmout))
#define TTSP_SET_FLG(flgid, setptn)								cal_svc(SVC_FN_SET_FLG, (flgid), (setptn), 0, 0, 0)
#define TTSP_CLR_FLG(flgid, clrptn)								cal_svc(SVC_FN_CLR_FLG, (flgid), (clrptn), 0, 0, 0)
#define TTSP_INI_FLG(flgid)										cal_svc(SVC_FN_INI_FLG, (flgid), 0, 0, 0, 0)
#define TTSP_REF_FLG(flgid, pk_rflg)							cal_svc(SVC_FN_REF_FLG, (flgid), (intptr_t)(pk_rflg), 0, 0, 0)
#define TTSP_SND_DTQ(dtqid, data)								cal_svc(SVC_FN_SND_DTQ, (dtqid), (data), 0, 0, 0)
#define TTSP_PSND_DTQ(dtqid, data)								cal_svc(SVC_FN_PSND_DTQ, (dtqid), (data), 0, 0, 0)
#define TTSP_TSND_DTQ(dtqid, data, tmout)						cal_svc(SVC_FN_TSND_DTQ, (dtqid), (data), (tmout), 0, 0)
#define TTSP_FSND_DTQ(dtqid, data)								cal_svc(SVC_FN_FSND_DTQ, (dtqid), (data), 0, 0, 0)
#define TTSP_RCV_DTQ(dtqid, p_data)								cal_svc(SVC_FN_RCV_DTQ, (dtqid), (intptr_t)(p_data), 0, 0, 0)
#define TTSP_PRCV_DTQ(dtqid, p_data)							cal_svc(SVC_FN_PRCV_DTQ, (dtqid), (intptr_t)(p_data), 0, 0, 0)
#define TTSP_TRCV_DTQ(dtqid, p_data, tmout)						cal_svc(SVC_FN_TRCV_DTQ, (dtqid), (intptr_t)(p_data), (tmout), 0, 0)
#define TTSP_INI_DTQ(dtqid)										cal_svc(SVC_FN_INI_DTQ, (dtqid), 0, 0, 0, 0)
#define TTSP_REF_DTQ(dtqid, pk_rdtq)							cal_svc(SVC_FN_REF_DTQ, (dtqid), (intptr_t)(pk_rdtq), 0, 0, 0)
#define TTSP_SND_PDQ(pdqid, data, datapri)						cal_svc(SVC_FN_SND_PDQ, (pdqid), (data), (datapri), 0, 0)
#define TTSP_PSND_PDQ(pdqid, data, datapri)						cal_svc(SVC_FN_PSND_PDQ, (pdqid), (data), (datapri), 0, 0)
#define TTSP_TSND_PDQ(pdqid, data, datapri, tmout)				cal_svc(SVC_FN_TSND_PDQ, (pdqid), (data), (datapri), (tmout), 0)
#define TTSP_RCV_PDQ(pdqid, p_data, p_datapri)					cal_svc(SVC_FN_RCV_PDQ, (pdqid), (intptr_t)(p_data), (intptr_t)(p_datapri), 0, 0)
#define TTSP_PRCV_PDQ(pdqid, p_data, p_datapri)					cal_svc(SVC_FN_PRCV_PDQ, (pdqid), (intptr_t)(p_data), (intptr_t)(p_datapri), 0, 0)
#define TTSP_TRCV_PDQ(pdqid, p_data, p_datapri, tmout)			cal_svc(SVC_FN_TRCV_PDQ, (pdqid), (intptr_t)(p_data), (intptr_t)(p_datapri), (tmout), 0)
#define TTSP_INI_PDQ(pdqid)										cal_svc(SVC_FN_INI_PDQ, (pdqid), 0, 0, 0, 0)
#define TTSP_REF_PDQ(pdqid, pk_rpdq)							cal_svc(SVC_FN_REF_PDQ, (pdqid), (intptr_t)(pk_rpdq), 0, 0, 0)
#define TTSP_LOC_MTX(mtxid)										cal_svc(SVC_FN_LOC_MTX, (mtxid), 0, 0, 0, 0)
#define TTSP_PLOC_MTX(mtxid)									cal_svc(SVC_FN_PLOC_MTX, (mtxid), 0, 0, 0, 0)
#define TTSP_TLOC_MTX(mtxid, tmout)								cal_svc(SVC_FN_TLOC_MTX, (mtxid), (tmout), 0, 0, 0)
#define TTSP_UNL_MTX(mtxid)										cal_svc(SVC_FN_UNL_MTX, (mtxid), 0, 0, 0, 0)
#define TTSP_INI_MTX(mtxid)										cal_svc(SVC_FN_INI_MTX, (mtxid), 0, 0, 0, 0)
#define TTSP_REF_MTX(mtxid, pk_rmtx)							cal_svc(SVC_FN_REF_MTX, (mtxid), (intptr_t)(pk_rmtx), 0, 0, 0)
#define TTSP_GET_MPF(mpfid, p_blk)								cal_svc(SVC_FN_GET_MPF, (mpfid), (intptr_t)(p_blk), 0, 0, 0)
#define TTSP_PGET_MPF(mpfid, p_blk)								cal_svc(SVC_FN_PGET_MPF, (mpfid), (intptr_t)(p_blk), 0, 0, 0)
#define TTSP_TGET_MPF(mpfid, p_blk, tmout)						cal_svc(SVC_FN_TGET_MPF, (mpfid), (intptr_t)(p_blk), (tmout), 0, 0)
#define TTSP_REL_MPF(mpfid, blk)								cal_svc(SVC_FN_REL_MPF, (mpfid), (intptr_t)(blk), 0, 0, 0)
#define TTSP_INI_MPF(mpfid)										cal_svc(SVC_FN_INI_MPF, (mpfid), 0, 0, 0, 0)
#define TTSP_REF_MPF(mpfid, pk_rmpf)							cal_svc(SVC_FN_REF_MPF, (mpfid), (intptr_t)(pk_rmpf), 0, 0, 0)


extern ER_UINT svc_ttsp_check_point(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_wait_check_point(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_check_finish(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_target_stop_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_target_start_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_target_gain_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_int_raise(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_cpuexc_raise(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_loc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_wait_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_wait_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_data(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_swait_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_rwait_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_pridata(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_swait_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_rwait_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_wait_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_wait_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_mbf_msg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_swait_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_ref_rwait_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_get_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_set_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ttsp_get_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_adj_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_set_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_sta_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_stp_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_sta_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_stp_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_dis_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ena_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ras_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_clr_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_prb_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_loc_cpu(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_unl_cpu(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_dis_dsp(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ena_dsp(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_chg_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rot_rdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_lod(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_nth(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_act_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_can_act(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_chg_pri(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_pri(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_tst(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_wup_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_can_wup(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_sus_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rsm_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rel_wai(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ter_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_dis_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ena_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ras_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_wai_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_pol_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_twai_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_sig_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_wai_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_pol_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_twai_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_set_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_clr_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_snd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_psnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_tsnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_fsnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_prcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_trcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_snd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_psnd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_tsnd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_prcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_trcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_loc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ploc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_tloc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_unl_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_snd_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_tsnd_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rcv_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_trcv_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_get_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_pget_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_tget_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_rel_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ini_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ref_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
extern ER_UINT svc_ext_ker(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);


/*
 *  自己診断関数の型
 */
typedef ER (*BIT_FUNC)(void);

/*
 *  自己診断関数の設定
 */
extern void    set_bit_func(BIT_FUNC bit_func);

/*
 *  テストライブラリ用変数初期化
 */
extern void    ttsp_initialize_test_lib(void);

/*
 *  チェックポイント
 */
extern void    ttsp_check_point(uint_t count);

/*
 *  チェックポイントがcountになるのを待つ
 */
extern void    ttsp_wait_check_point(uint_t count);

/*
 *  完了チェックポイント
 */
extern void    ttsp_check_finish(uint_t count);

/*
 *	チェックポイント通過の状態取得
 */
extern bool_t    ttsp_get_cp_state(void);

/*
 *	チェックポイント通過の状態設定
 */
extern void    ttsp_set_cp_state(bool_t state);

/*
 *  条件チェック
 */
extern void    _check_assert(const char *expr, const char *file, int_t line);
#define check_assert(exp) \
	((void) (!(exp) ? (_check_assert(#exp, __FILE__, __LINE__), 0) : 0))

/*
 *  値チェック
 */
extern void	_check_value(const char *var, const char *expected_var, long_t act_var, const char *file, int_t line);
#define check_value(var, expected_var) \
	((void)((var) != (expected_var) ? (_check_value(#var, #expected_var, (long_t)(var), __FILE__, __LINE__), 0) : 0))

/*
 *  エラーコードチェック
 */
extern void    _check_ercd(ER ercd, const char *file, int_t line);
#define check_ercd(ercd, expected_ercd)	 \
	((void) ((ercd) != (expected_ercd) ? \
			 (_check_ercd(ercd, __FILE__, __LINE__), 0) : 0))


/*
 *  コンテキストに応じたCPUロック
 */
extern bool_t ttsp_loc_cpu(void);

/*
 *  コンテキストに応じたCPUロック解除
 */
extern void ttsp_unl_cpu(bool_t locked);


/*
 *  ref_tsk代替関数
 */
typedef struct t_ttsp_rtsk {
	STAT		tskstat;    /* タスク状態 */
	PRI			tskpri;     /* タスクの現在優先度 */
	PRI			tskbpri;    /* タスクのベース優先度 */
	STAT		tskwait;    /* 待ち要因 */
	ID			wobjid;     /* 待ち対象のオブジェクトのID */
	TMO			lefttmo;    /* タイムアウトするまでの時間 */
	uint_t		actcnt;     /* 起動要求キューイング数 */
	uint_t		wupcnt;     /* 起床要求キューイング数 */
	bool_t		raster;		/* タスク終了要求状態 */
	bool_t		dister;		/* タスク終了禁止状態 */
	ATR			tskatr;     /* タスク属性 */
	intptr_t	exinf;      /* タスクの拡張情報 */
	PRI			itskpri;    /* タスクの起動時優先度 */
	size_t		sstksz;     /* システムスタック領域のサイズ */
	void		*sstk;      /* システムスタック領域の先頭番地 */
	size_t		ustksz;     /* ユーザスタック領域のサイズ */
	void		*ustk;      /* ユーザスタック領域の先頭番地 */
	uint_t		porder;     /* 同一優先度タスク内での優先順位 */
	uint_t		mtxcnt;		/* ロックしているミューテックス数 */
	ACVCT		acvct;      /* アクセス許可ベクタ */
	ID			domain;     /* 保護ドメイン */
} T_TTSP_RTSK;

extern ER ttsp_ref_tsk(ID tskid, T_TTSP_RTSK *pk_rtsk);
extern ER ttsp_ref_loc_mtx(ID tskid, uint_t order, ID *p_mtxid);


/*
 *  ref_sem代替関数
 */
typedef struct t_ttsp_rsem {
	uint_t	semcnt;     /* セマフォの資源数 */
	ATR		sematr;     /* セマフォ属性 */
	uint_t	isemcnt;    /* セマフォの初期資源数 */
	uint_t	maxsem;     /* セマフォの最大資源数 */
	uint_t	waitcnt;    /* 待ちタスクの数 */
	ACVCT	acvct;      /* アクセス許可ベクタ */
} T_TTSP_RSEM;

extern ER ttsp_ref_sem(ID semid, T_TTSP_RSEM *pk_rsem);


/*
 *  セマフォの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_sem(ID semid, uint_t order, ID *p_tskid);



/*
 *  ref_flg代替関数
 */
typedef struct t_ttsp_rflg {
	FLGPTN	flgptn;     /* イベントフラグの現在のビットパターン */
	ATR		flgatr;     /* イベントフラグ属性 */
	FLGPTN	iflgptn;    /* イベントフラグのビットパターンの初期値 */
	uint_t	waitcnt;    /* 待ちタスクの数 */
	ACVCT	acvct;      /* アクセス許可ベクタ */
} T_TTSP_RFLG;

extern ER ttsp_ref_flg(ID flgid, T_TTSP_RFLG *pk_rflg);


/*
 *  イベントフラグの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_flg(ID flgid, uint_t order, ID *p_tskid, FLGPTN *p_waiptn, MODE *p_wfmode);



/*
 *  ref_dtq代替関数
 */
typedef struct t_ttsp_rdtq {
	uint_t	sdtqcnt;    /* データキュー管理領域に格納されているデータの数 */
	ATR		dtqatr;     /* データキュー属性 */
	uint_t	dtqcnt;     /* データキューの容量 */
	uint_t	swaitcnt;   /* 送信待ちタスクの数 */
	uint_t	rwaitcnt;   /* 受信待ちタスクの数 */
	ACVCT	acvct;      /* アクセス許可ベクタ */
} T_TTSP_RDTQ;

extern ER ttsp_ref_dtq(ID dtqid, T_TTSP_RDTQ *pk_rdtq);


/*
 *  データキュー管理領域に格納されているデータ参照関数
 */
extern ER ttsp_ref_data(ID dtqid, uint_t index, intptr_t *p_data);


/*
 *  データキューの送信待ちタスク参照関数
 */
extern ER ttsp_ref_swait_dtq(ID dtqid, uint_t order, ID *p_tskid, intptr_t *p_data);


/*
 *  データキューの受信待ちタスク参照関数
 */
extern ER ttsp_ref_rwait_dtq(ID dtqid, uint_t order, ID *p_tskid);



/*
 *  ref_pdq代替関数
 */
typedef struct t_ttsp_rpdq {
	uint_t	spdqcnt;        /* 優先度データキュー管理領域に格納されているデータの数 */
	ATR		pdqatr;         /* 優先度データキュー属性 */
	uint_t	pdqcnt;         /* 優先度データキューの容量 */
	PRI		maxdpri;        /* データ優先度の最大値 */
	uint_t	swaitcnt;       /* 送信待ちタスクの数 */
	uint_t	rwaitcnt;       /* 受信待ちタスクの数 */
	ACVCT	acvct;          /* アクセス許可ベクタ */
} T_TTSP_RPDQ;

extern ER ttsp_ref_pdq(ID pdqid, T_TTSP_RPDQ *pk_rpdq);


/*
 *  優先度データキュー管理領域に格納されているデータ参照関数
 */
extern ER ttsp_ref_pridata(ID pdqid, uint_t index, intptr_t *p_data, PRI *p_datapri);


/*
 *  優先度データキューの送信待ちタスク参照関数
 */
extern ER ttsp_ref_swait_pdq(ID pdqid, uint_t order, ID *p_tskid, intptr_t *p_data, PRI *p_datapri);


/*
 *  優先度データキューの受信待ちタスク参照関数
 */
extern ER ttsp_ref_rwait_pdq(ID pdqid, uint_t order, ID *p_tskid);



/*
 *  ref_mpf代替関数
 */
typedef struct t_ttsp_rmpf {
	uint_t	fblkcnt;    /* 固定長メモリプール領域の空きメモリ領域に割り付けることができる固定長メモリブロックの数 */
	ATR		mpfatr;     /* 固定長メモリプール属性 */
	uint_t	blkcnt;     /* メモリブロック数 */
	uint_t	blksz;      /* メモリブロックのサイズ */
	uint_t	waitcnt;    /* 待ちタスクの数 */
	void	*mpf;       /* 固定長メモリプール領域の先頭番地 */
	ACVCT	acvct;      /* アクセス許可ベクタ */
} T_TTSP_RMPF;

extern ER ttsp_ref_mpf(ID mpfid, T_TTSP_RMPF *pk_rmpf);


/*
 *  固定長メモリプールの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_mpf(ID mpfid, uint_t order, ID *p_tskid);



/*
 *  ref_cyc代替関数
 */
typedef struct t_ttsp_rcyc {
	STAT		cycstat;    /* 周期ハンドラの動作状態 */
	RELTIM		lefttim;    /* 次に周期ハンドラを起動する時刻までの相対時間 */
	ATR			cycatr;     /* 周期ハンドラ属性 */
	intptr_t	exinf;      /* 周期ハンドラの拡張情報 */
	RELTIM		cyctim;     /* 周期ハンドラの起動周期 */
	RELTIM		cycphs;     /* 周期ハンドラの起動位相 */
	ACVCT		acvct;      /* アクセス許可ベクタ */
} T_TTSP_RCYC;

extern ER ttsp_ref_cyc(ID cycid, T_TTSP_RCYC *pk_rcyc);



/*
 *  ref_alm代替関数
 */
typedef struct t_ttsp_ralm {
	STAT		almstat;    /* アラームハンドラの動作状態 */
	RELTIM		lefttim;    /* アラームハンドラを起動する時刻までの相対時間 */
	ATR			almatr;     /* アラームハンドラ属性 */
	intptr_t	exinf;      /* アラームハンドラの拡張情報 */
	ACVCT		acvct;      /* アクセス許可ベクタ */
} T_TTSP_RALM;

extern ER ttsp_ref_alm(ID almid, T_TTSP_RALM *pk_ralm);



/*
 *  get_ipm代替関数
 */
extern ER ttsp_get_ipm(PRI *p_intpri);

/*
 *  set_tim代替関数
 */
extern ER ttsp_set_tim(SYSTIM systim);

/*
 *  get_tim代替関数
 */
extern ER ttsp_get_tim(SYSTIM *p_systim);



/*
 *  ref_mtx代替関数
 */
typedef struct t_ttsp_rmtx {
	ATR		mtxatr;     /* ミューテックス属性 */
	uint_t	ceilpri;    /* ミューテックスの上限優先度（内部表現）*/
	ID		htskid;     /* ミューテックスをロックしているタスクID */
	uint_t	waitcnt;    /* 待ちタスクの数 */
	ACVCT	acvct;      /* アクセス許可ベクタ */
} T_TTSP_RMTX;

extern ER ttsp_ref_mtx(ID mtxid, T_TTSP_RMTX *pk_rmtx);

/*
 *  ミューテックスの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_mtx(ID mtxid, uint_t order, ID *p_tskid);



/*
 *  ref_mbf代替関数
 */
typedef struct t_ttsp_rmbf {
	uint_t	smbfcnt;        /* 管理領域に格納されているメッセージの数 */
	ATR		mbfatr;         /* メッセージバッファ属性 */
	size_t	fmbfsz;         /* 管理領域中の空き領域のサイズ */
	size_t	mbfsz;          /* 管理領域のサイズ */
	uint_t	maxmsz;         /* 最大メッセージサイズ */
	uint_t	swaitcnt;       /* 送信待ちタスクの数 */
	uint_t	rwaitcnt;       /* 受信待ちタスクの数 */
	ACVCT	acvct;          /* アクセス許可ベクタ */
} T_TTSP_RMBF;

extern ER ttsp_ref_mbf(ID mbfid, T_TTSP_RMBF *pk_rmbf);


/*
 *  メッセージバッファ管理領域に格納されているメッセージ参照関数
 */
extern ER ttsp_ref_mbf_msg(ID mbfid, uint_t index, void *p_msg, size_t *p_msgsz);


/*
 *  メッセージバッファの送信待ちタスク参照関数
 */
extern ER ttsp_ref_swait_mbf(ID mbfid, uint_t order, ID *p_tskid, void *p_msg, size_t *p_msgsz);


/*
 *  メッセージバッファの受信待ちタスク参照関数
 */
extern ER ttsp_ref_rwait_mbf(ID mbfid, uint_t order, ID *p_tskid);



/*
 *  prb_memテスト用変数
 */
extern uint8_t	ttsp_mem_obj_kernel1;
extern uint8_t	ttsp_mem_obj_kernel2;
extern uint8_t	ttsp_mem_obj_user1;
extern uint8_t	ttsp_mem_obj_user2;

/*
 *  cal_svcテスト(E_SYSエラー)用SVC
 */
#define TTSP_FN_SVC_NEST_ERROR	255
extern ER_UINT ttsp_svc_nest_error(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);

/*
 *  cal_svcテスト(E_NOMEMエラー)用SVC
 *  (SVCが呼び出されることは無いため関数はttsp_svc_nest_errorを流用する)
 */
#define TTSP_FN_SVC_STACK_SIZE_ERROR	256

#ifdef MEM_PRO_TEST
/*
 *  メモリ保護テスト用SVC
 */
#define TTSP_FN_SVC_MEM_BSS_AREA_INIT	257
extern ER_UINT ttsp_svc_mem_bss_area_init(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid);
#endif /* MEM_PRO_TEST */

#endif /* TTSP_TEST_LIB_H */
