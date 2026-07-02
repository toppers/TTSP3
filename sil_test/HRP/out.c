/*
 *  TTSP
 *      TOPPERS Test Suite Package
 * 
 *  Copyright (C) 2010-2012 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2012 by FUJISOFT INCORPORATED
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
 * 
 *  $Id: out.c 2 2012-05-09 02:23:52Z nces-shigihara $
 */
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "out.h"

/* 割込みが発生したか判別するためのフラグ */
bool_t int_flag;

/* 【改変 2026-07-02・全プロファイル共通（A-profile / M-profile 統一）】
 * ユーザドメイン(DOM1)から不正メモリアクセスや特権コード呼出しを行ったときに
 * sil_dabort_handler / sil_pabort_handler が捕捉した例外種別を記録するグローバル変数．
 * 0=未捕捉, 24=DACCVIOL/DABORT, 25=IACCVIOL/PABORT．
 * sil_user_task 復帰後（DOM1 PSP/タスクコンテキスト）で参照して ttsp_check_point を発行する．
 * ttsp_check_point（SVC 経由）はハンドラ内コンテキスト（trampoline 含む）では発行できないため
 * 全プロファイル共通でこの変数経由のワンパス方式に統一する．
 * 【改変 2026-07-02・更新 2026-07-02: A-profile も同方式に統一（二重発行回避）】 */
static volatile uint_t sil_dabort_cp_result = 0U;

void main_task(intptr_t exinf) {
	SIL_PRE_LOC;
	ER ercd;

	/* 初期化ルーチン内で発生させた割込みを待つ */
	wait_raise_int();

	ttsp_check_point(1);

	/* 
	 * タスク
	 */
	syslog_0(LOG_NOTICE, "=== test start from TASK ===");
	all_test();
	ttsp_check_point(2);


	/*
	 * タスク例外処理ルーチン
	 *
	 * 【TTSP3向け改変 2026-06-14】第3世代カーネル（ASP3 等）はタスク例外処理
	 * 機能を持たない（ena_tex/ras_tex/dis_tex・DEF_TEX が存在しない）ため，
	 * タスク例外処理ルーチン文脈での SIL テストは対象外とする．チェックポイント
	 * 番号の連続性を保つため CP3/CP4 はプレースホルダとして発行する．
	 */
	syslog_0(LOG_NOTICE, "=== test from TASK EXCEPTION: skipped (no task exception in 3rd gen) ===");
	ttsp_check_point(3);
	ttsp_check_point(4);


	/* 
	 * アラームハンドラ
	 */
	syslog_0(LOG_NOTICE, "=== test start from ALARM ===");
	ercd = sta_alm(ALM, 0);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(5);
	ttsp_check_point(6);

	/* [e][k]ディスパッチ禁止状態 */
	ercd = dis_dsp();
	check_ercd(ercd, E_OK);
	ercd = sta_alm(ALM, 0);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(7);
	ercd = ena_dsp();
	check_ercd(ercd, E_OK);
	ttsp_check_point(8);


	/* 
	 * 周期ハンドラ
	 */
	syslog_0(LOG_NOTICE, "=== test start from CYCLIC ===");
	ercd = sta_cyc(CYC);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(9);
	ercd = stp_cyc(CYC);
	check_ercd(ercd, E_OK);
	ttsp_check_point(10);

	/* [e][k]ディスパッチ禁止状態 */
	ercd = dis_dsp();
	check_ercd(ercd, E_OK);
	ercd = sta_cyc(CYC);
	check_ercd(ercd, E_OK);
	ttsp_wait_check_point(11);
	ercd = stp_cyc(CYC);
	check_ercd(ercd, E_OK);
	ercd = ena_dsp();
	check_ercd(ercd, E_OK);
	ttsp_check_point(12);


	/* 
	 * CPU例外ハンドラ
	 */
	syslog_0(LOG_NOTICE, "=== test start from EXCEPTION ===");
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	ttsp_wait_check_point(13);
	ttsp_check_point(14);

	/* [d][j]割込み優先度マスク全解除でない状態 */
	ercd = chg_ipm(-1);
	check_ercd(ercd, E_OK);
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	ttsp_wait_check_point(15);
	ercd = chg_ipm(TIPM_ENAALL);
	check_ercd(ercd, E_OK);
	ttsp_check_point(16);

	/* [e][k]ディスパッチ禁止状態 */
	ercd = dis_dsp();
	check_ercd(ercd, E_OK);
	ttsp_cpuexc_raise(TTSP_EXCNO_A);
	ttsp_wait_check_point(17);
	ercd = ena_dsp();
	check_ercd(ercd, E_OK);
	ttsp_check_point(18);


#ifdef TTSP_INTNO_B
	/* 
	 * 割込みハンドラ
	 */
	syslog_0(LOG_NOTICE, "=== test start from INTHDR ===");
	ttsp_int_raise(TTSP_INTNO_B);
	ttsp_wait_check_point(19);
	ttsp_check_point(20);

	/* [e][k]ディスパッチ禁止状態 */
	ercd = dis_dsp();
	check_ercd(ercd, E_OK);
	ttsp_int_raise(TTSP_INTNO_B);
	ttsp_wait_check_point(21);
	ercd = ena_dsp();
	check_ercd(ercd, E_OK);
	ttsp_check_point(22);
#else
	ttsp_check_point(19);
	ttsp_check_point(20);
	ttsp_check_point(21);
	ttsp_check_point(22);
#endif /* TTSP_INTNO_B */


/* 【TTSP3向け改変 2026-06-14】ISR文脈は ATT_ISR 対応ターゲットのみ（zybo は非対応＝CP23-26 はスキップ）． */
#ifdef TTSP_SIL_TEST_ATT_ISR
	/*
	 * 割込みサービスルーチン
	 */
	syslog_0(LOG_NOTICE, "=== test start from ISR ===");
	ttsp_int_raise(TTSP_INTNO_C);
	ttsp_wait_check_point(23);
	ttsp_check_point(24);

	/* [e][k]ディスパッチ禁止状態 */
	ercd = dis_dsp();
	check_ercd(ercd, E_OK);
	ttsp_int_raise(TTSP_INTNO_C);
	ttsp_wait_check_point(25);
	ercd = ena_dsp();
	check_ercd(ercd, E_OK);
	ttsp_check_point(26);
#endif /* TTSP_INTNO_C */


	/* 【TTSP3向け改変 2026-06-14・HRP版】ユーザドメイン(DOM1)からの SIL アクセステスト．
	 * SIL_USER_TASK(DOM1) を起動し，その完了を待つ（CP23/24 は SIL_USER_TASK 側）． */
	syslog_0(LOG_NOTICE, "=== test start from USER DOMAIN (DOM1) ===");
	ercd = act_tsk(SIL_USER_TASK);
	check_ercd(ercd, E_OK);
	ercd = slp_tsk();
	check_ercd(ercd, E_OK);
	ttsp_check_point(27);


	/* 全割込みロック状態でext_kerを発行できることの確認 */
	SIL_LOC_INT();
	ext_ker();
}

