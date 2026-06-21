/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  上記著作権者は，以下の(1)〜(4)の条件を満たす場合に限り，本ソフトウェ
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
 */

/*
 *		ターゲット依存のテストサポート関数（MPS2-AN505 / Cortex-M33 用）
 *
 *  [改変] 2026-06-20: ek_ra8m2_gcc 版（M-profile / Cortex-M85）を ARM MPS2-AN505
 *  （ARMv8-M / Cortex-M33 / QEMU）向けへ複製した．本体ロジック（NVIC raise_int /
 *  udf による UsageFault / target_hrt_* による tick 制御 / USE_TSKINICTXB アクセサ）は
 *  arm_m 系で共通のためそのまま流用できる（tick は GPT0 でなく SysTick イベント駆動 HRT
 *  だが target_hrt_* インターフェースは同一）．TTSP3 ライセンス条件(2)に基づく改変明記．
 *  --- 以下 ek_ra8m2_gcc 由来の記述（M-profile 共通）---
 *  zybo_z7_gcc 版（A-profile / GIC / MPCore グローバルタイマ）を
 *  ベースに，M-profile（ARMv8-M）向けに作成した．
 *  TTSP3 ライセンス条件(2)に基づく改変明記．
 *   - 割込み発生/クリア：GIC ではなく NVIC（ISPR/ICPR）を操作する．カーネルの
 *     M-profile アクセサ raise_int()/clear_int()（core_kernel_impl.h）を用いる．
 *   - CPU例外発生：未定義命令 udf #0（UsageFault）を発行する．
 *   - CPU例外フック：M-profile では udf による UsageFault は同一 PC へ戻るため，
 *     T_EXCINF.pc を udf 命令(2バイト)分進めて発生元へ復帰できるようにする．
 *   - 時刻制御：MPCore グローバルタイマではなく，本ターゲットの高分解能タイマ
 *     （GPT0 イベント駆動，target_timer.c）を停止/再開/前進させる．
 */

/*
 *  ［インクルード順序］カーネルのタイマドライバ target_timer.c と同じ順序
 *  （kernel_impl.h → time_event.h → target_timer.h）でインクルードする．
 *  これにより target_rename.h による target_hrt_* のリネームが適用された状態で
 *  target_timer.h の関数宣言が可視化され，ttsp_target_gain_tick から
 *  target_hrt_raise_event() を正しく呼び出せる．
 *
 *  ref_tsk スタック情報アクセサ（USE_TSKINICTXB 用）は TINIB の完全な構造体定義
 *  （task.h，ALLFUNC 時に可視）を必要とするため task.h を取り込む．本ファイルは
 *  テストライブラリ ttsp_test_lib.c と同様に ALLFUNC 前提でビルドする．
 */
#include "kernel/kernel_impl.h"
#include "kernel/time_event.h"
#include "target_timer.h"
#include "kernel/task.h"
#include <sil.h>
#include "ttsp_target_test.h"

/*
 *  スタック領域の定義
 */
TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack");
#ifdef TTSP_STACK_SHARE_HRP
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack");
TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section");
#endif /* TTSP_STACK_SHARE_HRP */

/*
 *  スタック領域情報の取出し（USE_TSKINICTXB ターゲット用）
 *
 *  本ターゲット（arm_m_gcc）は TSKINICTXB を使う（core_kernel_impl.h で
 *  USE_TSKINICTXB を定義）。TSKINICTXB はシステムスタックを末尾/先頭番地
 *  （stk_top/stk_bottom）で，ユーザスタックを先頭番地/サイズ（ustk/ustksz）で
 *  保持する。TTSP3 のテストライブラリ（ttsp_test_lib.c の ref_tsk 検査）は
 *  ref_tsk 標準形式（先頭番地＋サイズ）を要求するため，TSKINICTXB から
 *  標準形式へ変換する以下のアクセサを提供する。
 *
 *  ・システムスタック先頭番地 = stk_bottom，サイズ = stk_top - stk_bottom
 *  ・ユーザスタック先頭番地 = ustk，サイズ = ustksz
 *  （A-profile ターゲット（zybo 等）は USE_TSKINICTXB 未定義のため本アクセサ不要。）
 */
#ifdef USE_TSKINICTXB

size_t
ttsp_target_get_sstksz(const TINIB *p_tinib)
{
	return ((size_t)((char *) p_tinib->tskinictxb.stk_top
					 - (char *) p_tinib->tskinictxb.stk_bottom));
}

size_t
ttsp_target_get_ustksz(const TINIB *p_tinib)
{
	return (p_tinib->tskinictxb.ustksz);
}

