/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2018 by FUJI SOFT INCORPORATED
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
 *      用できない形で再配布する場合には，次のいずれかの条件を満たすこと．
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
 *  [新規] 2026-06-16: 依存部カバレッジ用の共通スクラッチテスト（層1）．
 *  TOPPERS ポーティングマニュアル(porting.txt §6)が定める依存部の主要経路を
 *  1本のアプリで踏むことを目的とする（docs/DEP_COVERAGE_PLAN.md）．
 *  踏む対象: §6.3 システム状態管理(CPUロック/ディスパッチ禁止/sns系)，
 *  §6.4 割込み優先度マスク・多重割込み，§6.5 ディスパッチャ(preempt/自発/
 *  ext_tsk/act_tsk)，§6.7 CPU例外と発生時状態参照，ARM §6.9 FPUコンテキスト切替．
 */

#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

/*
 *  FPU を使用するワーカ．コンテキスト切替の際に FPU コンテキストの
 *  退避/復帰（ARM core_support.S の選択的保存経路）を踏ませる．
 */
static volatile double fpu_acc;

/*
 *  初期値付きグローバル変数（非ゼロ）．.data セクションに置かれ，起動時の
 *  ROM→RAM データ初期化コピー（start.S の DATA コピーループ）を踏ませる．
 *  .bss（ゼロ初期化）ではコピーループは走らないため，非ゼロ初期値が必要．
 */
static volatile uint32_t init_data = 0xDEADBEEFU;

void fpu_task(intptr_t exinf)
{
	double x = (double) exinf + 0.5;
	int_t i;

	for (i = 0; i < 800; i++) {
		x = x * 1.0000001 + 0.5;
		if ((i & 0x3f) == 0) {
			dly_tsk(1);		/* 他FPUタスク/メインへ切替＝FPU保存を誘発 */
		}
	}
	fpu_acc += x;
	ext_tsk();			/* §6.5.5 コンテキストを捨ててディスパッチ */
}

void high_task(intptr_t exinf)
{
	ttsp_check_point(5);
	slp_tsk();			/* §6.5.3 自発的なディスパッチ */
	ttsp_check_point(7);
	ext_tsk();
}

/*
 *  割込みハンドラ（割込みコンテキスト）から起動される高優先タスク．
 *  これにより main は「割込み契機のディスパッチ」で preempt され，後で
 *  ret_int_r 経由で復帰する（§6.6 割込みハンドラ出口でのコンテキスト復帰
 *  ＝ARM core_support.S の割込み復帰側 FPU/レジスタ復帰経路を踏む）．
 *  FPU を使うことで復帰時の FPU レジスタ復帰も併せて踏ませる．
 */
void irq_task(intptr_t exinf)
{
	volatile double y = (double) exinf + 1.25;
	int_t i;

	for (i = 0; i < 64; i++) {
		y = y * 1.0000001 + 0.25;
	}
	fpu_acc += y;
	ext_tsk();
}

/*
 *  CPU例外ハンドラ（タスク文脈）から iact_tsk で起動される高優先タスク．
 *  これにより例外出口で main が preempt され（再開番地 ret_exc_r を保存），
 *  本タスク終了後に main が ret_exc_r 経由で復帰する＝例外復帰側のディスパッチ
 *  経路（core_support.S exc_handler_3 のディスパッチ＋ret_exc_r）を踏む．
 */
void exc_task(intptr_t exinf)
{
	volatile double w = (double) exinf + 2.5;
	int_t i;

	for (i = 0; i < 64; i++) {
		w = w * 1.0000001 + 0.5;
	}
	fpu_acc += w;
	ext_tsk();
}

