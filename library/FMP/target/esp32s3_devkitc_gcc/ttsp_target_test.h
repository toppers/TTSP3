/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  [新規] 2026-07-07: ESP32-S3-DevKitC-1（Xtensa LX7デュアルコア）向け
 *  ターゲット依存部。zybo_z7_gcc（ARM MPCore版）を構成の雛形とし、
 *  中身はESP32-S3ポート（~/TOPPERS/esp32_s3）のarch/target実装に合わせて
 *  新規作成した。参考：polarfire_soc_kit_gcc（RISC-V版、FUNC_EXCEPTION=false
 *  で段階導入する方針が同じ）。
 *
 *  本版のスコープ（第一段階）：
 *   - FUNC_TIME=true：Xtensaコア内蔵CCOUNT/CCOMPARE0を直接操作して
 *     tick停止/再開/1tick進行を実装（target_timer.h参照）。
 *   - FUNC_INTERRUPT=true：TTSP_INTNO_AのみINT29（レベル3ソフトウェア
 *     割込み。XCHAL_INT29_TYPE=SOFTWARE）に割り当てる。ESP32-S3の
 *     ソフトウェア割込みはINT7/INT29の2本のみで、INT7はSIOドライバ
 *     （sample1用、chip_serial.c）が使用中のためTTSP3用にはINT29を使う
 *     （TTSP_INTNO_B〜Fは未定義＝対応する追加ソフト割込みが無いため）。
 *   - FUNC_EXCEPTION=false：TTSP_EXCNO_C相当のフェイタル（復帰不可）
 *     CPU例外機構が本ポートに無いため後回し（polarfire_soc_kit_gccと
 *     同じ判断）。TTSP_EXCNO_Aのみ定義（ill命令、cpuexc実装済みで
 *     復帰可能）。
 *   - PROCESSOR_NUM=1：まずシングルコアで検証する。マルチコア対応
 *     （IPIバリア同期を使うttsp_target_gain_tick_ipi等）は後続作業。
 */

#ifndef TTSP_TARGET_TEST_H
#define TTSP_TARGET_TEST_H

/*
 *  CPU例外を発生させる命令
 *
 *  本ポートのcore_test.h（arch/xtensa_gcc/common）と同じ：Xtensaの
 *  不正命令(ill)でIllegalInstruction例外(EXCCAUSE=0)を起こす。
 */
#define RAISE_CPU_EXCEPTION     Asm("ill")

/*
 *  TTSP3用の定義
 */

/*
 *  タスクのスタックサイズ
 *
 *  windowed ABIのウィンドウスピル分の余裕を持たせる
 *  （本ポートの既定STACK_SIZE=4096と同じ考え方、core_test.h参照）。
 */
#define TTSP_TASK_STACK_SIZE  4096

/*
 *  非タスクコンテキストのスタックサイズ（DEF_ICSのテストでのみ使用）
 */
#define TTSP_NON_TASK_STACK_SIZE  4096

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
 *  CFG_INTのトリガ属性
 */
#define TTSP_INT_TRIGGER_ATTR  TA_NULL

/*
 *  割込み優先度定義
 *
 *  本ポートのconfig_int（arch/xtensa_gcc/common/core_kernel_impl.h）は
 *  intpri引数を実際のハードウェア割込みレベルには反映しない（Xtensaの
 *  CPU割込みレベルはintno毎にハード固定のため）。値自体は
 *  $INTPRI_CFGINT_VALID=(-16..-1)（TBITW_IPRI=4）の範囲内であればよい。
 */
#define TTSP_GE_TIMER_INTPRI  TMIN_INTPRI /* タイマ割込みの割込み優先度より高い割込み優先度 */
#define TTSP_HIGH_INTPRI  -5              /* 割込み優先度高 */
#define TTSP_MID_INTPRI   -4              /* 割込み優先度中 */
#define TTSP_LOW_INTPRI   -3              /* 割込み優先度低 */

