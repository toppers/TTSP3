/*
 *  FMP_xsns_dpn_W_a
 *
 *  [WB] exception.c xsns_dpn: check_tskctx()==false → state=true [NGKI3152]
 *       タスクコンテキストから xsns_dpn(NULL) を直接呼び出す．
 *       FMP の xsns_dpn は check_tskctx() でコンテキストを判定し，
 *       タスクコンテキスト（excpt_nest_count==0）では kerflg_table 等を
 *       評価せず常に true を返す（NGKI3152）．
 *
 *  BBテストの check_library/exception は CPU 例外ハンドラ内
 *  （excpt_nest_count>0 → check_tskctx()==true）から xsns_dpn を呼ぶため，
 *  この else 分岐（タスクコンテキスト呼び出し）は未到達となる．
 *
 *  ※ FMP の kerflg_table=false 分岐は check_tskctx() ガードにより構造的到達
 *    不能（kerflg_table は start_dispatch 前に true 化される）．ASP の
 *    xsns_dpn_W-a（初期化ルーチンで kerflg=false 経路）とは対象分岐が異なる．
 *
 *  kernel: FMP3 3.4.0
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void ttsp_test_lib_init(intptr_t exinf)
{
	ttsp_initialize_test_lib();
}

void main_task(intptr_t exinf)
{
	bool_t state;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "FMP_xsns_dpn_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  タスクコンテキストから直接呼び出す → check_tskctx()==false →
	 *  else 分岐 → state=true（NGKI3152）
	 */
	state = xsns_dpn(NULL);
	check_value((int_t)state, (int_t)true);

	ttsp_check_point(2);

	syslog_0(LOG_NOTICE, "FMP_xsns_dpn_W_a: OK");
	ttsp_check_finish(3);
}