void main_task(intptr_t exinf)
{
	ER	ercd;
	PRI	ipm;

	ttsp_initialize_test_lib();
	/* 起動時の .data コピーが効いていることを確認（最適化除去防止も兼ねる） */
	if (init_data != 0xDEADBEEFU) {
		syslog_0(LOG_ERROR, "init_data mismatch (start.S .data copy)");
	}
	ttsp_check_point(1);

	/* §6.3 システム状態の管理：CPUロック／ディスパッチ禁止／状態参照 */
	loc_cpu();
	(void) sns_ctx();
	(void) sns_loc();
	unl_cpu();
	dis_dsp();
	(void) sns_dsp();
	(void) sns_dpn();
	ena_dsp();
	ttsp_check_point(2);

	/* §6.4.1 割込み優先度マスクの管理 */
	ercd = chg_ipm(TTSP_MID_INTPRI);
	check_ercd(ercd, E_OK);
	ercd = get_ipm(&ipm);
	check_ercd(ercd, E_OK);
	ercd = chg_ipm(TIPM_ENAALL);
	check_ercd(ercd, E_OK);
	ttsp_check_point(3);

	/* §6.5 ディスパッチャ：高優先タスク起動による preempt（§6.5.6 起動準備） */
	ttsp_check_point(4);
	ercd = act_tsk(HIGH_TASK);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(5);
	ttsp_check_point(6);
	ercd = wup_tsk(HIGH_TASK);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(7);
	ttsp_check_point(8);

	/* 同一優先度の回転（自発ディスパッチの別経路） */
	ercd = rot_rdq(TTSP_MID_INTPRI > 0 ? 1 : 1);
	check_ercd(ercd, E_OK);

	/* ARM §6.9 FPU：FPUワーカ2本を切替えながら走らせ FPU 保存経路を踏む */
	ercd = act_tsk(FPU_TASK1);
	check_ercd(ercd, E_OK);
	ercd = act_tsk(FPU_TASK2);
	check_ercd(ercd, E_OK);
	dly_tsk(50);
	ttsp_check_point(9);

	/* §6.4／§6.6 割込み：禁止/許可と多重割込み（低→中→高） */
	ercd = dis_int(TTSP_INTNO_A);
	check_ercd(ercd, E_OK);
	ercd = ena_int(TTSP_INTNO_A);
	check_ercd(ercd, E_OK);
	ttsp_int_raise(TTSP_INTNO_A);
	ttsp_wait_check_point(10);
	ttsp_check_point(11);

	/*
	 *  §6.7 CPU例外（カーネル管理外）：CPUロック状態（I ビットセット）で
	 *  CPU例外を起こし，カーネル管理外CPU例外の出入口（nk_exc_handler）を踏む．
	 *  （core_support.S：例外フレームの CPSR の I/F ビットがセットなら nk へ分岐）
	 */
	loc_cpu();
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	unl_cpu();
	ttsp_check_point(12);

	/* §6.7 CPU例外（復帰可能・タスク文脈）と発生時のシステム状態参照 */
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	ttsp_wait_check_point(13);

	ttsp_check_finish(14);
}

/*
 *  多重割込み：A(低)で B(中) を、B で C(高) を要求し，多段ネストを踏む．
 */
void inthdr_ttsp_intno_a(void)
{
	ttsp_clear_int_req(TTSP_INTNO_A);
	ttsp_int_raise(TTSP_INTNO_B);
	ttsp_check_point(10);
	syslog_0(LOG_NOTICE, "nested interrupt A/B/C : OK");
}

void inthdr_ttsp_intno_b(void)
{
	ttsp_clear_int_req(TTSP_INTNO_B);
	ttsp_int_raise(TTSP_INTNO_C);
}

void inthdr_ttsp_intno_c(void)
{
	ttsp_clear_int_req(TTSP_INTNO_C);
	/*
	 *  割込みコンテキストから高優先タスクを起動する．多重割込みが解け，
	 *  最外段の割込み出口で IRQ_TASK がディスパッチされて main が preempt
	 *  され（コンテキストは ret_int_r を再開番地として保存される），
	 *  IRQ_TASK 終了後に main が ret_int_r 経由で復帰する（割込み復帰側の
	 *  レジスタ/FPU 復帰経路を踏む）．
	 */
	iact_tsk(IRQ_TASK);
}

/*
 *  CPU例外ハンドラ．ttsp_cpuexc_hook で発生元の例外（未定義命令）を解消する．
 *  1回目はカーネル管理外（CPUロック中）の発生＝nk_exc_handler 経路で，この文脈では
 *  カーネルサービスコールを発行できないため最小限（hook のみ）で復帰する．
 *  2回目はタスク文脈の通常発生で，§6.7.6 の状態参照（xsns_dpn）まで踏む．
 */
void exception_ttsp_excno_a(void *p_excinf)
{
	static uint_t exc_cnt = 0;

	exc_cnt++;
	ttsp_cpuexc_hook(TTSP_EXCNO_A, p_excinf);
	if (exc_cnt == 1) {
		/* カーネル管理外CPU例外：サービスコール禁止．最小限で復帰 */
		return;
	}
	(void) xsns_dpn(p_excinf);
	/*
	 *  高優先タスクを起動する．例外出口で main が preempt され（再開番地
	 *  ret_exc_r を保存），例外復帰側のディスパッチ経路を踏む．
	 */
	(void) iact_tsk(EXC_TASK);
	ttsp_check_point(13);
	syslog_0(LOG_NOTICE, "ttsp_cpuexc_raise(TTSP_EXCNO_A) : OK");
	xlog_sys(p_excinf);	/* 例外フレーム(pc/cpsr/lr/r0-r3/nest_count/intpri)をダンプ */
}