/*
 *  割込み番号(正常値)
 *
 *  本ポートのintnoは素の番号（prcid符号化なし、target_kernel.trb参照。
 *  デュアルコアでも同一intno空間を各コアがローカルに持つため）。
 *  TTSP_INTNO_Aのみ、ESP32-S3の2本のソフトウェア割込みのうち未使用の
 *  INT29（レベル3）を割り当てる。INT7はSIOドライバが使用中。
 *  TTSP_INTNO_B〜Fは定義しない（対応するソフト割込みが本ポートに無い。
 *  out.cfg/out.cは#ifdefガードで未定義時は当該部分をスキップする）。
 */
#define TTSP_INTNO_A      29U       /* INT29（レベル3ソフトウェア割込み） */

/*
 *  割込みハンドラ番号(正常値)
 */
#define TTSP_INHNO_A       TTSP_INTNO_A

/*
 *  割込み番号(異常値)
 *
 *  $INTNO_VALID=0..TMAX_INTNO(31)（target_kernel.trb）。32以上は範囲外。
 *  TTSP_NOT_SET_INTNOはCFG_INT未設定の番号（INT29のみCFG_INT対象、
 *  それ以外の任意の番号でよい。INT0を使う。tick=6/IPI=13/UART=7/
 *  TTSP=29のいずれとも重複しない）。
 */
#define TTSP_INVALID_INTNO       0x100   /* 範囲外（0..31を超える） */
#define TTSP_NOT_SET_INTNO       0U      /* CFG_INT未設定の割込み番号 */

/*
 *  CPU例外ハンドラ番号(正常値)
 *
 *  FUNC_EXCEPTION=falseのためTTGはこれらを使うAPIバリエーションを
 *  生成しない想定。TTSP_EXCNO_Aのみ定義（ill＝EXCCAUSE=0、cpuexc
 *  ディスパッチ実装済みで復帰可能。excnoは(prcid<<16)|EXCCAUSE符号化、
 *  core_kernel_impl.h参照）。フェイタル系（復帰不可、TTSP_EXCNO_C相当）
 *  は本版では未対応のため定義しない。
 */
#define TTSP_EXCNO_A      ((1 << 16) | 0)   /* PE1、EXCCAUSE=0（IllegalInstruction） */

/*
 *  CPU例外ハンドラ番号(異常値)
 */
#define TTSP_INVALID_EXCNO  100

/*
 *  有効範囲外のクラス
 *
 *  PROCESSOR_NUM=1のためCLS_PRC1のみ有効。存在しないクラス番号を指定。
 */
#define TTSP_INVALID_PRC_CLASS  5

/*
 *  テスト用の関数
 */

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
 *  タスクのスタックサイズ／先頭番地の参照（ttsp_test_lib.cのttsp_ref_tsk用）
 *
 *  本ポートのTSKINICTXB（arch/xtensa_gcc/common/core_kernel_impl.h）は
 *  stk_top（確保域先頭＝低位アドレス、CRE_TSKのstk引数そのもの）と
 *  stk_bottom（確保域末尾＝高位アドレス、SP初期値。Xtensaスタックは
 *  下方伸長のためSPは末尾から使う）を持つ。stkszフィールドは無いため
 *  差分で計算する（core_kernel.trbのGenerateTskinictxb参照）。
 */
#define ttsp_target_get_stksz(p_tinib) \
	((size_t)((char *)(p_tinib)->tskinictxb.stk_bottom \
				- (char *)(p_tinib)->tskinictxb.stk_top))
#define ttsp_target_get_stk(p_tinib) \
	((void *)(p_tinib)->tskinictxb.stk_top)

/*
 *  割込を許可しないロックの取得
 *
 *  本ポートのジャイアントロック（S32C1Iソフトウェアスピンロック、
 *  arch/xtensa_gcc/esp32s3/chip_kernel_impl.h）をそのまま使う。
 *  PROCESSOR_NUM=1では実質的にロック競合は発生しないが、zybo版と
 *  同じインタフェース名で提供する。
 */
#define acquire_glock_wo_preempt()	acquire_glock()

#endif /* TTSP_TARGET_TEST_H */
