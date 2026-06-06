/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *
 *  上記著作権者は，TTSP3のライセンス（利用条件(1)〜(4)）に従い，
 *  本ソフトウェアの利用を無償で許諾する．詳細は他ソースファイルの
 *  ヘッダまたは配布物のドキュメントを参照のこと．
 *  本ソフトウェアは，無保証で提供されているものである．
 *
 *  2026-06-07: FMP3 POSIXターゲット（linux_gcc）用に新規作成．
 *  （zybo_z7_gcc版を雛形に，POSIXシミュレーション環境向けに再定義）
 *
 *  本ターゲットの制約:
 *  - 時刻はCLOCK_MONOTONIC（実時間）駆動のため停止できない．
 *    FUNC_TIME="false" で運用し，stop/start/gain_tick は空実装．
 *  - IRCはグローバルIRC（割込み番号は0〜TMAX_INTNO(255)のフラット空間．
 *    ハンドラの割付けはクラスで行う）．
 */

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

#include <signal.h>
#include <pthread.h>
#include "intno.h"

/*
 *  CPU例外を発生させる処理（自スレッドへのSIGFPE送出）
 */
#define RAISE_CPU_EXCEPTION		pthread_kill(pthread_self(), SIGFPE)

/*
 *  TTSP3用の定義
 */

/*
 *  タスクのスタックサイズ
 *  （glibc 2.34以降SIGSTKSZは定数でないため，リテラルで定義する）
 */
#define TTSP_TASK_STACK_SIZE  16384

/*
 *  非タスクコンテキストのスタックサイズ
 *  (DEF_ICSのテストでのみ使用する)
 */
#define TTSP_NON_TASK_STACK_SIZE  16384

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
 *  CFG_INTのトリガ属性（本ターゲットはエッジトリガのみサポート）
 */
#define TTSP_INT_TRIGGER_ATTR  TA_EDGE

/*
 *  割込み優先度定義
 *  （TMIN_INTPRI=-7，TMAX_INTPRI=-1，INTPRI_TIMER=TMAX_INTPRI-1=-2）
 */
#define TTSP_GE_TIMER_INTPRI  TMIN_INTPRI /* タイマ割込みより高い割込み優先度 */
#define TTSP_HIGH_INTPRI  -5              /* 割込み優先度高 */
#define TTSP_MID_INTPRI   -4              /* 割込み優先度中 */
#define TTSP_LOW_INTPRI   -3              /* 割込み優先度低 */

/*
 *  割込み番号(正常値)
 *
 *  グローバルIRC（フラット空間0〜255）．既使用番号を避けて割り当てる:
 *   0-3   : INTNO_TIMER_PRC1-4
 *   12-23 : カーネルIPI（DISPATCH/EXT_KER/SET_HRT_EVT）
 *   100   : INTNO_SIGIO
 *   101   : INTNO_SIGHUP
 */
#define TTSP_INTNO_A      40U      /* PE1割込み番号A */
#define TTSP_INTNO_B      41U      /* PE1割込み番号B */
#define TTSP_INTNO_C      42U      /* PE1割込み番号C */
#define TTSP_INTNO_D      43U      /* PE1割込み番号D */
#define TTSP_INTNO_E      44U      /* PE1割込み番号E */
#define TTSP_INTNO_F      45U      /* PE1割込み番号F */

#define TTSP_INTNO_PE2_A  50U      /* PE2割込み番号A */
#define TTSP_INTNO_PE2_B  51U      /* PE2割込み番号B */
#define TTSP_INTNO_PE2_C  52U      /* PE2割込み番号C */
#define TTSP_INTNO_PE2_D  53U      /* PE2割込み番号D */
#define TTSP_INTNO_PE2_E  54U      /* PE2割込み番号E */
#define TTSP_INTNO_PE2_F  55U      /* PE2割込み番号F */

#define TTSP_GLOBAL_IRC_INTNO_A  60U      /* グローバルIRC用割込み番号A */
#define TTSP_GLOBAL_IRC_INTNO_B  61U      /* グローバルIRC用割込み番号B */
#define TTSP_GLOBAL_IRC_INTNO_C  62U      /* グローバルIRC用割込み番号C */
#define TTSP_GLOBAL_IRC_INTNO_D  63U      /* グローバルIRC用割込み番号D */
#define TTSP_GLOBAL_IRC_INTNO_E  64U      /* グローバルIRC用割込み番号E */
#define TTSP_GLOBAL_IRC_INTNO_F  65U      /* グローバルIRC用割込み番号F */

/*
 *  割込みハンドラ番号(正常値)
 *  （本ターゲットのINHNOは (プロセッサID << 16) | INTNO）
 */
