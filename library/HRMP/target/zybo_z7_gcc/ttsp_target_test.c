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
#include "kernel/time_event.h"
#include "kernel/pcb.h"
#include <sil.h>
#include "ttsp_target_test.h"
#include "mpcore_timer.h"

TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC1");

/* カーネルドメインタスク用スタック */
#ifdef TTSP_STACK_SHARE_HRP
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack_prc1[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC1");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack_prc2[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC2");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack_prc1[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section_CLS_ALL_PRC1");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack_prc2[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section_CLS_ALL_PRC2");
#endif /* TTSP_STACK_SHARE_HRP */

/* DEF_ICSテスト用 */
TTSP_DEFINE_VAR_SECTION(STK_T, nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC1");
TTSP_DEFINE_VAR_SECTION(STK_T, nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC2");

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

/* 各プロセッサの割込み処理完了タイミングに使用するバリア同期 */
static volatile uint_t ipi_barrier_cur_phase = 1U;
static volatile uint_t ipi_local_phase[TNUM_PRCID] = {0U};
static volatile uint_t ipi_global_phase = 0U;
static volatile bool_t ipi_reentrant_check[TNUM_PRCID] = {false};
void
ttsp_ipi_barrier_sync(void)
{
	bool_t		errorflag = false;
	volatile	ulong_t i;
	volatile	uint_t flag;
	ID			prcid;
	ulong_t		timeout = 0U;
	volatile	uint_t phase = ipi_barrier_cur_phase;

	SIL_PRE_LOC;

	/*
	 *  割込みロック状態に
	 */
	SIL_LOC_INT();

	/*
	 *  PRCID取得
	 *  どのような状態でも取得できるように sil_get_pid() を使用する
	 */
	sil_get_pid(&prcid);

	/*
	 * リエントラントされた場合はエラー終了する
	 */
	if (ipi_reentrant_check[prcid - 1]) {
		syslog_1(LOG_ERROR, "## PE %d : ttsp_ipi_barrier_sync has re-entranted", prcid);
		syslog_1(LOG_ERROR, "## in \"ttsp_ipi_barrier_sync(%d)\".", phase);
		errorflag = true;
		goto error_exit;
	}
	ipi_reentrant_check[prcid - 1] = true;

	ipi_local_phase[prcid - 1] = phase;

	/*
	 *  割込みロック状態を解除
	 */
	SIL_UNL_INT();

	/*
	 *  バリア同期処理
	 */
	if (prcid == TOPPERS_MASTER_PRCID) {
		while (1) {
			flag = 0;
			for (i = 0; i < TNUM_PRCID; i++) {
				if (ipi_local_phase[i] == phase) {
					flag++;
				}
			}

			/*
			 * バリア同期完了チェック
			 * (チェックから終了処理まではディスパッチしないよう割込みロック状態とする)
			 */
			SIL_LOC_INT();
			if (flag == TNUM_PRCID) {
				/* 全プロセッサの同期を完了する前にフェーズを進める */
				ipi_barrier_cur_phase++;

				ipi_reentrant_check[prcid - 1] = false;
				ipi_global_phase = phase;
				/*
				 * 全PEのバリア同期処理が完了することを待つ
				 * (既に次のphaseの場合は待つ必要はない)
				 */
				for (i = 0; i < TNUM_PRCID; i++) {
					timeout = 0;
					while ((ipi_reentrant_check[i] == true) && (ipi_local_phase[i] == phase)) {
						timeout++;
						if (timeout > TTSP_LOOP_COUNT) {
							syslog_3(LOG_ERROR, "## PE %d : ttsp_ipi_barrier_sync(phase:%d) caused a timeout to wait for PE %d", prcid, phase, i + 1);
							errorflag = true;
							goto error_exit;
						}
						sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
					}
				}
				//syslog_2(LOG_NOTICE, "## PE %d : ttsp_ipi_barrier_sync: %d synched.", prcid, phase);
				SIL_UNL_INT();
				return;
			}
			SIL_UNL_INT();

			/*
			 * タイムアウト処理
			 */
			timeout++;
			if (timeout > TTSP_LOOP_COUNT) {
				syslog_2(LOG_ERROR, "## PE %d : ttsp_ipi_barrier_sync(phase:%d) caused a timeout", prcid, phase);
				errorflag = true;
				goto error_exit;
			}
			sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
		}
	}
	else {
		while (1) {
			/*
			 * バリア同期完了チェック
			 * チェックから終了処理まではディスパッチしないよう割込みロック状態とする
			 */
			SIL_LOC_INT();
			if (ipi_global_phase == phase) {
				ipi_reentrant_check[prcid - 1] = false;
				/*
				 * 全PEのバリア同期処理が完了することを待つ
				 * (既に次のphaseの場合は待つ必要はない)
				 */
				for (i = 0; i < TNUM_PRCID; i++) {
					timeout = 0;
					while ((ipi_reentrant_check[i] == true) && (ipi_local_phase[i] == phase)) {
						timeout++;
						if (timeout > TTSP_LOOP_COUNT) {
							syslog_3(LOG_ERROR, "## PE %d : ttsp_ipi_barrier_sync(phase:%d) caused a timeout to wait for PE %d", prcid, phase, i + 1);
							errorflag = true;
							goto error_exit;
						}
						sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
					}
				}
				//syslog_2(LOG_NOTICE, "## PE %d : ttsp_ipi_barrier_sync: %d synched.", prcid, phase);
				SIL_UNL_INT();
				return;
			}
			SIL_UNL_INT();

			/*
			 * タイムアウト処理
			 */
			timeout++;
			if (timeout > TTSP_LOOP_COUNT) {
				syslog_2(LOG_ERROR, "## PE %d : ttsp_ipi_barrier_sync(phase:%d) caused a timeout", prcid, phase);
				errorflag = true;
				goto error_exit;
			}
			sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
		}
	}

  error_exit:
	ext_ker();
}

static INTNO ttsp_intno[TNUM_PRCID] = {INTNO_TIMER_PRC1, INTNO_TIMER_PRC2};
void
ttsp_target_gain_tick_ipi(void)
{
	bool_t enable_comp;
	uint64_t comp_val;
	uint64_t comp_u, comp_l;
	const ID prcid = get_my_pcb()->prcid;

	/* 現在のコンペア値を取得 */
	comp_u = sil_rew_mem(MPCORE_GTC_CVR_U);
	comp_l = sil_rew_mem(MPCORE_GTC_CVR_L);
	comp_val = (uint64_t)((comp_u << 32) | comp_l);

	/* コンペアが有効かを取得 */
	enable_comp = ((sil_rew_mem(MPCORE_GTC_CTRL) & MPCORE_GTC_CTRL_ENACOMP) != 0U);

	/* インクリメントする途中でコンペア値と一致した場合，割込みを入れる */
	if (enable_comp && (comp_val == temp_gtc)) {
		/* 割込みを入れないプロセッサが存在した場合に備え同期は割込み発生前にする */
		ttsp_ipi_barrier_sync();
		raise_int(ttsp_intno[prcid - 1U]);
	}
	else {
		ttsp_ipi_barrier_sync();
	}
}

/*
 *  ティックの更新
 */
void
ttsp_target_gain_tick(void)
{
	uint32_t base_time, cur_time;
	uint32_t count_u, count_l;
	volatile ID prcid;
	volatile uint32_t i;
	const ID my_prcid = get_my_pcb()->prcid;

	/* 本関数到達までに他プロセッサへ出した要求が完了していない場合に備えたビジーウェイト */
	for (i = 0U; i < 1000U; i++) {
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	}

	/* 現在のGTC値，高分解能タイマ値を取得 */
	temp_gtc = mpcore_gtc_get_count();
	base_time = hrt_get_temp_gtc();

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

		/* コンペアが一致しているかすべてのプロセッサで確認するためプロセッサ間割込みを入れる */
		for (prcid = TMIN_PRCID; prcid <= TMAX_PRCID; prcid++) {
			if (my_prcid != prcid) {
				gicd_raise_sgi(TTSP_IPI_INTNO, prcid);
			}
		}

		/*
		 * 他プロセッサで割込みが入る前に時間を進めないよう，
		 * 本関数を実行するプロセッサは，同じコンテキストで実行する
		 */
		ttsp_target_gain_tick_ipi();
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
	if ((excno == TTSP_EXCNO_A) || (excno == TTSP_EXCNO_PE2_A)) {
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
