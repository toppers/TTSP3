/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2019 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
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
 */

/*
 *		テストプログラムのターゲット依存定義（MPS2-AN505 / Cortex-M33 用）
 *
 *  [改変] 2026-06-20: ek_ra8m2_gcc 版（M-profile / Cortex-M85）をベースに，
 *  ARM MPS2-AN505（ARMv8-M / Cortex-M33 / QEMU）向けへ複製・適合した．
 *  TTSP3 ライセンス条件(2)に基づく改変明記．mps2 固有の差分：
 *   - TTSP_SILLOC_NO_SVC を定義（M-profile：SIL_LOC_INT 下で svc=syslog を発行できない
 *     ため，ttsp_test_lib.c の check_point が syslog をロック外で出すよう分岐させる）．
 *   - 割込み番号は NVIC 空き IRQ ライン（カーネルは SysTick=HRT・CMSDK UART0 combined
 *     IRQ42=INTNO58 を使用。INTNO40〜45=IRQ24〜29 はこれらと重ならない）．
 *   - 実行は実機 J-Link でなく QEMU（mps2-an505・semihosting exit）。ttsp_target.sh 参照．
 *  以下は ek_ra8m2_gcc 由来の記述（M-profile 共通。番地は mps2 で読み替え）：
 *
 *  zybo_z7_gcc 版（A-profile / Cortex-A9）をベースに，
 *  M-profile（ARMv8-M）向けに作成した．
 *  TTSP3 ライセンス条件(2)に基づく主な改変点：
 *   - RAISE_CPU_EXCEPTION：A32 未定義命令(.long 0x06000010) を M-profile の
 *     未定義命令 udf #0（=.short 0xDE00）へ．M-profile では udf は UsageFault
 *     （INVSTATE/UNDEFINSTR，EXCNO_USAGE=6）を発生させる．
 *   - CPU例外番号：A-profile の EXCNO_UNDEF/EXCNO_SVC を M-profile の
 *     EXCNO_USAGE/EXCNO_SVCALL（arm_m.h）へ．TTSP_EXCNO_A は「発生元コンテキスト
 *     へ return 可能な未定義命令系例外」＝UsageFault とする．
 *   - 割込み番号：GIC SPI(0x20〜) を RA8M2 NVIC の空き IRQ ライン（IRQ24〜=
 *     INTNO 40〜，ペリフェラル未接続で NVIC ソフトウェアペンディング専用）へ．
 *     カーネルが使う GPT0 IRQ(4,5=INTNO 20,21)・SCI8 IRQ(0〜3=INTNO 16〜19)を避ける．
 *   - 割込み優先度：A-profile の固定値を M-profile 優先度モデル
 *     （TMIN_INTPRI=-15 … TMAX_INTPRI=-1，負値ほど高優先度）へ．
 *   - 標準RAMリージョン名："DDR" → "RAM"（target_mem.cfg の ATT_REG("RAM",...)）．
 *   - メモリアクセス違反番地：RA8M2 の未マップ領域 0xD0000000．
 */

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

/*
 *  M-profile（ARMv8-M）では SIL_LOC_INT()（全割込みロック＝BASEPRI を TMIN_INTPRI へ）が
 *  SVCall もマスクするため，ロック下で拡張サービスコール（HRP3 の syslog は svc）を発行
 *  できない（HardFault 昇格）．ttsp_test_lib.c の check_point に，syslog をロック外で出す
 *  M-profile 分岐を有効化する．
 */
#define TTSP_SILLOC_NO_SVC

#include "out.h"
#include "arm_m.h"		/* EXCNO_USAGE/EXCNO_SVCALL(ASP3 arm_m) */

/*
 *  ターゲットシステムのハードウェア資源の定義
 */

/*
 *  CPU例外を発生させる命令（M-profile：未定義命令 udf #0）
 *
 *  ARMv8-M では udf 命令は UsageFault（UFSR.UNDEFINSTR）を発生させる．
 *  arch/arm_m_gcc/common/core_test.h の RAISE_CPU_EXCEPTION（Asm("udf #0")）と
 *  同義．本ターゲットの DEF_EXC(EXCNO_USAGE) ハンドラで捕捉する．
 */
#define RAISE_CPU_EXCEPTION     Asm("udf #0")

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
 *  メモリアクセス違反発生番地
 *  (RA8M2 の未マップ領域．アクセスすると BusFault/MemManage となる)
 */