#define TTSP_INHNO_A       (0x10000U | TTSP_INTNO_A)      /* PE1割込みハンドラ番号A */
#define TTSP_INHNO_B       (0x10000U | TTSP_INTNO_B)      /* PE1割込みハンドラ番号B */
#define TTSP_INHNO_C       (0x10000U | TTSP_INTNO_C)      /* PE1割込みハンドラ番号C */

#define TTSP_INHNO_PE2_A   (0x20000U | TTSP_INTNO_PE2_A)  /* PE2割込みハンドラ番号A */
#define TTSP_INHNO_PE2_B   (0x20000U | TTSP_INTNO_PE2_B)  /* PE2割込みハンドラ番号B */
#define TTSP_INHNO_PE2_C   (0x20000U | TTSP_INTNO_PE2_C)  /* PE2割込みハンドラ番号C */

/*
 *  割込み番号(異常値)
 */
#define TTSP_INVALID_INTNO       0x100U   /* サポートしていない割込み番号（> TMAX_INTNO=255） */
#define TTSP_INVALID_INTNO_PE2   0x100U
#define TTSP_NOT_SET_INTNO       70U      /* 割込み属性が設定されていない割込み番号 */
#define TTSP_NOT_SET_INTNO_PE2   71U
/* グローバルIRCのため発行元プロセッサ制約はない（参照されない想定の安全値） */
#define TTSP_NOT_SELF_INTNO_PE1  72U
#define TTSP_NOT_SELF_INTNO_PE2  73U

/*
 *  割込みハンドラ番号(異常値)
 */
#define TTSP_INVALID_INHNO  (-1)
/* INHNOはプロセッサID接頭辞が必須（自プロセッサ＝PE1に割り付ける） */
#define TTSP_GLOBAL_IRC_INHNO_A  (0x10000U | TTSP_GLOBAL_IRC_INTNO_A)  /* グローバルIRC用割込みハンドラ番号A */
#define TTSP_GLOBAL_IRC_INHNO_B  (0x10000U | TTSP_GLOBAL_IRC_INTNO_B)  /* グローバルIRC用割込みハンドラ番号B */
#define TTSP_GLOBAL_IRC_INHNO_C  (0x10000U | TTSP_GLOBAL_IRC_INTNO_C)  /* グローバルIRC用割込みハンドラ番号C */

/*
 *  CPU例外ハンドラ番号(正常値)
 *  （シグナルベース．SIGFPEはpthread_killで発生させ，発生元へreturn可能）
 */
#define TTSP_EXCNO_A      EXCNO_SIGFPE_PRC1   /* CPU例外発生元のコンテキストへreturn可能 */
#define TTSP_EXCNO_B      EXCNO_SIGBUS_PRC1   /* 本番号でCPU例外を発生させるテストケースはない */
#define TTSP_EXCNO_PE2_A  EXCNO_SIGFPE_PRC2
#define TTSP_EXCNO_PE2_B  EXCNO_SIGBUS_PRC2

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  (0x10000U | 100U)

/*
 *  有効範囲外のクラス
 */
#define TTSP_INVALID_PRC_CLASS  5

/*
 *  各同期処理のタイムアウト用変数
 *  [sil_dly_nse(TTSP_SIL_DLY_NSE_TIME) * TTSP_LOOP_COUNT]
 */
#define TTSP_SIL_DLY_NSE_TIME  100000
#define TTSP_LOOP_COUNT        2000000

/*
 *  fch_hrtで取得するカウント値のシステム時間に対する係数
 */
#define TTSP_MOD_FCH_CNT 1

/*
 *  タスク初期化コンテキストブロックからのスタック情報の取出し
 *  （本ターゲットは USE_TSKINICTXB を定義．TSKINICTXB は stksz のみを持ち，
 *    スタック領域はpthreadが管理するため先頭番地は NULL を返す）
 */
#define ttsp_target_get_stksz(p_tinib)	((p_tinib)->tskinictxb.stksz)
#define ttsp_target_get_stk(p_tinib)	(NULL)

/*
 *  ティック更新の停止（本ターゲットでは未サポート: FUNC_TIME="false"）
 */
extern void ttsp_target_stop_tick(void);

/*
 *  ティック更新の再開（未サポート）
 */
extern void ttsp_target_start_tick(void);

/*
 *  ティックの更新（未サポート）
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
extern STK_T nontask1_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];
extern STK_T nontask2_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)];

/*
 *  割込みを許可しないジャイアントロックの取得
 *  （POSIX版: ミューテックスのトライロックをスピンで取得する．
 *    acquire_lock()と異なりCPUロックを解除しない）
 */
#define acquire_glock_wo_preempt()	acquire_lock_wo_preemption(&giant_lock)
Inline void
acquire_lock_wo_preemption(LOCK *p_lock)
{
	while (pthread_mutex_trylock(&(p_lock->lock_mutex)) != 0) ;
	p_lock->locked = true;
}

#endif /* TTSP_TARGET_TEST_H */
