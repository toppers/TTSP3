/*
 *  WB test xsns_dpn_W-b（FMP）専用 custom idle 注入ヘッダ（カーネル無改変）
 *
 *  COPTS に
 *    -include <wb_dir>/ttsp_custom_idle.inc
 *  を渡すことで，fmp3/arch/arm_gcc/common/core_support.S のアイドルループ
 *  dispatcher_2 に toppers_asm_custom_idle を注入する．アイドル
 *  （自 PE の p_runtsk==NULL）から C 関数 xsns_dpn_W_b_idle を呼び，PE2 で
 *  CPU 例外を発生させて exception.c の p_my_pcb->p_runtsk==NULL 分岐
 *  （state=true）に到達する．
 *
 *  本ファイルは全翻訳単位の先頭に -include されるが，TOPPERS_CUSTOM_IDLE と
 *  toppers_asm_custom_idle マクロを定義するのみで，マクロが実際に展開される
 *  のは core_support.S の dispatcher_2 のみ（C ソースでは未使用＝無害）．
 *  ASP 版 xsns_dpn_W-b と同型（idle 用スタックへ切換え後に C 関数を呼ぶ）。
 */
#ifndef TTSP_CUSTOM_IDLE_INC
#define TTSP_CUSTOM_IDLE_INC

#define TOPPERS_CUSTOM_IDLE

#define toppers_asm_custom_idle		\
			msr cpsr_c, #CPSR_SVC_MODE;	\
			bl xsns_dpn_W_b_idle

#endif /* TTSP_CUSTOM_IDLE_INC */
