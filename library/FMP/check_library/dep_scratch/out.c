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
 *  [新規] 2026-06-16: 依存部カバレッジ用の共通スクラッチ（FMP/SMP・層1）．
 *  ASP 版（library/ASP/check_library/dep_scratch）に SMP 固有の刺激を追加：
 *  スピンロック（loc_spn/unl_spn）と PE1→PE2 のタスク移送（mig_tsk）で
 *  core_support.S の dispatch_and_migrate（PE 間移送ディスパッチ）を踏む．
 *  チェックポイントは PE1 のみで進める（-smp 2・トレース下の SMP タイミング
 *  非決定性を避けるため，MP バリアは用いない）．docs/DEP_COVERAGE_PLAN.md．
 */

#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

static volatile double fpu_acc;
static ID g_prcid;            /* 本スクラッチは PE1 で進行（get_pidで取得） */

#define TTSP_PHASE_MIG		1	/* 他タスク移送（MIG_TASK）とのバリア同期フェーズ */
#define TTSP_PHASE_SELFMIG	2	/* 自己移送（SELFMIG_TASK）とのバリア同期フェーズ */
#define TTSP_PHASE_MACT		3	/* mact_tsk キューイング移送（MACT_TASK）の同期フェーズ */

void fpu_task(intptr_t exinf)
{
	double x = (double) exinf + 0.5;
	int_t i;

	for (i = 0; i < 800; i++) {
		x = x * 1.0000001 + 0.5;
		if ((i & 0x3f) == 0) {
			dly_tsk(1);
		}
	}
	fpu_acc += x;
	ext_tsk();
}

void high_task(intptr_t exinf)
{
	ttsp_mp_check_point(g_prcid, 5);
	slp_tsk();
	ttsp_mp_check_point(g_prcid, 7);
	ext_tsk();
}

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
 *  PE1 で起動後すぐ寝る．main が mig_tsk で PE2 へ移送し wup する．
 *  起床後は PE2 上で実行される＝PE 間移送ディスパッチ（dispatch_and_migrate）を踏む．
 */
void mig_task(intptr_t exinf)
{
	volatile double z = 1.5;
	int_t i;

	slp_tsk();			/* PE1 で起動後すぐ寝る．main が PE2 へ移送し wup する */
	for (i = 0; i < 64; i++) {
		z = z * 1.0000001 + 0.5;
	}
	fpu_acc += z;
	ttsp_barrier_sync(TTSP_PHASE_MIG, TNUM_PRCID);	/* PE2 として main と同期 */
	ext_tsk();
}

/*
 *  自タスクのマイグレーション：main より高優先で起動し，走行中に
 *  mig_tsk(TSK_SELF, 2) で自分を PE2 へ自己移送する．dly_tsk で一度ブロックして
 *  PE2 上で再開（PE 間移送ディスパッチ＝core_support.S の dispatch_and_migrate を踏む）．
 *  PE2 で再開後，main(PE1) とバリア同期して完了を通知する（dly_tsk ポーリングだと
 *  main が PE1 を起こし続け PE2 が走れないため，ビジー待ちのバリアで確実に待ち合わせる）．
 */
void selfmig_task(intptr_t exinf)
{
	volatile double s = 3.5;
	int_t	i;
	ID	prc = 0;

	(void) mig_tsk(TSK_SELF, 2);	/* 自タスクを PE2 へ自己移送 */
	dly_tsk(2);			/* 一度ブロックして次ディスパッチで PE2 へ移る */
	(void) sil_get_pid(&prc);
	for (i = 0; i < 64; i++) {
		s = s * 1.0000001 + 0.5;
	}
	fpu_acc += s;
	syslog_1(LOG_NOTICE, "self migration (mig_tsk TSK_SELF): now on PE%d",
			 (int_t) prc);
	ttsp_barrier_sync(TTSP_PHASE_SELFMIG, TNUM_PRCID);	/* PE2 として main と同期 */
	ext_tsk();
}

/*
 *  マイグレーションのキューイング対象タスク．1 回目は PE1 で起動して待ち状態に入り
 *  （mact_tsk のキューイング対象になる），main の ter_tsk で終了されると，キューイング
 *  された起動要求により actprc（PE2）へ移送されて再起動される．2 回目（PE2）で
 *  バリア同期する．main より高優先で，act_tsk で即起動して待ち状態に入る．
 */
void mact_task(intptr_t exinf)
{
	volatile double m = 4.5;
	int_t	i;
	ID	prc = 0;

	(void) sil_get_pid(&prc);
	if (prc == 1) {
		slp_tsk();		/* PE1 で待ち状態に（ter_tsk で終了される） */
		ext_tsk();		/* 通常ここへは戻らない（保険） */
		return;
	}
	/* ter_tsk のキューイング再起動で PE2 上で実行される */
	for (i = 0; i < 64; i++) {
		m = m * 1.0000001 + 0.5;
	}
	fpu_acc += m;
	syslog_1(LOG_NOTICE, "mact_tsk queued migration: reactivated on PE%d",
			 (int_t) prc);
	ttsp_barrier_sync(TTSP_PHASE_MACT, TNUM_PRCID);
	ext_tsk();
}