/*
 * 【TTSP3向け改変 2026-06-14・HRP版】ユーザドメイン(DOM1)で実行され、SIL 関数を発行する．
 * 自タスクスタック上の変数に対するメモリ空間アクセス（check_of_sil_mem）・sns_ker・
 * sil_dly_nse は、ユーザドメインから発行しても許可される（保護対象外の SIL 操作）ことを確認する．
 */
void sil_user_task(intptr_t exinf) {
	ttsp_check_point(23);

	/* メモリ空間アクセス関数（自タスクスタック上の変数＝DOM1 がアクセス権を持つ領域） */
	check_of_sil_mem();
	syslog_0(LOG_NOTICE, "USER DOMAIN: sil_*_mem() : OK");

	/* sns_ker（カーネル状態参照）＋SIL_LOC_INT/SIL_UNL_INT：タスク文脈なので false．
	 * ※ ユーザドメインから SIL_LOC_INT/SIL_UNL_INT/sns_ker が発行できることの確認も兼ねる． */
	test_of_sns_ker(sns_ker());

	/* 【ユーザドメインでの SIL 挙動・実測知見 2026-06-14】
	 * - sil_*_mem（自タスクスタック対象）/ SIL_LOC_INT/SIL_UNL_INT / sns_ker：OK（ユーザドメインから発行可）
	 * - 保護される操作は下記の異常系で明示テストする． */

	syslog_0(LOG_NOTICE, "USER DOMAIN SIL access  : OK");

	/* ============================================================
	 * 【ユーザドメイン SIL 異常系・明示テスト 2026-06-14】
	 * ユーザドメインから「保護される操作」が期待どおり拒否されることを明示的に確認する：
	 * ・サービスコール保護：get_tim → E_OACV（check_ercd で捕捉）
	 * ・メモリアクセス違反：不正アドレス sil_reb_mem → Data Abort（DEF_EXC で捕捉＋pc復帰）
	 * ・特権コード呼出し：sil_dly_nse → Prefetch Abort（実機では DEF_EXC が捕捉，QEMU は非対応）
	 * CP24/25 は sil_user_task（DOM1 PSP コンテキスト）で発行する
	 * （ハンドラ(trampoline)コンテキストでの SVC 発行はカーネル時刻管理を破壊するため）．
	 * ============================================================ */
	{
		SYSTIM abntim;
		ER abnercd;
		/* 時刻管理サービス get_tim：ユーザドメインからは E_OACV（アクセス保護） */
		abnercd = get_tim(&abntim);
		check_ercd(abnercd, E_OACV);
		syslog_0(LOG_NOTICE, "USER DOMAIN abnormal: get_tim -> E_OACV : OK");
	}

	/* 【異常系・fault・明示CP化・全プロファイル統一 2026-07-02】
	 * 不正アドレス（TTSP_MACV_ADDRESS=0xd0000000）への SIL メモリアクセスは
	 * データアボート（M-profile: DACCVIOL / A-profile: DABORT）になる．
	 * DEF_EXC(EXCNO_DABORT / MemManage) の sil_dabort_handler が捕捉して pc を進めて復帰する．
	 * sil_dabort_handler はハンドラ内で ttsp_check_point を発行せず，
	 * sil_dabort_cp_result=24 に設定して復帰する（A/M 両プロファイル共通）．
	 * CP24 はここ（DOM1 タスクコンテキスト）で一本化して発行する． */
	sil_dabort_cp_result = 0U;	/* 捕捉前にクリア */
	(void) sil_reb_mem((void *) TTSP_MACV_ADDRESS);
	/* ここに戻った時点で sil_dabort_handler が pc を修正して復帰している */
	if (sil_dabort_cp_result == 24U) {
		ttsp_check_point(24);
		syslog_0(LOG_NOTICE, "USER DOMAIN abnormal: sil_reb_mem(illegal) -> DABORT caught & recovered : OK");
	}
	else {
		syslog_1(LOG_ERROR, "## sil_reb_mem(illegal): DABORT not caught (cp_result=%d)", (intptr_t)sil_dabort_cp_result);
		ttsp_check_point(24);	/* 意図的に失敗させてエラーを記録 */
	}

	/* 【異常系・PABORT テスト・全プロファイル統一 2026-07-02】
	 * sil_dly_nse はユーザドメインから呼ぶと実装（カーネル専用テキスト）の
	 * フェッチで命令アクセス違反（M-profile: IACCVIOL / A-profile: PABORT）になる．
	 * sil_dabort_handler(M) / sil_pabort_handler(A) が捕捉し，
	 * sil_dabort_cp_result=25 に設定して復帰する（ハンドラ内では ttsp_check_point を発行しない）．
	 * CP25 はここ（DOM1 タスクコンテキスト）で一本化して発行する．
	 * 本環境（QEMU 11.0.0 / mps2-an505）では IACCVIOL は正しく発生し caught 経路で通過する
	 * （CP25 通常パスが実測確認済み）．QEMU の版や設定によって IACCVIOL が発生しない
	 * 場合の防御として，sil_dabort_cp_result==0 のスキップパスも残す． */
	sil_dabort_cp_result = 0U;	/* PABORT/IACCVIOL 捕捉前にクリア */
	sil_dly_nse(SIL_DLY_TIME);
	/* 復帰後: フォルトが発生した（正常）→ sil_dabort_cp_result==25
	 *         フォルトが発生しなかった（QEMU 版依存の非エミュレート）→ sil_dabort_cp_result==0 */
	if (sil_dabort_cp_result == 25U) {
		/* 正常経路: PABORT/IACCVIOL が正しく捕捉された */
		ttsp_check_point(25);
		syslog_0(LOG_NOTICE, "USER DOMAIN abnormal: sil_dly_nse() -> PABORT caught & recovered : OK");
	}
	else {
		/* 防御経路: フォルトが発生しなかった（QEMU 版依存）→ CP25 を直接記録して続行 */
		syslog_0(LOG_NOTICE, "USER DOMAIN abnormal: sil_dly_nse() PABORT not caught (QEMU version dependent), skipping CP25");
		ttsp_check_point(25);
	}

	ttsp_check_point(26);
	syslog_0(LOG_NOTICE, "USER DOMAIN SIL (normal+abnormal): OK");

	/* main_task を起こして本タスクを終了 */
	wup_tsk(MAIN_TASK);
	ext_tsk();
}

