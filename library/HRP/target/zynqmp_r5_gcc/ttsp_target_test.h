/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
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
 *  $Id: ttsp_target_test.h 70 2020-02-04 09:29:02Z fujisft-shigihara $
 */

/*
 *		テストプログラムのチップ依存定義（zybo_gcc用）
 */

/*
 *  [改変] 2026-06-12: zybo_z7_gcc版をベースに，HRP3のZynqMP Cortex-R5
 *  （zynqmp_r5_gcc）ターゲット向けに新規作成．割込み番号・例外番号は
 *  GIC（SPI 0x20〜）構成のため同一．
 */
#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

#include "out.h"

/*
 *  ターゲットシステムのハードウェア資源の定義
 */

/*
 *  CPU例外を発生させる命令
 *
 *  GCOV計装ビルド対応のため "teq r0, r0" を前置して Z=1 を設定する．
 *  0x06000010 は条件フィールドが EQ（cond=0000）の未定義命令で，Z=1 のときだけ
 *  未定義命令例外を発生させる．非計装時は直前の if(excno==TTSP_EXCNO_A) 比較で
 *  Z=1 が残るため発火していたが，--coverage 計装ではブロックのカウンタ加算が
 *  比較と本命令の間に挿入されて Z をクリアし，条件不成立で例外が発生しなかった
 *  （ttsp_wait_check_point(2) タイムアウト）．teq r0,r0 で常に Z=1 を保証する．
 *  非計装時の動作は変わらない（従来も Z=1 だった）．
 */
#define RAISE_CPU_EXCEPTION     Asm("teq r0, r0\n\t" ".long 0x06000010");

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
 */
#define TTSP_INTNO_A    0x20	/* 割込み番号A */
#define TTSP_INTNO_B    0x21	/* 割込み番号B */
#define TTSP_INTNO_C    0x22	/* 割込み番号C */
#define TTSP_INTNO_D    0x23	/* 割込み番号D */
#define TTSP_INTNO_E    0x24	/* 割込み番号E */
#define TTSP_INTNO_F    0x25	/* 割込み番号F */

/*
 *  割込み番号(異常値)
 */
#define TTSP_INVALID_INTNO 0x100	/* ターゲットでサポートしていない割込み番号 */
#define TTSP_NOT_SET_INTNO  0x10	/* 割込み要求ラインに対して割込み属性が設定されていない割込み番号 */

/*
 *  割込みハンドラ番号(正常値)
 */
#define TTSP_INHNO_A	TTSP_INTNO_A        /* 割込みハンドラ番号A */
#define TTSP_INHNO_B	TTSP_INTNO_B        /* 割込みハンドラ番号B */
#define TTSP_INHNO_C	TTSP_INTNO_C        /* 割込みハンドラ番号C */

/*
 *  割込みハンドラ番号(異常値)
 */
#define TTSP_INVALID_INHNO 0x100	/* INHNO_VALIDは0〜186（GIC） */

/*
 *  CPU例外ハンドラ番号(正常値)
 */
#define TTSP_EXCNO_A  EXCNO_UNDEF	/* CPU例外発生元のコンテキストへreturn可能(未定義命令) */
#define TTSP_EXCNO_B  EXCNO_SVC		/* 本番号でCPU例外を発生させるテストケースはない(SVC) */

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  100

/*
 *  タイムアウト用変数
 *  [sil_dly_nse(TTSP_SIL_DLY_NSE_TIME) * TTSP_LOOP_COUNT]
 *  デフォルト: 100マイクロ秒 * 500,000回 = 50秒
 *  ※シミュレータのため体感的に適度な設定とする
 */
#define TTSP_SIL_DLY_NSE_TIME  100000
#define TTSP_LOOP_COUNT        500000

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

extern TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack");

/* ユーザドメインタスク用スタック */
#ifdef TTSP_STACK_SHARE_HRP
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack");
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section");
#endif /* TTSP_STACK_SHARE_HRP */


#endif /* TTSP_TARGET_TEST_H */