#define TTSP_MACV_ADDRESS	0xD0000000

/*
 *  スタックサイズとして不正なサイズ
 */
#define TTSP_INVALID_STACK_SIZE	0x01

/*
 *  ターゲット定義の拡張後の割込み優先度最小値
 */
#define TTSP_TMIN_INTPRI	TMIN_INTPRI

/*
 *  割込み優先度定義（M-profile：TMIN_INTPRI=-15 が最高，TMAX_INTPRI=-1 が最低）
 */
#define TTSP_GE_TIMER_INTPRI  TMIN_INTPRI	/* タイマ割込みの割込み優先度より高い割込み優先度 */
#define TTSP_HIGH_INTPRI      (-5)			/* 割込み優先度高 */
#define TTSP_MID_INTPRI       (-4)			/* 割込み優先度中 */
#define TTSP_LOW_INTPRI       (-3)			/* 割込み優先度低 */

/*
 *  割込み番号(正常値)
 *
 *  RA8M2 NVIC の空き IRQ ライン（ペリフェラル未接続）を割り当てる．
 *  INTNO = NVIC IRQ番号 + 16．カーネルが使う GPT0(IRQ4,5=INTNO20,21)・
 *  SCI8(IRQ0〜3=INTNO16〜19) と重ならないよう IRQ24〜29(=INTNO40〜45)を使う．
 *  これらの割込みは raise_int()（NVIC ISPR へのソフトウェアペンディング）で
 *  発生させ，clear_int()（NVIC ICPR）でクリアする．
 */
#define TTSP_INTNO_A    40U	/* 割込み番号A (NVIC IRQ24) */
#define TTSP_INTNO_B    41U	/* 割込み番号B (NVIC IRQ25) */
#define TTSP_INTNO_C    42U	/* 割込み番号C (NVIC IRQ26) */
#define TTSP_INTNO_D    43U	/* 割込み番号D (NVIC IRQ27) */
#define TTSP_INTNO_E    44U	/* 割込み番号E (NVIC IRQ28) */
#define TTSP_INTNO_F    45U	/* 割込み番号F (NVIC IRQ29) */

/*
 *  割込み番号(異常値)
 */
#define TTSP_INVALID_INTNO 0x1000U	/* ターゲットでサポートしていない割込み番号(TMAX_INTNO=147超) */
#define TTSP_NOT_SET_INTNO  0x10U	/* 割込み属性が設定されていない割込み番号(INTNO16=SCI8 RXI枠) */

/*
 *  割込みハンドラ番号(正常値)
 */
#define TTSP_INHNO_A	TTSP_INTNO_A        /* 割込みハンドラ番号A */
#define TTSP_INHNO_B	TTSP_INTNO_B        /* 割込みハンドラ番号B */
#define TTSP_INHNO_C	TTSP_INTNO_C        /* 割込みハンドラ番号C */

/*
 *  割込みハンドラ番号(異常値)
 */
#define TTSP_INVALID_INHNO 0x1000U	/* INHNO の有効範囲は 15〜147(NVIC) */

/*
 *  CPU例外ハンドラ番号(正常値)
 *
 *  TTSP_EXCNO_A：CPU例外発生元のコンテキストへ return 可能な未定義命令系例外．
 *               M-profile では udf による UsageFault（EXCNO_USAGE=6, arm_m.h）．
 *  TTSP_EXCNO_B：本番号でCPU例外を発生させるテストケースはない（SVCall）．
 */
#define TTSP_EXCNO_A  EXCNO_USAGE	/* CPU例外発生元へreturn可能(未定義命令=UsageFault) */
#define TTSP_EXCNO_B  EXCNO_SVCALL	/* 本番号でCPU例外を発生させるテストケースはない(SVCall) */

/*
 *  A-profile の EXCNO_DABORT / EXCNO_PABORT の M-profile への対応付け
 *
 *  SIL テスト(sil_test/HRP/out.cfg)は，ユーザドメインの不正メモリアクセス（データ
 *  アボート）を捕捉するため DEF_EXC(EXCNO_DABORT, sil_dabort_handler) /
 *  DEF_EXC(EXCNO_PABORT, sil_pabort_handler) を登録する．M-profile にこれらの例外は
 *  無いため，対応する例外番号へ割り当てる：
 *   ・データアクセス違反（MPU 保護違反）= MemManage(#4, EXCNO_MPU) → EXCNO_DABORT
 *   ・命令／その他アクセス系 = BusFault(#5, EXCNO_BUS) → EXCNO_PABORT
 *  DEF_EXC が同一例外番号で衝突しないよう，両者には異なる番号を割り当てる．
 */
