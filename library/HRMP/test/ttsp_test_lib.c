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
 *  $Id: ttsp_test_lib.c 72 2020-03-19 08:08:03Z fujisft-shigihara $
 *
 *  [改変] 2026-06-08: HRMP3 3.4.0対応．make_non_runnable のシグネチャ変更
 *  （3引数→2引数，hrmp3/kernel/task.c:276）に追従．
 */

/*
 *		テストプログラム用ライブラリ
 */

#include <kernel.h>
#include <sil.h>
#include <t_syslog.h>
#include <t_stdlib.h>
#include "syssvc/syslog.h"
#include "target_timer.h"
#include "ttsp_test_lib.h"
#include <string.h>

/*
 *  チェックポイント通過カウント変数
 */
static volatile uint_t	check_count[TNUM_PRCID];

/*
 *  自己診断関数
 */
static volatile BIT_FUNC	check_bit_func;

/*
 *  チェックポイント通過の状態(true:正常，false:異常)
 */
static volatile bool_t		cp_state;

/*
 *  バリア同期用変数
 */
static volatile uint_t local_phase[TNUM_PRCID];
static volatile uint_t global_phase;
static volatile bool_t reentrant_check[TNUM_PRCID];

/*
 *  マルチプロセッサ用チェックポイント通過カウント変数
 */
static volatile ID	check_count_mp[TNUM_PRCID];

/*
 *  自己診断関数の設定
 */
void
set_bit_func(BIT_FUNC bit_func)
{
	check_bit_func = bit_func;
}

/*
 *  テストライブラリ用変数初期化
 */
void
ttsp_initialize_test_lib(void)
{
	uint_t i;

	for (i = 0; i < TNUM_PRCID; i++) {
		check_count[i] = 0U;
		local_phase[i] = 0U;
		reentrant_check[i] = false;
	}
	global_phase = 0U;
	check_bit_func = NULL;
	cp_state = true;
}

/*
 *	チェックポイント(ASPのAPIテスト流用のみ使用)
 */
void
ttsp_check_point(uint_t count)
{
	bool_t	errorflag = false;
	ER		rercd;
	ID      prcid;

	SIL_PRE_LOC;

	/*
	 *  割込みロック状態に
	 */
	SIL_LOC_INT();

	/*
	 *  PRCID取得
	 */
	sil_get_pid(&prcid);

	/*
	 *  シーケンスチェック
	 */
	if (++check_count[prcid - 1] == count) {
		syslog_2(LOG_NOTICE, "PE %d : Check point %d passed.", prcid, count);
	}
	else {
		syslog_2(LOG_ERROR, "## PE %d : Unexpected check point %d.", prcid, count);
		errorflag = true;
		goto error_exit;
	}

	/*
	 *  カーネルの内部状態の検査
	 */
	if (check_bit_func != NULL) {
		rercd = (*check_bit_func)();
		if (rercd < 0) {
			syslog_2(LOG_ERROR, "## Internal inconsistency detected (%s, %d).",
								itron_strerror(rercd), SERCD(rercd));
			errorflag = true;
			goto error_exit;
		}
	}

  error_exit:
	/*
	 *  割込みロック状態を解除
	 */
	SIL_UNL_INT();

	if (errorflag) {
		cp_state = false;
		if (sns_ker() == false) {
			ext_ker();
		}
	}
}

/*
 *	完了チェックポイント(ASPのAPIテスト流用のみ使用)
 */
void
ttsp_check_finish(uint_t count)
{
	ID	prcid;

	/*
	 *  PRCID取得
	 */
	sil_get_pid(&prcid);

	ttsp_check_point(count);
	syslog_1(LOG_NOTICE, "PE %d : All check points passed.", prcid);

	ext_ker();
}

/*
 *	チェックポイント通過の状態取得
 */
bool_t
ttsp_get_cp_state(void)
{
	return(cp_state);
}

/*
 *	チェックポイント通過の状態設定
 */
void
ttsp_set_cp_state(bool_t state)
{
	cp_state = state;
}

/*
 *  条件チェックのエラー処理
 */
void
_check_assert(const char *expr, const char *file, int_t line)
{
	syslog_3(LOG_ERROR, "## Assertion `%s' failed at %s:%u.",
			 expr, file, line);
	cp_state = false;
	if (sns_ker() == false) {
		(void) cal_svc(SVC_FN_EXT_KER, 0, 0, 0, 0, 0);
		while(1);
	}
}

/*
 *	値チェックのエラー処理
 */
void
_check_value(const char *var, const char *expected_var, long_t act_var, const char *file, int_t line)
{
	syslog_5(LOG_ERROR, "## Unexpected value %d for `%s == %s' failed at %s:%u.",
								act_var, var, expected_var, file, line);
	cp_state = false;
	if (sns_ker() == false) {
		(void) cal_svc(SVC_FN_EXT_KER, 0, 0, 0, 0, 0);
		while(1);
	}
}

/*
 *  エラーコードチェックのエラー処理
 */
void
_check_ercd(ER ercd, const char *file, int_t line)
{
	syslog_3(LOG_ERROR, "## Unexpected error %s detected at %s:%u.",
			 itron_strerror(ercd), file, line);
	cp_state = false;
	if (sns_ker() == false) {
		(void) cal_svc(SVC_FN_EXT_KER, 0, 0, 0, 0, 0);
		while(1);
	}
}

/*
 *  バリア同期
 */
void
ttsp_barrier_sync(uint_t phase, uint_t tnum_prcid)
{
	bool_t		errorflag = false;
	volatile	ulong_t i;
	volatile	uint_t flag;
	ID			prcid;
	ulong_t		timeout = 0;

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
	if (reentrant_check[prcid - 1]) {
		syslog_1(LOG_ERROR, "## PE %d : ttsp_barrier_sync has re-entranted", prcid);
		syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
		errorflag = true;
		goto error_exit;
	}
	reentrant_check[prcid - 1] = true;

	local_phase[prcid - 1] = phase;

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
				if (local_phase[i] == phase) {
					flag++;
				}
			}

			/*
			 * バリア同期完了チェック
			 * (チェックから終了処理まではディスパッチしないよう割込みロック状態とする)
			 */
			SIL_LOC_INT();
			if (flag == tnum_prcid) {
				reentrant_check[prcid - 1] = false;
				global_phase = phase;
				/*
				 * 全PEのバリア同期処理が完了することを待つ
				 * (既に次のphaseの場合は待つ必要はない)
				 */
				for (i = 0; i < TNUM_PRCID; i++) {
					timeout = 0;
					while ((reentrant_check[i] == true) && (local_phase[i] == phase)) {
						timeout++;
						if (timeout > TTSP_LOOP_COUNT) {
							syslog_3(LOG_ERROR, "## PE %d : ttsp_barrier_sync(phase:%d) caused a timeout to wait for PE %d", prcid, phase, i + 1);
							syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
							errorflag = true;
							goto error_exit;
						}
						sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
					}
				}
				syslog_2(LOG_NOTICE, "PE %d : Barrier sync phase : %d synchronized.", prcid, phase);
				SIL_UNL_INT();
				return;
			}
			SIL_UNL_INT();

			/*
			 * タイムアウト処理
			 */
			timeout++;
			if (timeout > TTSP_LOOP_COUNT) {
				syslog_2(LOG_ERROR, "## PE %d : ttsp_barrier_sync(phase:%d) caused a timeout", prcid, phase);
				syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
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
			if (global_phase == phase) {
				reentrant_check[prcid - 1] = false;
				/*
				 * 全PEのバリア同期処理が完了することを待つ
				 * (既に次のphaseの場合は待つ必要はない)
				 */
				for (i = 0; i < TNUM_PRCID; i++) {
					timeout = 0;
					while ((reentrant_check[i] == true) && (local_phase[i] == phase)) {
						timeout++;
						if (timeout > TTSP_LOOP_COUNT) {
							syslog_3(LOG_ERROR, "## PE %d : ttsp_barrier_sync(phase:%d) caused a timeout to wait for PE %d", prcid, phase, i + 1);
							syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
							errorflag = true;
							goto error_exit;
						}
						sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
					}
				}
				syslog_2(LOG_NOTICE, "PE %d : Barrier sync phase : %d synchronized.", prcid, phase);
				SIL_UNL_INT();
				return;
			}
			SIL_UNL_INT();

			/*
			 * タイムアウト処理
			 */
			timeout++;
			if (timeout > TTSP_LOOP_COUNT) {
				syslog_2(LOG_ERROR, "## PE %d : ttsp_barrier_sync(phase:%d) caused a timeout", prcid, phase);
				syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
				errorflag = true;
				goto error_exit;
			}
			sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
		}
	}

  error_exit:
	if (errorflag) {
		cp_state = false;
		ext_ker();
	}

	/*
	 *  正常な処理では通らないパスのため異常終了
	 */
	syslog_2(LOG_ERROR, "## PE %d : ttsp_barrier_sync(phase:%d) occurred an unexpected error.", prcid, phase);
	syslog_2(LOG_ERROR, "## in \"ttsp_barrier_sync(%d, %d)\".", phase, tnum_prcid);
	cp_state = false;
	ext_ker();
}

