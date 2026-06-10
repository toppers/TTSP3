/*
 *  FMP_xsns_dpn_W_b
 *
 *  [WB] exception.c xsns_dpn: p_my_pcb->p_runtsk == NULL → state=true
 *       実行可能タスクの無い PE（アイドル中・p_runtsk==NULL）で CPU 例外を
 *       発生させ，CPU 例外ハンドラから xsns_dpn(p_excinf) を呼び出す．
 *
 *       FMP の xsns_dpn は check_tskctx() が真（非タスクコンテキスト＝CPU 例外
 *       コンテキスト）の場合に自 PE の PCB を参照して以下を評価する:
 *         state = (kerflg_table[INDEX_PRC(prcid)] && exc_sense_intmask(p_excinf)
 *                       && p_my_pcb->enadsp
 *                       && p_my_pcb->p_runtsk != NULL) ? false : true;
 *       アイドル中の PE で発生した CPU 例外では
 *         - kerflg_table[PE]   = true（スケジューラ起動後）
 *         - exc_sense_intmask  = true（非ネスト・IPM 全解除・CPU アンロック）
 *         - p_my_pcb->enadsp   = true（ディスパッチ許可）
 *         - p_my_pcb->p_runtsk = NULL
 *       となり，短絡評価は最後の p_runtsk!=NULL で false 確定 → state=true．
 *       これが BB テスト・xsns_dpn_W-a でも未到達だった p_runtsk==NULL 分岐を
 *       カバーする（残る kerflg_table==false 分岐は構造的到達不能）。
 *
 *  到達手法（custom idle 方式・カーネル無改変）:
 *    fmp3/arch/arm_gcc/common/core_support.S のアイドルループ dispatcher_2 は
 *    TOPPERS_CUSTOM_IDLE 定義時に toppers_asm_custom_idle を実行する（その PE の
 *    p_runtsk==NULL のまま回る）．これを COPTS の
 *      -include <wb_dir>/ttsp_custom_idle.inc
 *    で注入し，フックから C 関数 xsns_dpn_W_b_idle を呼ぶ．fmp3 は編集しない
 *    （禁則②）．
 *
 *  SMP 構成（TNUM_PRCID>=2）:
 *    MAIN_TASK を PE1 のみに割り当て，PE2 には実行可能タスクが無い状態にする．
 *    PE2 は起動直後からアイドル（p_runtsk==NULL）で回る．custom idle フックは
 *    sil_get_pid で自 PE を判定し，PE2 でのみ CPU 例外を 1 回だけ発生させる
 *    （PE1 のアイドルでは発火しない＝PE1 用 CPU 例外ハンドラ未登録のため）．
 *    テストライブラリ初期化は ATT_INI（dispatch 開始前に master PE で実行）で
 *    行うため，PE2 の発火タイミングに依らず check_count は初期化済み．
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include <sil.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

static volatile bool_t custom_idle_fired = false;

/*
 *  テストライブラリ初期化（ATT_INI: dispatch 開始前に master PE で実行）
 */
void
ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
}

/*
 *  custom idle フック
 *
 *  各 PE のアイドルループ（dispatcher_2）から assembler マクロ
 *  toppers_asm_custom_idle 経由で呼ばれる（SVC モード・CPU アンロック・
 *  自 PE の p_runtsk==NULL で実行）．PE2 でのみ，初回 1 回だけ CPU 例外
 *  （復帰可能な未定義命令例外）を発生させる．
 */
void
xsns_dpn_W_b_idle(void)
{
	ID	prcid;

	sil_get_pid(&prcid);
	if (prcid == 2 && !custom_idle_fired) {
		custom_idle_fired = true;
		ttsp_cpuexc_raise(TTSP_EXCNO_PE2_A);
	}
}

/*
 *  CPU 例外ハンドラ（PE2 で実行）
 *
 *  アイドル中（p_runtsk==NULL）に発生した CPU 例外に対して呼ばれる．
 *  check_tskctx()==true（CPU 例外コンテキスト）かつ p_my_pcb->p_runtsk==NULL
 *  のため，xsns_dpn は true を返す．完了は本ハンドラ内の ttsp_check_finish
 *  （→ ext_ker）で行う．
 */
void
xsns_dpn_W_b_exc(void *p_excinf)
{
	bool_t	state;

	ttsp_cpuexc_hook(TTSP_EXCNO_PE2_A, p_excinf);

	ttsp_check_point(1);

	/* check_tskctx()==true かつ p_runtsk==NULL → state=true */
	state = xsns_dpn(p_excinf);
	check_value((int_t)state, (int_t)true);

	syslog_0(LOG_NOTICE, "FMP_xsns_dpn_W_b: OK");
	ttsp_check_finish(2);
}

/*
 *  PE1 の MAIN_TASK
 *
 *  自タスクを終了して PE1 もアイドルにする（PE1 のアイドルでは custom idle
 *  フックは発火しない）．検証は PE2 の CPU 例外ハンドラ側で行う．
 */
void
main_task(intptr_t exinf)
{
	ext_tsk();
}