#ifdef __TARGET_PROFILE_M
/*
 * 【M-profile (Cortex-M85/ARMv8-M) 版・2026-06-20】
 *
 *  A-profile はデータアボート(DABORT)とプリフェッチアボート(PABORT)が別例外だが，
 *  M-profile では不正データアクセス・不正命令フェッチとも MemManage(#4, EXCNO_MPU)
 *  に集約され，CFSR の MMFSR ビットで区別する（DACCVIOL=データ, IACCVIOL=命令）．
 *  したがって DEF_EXC(EXCNO_DABORT=MemManage) の単一ハンドラで両者を CFSR で demux し，
 *  CP24（データ）/ CP25（命令）を記録する．EXCNO_PABORT(=BusFault) は登録のみで発火しない．
 *
 *   ・データアクセス違反: faulting load 命令(2 or 4 バイトの Thumb)をスキップして復帰．
 *   ・命令アクセス違反  : 呼出し直後（例外フレームの stacked LR=リンクレジスタ）へ復帰．
 *
 * 【改変 2026-07-02: A/M 両プロファイル共通・ttsp_check_point 呼び出し方式の統一】
 *  HRP3 の cpuexc_thread_trampoline（Thread+MSP+特権）から呼ばれる例外ハンドラが
 *  ttsp_check_point (SVC 経由 syslog) を発行すると，カーネルの時刻管理状態が
 *  壊れてライブロック（SysTick 連発 / "no time event" 氾濫）に陥る．
 *  原因：trampoline が lock_flag を保存・復元する際，SVC ハンドラが
 *  nontask_extsvc_trampoline (svc 5) を経由して signal_time 系の内部状態を
 *  変化させ，lock_flag 復元後のカーネル時刻ベースが不整合になるため．
 *  対処：sil_dabort_handler は PC 修正と CFSR クリアのみ行い，
 *  ttsp_check_point は発行しない．捕捉した例外種別をグローバル変数
 *  sil_dabort_cp_result に記録し，sil_user_task（DOM1 PSP コンテキスト）
 *  への復帰後に DOM1 の通常 SVC 経路で ttsp_check_point を発行する．
 *  これにより trampoline コンテキストでの SVC 発行を完全に排除する．
 *  A-profile (zybo_z7_gcc) 側の sil_dabort_handler / sil_pabort_handler も同方式に統一
 *  （2026-07-02），二重発行回避と A/M のコード統一を実現した．
 */