/*
 *  id番号のチェックポイントを進める． 
 */
void
ttsp_mp_check_point(ID id, uint_t count)
{
	bool_t	errorflag = false;
	ER		rercd;
	ID		prcid;

	SIL_PRE_LOC;

	/*
	 *  割込みロック状態に
	 */
	SIL_LOC_INT();

	/*
	 *  PRCID取得
	 */
	sil_get_pid(&prcid);

	/*
	 * 引数で指定したプロセッサIDから変化していた場合
	 */
	if (prcid != id) {
		syslog_2(LOG_ERROR, "## PE %d : Processor has changed to %d", id, prcid);
		syslog_2(LOG_ERROR, "## in \"ttsp_mp_check_point(%d, %d)\".", id, count);
		errorflag = true;
		goto error_exit;
	}

	/*
	 *  IDチェック
	 */
	if (!((id > 0) && (id <= TNUM_PRCID))) {
		syslog_1(LOG_ERROR, "## PE %d : Unexpected ID was specified", prcid);
		syslog_2(LOG_ERROR, "## in \"ttsp_mp_check_point(%d, %d)\".", id, count);
		errorflag = true;
		goto error_exit;
	}

	/*
	 *  シーケンスチェック
	 */
	if (++check_count_mp[id - 1] == count) {
		syslog_2(LOG_NOTICE, "PE %d : Check point : %d passed.", prcid, count);
	}
	else {
		syslog_2(LOG_ERROR, "## PE %d : Unexpected Check Point : %d", prcid, count);
		syslog_2(LOG_ERROR, "## in \"ttsp_mp_check_point(%d, %d)\".", id, count);
		errorflag = true;
		goto error_exit;
	}

	/*
	 *  カーネルの内部状態の検査
	 */
	if (check_bit_func != NULL) {
		rercd = (*check_bit_func)();
		if (rercd < 0) {
			syslog_3(LOG_ERROR, "## PE %d : Internal inconsistency detected (%s, %d)",
								prcid, itron_strerror(rercd), SERCD(rercd));
			syslog_2(LOG_ERROR, "## in \"ttsp_mp_check_point(%d, %d)\".", id, count);
			errorflag = true;
			goto error_exit;
		}
	}

  error_exit:
	/*
	 *  割込みロック状態を解除
	 */
	SIL_UNL_INT();

	if (errorflag) {
		cp_state = false;
		if (sns_ker() == false) {
			ext_ker();
		}
	}
}


/*
 *  id番号のチェックポイントがcountになるのを待つ． 
 */
void
ttsp_mp_wait_check_point(ID id, uint_t count)
{
	ulong_t	timeout = 0;

	while (check_count_mp[id - 1] < count) {
		/*
		 * タイムアウト処理
		 */
		timeout++;
		if (timeout > TTSP_LOOP_COUNT) {
			syslog_3(LOG_ERROR, "## PE %d : ttsp_mp_wait_check_point(%d, %d) caused a timeout.", id, id, count);
			cp_state = false;
			ext_ker();
		}
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	}
}


/*
 *  id番号のチェックポイントを進めて，カーネルを終了させる．
 */ 
void
ttsp_mp_check_finish(ID id, uint_t count)
{
	ID	prcid;

	/*
	 *  PRCID取得
	 */
	sil_get_pid(&prcid);

	/*
	 * 引数で指定したプロセッサIDから変化していた場合
	 */
	if (prcid != id) {
		syslog_2(LOG_ERROR, "## PE %d : Processor has changed to %d", id, prcid);
		syslog_2(LOG_ERROR, "## in \"ttsp_mp_check_finish(%d, %d)\".", id, count);
	}
	else {
		ttsp_mp_check_point(id, count);
		syslog_1(LOG_NOTICE, "PE %d : All check points passed.", id);
	}

	ext_ker();
}


/*
 *  対象タスクの状態が指定した状態へ変化するのを待つ．
 */ 
void
ttsp_state_sync(char* proc_id, char* target_id, ID target_tskid, char* target_state_id, STAT target_state)
{
	ER ercd;
	ulong_t timeout = 0;
	T_TTSP_RTSK rtsk;

	do {
		ercd = ttsp_ref_tsk(target_tskid, &rtsk);
		check_ercd(ercd, E_OK);
		timeout++;
		if (timeout > TTSP_LOOP_COUNT) {
			syslog_1(LOG_ERROR, "## %s caused a timeout,", proc_id);
			syslog_2(LOG_ERROR, "## because %s didn't change to %s", target_id, target_state_id);
			syslog_0(LOG_ERROR, "## in \"ttsp_state_sync()\".");
			cp_state = false;
			ext_ker();
		}
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	} while (rtsk.tskstat != target_state);
}


/*
 *  実行状態のまま他タスクからter_tskにより終了されるのを待つ．
 */ 
void
ttsp_wait_finish_sync(char* proc_id)
{
	ulong_t timeout = 0;

	while(1) {
		timeout++;
		if (timeout > TTSP_LOOP_COUNT) {
			syslog_1(LOG_ERROR, "## %s caused a timeout.", proc_id);
			syslog_0(LOG_ERROR, "## in \"ttsp_wait_finish_sync()\".");
			cp_state = false;
			ext_ker();
		}
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	};
}


/*
 *  対象変数の値が指定した値へ変化するのを待つ．
 */ 
void
ttsp_value_sync(char* proc_id, char* var_name, intptr_t* target_var, intptr_t target_val)
{
	ulong_t timeout = 0;

	do {
		timeout++;
		if (timeout > TTSP_LOOP_COUNT) {
			syslog_1(LOG_ERROR, "## %s caused a timeout,", proc_id);
			syslog_2(LOG_ERROR, "## because %s didn't change to %d", var_name, target_val);
			syslog_0(LOG_ERROR, "## in \"ttsp_value_sync()\".");
			cp_state = false;
			ext_ker();
		}
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	} while (*target_var != target_val);
}



/*
 *  ref_tsk代替関数
 */
