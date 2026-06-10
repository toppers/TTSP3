/*
 *  ASP_xsns_dpn_W_b
 *
 *  [WB] exception.c L102 br[2]: p_runtsk == NULL → state=true
 *       全タスク終了後のアイドル状態（p_runtsk==NULL）で CPU 例外を発生させ，
 *       CPU 例外ハンドラから xsns_dpn(p_excinf) を呼び出す．
 *
 *       xsns_dpn の評価式:
 *         state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
 *                                && p_runtsk != NULL) ? false : true;
 *       アイドル中の CPU 例外では
 *         - kerflg            = true（スケジューラ起動後）
 *         - exc_sense_intmask = true（非ネスト・IPM 全解除・CPU アンロック）
 *         - enadsp            = true（ディスパッチ許可）
 *         - p_runtsk          = NULL
 *       となり，短絡評価は最後の p_runtsk!=NULL で false 確定 → state=true．
 *       これが BB テスト・xsns_dpn_W-a でも未到達だった L102 br[2] をカバーする．
 *
 *  到達手法（custom idle 方式・カーネル無改変）:
 *    asp3/arch/arm_gcc/common/core_support.S のアイドルループ dispatcher_1 は
 *    TOPPERS_CUSTOM_IDLE 定義時に toppers_asm_custom_idle を実行する（p_runtsk
 *    ==NULL のまま回る）．これを COPTS の
 *      -include <wb_dir>/ttsp_custom_idle.inc
 *    で注入し，フックから C 関数 xsns_dpn_W_b_idle を呼ぶ．asp3 は編集しない
 *    （禁則②）．公式 simtimer ターゲットの target_custom_idle と同型．
 *
 *  シナリオ:
 *    1. MAIN_TASK: 初期化 → ext_tsk() で自タスクを終了
 *    2. 実行可能タスクなし → p_runtsk=NULL → アイドル（dispatcher_1）
 *    3. custom idle hook xsns_dpn_W_b_idle: 初回のみ CPU 例外を発生
 *    4. CPU 例外ハンドラ xsns_dpn_W_b_exc: p_runtsk==NULL のまま
 *       xsns_dpn(p_excinf) を呼び，state==true を確認して完了
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

static volatile bool_t custom_idle_fired = false;

/*
 *  custom idle フック
 *
 *  core_support.S のアイドルループから assembler マクロ toppers_asm_custom_idle
 *  経由で呼ばれる（SVC モード・CPU アンロック・p_runtsk==NULL で実行）．
 *  初回のみ CPU 例外（復帰可能な未定義命令例外 EXCNO_UNDEF）を発生させる．
 *  例外ハンドラ側で ttsp_check_finish → ext_ker するため，通常は復帰しない
 *  が，万一復帰してもフラグで再発火を防ぐ．
 */
void
xsns_dpn_W_b_idle(void)
{
	if (!custom_idle_fired) {
		custom_idle_fired = true;
		ttsp_cpuexc_raise(TTSP_EXCNO_A);
	}
}

/*
 *  CPU 例外ハンドラ
 *
 *  アイドル中（p_runtsk==NULL）に発生した CPU 例外に対して呼ばれる．
 *  xsns_dpn は p_runtsk==NULL のため true を返す（L102 br[2]）．
 *  完了は本ハンドラ内の ttsp_check_finish（→ ext_ker）で行う．
 *  （check_library/exception のフェイタル例外ハンドラと同じ作法）
 */
void
xsns_dpn_W_b_exc(void *p_excinf)
{
	bool_t	state;

	ttsp_cpuexc_hook(TTSP_EXCNO_A, p_excinf);

	ttsp_check_point(2);

	/* p_runtsk==NULL → state=true（L102 br[2]） */
	state = xsns_dpn(p_excinf);
	check_value((int_t)state, (int_t)true);

	syslog_0(LOG_NOTICE, "ASP_xsns_dpn_W_b: OK");
	ttsp_check_finish(3);
}

void
main_task(intptr_t exinf)
{
	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_xsns_dpn_W_b: Start");

	ttsp_check_point(1);

	/*
	 *  自タスクを終了して実行可能タスクを無くす．カーネルはアイドル状態
	 *  （p_runtsk==NULL）に入り，custom idle hook が CPU 例外を発生させる．
	 */
	ext_tsk();
}
