/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2020 by FUJI SOFT INCORPORATED
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
 *  $Id: ttsp_target_test.h 72 2020-03-19 08:08:03Z fujisft-shigihara $
 */

/*
 *		テストプログラムのチップ依存定義（zybo_gcc用）
 */

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

#include "out.h"

/*
 *  ターゲットシステムのハードウェア資源の定義
 */

/*
 *  CPU例外を発生させる命令
 */
#define RAISE_CPU_EXCEPTION     Asm(".long 0x06000010");

/*
 *  TTSP3用の定義
 */

/*
 *  タスクのスタックサイズ
 */
#define TTSP_TASK_STACK_SIZE	4096

/*
 *  非タスクコンテキストのスタックサイズ
 *  (DEF_ICSのテストでのみ使用する)
 */
#define TTSP_NON_TASK_STACK_SIZE	2048

/*
 *  拡張サービスコールのスタックサイズ
 */
#define TTSP_SVC_STACK_SIZE	512

/*
 *  関数の先頭番地として不正な番地
 */
#define TTSP_INVALID_FUNC_ADDRESS	0x123456

/*
 *  スタック領域として不正な番地
 */
#define TTSP_INVALID_STK_ADDRESS	0x123456

/*
 *  固定長メモリープールの先頭番地として不正な番地
 */
#define TTSP_INVALID_MPF_ADDRESS	0x123456

/*
 *  変数の先頭番地として不正な番地
 */
#define TTSP_INVALID_VAR_ADDRESS  0x123456

/*
 *  メモリアクセス違反発生番地(P1領域)
 */
#define TTSP_MACV_ADDRESS	0x80000000

/*
 *  スタックサイズとして不正なサイズ
 */
#define TTSP_INVALID_STACK_SIZE	0x01

/*
 *  ターゲット定義の拡張後の割込み優先度最小値
 */
#define TTSP_TMIN_INTPRI	TMIN_INTPRI

/*
 *  割込み優先度定義
 */
#define TTSP_GE_TIMER_INTPRI  TMIN_INTPRI	/* タイマ割込みの割込み優先度より高い割込み優先度 */
#define TTSP_HIGH_INTPRI      -5			/* 割込み優先度高 */
#define TTSP_MID_INTPRI       -4			/* 割込み優先度中 */
#define TTSP_LOW_INTPRI       -3			/* 割込み優先度低 */

/*
 *  割込み番号(正常値)
 *   private_intno_list = [ *(0..31) ]
 *   global_intno_list = [ *(32..95) ]
 *
 *  Note: don't use interrupts that are already used by devices
 *   INTNO_TIMER_PRC1           : (0x10000U | MPCORE_IRQNO_GTC)    : MPCORE_IRQNO_GTC	27
 *   INTNO_TIMER_PRC2           : (0x20000U | MPCORE_IRQNO_GTC)    : MPCORE_IRQNO_GTC	27
 *   INTNO_IPI_DISPATCH_PRC1    : (0x00010000 | IPINO_DISPATCH)    : IPINO_DISPATCH		0
 *   INTNO_IPI_DISPATCH_PRC2    : (0x00020000 | IPINO_DISPATCH)    : IPINO_DISPATCH		0
 *   INTNO_IPI_EXT_KER_PRC1     : (0x00010000 | IPINO_EXT_KER)     : IPINO_EXT_KER		1
 *   INTNO_IPI_EXT_KER_PRC2     : (0x00020000 | IPINO_EXT_KER)     : IPINO_EXT_KER		1
 *   INTNO_IPI_SET_HRT_EVT_PRC1 : (0x00010000 | IPINO_SET_HRT_EVT) : IPINO_SET_HRT_EVT	2
 *   INTNO_IPI_SET_HRT_EVT_PRC2 : (0x00020000 | IPINO_SET_HRT_EVT) : IPINO_SET_HRT_EVT	2
 *   INTNO_SIO                  : ZYNQ_UART1_IRQ                   : ZYNQ_UART1_IRQ		82
 */
#define TTSP_INTNO_A      (0x10000|0x0010)      /* PE1割込み番号A */
#define TTSP_INTNO_B      (0x10000|0x0011)      /* PE1割込み番号B */
#define TTSP_INTNO_C      (0x10000|0x0012)      /* PE1割込み番号C */
#define TTSP_INTNO_D      (0x10000|0x0013)      /* PE1割込み番号D */
#define TTSP_INTNO_E      (0x10000|0x0014)      /* PE1割込み番号E */
#define TTSP_INTNO_F      (0x10000|0x0015)      /* PE1割込み番号F */