void main_task(intptr_t exinf)
{
	ER	ercd;
	PRI	ipm;

	ttsp_initialize_test_lib();
	get_pid(&g_prcid);
	ttsp_mp_check_point(g_prcid, 1);

	/* §6.3 システム状態の管理 */
	loc_cpu();
	(void) sns_ctx();
	(void) sns_loc();
	unl_cpu();
	dis_dsp();
	(void) sns_dsp();
	(void) sns_dpn();
	ena_dsp();
	ttsp_mp_check_point(g_prcid, 2);

	/* §6.4.1 割込み優先度マスクの管理 */
	ercd = chg_ipm(TTSP_MID_INTPRI);
	check_ercd(ercd, E_OK);
	ercd = get_ipm(&ipm);
	check_ercd(ercd, E_OK);
	ercd = chg_ipm(TIPM_ENAALL);
	check_ercd(ercd, E_OK);
	ttsp_mp_check_point(g_prcid, 3);

	/* SMP：スピンロックの取得/解放 */
	loc_spn(SPN1);
	unl_spn(SPN1);
	ttsp_mp_check_point(g_prcid, 4);

	/* §6.5 ディスパッチャ：高優先タスク起動による preempt */
	ercd = act_tsk(HIGH_TASK);
	check_ercd(ercd, E_OK);
	ttsp_mp_wait_check_point(g_prcid, 5);
	ttsp_mp_check_point(g_prcid, 6);
	ercd = wup_tsk(HIGH_TASK);
	check_ercd(ercd, E_OK);
	ttsp_mp_wait_check_point(g_prcid, 7);
	ttsp_mp_check_point(g_prcid, 8);

	/* FPU コンテキスト切替 */
	ercd = act_tsk(FPU_TASK1);
	check_ercd(ercd, E_OK);
	ercd = act_tsk(FPU_TASK2);
	check_ercd(ercd, E_OK);
	dly_tsk(50);
	ttsp_mp_check_point(g_prcid, 9);

	/* SMP：PE1→PE2 のタスク移送（mig_tsk）．移送可能クラス CLS_ALL_PRC1 の
	   タスクを PE1 で起動→寝かせ→PE2 へ移送→起床で PE2 ディスパッチ．
	   PE2 上で走り切るのをバリアで待ち合わせる（dly_tsk ポーリングは PE2 を
	   走らせ切れないため）． */
	ercd = act_tsk(MIG_TASK);
	check_ercd(ercd, E_OK);
	ercd = mig_tsk(MIG_TASK, 2);
	check_ercd(ercd, E_OK);
	ercd = wup_tsk(MIG_TASK);
	check_ercd(ercd, E_OK);
	ttsp_barrier_sync(TTSP_PHASE_MIG, TNUM_PRCID);

	/* SMP：自タスクの自己移送（mig_tsk(TSK_SELF, 2)）＝PE2 で再開させ
	   dispatch_and_migrate を踏む．SELFMIG_TASK は main より高優先なので act_tsk で
	   即起動→自己移送し，main はバリアで PE2 上の SELFMIG_TASK と待ち合わせる． */
	ercd = act_tsk(SELFMIG_TASK);
	check_ercd(ercd, E_OK);
	ttsp_barrier_sync(TTSP_PHASE_SELFMIG, TNUM_PRCID);

	/* SMP：マイグレーションのキューイング→ter_tsk で移送・再起動．
	   非休止タスクへの mact_tsk は起動をキューイング（actque/actprc）し，
	   ter_tsk による終了時に actprc のプロセッサ（PE2）へ移送して再起動する． */
	ercd = act_tsk(MACT_TASK);		/* MACT_TASK(高優先) 即起動→ slp_tsk で待ち */
	check_ercd(ercd, E_OK);
	ercd = mact_tsk(MACT_TASK, 2);		/* 非休止→起動をキューイング(actprc=2) */
	check_ercd(ercd, E_OK);
	ercd = ter_tsk(MACT_TASK);		/* 終了時に PE2 へ移送して再起動 */
	check_ercd(ercd, E_OK);
	ttsp_barrier_sync(TTSP_PHASE_MACT, TNUM_PRCID);
	ttsp_mp_check_point(g_prcid, 10);

	/* §6.4／§6.6 割込み：禁止/許可と多重割込み（低→中→高） */
	ercd = dis_int(TTSP_INTNO_A);
	check_ercd(ercd, E_OK);
	ercd = ena_int(TTSP_INTNO_A);
	check_ercd(ercd, E_OK);
	ttsp_int_raise(TTSP_INTNO_A);
	ttsp_mp_wait_check_point(g_prcid, 11);
	ttsp_mp_check_point(g_prcid, 12);

	/* §6.7 CPU例外（復帰可能）と発生時のシステム状態参照 */
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	ttsp_mp_wait_check_point(g_prcid, 13);

	ttsp_mp_check_finish(g_prcid, 14);
}

/*
 *  多重割込み：A(低)で B(中)、B で C(高) を要求．C の出口で IRQ_TASK を起動して
 *  main を割込み契機で preempt→ret_int_r 復帰させる（割込み復帰側の復帰経路）．
 */
void inthdr_ttsp_intno_a(void)
{
	ttsp_clear_int_req(TTSP_INTNO_A);
	ttsp_int_raise(TTSP_INTNO_B);
	ttsp_mp_check_point(g_prcid, 11);
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
	iact_tsk(IRQ_TASK);
}

void exception_ttsp_excno_a(void *p_excinf)
{
	ID	prcid = 0;

	ttsp_cpuexc_hook(TTSP_EXCNO_A, p_excinf);
	(void) xsns_dpn(p_excinf);
	(void) sil_get_pid(&prcid);
	ttsp_mp_check_point(g_prcid, 13);
	/* CPU例外ハンドラが走った PE をログ出力し，例外フレームを xlog_sys で吐く */
	syslog_1(LOG_NOTICE, "[PE%d] CPU exception (EXCNO_A) handled : OK", (int_t) prcid);
	xlog_sys(p_excinf);	/* pc/cpsr/lr/r0-r3/nest_count/intpri をダンプ */
}
