/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2012 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
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
 *  $Id: ttsp_target_test.h 36 2019-03-18 06:16:26Z fujisft-shigihara $
 */

/*
 * テストプログラムのチップ依存定義（imx8mm_evk用）
 */

#include "chip_timer.h"

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

/*
 *  CPU例外を発生させる命令
 */
#if 0
/* ロードエラー例外 */
#define RAISE_CPU_EXCEPTION	(*((volatile int *) 0xFFFFFEC1U));\
								Asm("isb":::"memory") 
#endif
#define RAISE_CPU_EXCEPTION	Asm("svc #0xF000")

/*
 *  TTSP3用の定義
 */

/*
 *  タスクのスタックサイズ
 */
#define TTSP_TASK_STACK_SIZE  2048

/*
 *  非タスクコンテキストのスタックサイズ
 *  (DEF_ICSのテストでのみ使用する)
 */
#define TTSP_NON_TASK_STACK_SIZE  2048

/*
 *  関数の先頭番地として不正な番地
 */
#define TTSP_INVALID_FUNC_ADDRESS  0x123456

/*
 *  スタック領域として不正な番地
 */
#define TTSP_INVALID_STK_ADDRESS  0x123456

/*
 *  固定長メモリープールの先頭番地として不正な番地
 */
#define TTSP_INVALID_MPF_ADDRESS  0x123456

/*
 *  変数の先頭番地として不正な番地
 */
#define TTSP_INVALID_VAR_ADDRESS  0x123456

/*
 *  スタックサイズとして不正なサイズ
 */
#define TTSP_INVALID_STACK_SIZE  0x01

/*
 *  ターゲット定義の拡張後の割込み優先度最小値
 */
#define TTSP_TMIN_INTPRI  TMIN_INTPRI

/*
 *  割込み優先度定義
 */
#define TTSP_GE_TIMER_INTPRI  TMIN_INTPRI /* タイマ割込みの割込み優先度より高い割込み優先度 */
#ifdef TOPPERS_TZ_S
#define TTSP_HIGH_INTPRI  -5              /* 割込み優先度高 */
#define TTSP_MID_INTPRI   -4              /* 割込み優先度中 */
#define TTSP_LOW_INTPRI   -3              /* 割込み優先度低 */
#else
#define TTSP_HIGH_INTPRI  -21              /* 割込み優先度高 */
#define TTSP_MID_INTPRI   -20              /* 割込み優先度中 */
#define TTSP_LOW_INTPRI   -19              /* 割込み優先度低 */
#endif


/*
 *  Interrupt numbers (valid numbers)
 *
 *  Note: don't use interrupts that are already used by devices
 *      IPI: S : 12, 13, 14, 15
 *           NS: 0, 1, 2, 3
 *      Global timer: 27(0x1b)
 *      UART2: 59(0x3b)
 *      UART3: 60(0x3c)
 */
#define TTSP_INTNO_A      (0x10000|0x00010)     /* PE1割込み番号A */
#define TTSP_INTNO_B      (0x10000|0x00011)     /* PE1割込み番号B */
#define TTSP_INTNO_C      (0x10000|0x00012)     /* PE1割込み番号C */
#define TTSP_INTNO_D      (0x10000|0x00013)     /* PE1割込み番号D */
#define TTSP_INTNO_E      (0x10000|0x00014)     /* PE1割込み番号E */
#define TTSP_INTNO_F      (0x10000|0x00015)     /* PE1割込み番号F */

#define TTSP_INTNO_PE2_A  (0x20000|0x00010)     /* PE2割込み番号A */
#define TTSP_INTNO_PE2_B  (0x20000|0x00011)     /* PE2割込み番号B */
#define TTSP_INTNO_PE2_C  (0x20000|0x00012)     /* PE2割込み番号C */
#define TTSP_INTNO_PE2_D  (0x20000|0x00013)     /* PE2割込み番号D */
#define TTSP_INTNO_PE2_E  (0x20000|0x00014)     /* PE2割込み番号E */
#define TTSP_INTNO_PE2_F  (0x20000|0x00015)     /* PE2割込み番号F */

#define TTSP_INTNO_PE3_A  (0x30000|0x00010)     /* PE3割込み番号A */
#define TTSP_INTNO_PE3_B  (0x30000|0x00011)     /* PE3割込み番号B */
#define TTSP_INTNO_PE3_C  (0x30000|0x00012)     /* PE3割込み番号C */
#define TTSP_INTNO_PE3_D  (0x30000|0x00013)     /* PE3割込み番号D */
#define TTSP_INTNO_PE3_E  (0x30000|0x00014)     /* PE3割込み番号E */
#define TTSP_INTNO_PE3_F  (0x30000|0x00015)     /* PE3割込み番号F */

