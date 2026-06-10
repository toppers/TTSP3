/*
 *  WB test xsns_dpn_W-b 専用 custom idle 注入ヘッダ（カーネル無改変）
 *
 *  COPTS に
 *    -include <wb_dir>/ttsp_custom_idle.inc
 *  を渡すことで，asp3/arch/arm_gcc/common/core_support.S のアイドルループ
 *  dispatcher_1 に toppers_asm_custom_idle を注入する．アイドル
 *  （p_runtsk==NULL）から C 関数 xsns_dpn_W_b_idle を呼び，そこで CPU 例外を
 *  発生させて exception.c L102 br[2]（p_runtsk==NULL → state=true）に到達する．
 *
 *  本ファイルは全翻訳単位の先頭に -include されるが，TOPPERS_CUSTOM_IDLE と
 *  toppers_asm_custom_idle マクロを定義するのみで，マクロが実際に展開される
 *  のは core_support.S の dispatcher_1 のみ（C ソースでは未使用＝無害）．
 *  公式 simtimer ターゲット（target/simtimer_ct11mpcore_gcc）の
 *  target_custom_idle と同型の手法．
 */
#ifndef TTSP_CUSTOM_IDLE_INC
#define TTSP_CUSTOM_IDLE_INC

#define TOPPERS_CUSTOM_IDLE

#define toppers_asm_custom_idle		\
			msr cpsr_c, #CPSR_SVC_MODE;	\
			bl xsns_dpn_W_b_idle

#endif /* TTSP_CUSTOM_IDLE_INC */
