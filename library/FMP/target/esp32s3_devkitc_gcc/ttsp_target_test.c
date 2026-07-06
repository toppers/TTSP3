/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  [新規] 2026-07-07: ESP32-S3-DevKitC-1向けターゲット依存部（7関数）。
 *  詳細はttsp_target_test.hのヘッダコメント参照。
 *
 *  tick制御の設計（stop/start/gain_tick）：
 *  XtensaのCCOUNTはフリーランカウンタでハードウェア的に停止する手段が
 *  無い（zybo版のGTC_CTRL.ENABLEのような全体停止ビットが無い）。
 *
 *  [改変] 2026-07-07: 当初 enable_int/disable_int(XT_TIMER_INTNUM)による
 *  割込みマスクのみで実装したが、これだけでは不十分だった。FMP3の
 *  time_event.c（update_current_evttim）は**HRT絶対値
 *  （target_hrt_get_current、CCOUNTベース）を直接参照して時刻を進める**
 *  設計のため、tick割込みをマスクしていても、get_tim等のAPI呼び出しの
 *  たびにCCOUNTの実際の経過が反映されてしまい、stop_tick中でも時間が
 *  進んでしまうことが実機QEMUで判明した（system1==system2のアサート失敗）。
 *  そこで、esp32_s3ポート本体のtarget_timer.hにHRT凍結機構
 *  （_kernel_hrt_frozen/_kernel_hrt_frozen_val）を追加し、target_hrt_
 *  get_current()が凍結中は固定値を返すようにした（既定は無効、TTSP3が
 *  明示的に有効化した時のみ動作が変わる）。
 *   - stop_tick ：disable_int(XT_TIMER_INTNUM)でtick割込みをマスクし、
 *                 現在のHRT値を記録して凍結する（以後get_tim等は
 *                 この固定値を見る）
 *   - start_tick：凍結解除→CCOMPARE0=CCOUNT+1→enable_int（即座に一致・
 *                 発火、通常運転へ）
 *   - gain_tick ：凍結解除→CCOMPARE0=CCOUNT+1→enable_intで1回発火させ、
 *                 signal_time()が次回のCCOMPARE0を新たに設定する
 *                 （＝値が変化する）のを待って1 tick処理完了を検知し、
 *                 再びdisable_int＋新しいHRT値で凍結し直す
 */

#include "kernel/kernel_impl.h"
#include "kernel/time_event.h"
#include "kernel/pcb.h"
#include <sil.h>
#include "target_timer.h"
#include "ttsp_target_test.h"

/* DEF_ICSテスト用 */
STK_T nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];
STK_T nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];

/*
 *  ティック更新の停止
 *
 *  CCOMPARE0を遠い未来に設定する。RMWではなく単純な書込みのため
 *  ジャイアントロックは不要（zybo版のGTC_CTRL共有RMWとは事情が異なり、
 *  CCOMPARE0は自コアのプライベートレジスタ）。
 */
void
ttsp_target_stop_tick(void)
{
	disable_int(XT_TIMER_INTNUM);
	_kernel_hrt_frozen_val = target_hrt_get_current();
	_kernel_hrt_frozen = true;
}

/*
 *  ティック更新の再開
 *
 *  凍結解除の瞬間に「凍結中に実際に経過したCPUサイクル」が一気に
 *  current_evttimへ反映されるのを防ぐため、凍結を解除する前にCCOUNT
 *  レジスタ自体を凍結時点の値（サイクル換算）へ巻き戻す。その後
 *  CCOMPARE0をCCOUNT+1にして一致させてから割込みを許可する（以降は
 *  signal_time()が通常どおり次回のCCOMPARE0を設定し続ける）。
 */
void
ttsp_target_start_tick(void)
{
	uint32_t	frozen_ccount;

	frozen_ccount = _kernel_hrt_frozen_val * TCYC_PER_HRT;
	Asm("wsr.ccount  %0 ; esync" :: "a"(frozen_ccount) : "memory");
	_kernel_hrt_frozen = false;
	xtensa_set_ccompare0(frozen_ccount + 1U);
	enable_int(XT_TIMER_INTNUM);
}

/*
 *  ティックの更新（1 tick分だけ進める）
 *
 *  停止中（割込みマスク＋HRT凍結中）の状態から、CCOUNTを凍結時点の値へ
 *  巻き戻してから凍結を解除し（start_tickと同じ理由）、CCOMPARE0=CCOUNT+1
 *  に一致させ、割込みを許可してtick割込みを1回だけ発生させる。
 *  signal_time()が新しいCCOMPARE0を設定する（＝値が変化する）まで待つ
 *  ことで1回のtick処理完了を検知し、その後再びマスク＋新しいHRT値で
 *  凍結し直す。本関数はタスクコンテキスト・CPUロック解除状態で呼ばれる
 *  前提（out.cのmain_taskがCPUロックせずに呼ぶ）。
 */
void
ttsp_target_gain_tick(void)
{
	uint32_t	frozen_ccount;
	uint32_t	compare_set;
	uint32_t	compare_now;
	ulong_t		timeout;
	HRTCNT		before;

	before = _kernel_hrt_frozen_val;
	frozen_ccount = before * TCYC_PER_HRT;
	Asm("wsr.ccount  %0 ; esync" :: "a"(frozen_ccount) : "memory");
	_kernel_hrt_frozen = false;
	xtensa_set_ccompare0(frozen_ccount + 1U);
	Asm("rsr.ccompare0  %0" : "=a"(compare_set));

	enable_int(XT_TIMER_INTNUM);
	timeout = 0U;
	do {
		Asm("rsr.ccompare0  %0" : "=a"(compare_now));
		timeout++;
	} while ((compare_now == compare_set) && (timeout < TTSP_LOOP_COUNT));
	disable_int(XT_TIMER_INTNUM);

	/*
	 *  再凍結する値は、実際に経過したCPUサイクル（enable_intから
	 *  disable_intまでの処理オーバーヘッド分を含む）ではなく、
	 *  「厳密にbefore+1」に固定する。out.cのテストは
	 *  「gain_tick呼び出し1回でシステム時刻がちょうど1進む」ことを
	 *  期待しており（(system1+1)==system2のアサート）、割込みハンドラ
	 *  実行等のオーバーヘッドをシステム時刻に含めるべきではないため。
	 */
	_kernel_hrt_frozen_val = before + 1U;
	_kernel_hrt_frozen = true;
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
 *
 *  TTSP_EXCNO_A（ill＝EXCCAUSE=0）のみ対応。フェイタル系（復帰不可）は
 *  本版では未対応（FUNC_EXCEPTION=falseのためTTGは生成しない想定）。
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
	clear_int(intno);
}