#define TTSP_INTNO_PE4_A  (0x40000|0x00010)     /* PE4割込み番号A */
#define TTSP_INTNO_PE4_B  (0x40000|0x00011)     /* PE4割込み番号B */
#define TTSP_INTNO_PE4_C  (0x40000|0x00012)     /* PE4割込み番号C */
#define TTSP_INTNO_PE4_D  (0x40000|0x00013)     /* PE4割込み番号D */
#define TTSP_INTNO_PE4_E  (0x40000|0x00014)     /* PE4割込み番号E */
#define TTSP_INTNO_PE4_F  (0x40000|0x00015)     /* PE4割込み番号F */

#define TTSP_GLOBAL_IRC_INTNO_A  0x00004        /* グローバルIRC用割込み番号A */
#define TTSP_GLOBAL_IRC_INTNO_B  0x00005        /* グローバルIRC用割込み番号B */
#define TTSP_GLOBAL_IRC_INTNO_C  0x00006        /* グローバルIRC用割込み番号C */
#define TTSP_GLOBAL_IRC_INTNO_D  0x00007        /* グローバルIRC用割込み番号D */
#define TTSP_GLOBAL_IRC_INTNO_E  0x00008        /* グローバルIRC用割込み番号E */
#define TTSP_GLOBAL_IRC_INTNO_F  0x00009        /* グローバルIRC用割込み番号F */



/*
 *  割込みハンドラ番号(正常値)
 */
#define TTSP_INHNO_A        TTSP_INTNO_A        /* PE1割込みハンドラ番号A */
#define TTSP_INHNO_B        TTSP_INTNO_B        /* PE1割込みハンドラ番号B */
#define TTSP_INHNO_C        TTSP_INTNO_C        /* PE1割込みハンドラ番号C */

#define TTSP_INHNO_PE2_A    TTSP_INTNO_PE2_A    /* PE2割込みハンドラ番号A */
#define TTSP_INHNO_PE2_B    TTSP_INTNO_PE2_B    /* PE2割込みハンドラ番号B */
#define TTSP_INHNO_PE2_C    TTSP_INTNO_PE2_C    /* PE2割込みハンドラ番号C */

#define TTSP_INHNO_PE3_A    TTSP_INTNO_PE3_A    /* PE2割込みハンドラ番号A */
#define TTSP_INHNO_PE3_B    TTSP_INTNO_PE3_B    /* PE2割込みハンドラ番号B */
#define TTSP_INHNO_PE3_C    TTSP_INTNO_PE3_C    /* PE2割込みハンドラ番号C */

#define TTSP_INHNO_PE4_A    TTSP_INTNO_PE4_A    /* PE2割込みハンドラ番号A */
#define TTSP_INHNO_PE4_B    TTSP_INTNO_PE4_B    /* PE2割込みハンドラ番号B */
#define TTSP_INHNO_PE4_C    TTSP_INTNO_PE4_C    /* PE2割込みハンドラ番号C */

/*
 *  Interrupt numbers (invalid numbers)
 */
#define TTSP_INVALID_INTNO       0x10100  /* PE1ターゲットでサポートしていない割込み番号 (0x100 > 0xFF) */
#define TTSP_INVALID_INTNO_PE2   0x20100  /* PE2ターゲットでサポートしていない割込み番号 (0x100 > 0xFF) */
#define TTSP_INVALID_INTNO_PE3   0x30100  /* PE1ターゲットでサポートしていない割込み番号 (0x100 > 0xFF) */
#define TTSP_INVALID_INTNO_PE4   0x40100  /* PE2ターゲットでサポートしていない割込み番号 (0x100 > 0xFF) */
#define TTSP_NOT_SET_INTNO       0x10016  /* PE1割込み要求ラインに対して割込み属性が設定されていない割込み番号 (IRQ16=0x16 not used) */
#define TTSP_NOT_SET_INTNO_PE2   0x20016  /* PE2割込み要求ラインに対して割込み属性が設定されていない割込み番号 (IRQ16=0x16 not used) */
#define TTSP_NOT_SET_INTNO_PE3   0x30016  /* PE2割込み要求ラインに対して割込み属性が設定されていない割込み番号 (IRQ16=0x16 not used) */
#define TTSP_NOT_SET_INTNO_PE4   0x40016  /* PE2割込み要求ラインに対して割込み属性が設定されていない割込み番号 (IRQ16=0x16 not used) */
#define TTSP_NOT_SELF_INTNO_PE1  0x40016  /* PE1上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x10016) */
#define TTSP_NOT_SELF_INTNO_PE2  0x30016  /* PE2上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x20016) */
#define TTSP_NOT_SELF_INTNO_PE3  0x20016  /* PE1上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x30016) */
#define TTSP_NOT_SELF_INTNO_PE4  0x10016  /* PE2上位ビットが発行元プロセッサIDと異なる割込み番号 (should be 0x40016) */

