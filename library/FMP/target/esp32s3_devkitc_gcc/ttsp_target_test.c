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
 *  [改変] 2026-07-07 (1回目): 割込みマスクのみでは不十分と判明。FMP3の
 *  time_event.c（update_current_evttim）はHRT絶対値（target_hrt_get_
 *  current、CCOUNTベース）を直接参照して時刻を進めるため、tick割込みを
 *  マスクしていてもget_tim等のAPI呼び出しでCCOUNTの実経過が反映され、
 *  stop_tick中でも時間が進んでしまう。esp32_s3ポート本体target_timer.hに
 *  HRT凍結機構（_kernel_hrt_frozen/_kernel_hrt_frozen_val）を追加し、
 *  target_hrt_get_current()が凍結中は固定値を返すようにした。
 *
 *  [改変] 2026-07-07 (2回目・重要): 1回目の実装は、gain_tick/start_tickで
 *  「CCOUNTレジスタ自体を凍結値へ巻き戻す」処理を行っていたが、これが
 *  TTSP3 APIテスト60/60失敗の根本原因だった。TTGが生成する全APIテストは
 *  main_task冒頭でstop_tick()を呼び凍結状態のまま実行される設計で、その中で
 *  msta_alm(ALM, 0, ...)等が呼ばれると、target_hrt_set_event/raise_event
 *  （target_timer.h、CCOMPARE0書き込み）は**実際のCCOUNT**を基準に計算し
 *  「実CCOUNT+1」へ設定する（これはxtensa_get_ccount()を直接参照し、凍結
 *  フェイクの影響を受けないため）。ここでgain_tickがCCOUNTを凍結値（stop_
 *  tick時点の古い値）へ巻き戻すと、CCOUNTがCCOMPARE0より小さくなり、
 *  msta_almが設定した「即時発火」の予定を台無しにし、二度と一致しなくなる
 *  （Xtensaの一致割込みは厳密一致のみで、一度通り過ぎると次は約2^32
 *  カウント後）。これによりアラームハンドラが永遠に呼ばれずCP待ちで
 *  タイムアウトしていた（GDB実測：gain_tick前後でCCOUNTが逆行）。
 *
 *  修正：**CCOUNTレジスタは一切操作しない**。凍結フラグ
 *  （_kernel_hrt_frozen_val）はget_tim等の読み出し専用フェイクとしてのみ
 *  使い、CCOMPARE0操作はstop_tick前後を通じて常に実CCOUNT基準で行う。
 *   - stop_tick ：disable_int(XT_TIMER_INTNUM)でtick割込みをマスクし、
 *                 現在のHRT値を記録して凍結する（以後get_tim等はこの
 *                 固定値を見る。CCOUNT/CCOMPARE0は一切触らない）
 *   - start_tick：凍結解除→CCOMPARE0=実CCOUNT+1→enable_int（既に他API
 *                 が設定したCCOMPARE0があってもここで上書きし、即座に
 *                 一致・発火させ通常運転へ移行する）
 *   - gain_tick ：CCOMPARE0=実CCOUNT+1に設定→enable_intで1回発火させ、
 *                 signal_time()が次回のCCOMPARE0を新たに設定する
 *                 （＝値が変化する）のを待って1 tick処理完了を検知し、
 *                 凍結中だったら再びdisable_int＋凍結値+1で凍結し直す
 *                 （非凍結中に呼ばれた場合はenable_intのまま通常運転を
 *                 継続。TTGの一部APIテストがstop_tickを経ずに単体で
 *                 gain_tickを呼ぶパターンに対応）
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
 *  CCOUNTは操作しない（ヘッダコメント参照）。凍結を解除し、CCOMPARE0を
 *  実CCOUNT+1にして一致させてから割込みを許可する（以降はsignal_time()が
 *  通常どおり次回のCCOMPARE0を設定し続ける）。
 */
void
ttsp_target_start_tick(void)
{
	_kernel_hrt_frozen = false;
	xtensa_set_ccompare0(xtensa_get_ccount() + 1U);
	enable_int(XT_TIMER_INTNUM);
}

