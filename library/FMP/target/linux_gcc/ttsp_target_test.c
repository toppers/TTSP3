/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  上記著作権者は，TTSP3のライセンス（利用条件(1)〜(4)）に従い，
 *  本ソフトウェアの利用を無償で許諾する．詳細は他ソースファイルの
 *  ヘッダまたは配布物のドキュメントを参照のこと．
 *  本ソフトウェアは，無保証で提供されているものである．
 *
 *  2026-06-07: FMP3 POSIXターゲット（linux_gcc）用に新規作成．
 */

#include "kernel/kernel_impl.h"
#include <sil.h>
#include "ttsp_target_test.h"

/* DEF_ICSテスト用 */
STK_T nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];
STK_T nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];

/*
 *  ティック更新の停止
 *
 *  本ターゲットの時刻はCLOCK_MONOTONIC（実時間）駆動のため停止できない．
 *  FUNC_TIME="false" で運用し，本関数は呼び出されない（空実装）．
 */
void
ttsp_target_stop_tick(void)
{
}

/*
 *  ティック更新の再開（未サポート: 空実装）
 */
void
ttsp_target_start_tick(void)
{
}

/*
 *  ティックの更新（未サポート: 空実装）
 */
void
ttsp_target_gain_tick(void)
{
}

/*
 *  割込みの発生
 *  （本ターゲットの raise_int はCPUロック状態での呼出しを要求するため，
 *    非ロック状態から呼ばれた場合はロックを取得して呼び出す）
 */
void
ttsp_int_raise(INTNO intno)
{
	bool_t	locked;

	locked = sense_lock();
	if (!locked) {
		lock_cpu();
	}
	raise_int(intno);
	if (!locked) {
		unlock_cpu();
	}
}

/*
 *  CPU例外の発生
 *  （自スレッド＝発行元プロセッサへのシグナル送出で実現する）
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
ttsp_cpuexc_hook(EXCNO excno, void* p_excinf)
{
}

/*
 *  割込み要求のクリア（raise_int と同様にCPUロックを確保して呼び出す）
 */
void
ttsp_clear_int_req(INTNO intno)
{
	bool_t	locked;

	locked = sense_lock();
	if (!locked) {
		lock_cpu();
	}
	clear_int(intno);
	if (!locked) {
		unlock_cpu();
	}
}