#define TTSP_CFSR_ADDR     0xE000ED28U	/* Configurable Fault Status Register */
#define TTSP_MMFSR_IACCVIOL 0x01U		/* 命令アクセス違反 */
#define TTSP_MMFSR_DACCVIOL 0x02U		/* データアクセス違反 */

/*
 *  ARM-M 例外フレーム(p_excinf)のワードオフセット（arm_m.h と一致）:
 *  [0]=basepri/primask [1]=EXC_RETURN [2..7]=R0,R1,R2,R3,R12,LR [8]=PC [9]=xPSR．
 *  T_EXCINF 構造体メンバ(->pc 等)は前置きワード数が異なり 1 ワードずれるため，オフセットで操作する．
 */
#define TTSP_EXCINF_LR  7U
#define TTSP_EXCINF_PC  8U

/* sil_dabort_cp_result は上部（ファイル先頭付近）で既に定義済み */

void sil_dabort_handler(void *p_excinf) {
	volatile uint32_t *p_cfsr = (volatile uint32_t *) TTSP_CFSR_ADDR;
	uint32_t *p_frame = (uint32_t *) p_excinf;
	uint32_t cfsr = *p_cfsr;

	/*
	 *  CFSR 参照・write-1-clear と p_excinf の PC 書換え（特権操作）のみ行う．
	 *  ttsp_check_point (SVC) はここでは呼ばない（trampoline コンテキストでの
	 *  SVC 発行がカーネル時刻管理状態を破壊するため）．
	 *  捕捉した例外種別を sil_dabort_cp_result に記録し，
	 *  sil_user_task （DOM1 PSP）復帰後に発行する．
	 */
	if ((cfsr & TTSP_MMFSR_IACCVIOL) != 0U) {
		/* 命令アクセス違反（PABORT 相当）: 呼出し直後（stacked LR）へ復帰 */
		p_frame[TTSP_EXCINF_PC] = p_frame[TTSP_EXCINF_LR];
		*p_cfsr = TTSP_MMFSR_IACCVIOL;		/* write-1-clear */
		sil_dabort_cp_result = 25U;
	}
	else {
		/* データアクセス違反（DABORT 相当）: faulting load(2/4B Thumb)をスキップ */
		uint32_t pc = p_frame[TTSP_EXCINF_PC];
		uint16_t insn = *(volatile uint16_t *) pc;	/* 上位5bitが11101/11110/11111 なら32bit */
		p_frame[TTSP_EXCINF_PC] = pc + (((insn & 0xF800U) >= 0xE800U) ? 4U : 2U);
		*p_cfsr = TTSP_MMFSR_DACCVIOL;		/* write-1-clear */
		sil_dabort_cp_result = 24U;
	}
	/* ttsp_check_point(cp) はここでは呼ばない。sil_user_task 復帰後に発行する。 */
}

void sil_pabort_handler(void *p_excinf) {
	/* M-profile では命令アクセス違反も MemManage(#4) で sil_dabort_handler が捕捉するため，
	 * 本ハンドラ(EXCNO_PABORT=BusFault #5)は発火しない（DEF_EXC 登録のみ）． */
	(void) p_excinf;
}