#ifndef EXCNO_DABORT
#define EXCNO_DABORT  EXCNO_MPU		/* データアクセス違反 → MemManage(#4) */
#endif
#ifndef EXCNO_PABORT
#define EXCNO_PABORT  EXCNO_BUS		/* 命令／その他アクセス違反 → BusFault(#5) */
#endif

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  100		/* TMAX_EXCNO=14 を超える値 */

/*
 *  タイムアウト用変数
 *  [sil_dly_nse(TTSP_SIL_DLY_NSE_TIME) * TTSP_LOOP_COUNT]
 */
#define TTSP_SIL_DLY_NSE_TIME  100000
#define TTSP_LOOP_COUNT        500000

/*
 *  SIL テスト周期ハンドラ(cychdr)の周期[µs]（EK-RA8M2 適合化）
 *
 *  既定 100ms では，cychdr の all_test 実行（低速 115200 シリアル出力等で数百 ms）が周期を超え，
 *  イベント駆動 HRT のキャッチアップ・ライブロックに陥る（実機 halt で確認）。ハンドラ実行時間より
 *  十分大きい 3 秒に設定し，1 周期内に cychdr が完了するようにして回避する（sil_test/HRP/out.cfg
 *  が本マクロを参照）。
 */
#define TTSP_SIL_CYC_TIME      3000000

/*
 *  fch_hrtで取得するカウント値のシステム時間に対する係数
 *  (target_hrt_get_current は us 単位の HRTCNT を返すため 1)
 */
#define TTSP_MOD_FCH_CNT 1

/*
 * アライン指定宣言マクロ
 */
/* ARMv8-M(PMSAv8) の保護対象スタック領域は MPU リージョン境界＝32 バイト整列が必要
 * （ユーザタスクスタック ttg_ustack 等。非整列だと cfg が E_PAR: stack area not aligned to 32 bytes）． */
#define TTSP_DEFINE_VAR_SECTION(type, var, sec)	type var __attribute__((section(sec), aligned(32)));

/*
 * 標準RAMリージョン名（EK-RA8M2: target_mem.cfg の ATT_REG("RAM",...)）
 */
#define TTSP_STANDARD_RAM_REGION	"RAM"

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

/*
 *  スタック領域情報の取出し（USE_TSKINICTXB ターゲット用）
 *
 *  本ターゲット（arm_m_gcc）は TSKINICTXB を使う（USE_TSKINICTXB 定義）。
 *  TTSP3 テストライブラリ（ttsp_test_lib.c の ref_tsk 検査）は，USE_TSKINICTXB
 *  ターゲットで以下のアクセサにより ref_tsk 標準形式（スタック先頭番地＋サイズ）へ
 *  変換する。A-profile ターゲット（zybo 等）は USE_TSKINICTXB 未定義のため不要。
 */
#ifdef USE_TSKINICTXB
/*
 *  TINIB の完全な構造体定義（task.h，ALLFUNC 時に可視）を取り込む．
 *  TTSP3 テストライブラリ（ttsp_test_lib.c）も本ヘッダ経由でこの定義を必要とする
 *  （ref_tsk 検査で p_tinib->tskinictxb を参照するため）．
 */
#include "kernel/task.h"
/* ASP3 は保護なし＝タスク単一スタック。TSKINICTXB.stk_top/stk_bottom から取得 */
extern size_t ttsp_target_get_stksz(const TINIB *p_tinib);
extern void  *ttsp_target_get_stk(const TINIB *p_tinib);
#endif /* USE_TSKINICTXB */

extern TTSP_DEFINE_VAR_SECTION(STK_T, nontask_stack[COUNT_STK_T(TTSP_NON_TASK_STACK_SIZE)], ".system_stack");

/* ユーザドメインタスク用スタック */
#ifdef TTSP_STACK_SHARE_HRP
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_sstack[TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".system_stack");
extern TTSP_DEFINE_VAR_SECTION(STK_T, ttg_ustack[TTG_DOMAIN_NUM][TTG_STACK_NUM][COUNT_STK_T(TTSP_TASK_STACK_SIZE)], ".ttg_stack_section");
#endif /* TTSP_STACK_SHARE_HRP */


#endif /* TTSP_TARGET_TEST_H */
