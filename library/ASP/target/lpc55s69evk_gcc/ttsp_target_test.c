/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 * 
 *  Copyright (C) 2010-2012 by Center for Embedded Computing Systems
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
 *  $Id: ttsp_target_test.c 79 2020-03-28 02:13:17Z ertl-komori $
 */

#include "kernel_impl.h"
#include "ttsp_target_test.h"
#include <sil.h>
#include "target_timer.h"

/*
 * ティック更新の停止
 */
void ttsp_target_stop_tick(void)
{
	/* CTimer0 を停止 */
	sil_wrw_mem(LPC5500_CTIMER_TCR(LPC5500_CTIMER0_BASE), 0);
}

/*
 * ティック更新の再開
 */
void ttsp_target_start_tick(void)
{
	/* CTimer0 を再開 */
	sil_wrw_mem(LPC5500_CTIMER_TCR(LPC5500_CTIMER0_BASE), LPC5500_CTIMER_TCR_CEN);
}

/*
 * ティックの更新
 * グローバルタイマを1カウント進め，タイムイベントがあれば割り込みを発生させる
 */
void ttsp_target_gain_tick(void)
{
	/* グローバルタイマをインクリメント */
	const uint32_t tick = sil_rew_mem(LPC5500_CTIMER_TC(LPC5500_CTIMER0_BASE)) + 1;
	sil_wrw_mem(LPC5500_CTIMER_TC(LPC5500_CTIMER0_BASE), tick);
	if (tick == sil_rew_mem(LPC5500_CTIMER_MR0(LPC5500_CTIMER0_BASE))) {
		/* タイムイベントの時刻に到達した */
		raise_int(INTNO_TIMER);
	}
}

/*
 * 割込みの発生   
 */
void ttsp_int_raise(INTNO intno)
{
	raise_int(intno);
}


/*
 * CPU例外の発生
 */
void ttsp_cpuexc_raise(EXCNO excno)
{
	if (excno == TTSP_EXCNO_A) {
		RAISE_CPU_EXCEPTION;
	}
}

/*
 * 割込み要求のクリア(テスト用：不要)
 */
void ttsp_clear_int_req(INTNO intno)
{

}

/*
 * CPU例外ハンドラの入り口処理
 */
void ttsp_cpuexc_hook(EXCNO excno, void* p_excinf)
{
	/* 戻りアドレスを設定 */
	*(((uint32_t*)p_excinf) + P_EXCINF_OFFSET_PC) += 4;
}