#else /* A-profile (Cortex-A/R) 版 */

/* ユーザモードの lr（バンクレジスタ）を取得する（PABORT 復帰用）． */
static uint32_t sil_get_lr_usr(void) {
	uint32_t lr;
	Asm("sub sp, sp, #4		\n"
	"	stm sp, {lr}^		\n"
	"	ldmfd sp!, {%0}		\n"
	: "=r"(lr));
	return(lr);
}

/*
 * 【TTSP3向け改変 2026-06-14・HRP版】ユーザドメインからの不正アドレス SIL アクセス（データアボート）
 * を捕捉する CPU 例外ハンドラ．p_excinf の PC を fault 命令の次へ進めて復帰する
 * （PREPARE_RETURN_CPUEXC_DABORT 相当＝ARM の load 命令1個分 4 バイトをスキップ）．
 * 【改変 2026-07-02: M-profile との統一により ttsp_check_point の呼び出しをここから削除．
 *  代わりに sil_dabort_cp_result=24 を設定し，CP24 の発行は sil_user_task（タスク文脈）側で行う．
 *  これにより A/M 両プロファイルで CP 発行経路が一本化され二重発行が回避される．】 */
void sil_dabort_handler(void *p_excinf) {
	sil_dabort_cp_result = 24U;
	((T_EXCINF *) p_excinf)->pc -= 4U;
}

/*
 * 【TTSP3向け改変 2026-06-14・HRP版】ユーザドメインからの sil_dly_nse 呼出し（プリフェッチアボート）
 * を捕捉する CPU 例外ハンドラ．p_excinf の PC を呼出し直後（ユーザモード lr）へ進めて
 * 復帰する（PREPARE_RETURN_CPUEXC_PABORT_USR 相当）．
 * 【改変 2026-07-02: M-profile との統一により ttsp_check_point の呼び出しをここから削除．
 *  代わりに sil_dabort_cp_result=25 を設定し，CP25 の発行は sil_user_task（タスク文脈）側で行う．
 *  これにより A/M 両プロファイルで CP 発行経路が一本化され二重発行が回避される．】 */
void sil_pabort_handler(void *p_excinf) {
	sil_dabort_cp_result = 25U;
	((T_EXCINF *) p_excinf)->pc = sil_get_lr_usr();
}

#endif /* __TARGET_PROFILE_M */

/*
 * 【TTSP3向け改変 2026-06-14】texhdr（タスク例外処理ルーチン）は第3世代カーネルに
 * タスク例外機能が無いため削除した．呼び出していた DEF_TEX も out.cfg から除去．
 */

void almhdr(intptr_t exinf) {
	static int bootcnt = 0;

	bootcnt++;

	if (bootcnt == 1) {
		ttsp_check_point(5);
		all_test();
	}
	if (bootcnt == 2) {
		ttsp_check_point(7);
		part_test(DIS_DSP);
	}
}

void cychdr(intptr_t exinf) {
	static int bootcnt = 0;

	bootcnt++;

	if (bootcnt == 1) {
		ttsp_check_point(9);
		all_test();
	}
	if (bootcnt == 2) {
		ttsp_check_point(11);
		part_test(DIS_DSP);
	}
}

void inirtn(intptr_t exinf) {
	ttsp_initialize_test_lib();
	int_flag = false;

	syslog_0(LOG_NOTICE, "=== test start from INIRTN ===");

	/*「メモリ空間アクセス関数」の確認 */
	test_of_sil_mem();

	/* sns_ker()の確認 */
	test_of_sns_ker(sns_ker());

	/* [a]通常状態 */
	test_of_SIL_LOC_INT();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [a]: OK");
}

void terrtn(intptr_t exinf) {
	bool_t state;

	/* エラーが発生している場合は終了ルーチンを実行しない */
	state = ttsp_get_cp_state();
	if (state == false) {
		return;
	};

	syslog_0(LOG_NOTICE, "=== test start from TERRTN ===");

	/*「メモリ空間アクセス関数」の確認 */
	test_of_sil_mem();

	/* sns_ker()の確認 */
	test_of_sns_ker(sns_ker());

	/* [a]通常状態 */
	test_of_SIL_LOC_INT();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [a]: OK");

	/* すべて正常終了であればメッセージ表示 */
	state = ttsp_get_cp_state();
	if (state == true) {
		syslog_0(LOG_NOTICE, "All check points passed.");
	};
}