ER
ttsp_ref_tsk(ID tskid, T_TTSP_RTSK *pk_rtsk)
{
	TCB		*p_tcb;
	uint_t	tstat;
	ER		ercd;
	PCB		*p_pcb;
	uint_t	porder;
	uint_t	mtxcnt;
	MTXCB	*p_mtxcb;
	QUEUE	*p_next;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_TSKID(tskid));
	p_tcb = _kernel_p_tcb_table[tskid - 1];
	p_pcb = p_tcb->p_pcb;
	acquire_glock_wo_preempt();

	tstat = p_tcb->tstat;
	if (TSTAT_DORMANT(tstat)) {
		/*
		 *  対象タスクが休止状態の場合
		 */
		pk_rtsk->tskstat = TTS_DMT;
	}
	else {
		/*
		 *  タスク状態の取出し
		 */
		if (TSTAT_SUSPENDED(tstat)) {
			if (TSTAT_WAITING(tstat)) {
				pk_rtsk->tskstat = TTS_WAS;
			}
			else if (p_tcb == p_pcb->p_runtsk) {
				pk_rtsk->tskstat = TTS_RUS;
			}
			
			else {
				pk_rtsk->tskstat = TTS_SUS;
			}
		}
		else if (TSTAT_WAITING(tstat)) {
			pk_rtsk->tskstat = TTS_WAI;
		}
		else if (p_tcb == p_pcb->p_runtsk) {
			pk_rtsk->tskstat = TTS_RUN;
		}
		else {
			pk_rtsk->tskstat = TTS_RDY;
		}

		/*
		 *  現在優先度とベース優先度の取出し
		 */
		pk_rtsk->tskpri = EXT_TSKPRI(p_tcb->priority);
		pk_rtsk->tskbpri = EXT_TSKPRI(p_tcb->bpriority);

		if (TSTAT_WAITING(tstat)) {
			/*
			 *  待ち要因と待ち対象のオブジェクトのIDの取出し
			 */
			switch (tstat & TS_WAITING_MASK) {
			case TS_WAITING_SLP:
				pk_rtsk->tskwait = TTW_SLP;
				break;
			case TS_WAITING_DLY:
				pk_rtsk->tskwait = TTW_DLY;
				break;
			case TS_WAITING_SEM:
				pk_rtsk->tskwait = TTW_SEM;
				pk_rtsk->wobjid = SEMID(((SEMCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_FLG:
				pk_rtsk->tskwait = TTW_FLG;
				pk_rtsk->wobjid = FLGID(((FLGCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_SDTQ:
				pk_rtsk->tskwait = TTW_SDTQ;
				pk_rtsk->wobjid = DTQID(((DTQCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_RDTQ:
				pk_rtsk->tskwait = TTW_RDTQ;
				pk_rtsk->wobjid = DTQID(((DTQCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_SPDQ:
				pk_rtsk->tskwait = TTW_SPDQ;
				pk_rtsk->wobjid = PDQID(((PDQCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_RPDQ:
				pk_rtsk->tskwait = TTW_RPDQ;
				pk_rtsk->wobjid = PDQID(((PDQCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_MPF:
				pk_rtsk->tskwait = TTW_MPF;
				pk_rtsk->wobjid = MPFID(((MPFCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_MTX:
				pk_rtsk->tskwait = TTW_MTX;
				pk_rtsk->wobjid = MTXID(((MTXCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_SMBF:
				pk_rtsk->tskwait = TTW_SMBF;
				pk_rtsk->wobjid = MBFID(((MBFCB*)(p_tcb->p_wobjcb)));
				break;
			case TS_WAITING_RMBF:
				pk_rtsk->tskwait = TTW_RMBF;
				pk_rtsk->wobjid = MBFID(((MBFCB*)(p_tcb->p_wobjcb)));
				break;
			}

			/*
			 *  タイムアウトするまでの時間の取出し
			 */
			if (p_tcb->winfo.tmevtb.callback != NULL) {
				pk_rtsk->lefttmo = (TMO) tmevt_lefttim(&(p_tcb->winfo.tmevtb));
			}
			else {
				pk_rtsk->lefttmo = TMO_FEVR;
			}
		}

		/*
		 *  起床要求キューイング数の取出し
		 */
		pk_rtsk->wupcnt = p_tcb->wupque ? 1U : 0U;
	}

	/*
	 *  起動要求キューイング数の取出し
	 */
	pk_rtsk->actcnt = p_tcb->actque ? 1U : 0U;

	/*
	 *  タスク終了要求状態の取出し
	 */
	pk_rtsk->raster = p_tcb->raster;

	/*
	 *  タスク終了禁止状態の取出し
	 */
	pk_rtsk->dister = !(p_tcb->enater);

	/*
	 *  タスク属性の取出し
	 */
	pk_rtsk->tskatr = p_tcb->p_tinib->tskatr;

	/*
	 *  タスクの拡張情報の取出し
	 */
	pk_rtsk->exinf = p_tcb->p_tinib->exinf;

	/*
	 *  タスクの起動時優先度の取出し
	 */
	pk_rtsk->itskpri = EXT_TSKPRI(p_tcb->p_tinib->ipriority);

	/*
	 *  スタック領域のサイズの取出し
	 */
#ifdef USE_TSKINICTXB
	/*
	 *  USE_TSKINICTXBを定義しているターゲットでは
	 *  標準形式への変換マクロ／変数を用意する
	 */
	pk_rtsk->sstksz = ttsp_target_get_sstksz(p_tcb->p_tinib);
	pk_rtsk->sstksz = ttsp_target_get_ustksz(p_tcb->p_tinib);
#else /* USE_TSKINICTXB */
	pk_rtsk->sstksz = p_tcb->p_tinib->sstksz;
	pk_rtsk->ustksz = p_tcb->p_tinib->ustksz;
#endif /* USE_TSKINICTXB */

	/*
	 *  スタック領域の先頭番地の取出し
	 */
#ifdef USE_TSKINICTXB
	pk_rtsk->sstk = ttsp_target_get_sstk(p_tcb->p_tinib);
	pk_rtsk->ustk = ttsp_target_get_ustk(p_tcb->p_tinib);
#else /* USE_TSKINICTXB */
	pk_rtsk->sstk = p_tcb->p_tinib->sstk;
	pk_rtsk->ustk = p_tcb->p_tinib->ustk;
#endif /* USE_TSKINICTXB */

	/*
	 *  同一優先度タスク内での優先順位算出
	 *  ("MAIN_TASK(=1)"はカウント対象外とする)
	 */
	if ((TTS_RUN == pk_rtsk->tskstat) || (TTS_RDY == pk_rtsk->tskstat)) {
		porder = 0;
		p_next = NULL;
		p_next = p_tcb->p_schedcb->ready_queue[pk_rtsk->tskpri - 1].p_next;
		do {
			if (TSKID((TCB *) p_next) != 1) {
				porder++;
			}
			if (TSKID((TCB *) p_next) == tskid) {
				break;
			}
			p_next = p_next->p_next;
		} while (&(p_tcb->p_schedcb->ready_queue[pk_rtsk->tskpri - 1]) != p_next);

		pk_rtsk->porder = porder;
	}

	/*
	 *  ロックしているミューテックス数
	 */
	if (p_tcb->p_lastmtx != NULL) {
		mtxcnt = 0;
		p_mtxcb = p_tcb->p_lastmtx;
		do {
			mtxcnt++;
			p_mtxcb = p_mtxcb->p_prevmtx;
		} while (p_mtxcb != NULL);

		pk_rtsk->mtxcnt = mtxcnt;
	}

	/*
	 *  割付けプロセッサのIDの取出し
	 */
	pk_rtsk->prcid = p_pcb->prcid;

	/*
	 *  次の起動時の時割付けプロセッサIDの取出し
	 */
	pk_rtsk->actprc = p_tcb->actprc;

	/*
	 *  タスクの初期割付けプロセッサの取出し
	 */
	pk_rtsk->iprcid = p_tcb->p_tinib->iprcid;

	/*
	 *  タスクの割付け可能プロセッサの取出し
	 */
	pk_rtsk->affinity = p_tcb->p_tinib->affinity;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rtsk->acvct = p_tcb->p_tinib->acvct;

	/*
	 *  保護ドメインの取出し
	 */
	if (p_tcb->p_dominib->domptn == TACP_KERNEL) {
		pk_rtsk->domain = TDOM_KERNEL;
	}
	else {
		pk_rtsk->domain = (ID) (((p_tcb->p_dominib) - _kernel_dominib_table) + TMIN_DOMID);
	}

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ロック中のミューテックス参照関数
 */
ER
ttsp_ref_loc_mtx(ID tskid, uint_t order, ID *p_mtxid)
{
	TCB			*p_tcb;
	ER			ercd;
	bool_t		locked;
	T_TTSP_RTSK	ref_rtsk;
	MTXCB		*p_mtxcb;
	uint_t		i;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_TSKID(tskid));
	p_tcb = _kernel_p_tcb_table[tskid - 1];

	/*
	 *  ロックしているミューテックス数をチェック
	 */
	ercd = ttsp_ref_tsk(tskid, &ref_rtsk);
	check_ercd(ercd, E_OK);
	if ((ref_rtsk.mtxcnt == 0) || (ref_rtsk.mtxcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderでロックしているミューテックスIDを取得
	 */
	i = 1;
	p_mtxcb = p_tcb->p_lastmtx;
	while (i < order) {
		p_mtxcb = p_mtxcb->p_prevmtx;
		i++;
	}

	*p_mtxid = MTXID(p_mtxcb);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_sem代替関数
 */
ER
ttsp_ref_sem(ID semid, T_TTSP_RSEM *pk_rsem)
{
	SEMCB	*p_semcb;
	ER		ercd;
	bool_t	locked;
	uint_t	waitcnt;
	QUEUE	*p_next;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_SEMID(semid));
	p_semcb = _kernel_p_semcb_table[semid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  セマフォの資源数，セマフォ属性，
	 *  セマフォの初期資源数，セマフォの最大資源数を取得
	 */
	pk_rsem->semcnt = p_semcb->semcnt;
	pk_rsem->sematr = p_semcb->p_seminib->sematr;
	pk_rsem->isemcnt = p_semcb->p_seminib->isemcnt;
	pk_rsem->maxsem = p_semcb->p_seminib->maxsem;

	/*
	 *  待ちタスクの数算出
	 */
	waitcnt = 0;
	if (wait_tskid(&(p_semcb->wait_queue)) != TSK_NONE) {
		p_next = p_semcb->wait_queue.p_next;
		while (&(p_semcb->wait_queue) != p_next) {
			waitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rsem->waitcnt = waitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rsem->acvct = p_semcb->p_seminib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  セマフォの待ちタスク参照関数
 */
ER
ttsp_ref_wait_sem(ID semid, uint_t order, ID *p_tskid)
{
	SEMCB		*p_semcb;
	ER			ercd;
	bool_t		locked;
	T_TTSP_RSEM	ref_rsem;
	QUEUE		*p_next;
	uint_t		i;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_SEMID(semid));
	p_semcb = _kernel_p_semcb_table[semid - 1];

	/*
	 *  待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_sem(semid, &ref_rsem);
	check_ercd(ercd, E_OK);
	if ((ref_rsem.waitcnt == 0) || (ref_rsem.waitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_semcb->wait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_flg代替関数
 */
ER
ttsp_ref_flg(ID flgid, T_TTSP_RFLG *pk_rflg)
{
	FLGCB	*p_flgcb;
	ER		ercd;
	bool_t	locked;
	uint_t	waitcnt;
	QUEUE	*p_next;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_FLGID(flgid));
	p_flgcb = _kernel_p_flgcb_table[flgid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  イベントフラグの現在のビットパターン，イベントフラグ属性，
	 *  イベントフラグのビットパターンの初期値を取得
	 */
	pk_rflg->flgptn = p_flgcb->flgptn;
	pk_rflg->flgatr = p_flgcb->p_flginib->flgatr;
	pk_rflg->iflgptn = p_flgcb->p_flginib->iflgptn;

	/*
	 *  待ちタスクの数
	 */
	waitcnt = 0;
	if (wait_tskid(&(p_flgcb->wait_queue)) != TSK_NONE) {
		p_next = p_flgcb->wait_queue.p_next;
		while (&(p_flgcb->wait_queue) != p_next) {
			waitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rflg->waitcnt = waitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rflg->acvct = p_flgcb->p_flginib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  イベントフラグの待ちタスク参照関数
 */
ER
ttsp_ref_wait_flg(ID flgid, uint_t order, ID *p_tskid, FLGPTN *p_waiptn, MODE *p_wfmode)
{
	FLGCB		*p_flgcb;
	ER			ercd;
	bool_t		locked;
	T_TTSP_RFLG	ref_rflg;
	QUEUE		*p_next;
	uint_t		i;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_FLGID(flgid));
	p_flgcb = _kernel_p_flgcb_table[flgid - 1];

	/*
	 *  待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_flg(flgid, &ref_rflg);
	check_ercd(ercd, E_OK);
	if ((ref_rflg.waitcnt == 0) || (ref_rflg.waitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで待ちとなっているタスクID，待ちビットパターン，データ情報を取得
	 */
	i = 1;
	p_next = &(p_flgcb->wait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);
	*p_waiptn = ((WINFO_FLG *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->waiptn;
	*p_wfmode = ((WINFO_FLG *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->wfmode;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_dtq代替関数
 */
ER
ttsp_ref_dtq(ID dtqid, T_TTSP_RDTQ *pk_rdtq)
{
	DTQCB	*p_dtqcb;
	ER		ercd;
	uint_t	swaitcnt;
	uint_t	rwaitcnt;
	QUEUE	*p_next;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_DTQID(dtqid));
	p_dtqcb = _kernel_p_dtqcb_table[dtqid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  データキュー管理領域に格納されているデータの数，
	 *  データキュー属性，データキューの容量を取得
	 */
	pk_rdtq->sdtqcnt = p_dtqcb->count;
	pk_rdtq->dtqatr = p_dtqcb->p_dtqinib->dtqatr;
	pk_rdtq->dtqcnt = p_dtqcb->p_dtqinib->dtqcnt;

	/*
	 *  送信待ちタスクの数算出
	 */
	swaitcnt = 0;
	if (wait_tskid(&(p_dtqcb->swait_queue)) != TSK_NONE) {
		p_next = p_dtqcb->swait_queue.p_next;
		while (&(p_dtqcb->swait_queue) != p_next) {
			swaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rdtq->swaitcnt = swaitcnt;

	/*
	 *  受信待ちタスクの数算出
	 */
	rwaitcnt = 0;
	if (wait_tskid(&(p_dtqcb->rwait_queue)) != TSK_NONE) {
		p_next = p_dtqcb->rwait_queue.p_next;
		while (&(p_dtqcb->rwait_queue) != p_next) {
			rwaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rdtq->rwaitcnt = rwaitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rdtq->acvct = p_dtqcb->p_dtqinib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  データキュー管理領域に格納されているデータ参照関数
 */
ER
ttsp_ref_data(ID dtqid, uint_t index, intptr_t *p_data)
{
	DTQCB	*p_dtqcb;
	ER		ercd;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_DTQID(dtqid));
	p_dtqcb = _kernel_p_dtqcb_table[dtqid - 1];

	/*
	 *  データキュー管理領域につながれているデータの数をチェック
	 */
	if ((p_dtqcb->count == 0) || (p_dtqcb->count < index)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  indexに格納されているデータ情報を取得
	 *  (データキュー内の順序が入れ替わっていることを考慮する)
	 */
	*p_data = (p_dtqcb->p_dtqinib->p_dtqmb + ((p_dtqcb->head + index - 1) % p_dtqcb->p_dtqinib->dtqcnt))->data;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  データキューの送信待ちタスク参照関数
 */
ER
ttsp_ref_swait_dtq(ID dtqid, uint_t order, ID *p_tskid, intptr_t *p_data)
{
	DTQCB		*p_dtqcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RDTQ	ref_rdtq;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_DTQID(dtqid));
	p_dtqcb = _kernel_p_dtqcb_table[dtqid - 1];

	/*
	 *  送信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_dtq(dtqid, &ref_rdtq);
	check_ercd(ercd, E_OK);
	if ((ref_rdtq.swaitcnt == 0) || (ref_rdtq.swaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで送信待ちとなっているタスクID，データ情報を取得
	 */
	i = 1;
	p_next = &(p_dtqcb->swait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);
	*p_data = ((WINFO_SDTQ *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->data;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  データキューの受信待ちタスク参照関数
 */
ER
ttsp_ref_rwait_dtq(ID dtqid, uint_t order, ID *p_tskid)
{
	DTQCB		*p_dtqcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RDTQ	ref_rdtq;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_DTQID(dtqid));
	p_dtqcb = _kernel_p_dtqcb_table[dtqid - 1];

	/*
	 *  受信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_dtq(dtqid, &ref_rdtq);
	check_ercd(ercd, E_OK);
	if ((ref_rdtq.rwaitcnt == 0) || (ref_rdtq.rwaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで受信待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_dtqcb->rwait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_pdq代替関数
 */
ER
ttsp_ref_pdq(ID pdqid, T_TTSP_RPDQ *pk_rpdq)
{
	PDQCB	*p_pdqcb;
	ER		ercd;
	uint_t	swaitcnt;
	uint_t	rwaitcnt;
	QUEUE	*p_next;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_PDQID(pdqid));
	p_pdqcb = _kernel_p_pdqcb_table[pdqid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  優先度データキュー管理領域に格納されているデータの数，
	 *  優先度データキュー属性，優先度データキューの容量，
	 *  データ優先度の最大値を取得
	 */
	pk_rpdq->spdqcnt = p_pdqcb->count;
	pk_rpdq->pdqatr = p_pdqcb->p_pdqinib->pdqatr;
	pk_rpdq->pdqcnt = p_pdqcb->p_pdqinib->pdqcnt;
	pk_rpdq->maxdpri = p_pdqcb->p_pdqinib->maxdpri;

	/*
	 *  送信待ちタスクの数算出
	 */
	swaitcnt = 0;
	if (wait_tskid(&(p_pdqcb->swait_queue)) != TSK_NONE) {
		p_next = p_pdqcb->swait_queue.p_next;
		while (&(p_pdqcb->swait_queue) != p_next) {
			swaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rpdq->swaitcnt = swaitcnt;

	/*
	 *  受信待ちタスクの数算出
	 */
	rwaitcnt = 0;
	if (wait_tskid(&(p_pdqcb->rwait_queue)) != TSK_NONE) {
		p_next = p_pdqcb->rwait_queue.p_next;
		while (&(p_pdqcb->rwait_queue) != p_next) {
			rwaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rpdq->rwaitcnt = rwaitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rpdq->acvct = p_pdqcb->p_pdqinib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  優先度データキュー管理領域に格納されているデータ参照関数
 */
ER
ttsp_ref_pridata(ID pdqid, uint_t index, intptr_t *p_data, PRI *p_datapri)
{
	PDQCB	*p_pdqcb;
	PDQMB	*p_pdqmb;
	ER		ercd;
	uint_t	i;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_PDQID(pdqid));
	p_pdqcb = _kernel_p_pdqcb_table[pdqid - 1];

	/*
	 *  格納されているデータの数をチェック
	 */
	if ((p_pdqcb->count == 0) || (p_pdqcb->count < index)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  indexに格納されているデータ情報を取得
	 */
	i = 1;
	p_pdqmb = p_pdqcb->p_head;
	while (i < index) {
		p_pdqmb = p_pdqmb->p_next;
		i++;
	}
	*p_data = p_pdqmb->data;
	*p_datapri = p_pdqmb->datapri;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  優先度データキューの送信待ちタスク参照関数
 */
ER
ttsp_ref_swait_pdq(ID pdqid, uint_t order, ID *p_tskid, intptr_t *p_data, PRI *p_datapri)
{
	PDQCB		*p_pdqcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RPDQ	ref_rpdq;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_PDQID(pdqid));
	p_pdqcb = _kernel_p_pdqcb_table[pdqid - 1];

	/*
	 *  送信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_pdq(pdqid, &ref_rpdq);
	check_ercd(ercd, E_OK);
	if ((ref_rpdq.swaitcnt == 0) || (ref_rpdq.swaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで送信待ちとなっているタスクID，データ情報を取得
	 */
	i = 1;
	p_next = &(p_pdqcb->swait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);
	*p_data = ((WINFO_SPDQ *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->data;
	*p_datapri = ((WINFO_SPDQ *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->datapri;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  優先度データキューの受信待ちタスク参照関数
 */
ER
ttsp_ref_rwait_pdq(ID pdqid, uint_t order, ID *p_tskid)
{
	PDQCB		*p_pdqcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RPDQ	ref_rpdq;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_PDQID(pdqid));
	p_pdqcb = _kernel_p_pdqcb_table[pdqid - 1];

	/*
	 *  受信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_pdq(pdqid, &ref_rpdq);
	check_ercd(ercd, E_OK);
	if ((ref_rpdq.rwaitcnt == 0) || (ref_rpdq.rwaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで受信待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_pdqcb->rwait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_spn代替関数
 */
#ifndef TMAX_NATIVE_SPN
#define IS_NATIVE(spnatr)	true
#else /* TMAX_NATIVE_SPN */
#if TMAX_NATIVE_SPN == 0
#define IS_NATIVE(spnatr)	false
#else /* TMAX_NATIVE_SPN == 0 */
#define IS_NATIVE(spnatr)	(((spnatr) & TA_NATIVE) != 0U)
#endif /* TMAX_NATIVE_SPN == 0 */
#endif /* TMAX_NATIVE_SPN */
ER
ttsp_ref_spn(ID spnid, T_TTSP_RSPN *pk_rspn)
{
	ER		ercd;
	bool_t	locked;
	bool_t	spnlocked;
	const SPNINIB	*p_spninib;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_SPNID(spnid));
	p_spninib = &(spninib_table[((uint_t)((spnid) - TMIN_SPNID))]);

	acquire_glock_wo_preempt();

	/*
	 *  スピンロックのロック状態と属性を取得
	 */
	if (IS_NATIVE(p_spninib->spnatr)) {
		spnlocked = refer_native_spn(p_spninib);
	}
	else {
		spnlocked = *((volatile bool_t *)((p_spninib)->lock));
	}
	pk_rspn->spnstat = spnlocked ? TSPN_LOC : TSPN_UNL;
	pk_rspn->spnatr = p_spninib->spnatr;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rspn->acvct = p_spninib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_mpf代替関数
 */
ER
ttsp_ref_mpf(ID mpfid, T_TTSP_RMPF *pk_rmpf)
{
	MPFCB	*p_mpfcb;
	ER		ercd;
	bool_t	locked;
	uint_t	waitcnt;
	QUEUE	*p_next;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MPFID(mpfid));
	p_mpfcb = _kernel_p_mpfcb_table[mpfid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  固定長メモリプール領域の空きメモリ領域に割り付けることができる
	 *  固定長メモリブロックの数，固定長メモリプール属性，メモリブロック数，
	 *  メモリブロックのサイズを取得
	 */
	pk_rmpf->fblkcnt = p_mpfcb->fblkcnt;
	pk_rmpf->mpfatr = p_mpfcb->p_mpfinib->mpfatr;
	pk_rmpf->blkcnt = p_mpfcb->p_mpfinib->blkcnt;
	pk_rmpf->blksz = p_mpfcb->p_mpfinib->blksz;
	pk_rmpf->mpf = p_mpfcb->p_mpfinib->mpf;

	/*
	 *  待ちタスクの数
	 */
	waitcnt = 0;
	if (wait_tskid(&(p_mpfcb->wait_queue)) != TSK_NONE) {
		p_next = p_mpfcb->wait_queue.p_next;
		while (&(p_mpfcb->wait_queue) != p_next) {
			waitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rmpf->waitcnt = waitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rmpf->acvct = p_mpfcb->p_mpfinib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  固定長メモリプールの待ちタスク参照関数
 */
ER
ttsp_ref_wait_mpf(ID mpfid, uint_t order, ID *p_tskid)
{
	MPFCB		*p_mpfcb;
	ER			ercd;
	bool_t		locked;
	T_TTSP_RMPF	ref_rmpf;
	QUEUE		*p_next;
	uint_t		i;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MPFID(mpfid));
	p_mpfcb = _kernel_p_mpfcb_table[mpfid - 1];

	/*
	 *  待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_mpf(mpfid, &ref_rmpf);
	check_ercd(ercd, E_OK);
	if ((ref_rmpf.waitcnt == 0) || (ref_rmpf.waitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_mpfcb->wait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}

	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_cyc代替関数
 */
ER
ttsp_ref_cyc(ID cycid, T_TTSP_RCYC *pk_rcyc)
{
	CYCCB	*p_cyccb;
	ER		ercd;
	PCB		*p_pcb;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_CYCID(cycid));
	p_cyccb = _kernel_p_cyccb_table[cycid - 1];
	p_pcb = get_my_pcb();
	acquire_glock_wo_preempt();

	/*
	 *  次に周期ハンドラを起動する時刻までの相対時間
	 */
	if (p_cyccb->cycsta) {
		pk_rcyc->cycstat = TCYC_STA;
		pk_rcyc->lefttim = tmevt_lefttim(&(p_cyccb->tmevtb));
	}
	else {
		pk_rcyc->cycstat = TCYC_STP;
	}

	/*
	 *  周期ハンドラ属性，周期ハンドラの拡張情報，
	 *  周期ハンドラの起動周期，周期ハンドラの起動位相を取得
	 */
	pk_rcyc->cycatr = p_cyccb->p_cycinib->cycatr;
	pk_rcyc->exinf = p_cyccb->p_cycinib->exinf;
	pk_rcyc->cyctim = p_cyccb->p_cycinib->cyctim;
	pk_rcyc->cycphs = p_cyccb->p_cycinib->cycphs;
	pk_rcyc->prcid = p_cyccb->p_pcb->prcid;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rcyc->acvct = p_cyccb->p_cycinib->acvct;

	/*
	 *  保護ドメインの取出し
	 */
	if (p_cyccb->p_cycinib->p_dominib->domptn == TACP_KERNEL) {
		pk_rcyc->domain = TDOM_KERNEL;
	}
	else {
		pk_rcyc->domain = (ID) (((p_cyccb->p_cycinib->p_dominib) - _kernel_dominib_table) + TMIN_DOMID);
	}

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_alm代替関数
 */
ER
ttsp_ref_alm(ID almid, T_TTSP_RALM *pk_ralm)
{
	ALMCB	*p_almcb;
	ER		ercd;
	PCB		*p_pcb;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_ALMID(almid));
	p_almcb = _kernel_p_almcb_table[almid - 1];
	p_pcb = get_my_pcb();
	acquire_glock_wo_preempt();

	/*
	 *  アラームハンドラを起動する時刻までの相対時間
	 */
	if (p_almcb->almsta) {
		pk_ralm->almstat = TALM_STA;
		pk_ralm->lefttim = tmevt_lefttim(&(p_almcb->tmevtb));
	}
	else {
		pk_ralm->almstat = TALM_STP;
	}

	/*
	 *  アラームハンドラ属性，アラームハンドラの拡張情報を取得
	 */
	pk_ralm->almatr = p_almcb->p_alminib->almatr;
	pk_ralm->exinf = p_almcb->p_alminib->exinf;
	pk_ralm->prcid = p_almcb->p_pcb->prcid;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_ralm->acvct = p_almcb->p_alminib->acvct;

	/*
	 *  保護ドメインの取出し
	 */
	if (p_almcb->p_alminib->p_dominib->domptn == TACP_KERNEL) {
		pk_ralm->domain = TDOM_KERNEL;
	}
	else {
		pk_ralm->domain = (ID) (((p_almcb->p_alminib->p_dominib) - _kernel_dominib_table) + TMIN_DOMID);
	}

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_mbf代替関数
 */
ER
ttsp_ref_mbf(ID mbfid, T_TTSP_RMBF *pk_rmbf)
{
	MBFCB	*p_mbfcb;
	ER		ercd;
	uint_t	swaitcnt;
	uint_t	rwaitcnt;
	QUEUE	*p_next;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MBFID(mbfid));
	p_mbfcb = _kernel_p_mbfcb_table[mbfid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  管理領域に格納されているメッセージの数，
	 *  メッセージバッファ属性，空き領域のサイズ，
	 *  メッセージバッファ管理領域のサイズ，最大メッセージサイズを取得
	 */
	pk_rmbf->smbfcnt = p_mbfcb->smbfcnt;
	pk_rmbf->mbfatr = p_mbfcb->p_mbfinib->mbfatr;
	pk_rmbf->fmbfsz = p_mbfcb->fmbfsz;
	pk_rmbf->mbfsz = p_mbfcb->p_mbfinib->mbfsz;
	pk_rmbf->maxmsz = p_mbfcb->p_mbfinib->maxmsz;

	/*
	 *  送信待ちタスクの数算出
	 */
	swaitcnt = 0;
	if (wait_tskid(&(p_mbfcb->swait_queue)) != TSK_NONE) {
		p_next = p_mbfcb->swait_queue.p_next;
		while (&(p_mbfcb->swait_queue) != p_next) {
			swaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rmbf->swaitcnt = swaitcnt;

	/*
	 *  受信待ちタスクの数算出
	 */
	rwaitcnt = 0;
	if (wait_tskid(&(p_mbfcb->rwait_queue)) != TSK_NONE) {
		p_next = p_mbfcb->rwait_queue.p_next;
		while (&(p_mbfcb->rwait_queue) != p_next) {
			rwaitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rmbf->rwaitcnt = rwaitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rmbf->acvct = p_mbfcb->p_mbfinib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}

/*
 *  メッセージバッファ管理領域に格納されているメッセージ参照関数
 */
ER
ttsp_ref_mbf_msg(ID mbfid, uint_t index, void *p_msg, size_t *p_msgsz)
{
	MBFCB	*p_mbfcb;
	ER		ercd;
	uint_t	i;
	char	*mbuffer;
	uint_t	msgsz, msgpos, copysz;
	size_t	remsz;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MBFID(mbfid));
	p_mbfcb = _kernel_p_mbfcb_table[mbfid - 1];

	/*
	 *  メッセージバッファ管理領域に格納されているメッセージの数をチェック
	 */
	if ((p_mbfcb->smbfcnt == 0) || (p_mbfcb->smbfcnt < index)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/* 取得する対象のバッファ位置特定とメッセージサイズ取得 */
	i = 0;
	msgpos = p_mbfcb->head;
	mbuffer = (char *)(p_mbfcb->p_mbfinib->mbfmb);
	while (1) {
		msgsz = *((uint_t *) &(mbuffer[msgpos]));
		msgpos = msgpos + sizeof(uint_t);
		if (msgpos >= p_mbfcb->p_mbfinib->mbfsz) {
			msgpos = 0U;
		}

		i++;
		if (i >= index) {
			break;
		}

		remsz = p_mbfcb->p_mbfinib->mbfsz - msgpos;
		copysz = msgsz;
		if (remsz < copysz) {
			copysz -= remsz;
			msgpos = 0U;
		}
		msgpos += TOPPERS_ROUND_SZ(copysz, sizeof(uint_t));
		if (msgpos >= p_mbfcb->p_mbfinib->mbfsz) {
			msgpos = 0U;
		}
	}

	/* 取得したメッセージとサイズを格納 */
	*p_msgsz = msgsz;
	remsz = p_mbfcb->p_mbfinib->mbfsz - msgpos;
	copysz = msgsz;
	if (remsz < copysz) {
		memcpy(p_msg, &(mbuffer[msgpos]), remsz);
		p_msg = ((char *) p_msg) + remsz;
		copysz -= remsz;
		msgpos = 0U;
	}
	memcpy(p_msg, &(mbuffer[msgpos]), copysz);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}

/*
 *  メッセージバッファの送信待ちタスク参照関数
 */
ER
ttsp_ref_swait_mbf(ID mbfid, uint_t order, ID *p_tskid, void *p_msg, size_t *p_msgsz)
{
	MBFCB		*p_mbfcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RMBF	ref_rmbf;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MBFID(mbfid));
	p_mbfcb = _kernel_p_mbfcb_table[mbfid - 1];

	/*
	 *  送信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_mbf(mbfid, &ref_rmbf);
	check_ercd(ercd, E_OK);
	if ((ref_rmbf.swaitcnt == 0) || (ref_rmbf.swaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで送信待ちとなっているタスクID，メッセージ情報を取得
	 */
	i = 1;
	p_next = &(p_mbfcb->swait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);
	*p_msgsz = ((WINFO_SMBF *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->msgsz;
	memcpy(p_msg, ((WINFO_SMBF *)(&(((TCB *)(p_next->p_next))->winfo_obj)))->msg, *p_msgsz);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}

/*
 *  メッセージバッファの受信待ちタスク参照関数
 */
ER
ttsp_ref_rwait_mbf(ID mbfid, uint_t order, ID *p_tskid)
{
	MBFCB		*p_mbfcb;
	QUEUE		*p_next;
	ER			ercd;
	uint_t		i;
	bool_t		locked;
	T_TTSP_RMBF	ref_rmbf;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MBFID(mbfid));
	p_mbfcb = _kernel_p_mbfcb_table[mbfid - 1];

	/*
	 *  受信待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_mbf(mbfid, &ref_rmbf);
	check_ercd(ercd, E_OK);
	if ((ref_rmbf.rwaitcnt == 0) || (ref_rmbf.rwaitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで受信待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_mbfcb->rwait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  get_ipm代替関数
 */
ER
ttsp_get_ipm(PRI *p_intpri)
{
	bool_t	locked;

	locked = ttsp_loc_cpu();

	/*
	 *  割込み優先度マスクを取得
	 */
	*p_intpri = t_get_ipm();

	ttsp_unl_cpu(locked);

	return(E_OK);
}


/*
 *  set_tim代替関数
 */
ER
ttsp_set_tim(SYSTIM systim)
{
	bool_t	locked;

	locked = ttsp_loc_cpu();

	/*
	 *  システム時刻を設定
	 */
	update_current_evttim();
	systim_offset = systim - monotonic_evttim;

	ttsp_unl_cpu(locked);

	return(E_OK);
}


/*
 *  get_tim代替関数
 */
ER
ttsp_get_tim(SYSTIM *p_systim)
{
	bool_t	locked;

	locked = ttsp_loc_cpu();

	/*
	 *  システム時刻を取得
	 */
	update_current_evttim();
	*p_systim = systim_offset + monotonic_evttim;

	ttsp_unl_cpu(locked);

	return(E_OK);
}


/*
 *  sus_tsk代替関数
 */
ER
ttsp_sus_tsk(ID tskid)
{
	TCB		*p_tcb;
	ER		ercd;
	PCB		*p_my_pcb;
	bool_t	locked;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_TSKID(tskid));
	p_tcb = _kernel_p_tcb_table[tskid - 1];
	p_my_pcb = get_my_pcb();
	acquire_glock_wo_preempt();

	if (TSTAT_DORMANT(p_tcb->tstat)) {
		ercd = E_OBJ;
	}
	else if (p_tcb->raster) {
		ercd = E_RASTER;
	}
	else if (TSTAT_RUNNABLE(p_tcb->tstat)) {
		/*
		 *  実行できる状態から強制待ち状態への遷移
		 */
		p_tcb->tstat = TS_SUSPENDED;
		make_non_runnable(p_my_pcb, p_tcb);
		/* 他プロセッサからの呼出しを想定してプロセッサ間割込みを入れておく */
		request_dispatch_prc(p_tcb->p_pcb->prcid);

		ercd = E_OK;
	}
	else if (TSTAT_SUSPENDED(p_tcb->tstat)) {
		ercd = E_QOVR;
	}
	else {
		/*
		 *  待ち状態から二重待ち状態への遷移
		 */
		p_tcb->tstat |= TS_SUSPENDED;
		ercd = E_OK;
	}

	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}


/*
 *  ref_mtx代替関数
 */
ER
ttsp_ref_mtx(ID mtxid, T_TTSP_RMTX *pk_rmtx)
{
	MTXCB	*p_mtxcb;
	ER		ercd;
	bool_t	locked;
	uint_t	waitcnt;
	QUEUE	*p_next;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MTXID(mtxid));
	p_mtxcb = _kernel_p_mtxcb_table[mtxid - 1];

	acquire_glock_wo_preempt();

	/*
	 *  ミューテックス属性，上限優先度を取得
	 */
	pk_rmtx->mtxatr = p_mtxcb->p_mtxinib->mtxatr;
	pk_rmtx->ceilpri = EXT_TSKPRI(p_mtxcb->p_mtxinib->ceilpri);

	/*
	 *  ロックしているタスクID
	 */
	pk_rmtx->htskid = (p_mtxcb->p_loctsk != NULL) ? TSKID(p_mtxcb->p_loctsk)
													: TSK_NONE;

	/*
	 *  待ちタスクの数算出
	 */
	waitcnt = 0;
	if (wait_tskid(&(p_mtxcb->wait_queue)) != TSK_NONE) {
		p_next = p_mtxcb->wait_queue.p_next;
		while (&(p_mtxcb->wait_queue) != p_next) {
			waitcnt++;
			p_next = p_next->p_next;
		}
	}
	pk_rmtx->waitcnt = waitcnt;

	/*
	 *  アクセス許可ベクタの取出し
	 */
	pk_rmtx->acvct = p_mtxcb->p_mtxinib->acvct;

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}

/*
 *  ミューテックスの待ちタスク参照関数
 */
ER
ttsp_ref_wait_mtx(ID mtxid, uint_t order, ID *p_tskid)
{
	MTXCB		*p_mtxcb;
	ER			ercd;
	bool_t		locked;
	T_TTSP_RMTX	ref_rmtx;
	QUEUE		*p_next;
	uint_t		i;

	locked = ttsp_loc_cpu();

	CHECK_ID(VALID_MTXID(mtxid));
	p_mtxcb = _kernel_p_mtxcb_table[mtxid - 1];

	/*
	 *  待ちタスクの数をチェック
	 */
	ercd = ttsp_ref_mtx(mtxid, &ref_rmtx);
	check_ercd(ercd, E_OK);
	if ((ref_rmtx.waitcnt == 0) || (ref_rmtx.waitcnt < order)) {
		ercd = E_PAR;
		goto error_exit;
	}

	acquire_glock_wo_preempt();

	/*
	 *  orderで待ちとなっているタスクIDを取得
	 */
	i = 1;
	p_next = &(p_mtxcb->wait_queue);
	while (i < order) {
		p_next = p_next->p_next;
		i++;
	}
	*p_tskid = wait_tskid(p_next);

	ercd = E_OK;
	release_glock();

  error_exit:
	ttsp_unl_cpu(locked);
	return(ercd);
}

/*
 *  コンテキストに応じたCPUロック
 */
bool_t
ttsp_loc_cpu(void)
{
	bool_t	locked = true;

	if (!sense_lock()) {
		lock_cpu();
		locked = false;
	}

	return(locked);
}

/*
 *  コンテキストに応じたCPUロック解除
 */
void
ttsp_unl_cpu(bool_t locked)
{
	if (!locked) {
		unlock_cpu();
	}
}


/*
 *  ユーザドメインからTTSP3ライブラリを呼び出すためのSVC
 */
ER_UINT
svc_ttsp_check_point(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_check_point((uint_t) par1);
	return(E_OK);
}

ER_UINT
svc_ttsp_check_finish(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_check_finish((uint_t) par1);
	return(E_OK);
}

ER_UINT
svc_ttsp_barrier_sync(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_barrier_sync((uint_t) par1, (uint_t) par2);
	return(E_OK);
}

ER_UINT
svc_ttsp_mp_check_point(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_mp_check_point((ID) par1, (uint_t) par2);
	return(E_OK);
}

ER_UINT
svc_ttsp_mp_wait_check_point(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_mp_wait_check_point((ID) par1, (uint_t) par2);
	return(E_OK);
}

ER_UINT
svc_ttsp_mp_check_finish(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_mp_check_finish((ID) par1, (uint_t) par2);
	return(E_OK);
}

ER_UINT
svc_ttsp_state_sync(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_state_sync((char*) par1, (char*) par2, (ID) par3, (char*) par4, (STAT) par5);
	return(E_OK);
}

ER_UINT
svc_ttsp_wait_finish_sync(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_wait_finish_sync((char*) par1);
	return(E_OK);
}

ER_UINT
svc_ttsp_value_sync(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_value_sync((char*) par1, (char*) par2, (intptr_t*) par3, par4);
	return(E_OK);
}

ER_UINT
svc_ttsp_target_stop_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_target_stop_tick();
	return(E_OK);
}

ER_UINT
svc_ttsp_target_start_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_target_start_tick();
	return(E_OK);
}

ER_UINT
svc_ttsp_target_gain_tick(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_target_gain_tick();
	return(E_OK);
}

ER_UINT
svc_ttsp_int_raise(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_int_raise((INTNO) par1);
	return(E_OK);
}

ER_UINT
svc_ttsp_cpuexc_raise(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ttsp_cpuexc_raise((EXCNO) par1);
	return(E_OK);
}

ER_UINT
svc_ttsp_ref_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_tsk((ID) par1, (T_TTSP_RTSK *) par2));
}

ER_UINT
svc_ttsp_ref_loc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_loc_mtx((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_sem((ID) par1, (T_TTSP_RSEM *) par2));
}

ER_UINT
svc_ttsp_ref_wait_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_wait_sem((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_flg((ID) par1, (T_TTSP_RFLG *) par2));
}

ER_UINT
svc_ttsp_ref_wait_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_wait_flg((ID) par1, (uint_t) par2, (ID *) par3, (FLGPTN *) par4, (MODE *) par5));
}

ER_UINT
svc_ttsp_ref_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_dtq((ID) par1, (T_TTSP_RDTQ *) par2));
}

ER_UINT
svc_ttsp_ref_data(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_data((ID) par1, (uint_t) par2, (intptr_t *) par3));
}

ER_UINT
svc_ttsp_ref_swait_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_swait_dtq((ID) par1, (uint_t) par2, (ID *) par3, (intptr_t *) par4));
}

ER_UINT
svc_ttsp_ref_rwait_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_rwait_dtq((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_pdq((ID) par1, (T_TTSP_RPDQ *) par2));
}

ER_UINT
svc_ttsp_ref_pridata(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_pridata((ID) par1, (uint_t) par2, (intptr_t *) par3, (PRI *) par4));
}

ER_UINT
svc_ttsp_ref_swait_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_swait_pdq((ID) par1, (uint_t) par2, (ID *) par3, (intptr_t *) par4, (PRI *) par5));
}

ER_UINT
svc_ttsp_ref_rwait_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_rwait_pdq((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_spn(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_spn((ID) par1, (T_TTSP_RSPN *) par2));
}

ER_UINT
svc_ttsp_ref_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_mpf((ID) par1, (T_TTSP_RMPF *) par2));
}

ER_UINT
svc_ttsp_ref_wait_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_wait_mpf((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_cyc((ID) par1, (T_TTSP_RCYC *) par2));
}

ER_UINT
svc_ttsp_ref_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_alm((ID) par1, (T_TTSP_RALM *) par2));
}

ER_UINT
svc_ttsp_ref_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_mtx((ID) par1, (T_TTSP_RMTX *) par2));
}

ER_UINT
svc_ttsp_ref_wait_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_wait_mtx((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_ref_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_mbf((ID) par1, (T_TTSP_RMBF *) par2));
}

ER_UINT
svc_ttsp_ref_mbf_msg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_mbf_msg((ID) par1, (uint_t) par2, (void *) par3, (size_t *) par4));
}

ER_UINT
svc_ttsp_ref_swait_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_swait_mbf((ID) par1, (uint_t) par2, (ID *) par3, (void *) par4, (size_t *) par5));
}

ER_UINT
svc_ttsp_ref_rwait_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_ref_rwait_mbf((ID) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_ttsp_get_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_get_ipm((PRI *) par1));
}

ER_UINT
svc_ttsp_set_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_set_tim((SYSTIM) par1));
}

ER_UINT
svc_ttsp_get_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_get_tim((SYSTIM*) par1));
}

ER_UINT
svc_ttsp_sus_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ttsp_sus_tsk((ID) par1));
}

ER_UINT
svc_adj_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) adj_tim((int32_t) par1));
}

ER_UINT
svc_set_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) set_tim((SYSTIM) par1));
}

ER_UINT
svc_get_tim(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_tim((SYSTIM *) par1));
}

ER_UINT
svc_sta_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) sta_alm((ID) par1, (RELTIM) par2));
}

ER_UINT
svc_stp_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) stp_alm((ID) par1));
}

ER_UINT
svc_ref_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_alm((ID) par1, (T_RALM *) par2));
}

ER_UINT
svc_sta_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) sta_cyc((ID) par1));
}

ER_UINT
svc_stp_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) stp_cyc((ID) par1));
}

ER_UINT
svc_ref_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_cyc((ID) par1, (T_RCYC *) par2));
}

ER_UINT
svc_dis_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) dis_int((INTNO) par1));
}

ER_UINT
svc_ena_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ena_int((INTNO) par1));
}

ER_UINT
svc_ras_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ras_int((INTNO) par1));
}

