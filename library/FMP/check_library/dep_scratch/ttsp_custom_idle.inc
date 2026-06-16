/*
 *  依存部スクラッチ用 custom idle 注入ヘッダ（カーネル無改変）．
 *
 *  COPTS に -include <dir>/ttsp_custom_idle.inc を渡すと，
 *  asp3/arch/arm_gcc/common/core_support.S のアイドルループ dispatcher_1 に
 *  toppers_asm_custom_idle が展開され，アイドル（p_runtsk==NULL）から C 関数
 *  idle_hook を呼ぶ．idle_hook が CPU 例外を発生させることで，例外復帰側の
 *  p_runtsk==NULL 経路（core_support.S 1139-1150）に到達する．
 *
 *  本ファイルは全翻訳単位に -include されるが，マクロ定義のみで実際に展開される
 *  のは core_support.S の dispatcher_1 のみ（C ソースでは未使用＝無害）．
 *  公式 simtimer ターゲットの target_custom_idle と同型．
 */
#ifndef TTSP_CUSTOM_IDLE_INC
#define TTSP_CUSTOM_IDLE_INC

#define TOPPERS_CUSTOM_IDLE

#define toppers_asm_custom_idle		\
			msr cpsr_c, #CPSR_SVC_MODE;	\
			bl idle_hook

#endif /* TTSP_CUSTOM_IDLE_INC */