/*
 *  割込みハンドラ番号(異常値)
 */
#define TTSP_INVALID_INHNO  -1
#define TTSP_GLOBAL_IRC_INHNO_A  TTSP_GLOBAL_IRC_INTNO_A        /* グローバルIRC用割込みハンドラ番号A */
#define TTSP_GLOBAL_IRC_INHNO_B  TTSP_GLOBAL_IRC_INTNO_B        /* グローバルIRC用割込みハンドラ番号 */
#define TTSP_GLOBAL_IRC_INHNO_C  TTSP_GLOBAL_IRC_INTNO_C        /* グローバルIRC用割込みハンドラ番号C */

/*
 *  CPU例外ハンドラ番号(正常値)
 */
#define TTSP_EXCNO_A      (0x10000|EXCNO_CUR_SPX_SYNC)    /* 同期例外 */
#define TTSP_EXCNO_B      (0x10000|EXCNO_CUR_SPX_SYNC)    /* 本番号で例外を発生させるテストケースはない   */
#define TTSP_EXCNO_PE2_A  (0x20000|EXCNO_CUR_SPX_SYNC)    /* 同期例外 */
#define TTSP_EXCNO_PE2_B  (0x20000|EXCNO_CUR_SPX_SYNC)    /* 本番号で例外を発生させるテストケースはない   */
#define TTSP_EXCNO_PE3_A  (0x30000|EXCNO_CUR_SPX_SYNC)    /* 同期例外 */
#define TTSP_EXCNO_PE3_B  (0x30000|EXCNO_CUR_SPX_SYNC)    /* 本番号で例外を発生させるテストケースはない   */
#define TTSP_EXCNO_PE4_A  (0x40000|EXCNO_CUR_SPX_SYNC)    /* 同期例外 */
#define TTSP_EXCNO_PE4_B  (0x40000|EXCNO_CUR_SPX_SYNC)    /* 本番号で例外を発生させるテストケースはない   */

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  300

/*
 *  有効範囲外のクラス
 */
#define TTSP_INVALID_PRC_CLASS  9

/*
 *  テスト用の関数
 */

/*
 *  各同期処理のタイムアウト用変数
 *  [sil_dly_nse(TTSP_SIL_DLY_NSE_TIME) * TTSP_LOOP_COUNT]
 */
/* 10マイクロ秒 * 6,000,00回 = 6秒 */
#define TTSP_SIL_DLY_NSE_TIME  10000
#define TTSP_LOOP_COUNT        600000


/*
 *  fch_hrtで取得するカウント値のシステム時間に対する係数
 */
#define TTSP_MOD_FCH_CNT 1


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
 *  (グローバルタイマ方式扱いとする)
 */
extern void ttsp_target_gain_tick(void);

/*
 *  割込みの発生
 */
extern void ttsp_int_raise(INTNO intno);

/*
 *  CPU例外の発生
 */
extern void ttsp_cpuexc_raise(EXCNO excno);

/*
 *  CPU例外発生時のフック処理
 */
extern void ttsp_cpuexc_hook(EXCNO excno, void* p_excinf);

/*
 *  割込み要求のクリア
 */
extern void ttsp_clear_int_req(INTNO intno);

/* DEF_ICSテスト用 */
extern STK_T nontask1_stack[TTSP_NON_TASK_STACK_SIZE];
extern STK_T nontask2_stack[TTSP_NON_TASK_STACK_SIZE];


/*
 *  割込を許可しないロックの取得
 */
#define acquire_glock_wo_preempt()	acquire_lock_wo_preemption(&giant_lock)
Inline void
acquire_lock_wo_preemption(LOCK *p_lock)
{
	uint32_t locked;
	ID       prcid;

	sil_get_pid(&prcid);    /*  プロセッサID取得    */

	while (true) {
		/*
		 * スピンロックの取得
		 * プロセッサIDを書き込む
		 */
		Asm("   mov   x2, %2    \n"
			"\t ldxr  w1, [%1]     \n"
			"\t cmp   w1, #0x00    \n"
			"\t b.eq  1f           \n"
			"\t wfe                \n"
			"\t b     2f           \n"
			"\t 1:                 \n"
			"\t stxr  w1, w2, [%1] \n"
			"\t 2:                 \n"
			"\t mov   %0, x1       \n"
			:"=r"(locked)               /*  %0      出力オペランド  */
			:"r"(p_lock), "r"(prcid)    /*  %1 %2   入力オペランド  */
			:"x1", "x2", "cc");   /*  破壊レジスタ    */

		if (locked == 0) {
			/* スピンロックが取得成功 */
			/* Data meory barrier */
			Asm("dmb sy");
			Asm("":::"memory");
			return;
		}
	}

}

#endif /* TTSP_TARGET_TEST_H */