ER_UINT
svc_clr_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) clr_int((INTNO) par1));
}

ER_UINT
svc_prb_int(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) prb_int((INTNO) par1));
}

ER_UINT
svc_loc_cpu(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) loc_cpu());
}

ER_UINT
svc_unl_cpu(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) unl_cpu());
}

ER_UINT
svc_dis_dsp(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) dis_dsp());
}

ER_UINT
svc_ena_dsp(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ena_dsp());
}

ER_UINT
svc_chg_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) chg_ipm((PRI) par1));
}

ER_UINT
svc_get_ipm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_ipm((PRI *) par1));
}

ER_UINT
svc_rot_rdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rot_rdq((PRI) par1));
}

ER_UINT
svc_get_lod(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_lod((PRI) par1, (uint_t *) par2));
}

ER_UINT
svc_get_nth(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_nth((PRI) par1, (uint_t) par2, (ID *) par3));
}

ER_UINT
svc_act_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) act_tsk((ID) par1));
}

ER_UINT
svc_can_act(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return(can_act((ID) par1));
}

ER_UINT
svc_chg_pri(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) chg_pri((ID) par1, (PRI) par2));
}

ER_UINT
svc_get_pri(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_pri((ID) par1, (PRI *) par2));
}

ER_UINT
svc_get_tst(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_tst((ID) par1, (STAT *) par2));
}