/*
 *  ティックの更新（1 tick分だけ進める）
 *
 *  [改変] 2026-07-07: 当初「stop_tick中（凍結状態）にのみ呼ばれる」という
 *  前提で実装していたが誤りだった。TTGが生成するAPIテストは、stop_tickを
 *  呼ばずに**通常運転中（非凍結）へ単体でgain_tickを呼ぶ**パターンを多用する
 *  （例：msta_alm(ALM, 0, ...)で即時アラームを設定した直後にgain_tickを呼び、
 *  アラームハンドラの発火を確実にする）。非凍結時に旧実装のまま
 *  `_kernel_hrt_frozen_val`（未凍結時は無効な古い値）でCCOUNTを巻き戻すと、
 *  システム時刻が不正に後退し、アラーム関連のAPIテストが広範囲に失敗した
 *  （ttsp_mp_wait_check_pointタイムアウト・ralm.almstat不一致等、
 *  APIテスト60/60失敗の根本原因と判明）。
 *
 *  修正：凍結中かどうかで分岐する。
 *   - 凍結中（stop_tick経由）：従来通りCCOUNTを凍結値へ巻き戻してから
 *     処理する（check_library/timerのシーケンス互換のため）。
 *   - 非凍結（通常運転中）：CCOUNTは一切操作せず、現在のCCOUNTを基準に
 *     CCOMPARE0=CCOUNT+1で即座に一致・発火させるだけ。処理後は凍結せず
 *     enable_int状態のまま通常運転を継続する。
 */
void
ttsp_target_gain_tick(void)
{
	ulong_t		timeout;
	bool_t		was_frozen;
	uint32_t	cur_ccount;
	uint32_t	cur_compare;

	was_frozen = _kernel_hrt_frozen;

	/*
	 *  [改変] 2026-07-07 (3回目・重要): 凍結値のインクリメントは
	 *  「割込みを発生させてsignal_time()を呼ぶ**前**」に行う必要がある。
	 *  以前は逆順（発火→待機→その後+1）だったため、signal_time()内の
	 *  update_current_evttim()がtarget_hrt_get_current()（凍結値）を
	 *  参照した時点ではまだ古い値のままで、current_evttimが進まず、
	 *  「0 tick後」に設定したアラーム（top_evttim==current_evttim）の
	 *  発火条件（top_evttim<=current_evttim）が満たされずハンドラが
	 *  呼ばれない不具合があった。修正：先に凍結値を+1してから割込みを
	 *  発生させる。
	 *
	 *  [改変] 2026-07-07 (6回目・最終・重要): 「CCOMPARE0の値をタスク
	 *  コンテキストでポーリングし、変化を検知したらdisable_int」という
	 *  設計は、QEMU上ではCCOUNTの進み方が命令数に対して線形でない
	 *  （GDB実測：xtensa_set_ccompare0からenable_int完了までの数命令の
	 *  間に239サイクルもの経過を確認）ため、タイトな設定・小さいマージン
	 *  では容易に取りこぼされ（一致イベント自体が発生しない）、逆に
	 *  マージンを増やすと1回のgain_tick呼び出し中に2回目の一致が生じて
	 *  ネスト割込みパニックを起こす、という板挟みで、ポーリング方式では
	 *  「確実にちょうど1回だけ」発火させることができなかった
	 *  （5回目までの改変過程はいずれも部分的にしか機能しなかった）。
	 *
	 *  最終修正：ポーリングでの間接検出をやめ、tick割込みハンドラ自身
	 *  （esp32_s3ポート本体のtarget_timer.c
	 *  ・_kernel_l1int_dispatch）に「1回限りモード」の完了通知フック
	 *  _kernel_hrt_gain_tick_pendingを追加した（詳細はtarget_timer.c参照）。
	 *  enable_int前にこのフラグを立てておけば、tick割込みハンドラが
	 *  signal_time()実行直後に自分で気づいてdisable_intし、フラグを
	 *  下ろす。タスク側はこのフラグが下りるのを待つだけでよく、
	 *  「ハンドラ実行後、確実に1回でマスクされる」ことが保証される。
	 *  待機中、CCOMPARE0がまだ実CCOUNTに追い越されていないか定期的に
	 *  確認し、追い越されていれば再設定する（取りこぼし救済。今回は
	 *  ワンショットフラグがあるため、複数回再設定しても安全）。
	 */
	if (was_frozen) {
		_kernel_hrt_frozen_val += 1U;
		_kernel_hrt_gain_tick_pending = true;
	}

	xtensa_set_ccompare0(xtensa_get_ccount() + 1U);
	enable_int(XT_TIMER_INTNUM);

	if (was_frozen) {
		timeout = 0U;
		while (_kernel_hrt_gain_tick_pending && timeout < TTSP_LOOP_COUNT) {
			cur_ccount = xtensa_get_ccount();
			Asm("rsr.ccompare0  %0" : "=a"(cur_compare));
			if ((int32_t) (cur_ccount - cur_compare) >= 0) {
				xtensa_set_ccompare0(cur_ccount + 1U);
			}
			timeout++;
		}
	}
	/* 非凍結だった場合はenable_intのまま（通常運転を継続）。 */
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
