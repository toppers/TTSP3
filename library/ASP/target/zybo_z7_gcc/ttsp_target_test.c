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

#define USE_MPCORE_GTC_HRT

#include "kernel/kernel_impl.h"
#include <sil.h>
#include "ttsp_target_test.h"
#include "mpcore_timer.h"

/*
 *  ティック更新の停止
 */ 
void
ttsp_target_stop_tick(void)
{
	sil_wrw_mem(MPCORE_GTC_CTRL, sil_rew_mem(MPCORE_GTC_CTRL) & ~MPCORE_GTC_CTRL_ENABLE);
}

/*
 *  ティック更新の再開
 */ 
void
ttsp_target_start_tick(void)
{
	sil_wrw_mem(MPCORE_GTC_CTRL, sil_rew_mem(MPCORE_GTC_CTRL) | MPCORE_GTC_CTRL_ENABLE);
}

uint64_t temp_gtc = 0U;

Inline HRTCNT
hrt_get_temp_gtc(void)
{
	return ((HRTCNT)(temp_gtc / MPCORE_GTC_FREQ));
}

/*
 *  ティックの更新
 */
void
ttsp_target_gain_tick(void)
{
	bool_t enable_comp;
	uint32_t base_time, cur_time;
	uint32_t count_u, count_l;
	uint64_t comp_u, comp_l;
	uint64_t comp_val;

	/* 現在のGTC値，コンペア値，高分解能タイマ値を取得 */
	temp_gtc = mpcore_gtc_get_count();
	base_time = hrt_get_temp_gtc();
	comp_u = sil_rew_mem(MPCORE_GTC_CVR_U);
	comp_l = sil_rew_mem(MPCORE_GTC_CVR_L);
	comp_val = (uint64_t)((comp_u << 32) | comp_l);

	/* コンペアが有効かを取得 */
	enable_comp = ((sil_rew_mem(MPCORE_GTC_CTRL) & MPCORE_GTC_CTRL_ENACOMP) != 0U);

	while (1) {
		/* 高分解能タイマ値が2us進むまで，コピーしたGTC値をインクリメントする */
		temp_gtc++;
		cur_time = hrt_get_temp_gtc();
		if ((base_time + 2U) == cur_time) {
			/* 2us進む直前のGTC値を採用する(1usの最大範囲まで進める) */
			temp_gtc--;
			break;
		}

		/* 進めたGTCの値をレジスタに書き込む */
		count_u = temp_gtc >> 32;
		count_l = temp_gtc;
		sil_wrw_mem(MPCORE_GTC_COUNT_U, count_u);
		sil_wrw_mem(MPCORE_GTC_COUNT_L, count_l);

		/* インクリメントする途中でコンペア値と一致した場合，割込みを入れる */
		if (enable_comp && (comp_val == temp_gtc)) {
			raise_int(MPCORE_IRQNO_GTC);
		}
	}

	/* 算出したGTCの値をレジスタに書き込む */
	count_u = temp_gtc >> 32;
	count_l = temp_gtc;
	sil_wrw_mem(MPCORE_GTC_COUNT_U, count_u);
	sil_wrw_mem(MPCORE_GTC_COUNT_L, count_l);
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
ttsp_cpuexc_hook(EXCNO excno, void* p_excinf)
{

}

/*
 *  割込み要求のクリア
 */
void
ttsp_clear_int_req(INTNO intno)
{

}