ER_UINT
svc_ref_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_tsk((ID) par1, (T_RTSK *) par2));
}

ER_UINT
svc_wup_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) wup_tsk((ID) par1));
}

ER_UINT
svc_can_wup(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return(can_wup((ID) par1));
}

ER_UINT
svc_sus_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) sus_tsk((ID) par1));
}

ER_UINT
svc_rsm_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rsm_tsk((ID) par1));
}

ER_UINT
svc_rel_wai(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rel_wai((ID) par1));
}

ER_UINT
svc_ter_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ter_tsk((ID) par1));
}

ER_UINT
svc_dis_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) dis_ter());
}

ER_UINT
svc_ena_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ena_ter());
}

ER_UINT
svc_ras_ter(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ras_ter((ID) par1));
}

ER_UINT
svc_wai_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) wai_sem((ID) par1));
}

ER_UINT
svc_pol_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) pol_sem((ID) par1));
}

ER_UINT
svc_twai_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) twai_sem((ID) par1, (TMO) par2));
}

ER_UINT
svc_sig_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) sig_sem((ID) par1));
}

ER_UINT
svc_ini_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_sem((ID) par1));
}

ER_UINT
svc_ref_sem(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_sem((ID) par1, (T_RSEM *) par2));
}

ER_UINT
svc_wai_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) wai_flg((ID) par1, (FLGPTN) par2, (MODE) par3, (FLGPTN *) par4));
}