void *
ttsp_target_get_sstk(const TINIB *p_tinib)
{
	return ((void *) p_tinib->tskinictxb.stk_bottom);
}

void *
ttsp_target_get_ustk(const TINIB *p_tinib)
{
	return (p_tinib->tskinictxb.ustk);
}

#endif /* USE_TSKINICTXB */

/*
 *  ティック更新の停止
 *
 *  高分解能タイマ（GPT0）を停止する（target_hrt_terminate が R_GPT_Stop/Close
 *  を行う）．FSP 制御構造体（g_timer0_ctrl）へ直接依存しないよう，カーネルが
 *  公開する target_timer.h の API 経由で操作する．
 *  ［注意］本ターゲットでは WDT リフレッシュを GPT0 割込みハンドラ
 *  （target_hrt_handler）で行っているため，長時間停止すると WDT リセットの
 *  恐れがある．TTSP3 の時刻制御テストは停止→gain_tick→再開を短時間で行う
 *  前提のため実用上問題ないが，停止状態を長く保つテストには注意．
 */
void
ttsp_target_stop_tick(void)
{
	target_hrt_terminate(0);
}

/*
 *  ティック更新の再開
 *
 *  高分解能タイマ（GPT0）を再開する（target_hrt_initialize が R_GPT_Open/Start
 *  を行う）．
 */
void
ttsp_target_start_tick(void)
{
	target_hrt_initialize(0);
}

/*
 *  ティックの更新（時刻を 1μs 進める）
 *
 *  停止中の高分解能タイマに対し，TTSP3 の時刻制御テストが期待する
 *  「時刻を確実に前進させる」セマンティクスを与える．本ターゲットの
 *  HRT は GPT0 のコンペアマッチA 割込みで時間イベントを処理する
 *  （signal_time）ため，コンペアマッチA 割込みを直接要求して
 *  1 ティック分の時間イベント処理を進める．
 */
void
ttsp_target_gain_tick(void)
{
	target_hrt_raise_event();
}

/*
 *  割込みを発生させる（NVIC ソフトウェアペンディング）
 *
 *  カーネルの M-profile アクセサ raise_int()（core_kernel_impl.h）は
 *  NVIC の ISPR（IRQ）または ICSR.PENDSTSET（SysTick）へ書き込み，
 *  対象割込みをペンディング状態にする．
 */
void
ttsp_int_raise(INTNO intno)
{
	raise_int(intno);
}

/*
 *  割込み要求のクリア（NVIC クリアペンディング）
 *
 *  カーネルの M-profile アクセサ clear_int()（core_kernel_impl.h）は
 *  NVIC の ICPR（IRQ）または ICSR.PENDSTCLR（SysTick）へ書き込み，
 *  対象割込みのペンディングをクリアする．
 */
void
ttsp_clear_int_req(INTNO intno)
{
	clear_int(intno);
}

/*
 *  CPU例外を発生させる
 *
 *  TTSP_EXCNO_A（UsageFault）の場合のみ udf #0 を実行して UsageFault を
 *  発生させる．
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
 *
 *  M-profile では未定義命令(udf)による UsageFault は，例外復帰時に
 *  同一 PC（udf 命令）へ戻るため，何もしないと無限に再フォルトする
 *  （A-profile では未定義命令例外ハンドラ復帰時に LR が次命令を指す）．
 *  そこで，TTSP_EXCNO_A の場合は T_EXCINF.pc を udf 命令(2バイト Thumb)
 *  分進め，発生元コンテキストの次命令へ復帰させる．
 *
 *  本フックは sil_test/api_test の CPU例外ハンドラ（exchdr 等）の先頭で
 *  呼ばれる（out.c 参照）．
 */
void
ttsp_cpuexc_hook(EXCNO excno, void *p_excinf)
{
	if (excno == TTSP_EXCNO_A) {
		/* udf #0 は 2 バイトの Thumb 命令．次命令へ復帰させる．
		 *
		 *  注意: ARM-M の例外フレーム(p_excinf)は [0]=basepri/primask [1]=EXC_RETURN の
		 *  2 ワード前置きで，PC は P_EXCINF_OFFSET_PC(=8) ワード目にある（arm_m.h・カーネルの
		 *  sense 関数や core_exc_entry/STEP2 復帰もこのオフセットを使用）。一方 T_EXCINF 構造体は
		 *  nest_count/intpri/rundom の 3 ワード前置きのため ->pc は 9 ワード目（=XPSR の位置）に
		 *  なり 1 ワードずれる。そこで構造体メンバではなくオフセットで PC を進める。 */
		((uint32_t *) p_excinf)[P_EXCINF_OFFSET_PC] += 2U;
	}
}
