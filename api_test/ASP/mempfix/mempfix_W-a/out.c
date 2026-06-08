/*
 *  ASP_mempfix_W_a
 *
 *  [WB] mempfix.c L309 br[0]: CHECK_PAR(blkoffset % blksz == 0U) — FALSE
 *       アドレスが blksz の倍数でないブロックポインタを rel_mpf に渡すと E_PAR を返すこと
 *
 *  シナリオ:
 *    1. pget_mpf(MPF1, &blk) → blk = pool_base（ブロック0の先頭アドレス）
 *    2. rel_mpf(MPF1, (char*)blk + 1)
 *         blkoffset = 1, blksz = 256
 *         CHECK_PAR(1 % 256 == 0) → 1 ≠ 0 → FALSE → L309 br[0] → E_PAR
 *    3. rel_mpf(MPF1, blk) → E_OK（正常返却で後片付け）
 *
 *  kernel: ASP3 3.7.2
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

void main_task(intptr_t exinf)
{
	ER ercd;
	void *blk;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_mempfix_W_a: Start");

	ttsp_check_point(1);

	/*
	 *  ブロックを取得して pool_base を得る
	 *  (blk = pool_base = p_mpfcb->p_mpfinib->mpf)
	 */
	ercd = pget_mpf(ASP_mempfix_W_a_MPF1, &blk);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/*
	 *  pool_base+1 を返却 → blkoffset=1, 1 % 256 ≠ 0 → L309 br[0] → E_PAR
	 */
	ercd = rel_mpf(ASP_mempfix_W_a_MPF1, (char *)blk + 1);
	check_ercd(ercd, E_PAR);

	ttsp_check_point(3);

	/*
	 *  正しいポインタで後片付け（blk は E_PAR で未返却のまま）
	 */
	ercd = rel_mpf(ASP_mempfix_W_a_MPF1, blk);
	check_ercd(ercd, E_OK);

	syslog_0(LOG_NOTICE, "ASP_mempfix_W_a: OK");
	ttsp_check_finish(4);
}