ER_UINT
svc_pol_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) pol_flg((ID) par1, (FLGPTN) par2, (MODE) par3, (FLGPTN *) par4));
}

ER_UINT
svc_twai_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) twai_flg((ID) par1, (FLGPTN) par2, (MODE) par3, (FLGPTN *) par4, (TMO) par5));
}

ER_UINT
svc_set_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) set_flg((ID) par1, (FLGPTN) par2));
}

ER_UINT
svc_clr_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) clr_flg((ID) par1, (FLGPTN) par2));
}

ER_UINT
svc_ini_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_flg((ID) par1));
}

ER_UINT
svc_ref_flg(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_flg((ID) par1, (T_RFLG *) par2));
}

ER_UINT
svc_snd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) snd_dtq((ID) par1, par2));
}

ER_UINT
svc_psnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) psnd_dtq((ID) par1, par2));
}

ER_UINT
svc_tsnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) tsnd_dtq((ID) par1, par2, (TMO) par3));
}

ER_UINT
svc_fsnd_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) fsnd_dtq((ID) par1, par2));
}

ER_UINT
svc_rcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rcv_dtq((ID) par1, (intptr_t *) par2));
}

ER_UINT
svc_prcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) prcv_dtq((ID) par1, (intptr_t *) par2));
}

ER_UINT
svc_trcv_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) trcv_dtq((ID) par1, (intptr_t *) par2, (TMO) par3));
}

