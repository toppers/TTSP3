/*
 *  ASP_rel_mpf_W_b
 *
 *  [WB] mempfix.c L310 br[0]: CHECK_PAR(blkoffset / blksz < unused) — FALSE
 *       blkidx（= blkoffset / blksz）が unused（割当済み高水準線）以上のとき E_PAR を返すこと
 *
 *  シナリオ:
 *    1. pget_mpf × 2 → blk1 = pool_base（index 0）, blk2 = pool_base+256（index 1）
 *       この時点で p_mpfcb->unused = 2
 *    2. rel_mpf(MPF1, (char*)blk1 + 2*256)
 *         blkoffset = 512, blksz = 256
 *         L308: pool_base <= pool_base+512 → TRUE (通過)
 *         L309: 512 % 256 = 0 → TRUE (通過)
 *         L310: 512/256=2 < unused=2 → 2 < 2 = FALSE → L310 br[0] → E_PAR
 *    3. rel_mpf(MPF1, blk1), rel_mpf(MPF1, blk2) → E_OK（後片付け）
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
	void *blk1, *blk2;

	ttsp_target_stop_tick();
	ttsp_initialize_test_lib();
	syslog_0(LOG_NOTICE, "ASP_rel_mpf_W_b: Start");

	ttsp_check_point(1);

	/*
	 *  2ブロック取得: blk1 = index 0, blk2 = index 1
	 *  取得後 p_mpfcb->unused = 2
	 */
	ercd = pget_mpf(ASP_rel_mpf_W_b_MPF1, &blk1);
	check_ercd(ercd, E_OK);
	ercd = pget_mpf(ASP_rel_mpf_W_b_MPF1, &blk2);
	check_ercd(ercd, E_OK);

	ttsp_check_point(2);

	/*
	 *  pool_base + 2*blksz を返却 → blkidx=2, 2 < unused=2 は FALSE
	 *  → L310 br[0] → E_PAR
	 */
	ercd = rel_mpf(ASP_rel_mpf_W_b_MPF1, (char *)blk1 + 2 * 256);
	check_ercd(ercd, E_PAR);

	ttsp_check_point(3);

	/*
	 *  正しいポインタで後片付け（blk1, blk2 は E_PAR で未返却のまま）
	 */
	ercd = rel_mpf(ASP_rel_mpf_W_b_MPF1, blk1);
	check_ercd(ercd, E_OK);
	ercd = rel_mpf(ASP_rel_mpf_W_b_MPF1, blk2);
	check_ercd(ercd, E_OK);

	syslog_0(LOG_NOTICE, "ASP_rel_mpf_W_b: OK");
	ttsp_check_finish(4);
}