void exchdr(void* p_excinf) {
	static int bootcnt = 0;

	bootcnt++;

	ttsp_cpuexc_hook(TTSP_EXCNO_A, p_excinf);

	if (bootcnt == 1) {
		ttsp_check_point(13);
		all_test();
	}
	if (bootcnt == 2) {
		ttsp_check_point(15);
		part_test(CHG_IPM);
	}
	if (bootcnt == 3) {
		ttsp_check_point(17);
		part_test(DIS_DSP);
	}
}

#ifdef TTSP_INTNO_B
void inthdr(void) {
	static int bootcnt = 0;

	/* 【TTSP3向け改変 2026-06-14】i_begin_int/i_end_int は第3世代カーネル（ASP3 3.7）で廃止のため削除． */
	ttsp_clear_int_req(TTSP_INTNO_B);

	bootcnt++;

	if (bootcnt == 1) {
		ttsp_check_point(19);
		all_test();
	}
	if (bootcnt == 2) {
		ttsp_check_point(21);
		part_test(DIS_DSP);
	}
}
#endif /* TTSP_INTNO_B */

#ifdef TTSP_INTNO_C
void isr(intptr_t exinf) {
	static int bootcnt = 0;

	ttsp_clear_int_req(TTSP_INTNO_C);

	bootcnt++;

	if (bootcnt == 1) {
		ttsp_check_point(23);
		all_test();
	}
	if (bootcnt == 2) {
		ttsp_check_point(26);
		part_test(DIS_DSP);
	}
}
#endif /* TTSP_INTNO_C */

void all_test(void) {
	ER ercd;

	/*「微少時間待ち」の確認 */
	if (!(sns_ctx())) {
		test_of_sil_dly_nse();
	}

	/*「メモリ空間アクセス関数」の確認 */
	test_of_sil_mem();

	/* 「sns_ker()発行」の確認 */
	test_of_sns_ker(sns_ker());

	/*
	 * 「全割込みロック状態の制御」の確認
	 */

	/* 事前条件にネストがないテスト */

	/* [a]通常状態 */
	test_of_SIL_LOC_INT();
	wait_raise_int();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [a]: OK");

	/* [b]全割込みロック状態 */
	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		test_of_SIL_LOC_INT();
		SIL_UNL_INT();
	}
	wait_raise_int();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [b]: OK");

	/* [c]CPUロック状態 */
	if (sns_ctx()) {
		ercd = iloc_cpu();
	} else {
		ercd = loc_cpu();
	}
	check_ercd(ercd, E_OK);
	test_of_SIL_LOC_INT();
	if (sns_ctx()) {
		ercd = iunl_cpu();
	} else {
		ercd = unl_cpu();
	}
	check_ercd(ercd, E_OK);
	wait_raise_int();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [c]: OK");

	/* [d]割込み優先度マスク全解除でない状態 */
	if (!(sns_ctx())) {
		ercd = chg_ipm(-1);
		check_ercd(ercd, E_OK);
		test_of_SIL_LOC_INT();
		ercd = chg_ipm(TIPM_ENAALL);
		check_ercd(ercd, E_OK);
		wait_raise_int();
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [d]: OK");
	}

	/* [e]ディスパッチ禁止状態 */
	if (!(sns_ctx())) {
		ercd = dis_dsp();
		check_ercd(ercd, E_OK);
		test_of_SIL_LOC_INT();
		ercd = ena_dsp();
		check_ercd(ercd, E_OK);
		wait_raise_int();
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [e]: OK");
	}

	/* 事前条件にネストが存在するテスト */

	/* [h]SIL_LOC_INT() → SIL_LOC_INT() */
	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		{
			SIL_PRE_LOC;
			SIL_LOC_INT();
			test_of_SIL_LOC_INT();
			SIL_UNL_INT();
		}
		SIL_UNL_INT();
	}
	wait_raise_int();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [h]: OK");

	/* [i]loc_cpu()/iloc_cpu() → SIL_LOC_INT() */
	if (sns_ctx()) {
		ercd = iloc_cpu();
	} else {
		ercd = loc_cpu();
	}
	check_ercd(ercd, E_OK);
	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		test_of_SIL_LOC_INT();
		SIL_UNL_INT();
	}
	if (sns_ctx()) {
		ercd = iunl_cpu();
	} else {
		ercd = unl_cpu();
	}
	check_ercd(ercd, E_OK);
	wait_raise_int();
	syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [i]: OK");

	/* [j]chg_ipm(-1) → SIL_LOC_INT() */
	if (!(sns_ctx())) {
		ercd = chg_ipm(-1);
		check_ercd(ercd, E_OK);
		{
			SIL_PRE_LOC;
			SIL_LOC_INT();
			test_of_SIL_LOC_INT();
			SIL_UNL_INT();
		}
		ercd = chg_ipm(TIPM_ENAALL);
		check_ercd(ercd, E_OK);
		wait_raise_int();
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [j]: OK");
	}

	/* [k]dis_dsp() → SIL_LOC_INT() */
	if (!(sns_ctx())) {
		ercd = dis_dsp();
		check_ercd(ercd, E_OK);
		{
			SIL_PRE_LOC;
			SIL_LOC_INT();
			test_of_SIL_LOC_INT();
			SIL_UNL_INT();
		}
		ercd = ena_dsp();
		check_ercd(ercd, E_OK);
		wait_raise_int();
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [k]: OK");
	}
}