ER_UINT
svc_ini_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_dtq((ID) par1));
}

ER_UINT
svc_ref_dtq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_dtq((ID) par1, (T_RDTQ *) par2));
}

ER_UINT
svc_snd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) snd_pdq((ID) par1, par2, (PRI) par3));
}

ER_UINT
svc_psnd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) psnd_pdq((ID) par1, par2, (PRI) par3));
}

ER_UINT
svc_tsnd_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) tsnd_pdq((ID) par1, par2, (PRI) par3, (TMO) par4));
}

ER_UINT
svc_rcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rcv_pdq((ID) par1, (intptr_t *) par2, (PRI *) par3));
}

ER_UINT
svc_prcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) prcv_pdq((ID) par1, (intptr_t *) par2, (PRI *) par3));
}

ER_UINT
svc_trcv_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) trcv_pdq((ID) par1, (intptr_t *) par2, (PRI *) par3, (TMO) par4));
}

ER_UINT
svc_ini_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_pdq((ID) par1));
}

ER_UINT
svc_ref_pdq(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_pdq((ID) par1, (T_RPDQ *) par2));
}

ER_UINT
svc_loc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) loc_mtx((ID) par1));
}

ER_UINT
svc_ploc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ploc_mtx((ID) par1));
}

ER_UINT
svc_tloc_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) tloc_mtx((ID) par1, (TMO) par2));
}

