/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
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
 *  $Id: ttsp_target_test.c 62 2019-12-20 01:20:29Z fujisft-shigihara $
 */

/*
 *  【改変】タイマドライバシミュレータ（simt）版．ティック制御は MPCore GTC では
 *  なく simt のシミュレーション時刻（simtim_advance）で行う．
 */
#include "kernel/kernel_impl.h"
#include <sil.h>
#include "ttsp_target_test.h"
#include "sim_timer.h"

TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack");

/* カーネルドメインタスク用スタック */
#ifdef TTSP_STACK_SHARE_HRP
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section");
#endif /* TTSP_STACK_SHARE_HRP */

/*
 *  ティック更新の停止
 *
 *  simt ではシミュレーション時刻は simtim_advance／アイドル処理でのみ進むため，
 *  ハードウェアタイマのような「停止」は不要（何もしない）．
 */
void
ttsp_target_stop_tick(void)
{
}

/*
 *  ティック更新の再開
 */
void
ttsp_target_start_tick(void)
{
}

/*
 *  ティックの更新
 *
 *  シミュレーション時刻を TTSP_SIMT_GAIN_STEP だけ進める（既定 1）．時間区画
 *  スケジューリングのテストでは，呼出し側で必要なステップ数だけ繰り返し呼ぶ．
 */
#ifndef TTSP_SIMT_GAIN_STEP
#define TTSP_SIMT_GAIN_STEP		1U
#endif /* TTSP_SIMT_GAIN_STEP */

void
ttsp_target_gain_tick(void)
{
	simtim_advance(TTSP_SIMT_GAIN_STEP);
}

/*
 *  割込みの発生
 */
void
ttsp_int_raise(INTNO intno)
{
	raise_int(intno);
}

/*
 *  CPU例外の発生
 */
void
ttsp_cpuexc_raise(EXCNO excno)
{
	if (excno == TTSP_EXCNO_A) {
		RAISE_CPU_EXCEPTION;
	}
}

/*
 *  CPU例外発生時のフック処理
 */
void
ttsp_cpuexc_hook(EXCNO excno, void *p_excinf)
{

}

/*
 *  割込み要求のクリア
 */
void
ttsp_clear_int_req(INTNO intno)
{

}