#define TTSP_INTNO_PE2_A  (0x20000|0x0010)      /* PE2割込み番号A */
#define TTSP_INTNO_PE2_B  (0x20000|0x0011)      /* PE2割込み番号B */
#define TTSP_INTNO_PE2_C  (0x20000|0x0012)      /* PE2割込み番号C */
#define TTSP_INTNO_PE2_D  (0x20000|0x0013)      /* PE2割込み番号D */
#define TTSP_INTNO_PE2_E  (0x20000|0x0014)      /* PE2割込み番号E */
#define TTSP_INTNO_PE2_F  (0x20000|0x0015)      /* PE2割込み番号F */

#define TTSP_GLOBAL_IRC_INTNO_A  0x0020         /* グローバルIRC用割込み番号A */
#define TTSP_GLOBAL_IRC_INTNO_B  0x0021         /* グローバルIRC用割込み番号B */
#define TTSP_GLOBAL_IRC_INTNO_C  0x0022         /* グローバルIRC用割込み番号C */
#define TTSP_GLOBAL_IRC_INTNO_D  0x0023         /* グローバルIRC用割込み番号D */
#define TTSP_GLOBAL_IRC_INTNO_E  0x0024         /* グローバルIRC用割込み番号E */
#define TTSP_GLOBAL_IRC_INTNO_F  0x0025         /* グローバルIRC用割込み番号F */

/*
 *  ティック更新用割込み
 *
 *  HRMP3対応（FMPと同じ修正）．0x001e（PPI: ウォッチドッグ）から
 *  0x0004（SGI 4）に変更．gicd_raise_sgi()/raise_int() はプロセッサ間割込みとして
 *  SGI（INTID 0〜15）のみ発行可能で，PPIを指定すると GICD_SGIR のINTIDフィールド
 *  （4bit）で折り返され SGI 14 が誤発火し，「Unregistered interrupt occurs.」で
 *  ティック更新を伴うテスト（alarm/cyclic/timer 等）が全滅していた．カーネルは
 *  SGI 0〜2（dispatch/ext_ker/set_hrt_evt）を使用するため空きの SGI 4 を選定．
 */
#define TTSP_IPI_INTPRI -16
#define TTSP_IPI_INTNO 0x0004
#define TTSP_IPI_INTNO_PRC1 (0x10000|TTSP_IPI_INTNO)
#define TTSP_IPI_INTNO_PRC2 (0x20000|TTSP_IPI_INTNO)

/*
 *  割込みハンドラ番号(正常値)
 */
#define TTSP_INHNO_A       TTSP_INTNO_A      /* PE1割込みハンドラ番号A */
#define TTSP_INHNO_B       TTSP_INTNO_B      /* PE1割込みハンドラ番号B */
#define TTSP_INHNO_C       TTSP_INTNO_C      /* PE1割込みハンドラ番号C */

#define TTSP_INHNO_PE2_A   TTSP_INTNO_PE2_A  /* PE2割込みハンドラ番号A */
#define TTSP_INHNO_PE2_B   TTSP_INTNO_PE2_B  /* PE2割込みハンドラ番号B */
#define TTSP_INHNO_PE2_C   TTSP_INTNO_PE2_C  /* PE2割込みハンドラ番号C */

/*
 *  割込み番号(異常値)
 */
#define TTSP_INVALID_INTNO       0x10100  /* PE1ターゲットでサポートしていない割込み番号 (0x100 > 0x5F) */
#define TTSP_INVALID_INTNO_PE2   0x20100  /* PE2ターゲットでサポートしていない割込み番号 (0x100 > 0x5F) */
#define TTSP_NOT_SET_INTNO       0x1001f  /* PE1割込み要求ラインに対して割込み属性が設定されていない割込み番号 */
#define TTSP_NOT_SET_INTNO_PE2   0x2001f  /* PE2割込み要求ラインに対して割込み属性が設定されていない割込み番号 */
#define TTSP_NOT_SELF_INTNO_PE1  0x20032  /* PE1上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x10001) */
#define TTSP_NOT_SELF_INTNO_PE2  0x10032  /* PE2上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x20001) */

/*
 *  割込みハンドラ番号(異常値)
 */