ER_UINT
svc_unl_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) unl_mtx((ID) par1));
}

ER_UINT
svc_ini_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_mtx((ID) par1));
}

ER_UINT
svc_ref_mtx(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_mtx((ID) par1, (T_RMTX *) par2));
}

ER_UINT
svc_snd_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) snd_mbf((ID) par1, (const void *) par2, (uint_t) par3));
}

ER_UINT
svc_tsnd_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) tsnd_mbf((ID) par1, (const void *) par2, (uint_t) par3, (TMO) par4));
}

ER_UINT
svc_rcv_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return(rcv_mbf((ID) par1, (void *) par2));
}

ER_UINT
svc_trcv_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return(trcv_mbf((ID) par1, (void *) par2, (TMO) par3));
}

ER_UINT
svc_ini_mbf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_mbf((ID) par1));
}

ER_UINT
svc_get_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) get_mpf((ID) par1, (void **) par2));
}

ER_UINT
svc_pget_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) pget_mpf((ID) par1, (void **) par2));
}

ER_UINT
svc_tget_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) tget_mpf((ID) par1, (void **) par2, (TMO) par3));
}

ER_UINT
svc_rel_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) rel_mpf((ID) par1, (void *) par2));
}

ER_UINT
svc_ini_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ini_mpf((ID) par1));
}

ER_UINT
svc_ref_mpf(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_mpf((ID) par1, (T_RMPF *) par2));
}

ER_UINT
svc_ext_ker(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	ext_ker();
	return(E_OK);
}

ER_UINT
svc_msta_alm(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) msta_alm((ID) par1, (RELTIM) par2, (ID) par3));
}

ER_UINT
svc_msta_cyc(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) msta_cyc((ID) par1, (ID) par2));
}

ER_UINT
svc_mget_lod(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) mget_lod((ID) par1, (PRI) par2, (uint_t *) par3));
}

ER_UINT
svc_mget_nth(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) mget_nth((ID) par1, (PRI) par2, (uint_t) par3, (ID *) par4));
}

ER_UINT
svc_mact_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) mact_tsk((ID) par1, (ID) par2));
}

ER_UINT
svc_mig_tsk(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) mig_tsk((ID) par1, (ID) par2));
}

ER_UINT
svc_loc_spn(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) loc_spn((ID) par1));
}

ER_UINT
svc_try_spn(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) try_spn((ID) par1));
}

ER_UINT
svc_unl_spn(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) unl_spn((ID) par1));
}

ER_UINT
svc_ref_spn(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	return((ER_UINT) ref_spn((ID) par1, (T_RSPN *) par2));
}


/*
 *  cal_svc E_SYSエラーテスト用SVC
 */
ER_UINT
ttsp_svc_nest_error(intptr_t par1, intptr_t par2, intptr_t par3, intptr_t par4, intptr_t par5, ID cdmid)
{
	static uint16_t cnt = 0U;
	ER_UINT			eruint = E_OK;
	cnt++;

	if (cnt < 256) {
		/* 255回目までの呼出しはE_OKが返る */
		eruint = cal_svc(TTSP_FN_SVC_NEST_ERROR, par1, par2, par3, par4, par5);
		if (cnt != 255) {
			check_ercd(eruint, E_OK);
		}
		else {
			check_ercd(eruint, E_SYS);
		}
	}
	else {
		/* SVCのネスト呼出し終了 */
	}

	return(eruint);
}