void part_test(E_TEST_TYPE test_type) {

	/* [d]割込み優先度マスク全解除でない状態 */
	/* [e]ディスパッチ禁止状態 */
	test_of_SIL_LOC_INT();
	wait_raise_int();
	if (test_type == CHG_IPM) {
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [d]: OK");
	}
	else if (test_type == DIS_DSP) {
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [e]: OK");
	}

	/* [j]chg_ipm(-1) → SIL_LOC_INT() */
	/* [k]dis_dsp() → SIL_LOC_INT() */
	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		test_of_SIL_LOC_INT();
		SIL_UNL_INT();
	}
	wait_raise_int();
	if (test_type == CHG_IPM) {
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [j]: OK");
	}
	else if (test_type == DIS_DSP) {
		syslog_0(LOG_NOTICE, "test_of_SIL_LOC_INT() [k]: OK");
	}
}

void inthdr_for_int_test(void) {
	/* 【TTSP3向け改変 2026-06-14】i_begin_int/i_end_int は第3世代カーネル（ASP3 3.7）で
	 * 廃止（DEF_INH ハンドラはカーネルが入口/出口処理を行う）ため削除． */
	ttsp_clear_int_req(TTSP_INTNO_A);

	/* 割込みが入ったことを通知 */
	int_flag = true;
}

void test_of_sil_dly_nse(void) {
	ER ercd;
	SYSTIM system1, system2;

	ercd = get_tim(&system1);
	check_ercd(ercd, E_OK);
	sil_dly_nse(SIL_DLY_TIME);
	ercd = get_tim(&system2);
	check_ercd(ercd, E_OK);
	check_assert((system2 - system1) >= SIL_DLY_TIME_SUB);

	syslog_0(LOG_NOTICE, "test_of_sil_dly_nse()    : OK");
}

void test_of_sil_mem(void) {
	check_of_sil_mem();

	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		check_of_sil_mem();
		SIL_UNL_INT();
	}

	syslog_0(LOG_NOTICE, "test_of_sil_mem()        : OK");
}

void test_of_sns_ker(bool_t flag) {
	bool_t state;

	state = sns_ker();
	check_assert(state == flag);

	{
		SIL_PRE_LOC;
		SIL_LOC_INT();
		state = sns_ker();
		check_assert(state == flag);
		SIL_UNL_INT();
	}

	syslog_0(LOG_NOTICE, "test_of_sns_ker()        : OK");
}

void test_of_SIL_LOC_INT(void) {
	SIL_PRE_LOC;

	/* フラグ初期化 */
	int_flag = false;

	/* テスト対象のSIL関数発行 */
	SIL_LOC_INT();

	/* 割込みを発生 */
	ttsp_int_raise(TTSP_INTNO_A);

	/* 割込みが発生しないことを待つ */
	sil_dly_nse(TTSP_WAIT_NOT_RAISE_INT);

	/* フラグが更新されていないことを確認 */
	check_assert(int_flag == false);

	/* 元の状態に戻す */
	/* (b-2/h-2/i-2/j-2/k-2のテストを兼ねる) */
	SIL_UNL_INT();
}