#define TTSP_INVALID_INHNO  -1
#define TTSP_GLOBAL_IRC_INHNO_A  TTSP_GLOBAL_IRC_INTNO_A        /* グローバルIRC用割込みハンドラ番号A */
#define TTSP_GLOBAL_IRC_INHNO_B  TTSP_GLOBAL_IRC_INTNO_B        /* グローバルIRC用割込みハンドラ番号B */
#define TTSP_GLOBAL_IRC_INHNO_C  TTSP_GLOBAL_IRC_INTNO_C        /* グローバルIRC用割込みハンドラ番号C */

/*
 *  CPU例外ハンドラ番号(正常値)
 */
#define TTSP_EXCNO_A      (0x10000|EXCNO_UNDEF)       /* CPU例外発生元のコンテキストへreturn可能(未定義命令) */
#define TTSP_EXCNO_B      (0x10000|EXCNO_SVC)         /* 本番号でCPU例外を発生させるテストケースはない(SVC) */
#define TTSP_EXCNO_PE2_A  (0x20000|EXCNO_UNDEF)       /* PE2未定義命令 */
#define TTSP_EXCNO_PE2_B  (0x20000|EXCNO_SVC)         /* PE2SVC */

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  100

/*
 *  有効範囲外のクラス
 */
#define TTSP_INVALID_PRC_CLASS  5

/*
 *  タイムアウト用変数
 *  [sil_dly_nse(TTSP_SIL_DLY_NSE_TIME) * TTSP_LOOP_COUNT]
 *  ※シミュレータのため体感的に適度な設定とする
 */
#define TTSP_SIL_DLY_NSE_TIME  100000
#define TTSP_LOOP_COUNT        2000000

/*
 *  fch_hrtで取得するカウント値のシステム時間に対する係数
 */
#define TTSP_MOD_FCH_CNT 1

/*
 * アライン指定宣言マクロ
 */
#define TTSP_DEFINE_VAR_SECTION(type, var, sec)	type var __attribute__((section(sec)));

/*
 * 標準RAMリージョン名
 */
#define TTSP_STANDARD_RAM_REGION	"DDR"

/*
 *  TTSP3用の関数
 */

/*
 *  ティック更新の停止
 */
extern void ttsp_target_stop_tick(void);

/*
 *  ティック更新の再開
 */
extern void ttsp_target_start_tick(void);

/*
 *  ティックの更新
 */
extern void ttsp_target_gain_tick(void);

/*
 *  ティックの更新(各プロセッサに入れるコア間割込み)
 */
extern void ttsp_target_gain_tick_ipi(void);

/*
 *  割込みの発生
 */
extern void ttsp_int_raise(INTNO intno);

/*
 *  割込み要求のクリア
 */
extern void ttsp_clear_int_req(INTNO intno);

/*
 *  CPU例外の発生
 */
extern void ttsp_cpuexc_raise(EXCNO excno);

/*
 *  CPU例外発生時のフック処理
 */
extern void ttsp_cpuexc_hook(EXCNO excno, void *p_excinf);


/* ユーザドメインタスク用スタック */
#ifdef TTSP_STACK_SHARE_HRP
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack_prc1[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC1");
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack_prc2[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC2");
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack_prc1[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section_CLS_ALL_PRC1");
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack_prc2[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section_CLS_ALL_PRC2");
#endif /* TTSP_STACK_SHARE_HRP */

/* DEF_ICSテスト用 */
extern TTSP_DEFINE_VAR_SECTION(STK_T, nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC1");
extern TTSP_DEFINE_VAR_SECTION(STK_T, nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack_CLS_ALL_PRC2");


/*
 *  割込を許可しないロックの取得
 */
#define acquire_glock_wo_preempt()	acquire_lock_wo_preemption(&giant_lock)
Inline void
acquire_lock_wo_preemption(LOCK *p_lock)
{
	uint32_t	locked;

	while (true) {
		Asm("mov	r2, #1			\n"
		"	ldrex	r1, [%1]		\n"
		"	cmp		r1, #0			\n"
#ifndef TOPPERS_OMIT_USE_WFE
		"	wfene					\n"
#endif /* TOPPERS_OMIT_USE_WFE */
		"	strexeq	r1, r2, [%1]	\n"
		"	mov		%0, r1			\n"
		: "=r"(locked) : "r"(p_lock) : "r1","r2","cc");

		if (locked == 0U) {
			/* ロック取得成功 */
			CP15_DATA_MEMORY_BARRIER();
			Asm("":::"memory");
			return;
		}
	}
}

#endif /* TTSP_TARGET_TEST_H */