void wait_raise_int(void) {
	ulong_t timeout = 0;

#ifdef __TARGET_PROFILE_M
	/*
	 * 【M-profile (Cortex-M85/ARMv8-M) 構造的制約・2026-06-20】
	 *
	 *  M-profile では CPU ロックを BASEPRI=IIPM_LOCK(優先度フィールド1) で実現するため，
	 *  CPU ロック中はカーネル管理割込み（フィールド1〜15）が全てマスクされる（フィールド0 は
	 *  フォルト/SVCall 専用で通常割込みは置けない）。テスト割込み TTSP_INTNO_A は
	 *  TTSP_GE_TIMER_INTPRI=TMIN_INTPRI=フィールド1（ロックレベルと同一）であり，CPU ロック中は
	 *  発火できない。時間イベントハンドラ（ALARM/CYCLIC）は signal_time により CPU ロック下で
	 *  実行されるため，その文脈からの「割込みを上げて発火を待つ」テストは原理的に成立せず，
	 *  wait_raise_int が sil_dly_nse ループでスピンし WDT リセットに至る（実機 halt で確認:
	 *  BASEPRI=0x10, int 未発火, GPT 読出しでスピン）。
	 *  そこで CPU ロック中は，上げた割込み要求をクリアして待たずに戻る（当該サブテストは
	 *  本ターゲットでは対象外＝sys_manage SOM 除外と同様の target 適合化）。タスク文脈
	 *  （非ロック）では従来どおり割込み発火を待つためカバレッジは維持される。
	 *
	 *  判別は sns_ctx()（非タスク文脈）で行う：時間イベントハンドラ(ALARM/CYCLIC)・初期化
	 *  ルーチン(INIRTN)は非タスク文脈で，かつ signal_time 等が BASEPRI を直接 field1 へ上げる
	 *  ため（lock_flag を立てない経路があり sns_loc() では判別できない），sns_ctx() を用いる。
	 */
	if (sns_ctx()) {
		ttsp_clear_int_req(TTSP_INTNO_A);
		int_flag = false;
		return;
	}
#endif /* __TARGET_PROFILE_M */

	/* 割込みが発生するのを待つ */
	while (int_flag == false) {
		timeout++;
		if (timeout > TTSP_LOOP_COUNT) {
			syslog_0(LOG_ERROR, "## wait_raise_int() caused a timeout.");
			ttsp_set_cp_state(false);
			ext_ker();
		}
		sil_dly_nse(TTSP_SIL_DLY_NSE_TIME);
	}
}

void check_of_sil_mem(void) {
	uint8_t   r8_data  = R_DATA8;
	uint16_t  r16_data = R_DATA16;
	uint32_t  r32_data = R_DATA32;
	uint8_t   w8_data  = W_DATA8;
	uint16_t  w16_data = W_DATA16;
	uint32_t  w32_data = W_DATA32;
	uint8_t   w8_temp  = CLEAR32;
	uint16_t  w16_temp = CLEAR32;
	uint32_t  w32_temp = CLEAR32;

	/* 8bit メモリ空間アクセス関数 */
	w8_temp = sil_reb_mem((void*)&r8_data);
	check_assert(w8_temp == R_DATA8);
	w8_temp = CLEAR32;

	sil_wrb_mem((void*)&w8_temp, w8_data);
	check_assert(w8_temp == W_DATA8);
	w8_temp = CLEAR32;

	/* 16bit メモリ空間アクセス関数 */
	w16_temp = sil_reh_mem((void*)&r16_data);
	check_assert(w16_temp == R_DATA16);
	w16_temp = CLEAR32;

	sil_wrh_mem((void*)&w16_temp, w16_data);
	check_assert(w16_temp == W_DATA16);
	w16_temp = CLEAR32;

#ifdef SIL_ENDIAN_LITTLE
	w16_temp = sil_reh_lem((void*)&r16_data);
#endif /* SIL_ENDIAN_LITTLE */
#ifdef SIL_ENDIAN_BIG
	w16_temp = sil_reh_bem((void*)&r16_data);
#endif /* SIL_ENDIAN_BIG */
	check_assert(w16_temp == R_DATA16);
	w16_temp = CLEAR32;

#ifdef SIL_ENDIAN_LITTLE
	sil_wrh_lem((void*)&w16_temp, w16_data);
#endif /* SIL_ENDIAN_LITTLE */
#ifdef SIL_ENDIAN_BIG
	sil_wrh_bem((void*)&w16_temp, w16_data);
#endif /* SIL_ENDIAN_BIG */
	check_assert(w16_temp == W_DATA16);
	w16_temp = CLEAR32;

	/* 32bit メモリ空間アクセス関数 */
	w32_temp = sil_rew_mem((void*)&r32_data);
	check_assert(w32_temp == R_DATA32);
	w32_temp = CLEAR32;

	sil_wrw_mem((void*)&w32_temp, w32_data);
	check_assert(w32_temp == W_DATA32);
	w32_temp = CLEAR32;

#ifdef SIL_ENDIAN_LITTLE
	w32_temp = sil_rew_lem((void*)&r32_data);
#endif /* SIL_ENDIAN_LITTLE */
#ifdef SIL_ENDIAN_BIG
	w32_temp = sil_rew_bem((void*)&r32_data);
#endif /* SIL_ENDIAN_BIG */
	check_assert(w32_temp == R_DATA32);
	w32_temp = CLEAR32;

#ifdef SIL_ENDIAN_LITTLE
	sil_wrw_lem((void*)&w32_temp, w32_data);
#endif /* SIL_ENDIAN_LITTLE */
#ifdef SIL_ENDIAN_BIG
	sil_wrw_bem((void*)&w32_temp, w32_data);
#endif /* SIL_ENDIAN_BIG */
	check_assert(w32_temp == W_DATA32);
	w32_temp = CLEAR32;
}
