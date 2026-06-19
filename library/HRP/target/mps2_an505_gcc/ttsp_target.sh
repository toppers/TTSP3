#
#  TTSP3
#      TOPPERS Test Suite Package 3
#
#  Copyright (C) 2009-2019 by FUJI SOFT INCORPORATED
#  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#
#  本ファイルはTTSP3ライセンスに従って利用できる．詳細は配布物に含まれ
#  る利用条件を参照のこと．
#
#  [改変] 2026-06-20: ek_ra8m2_gcc 版（HRP3 / Cortex-M85 / J-Link 実機）をベースに，
#  ARM MPS2-AN505（Cortex-M33 / QEMU）向けへ複製・適合．実行を J-Link 実機から
#  qemu-system-arm（mps2-an505・semihosting exit）へ置換した．TTSP3 ライセンス条件(2)
#  に基づく改変明記．
#
#		ターゲット依存設定（MPS2-AN505 / Cortex-M33 / QEMU 用）
#

#
# QEMU（mps2-an505）を使用する
#
USE_QEMU=true

#
# アプリケーションプログラム名（HRP の最終 ELF は "hrp"）
#
APPLI_NAME="out"

#
# アーキテクチャ上の使用フォルダ
#
ARCH_PATH=

#
# プロセッサ数（シングルコア）
#
PROCESSOR_NUM=1

#
# ターゲット依存関数の実装状況
#
FUNC_TIME="true"		# システム時刻制御関数（stop/start/gain_tick）
FUNC_INTERRUPT="true"	# 割込み発生関数（NVIC ソフトウェアペンディング）
FUNC_EXCEPTION="true"	# CPU例外発生関数（udf #0 = UsageFault）

#
# IRCアーキテクチャ
#
IRC_ARCH="local"

#
# TTGに与えるオプション
#
TTG_OPT=

#
# コンフィギュレータ（configure.rb）に与えるオプション
#  ・-std=gnu17 はカーネルの target/ek_ra8m2_gcc/Makefile.target が付与する
#    （GCC15 デフォルト C23 で tecsgen 1.8.0 が破綻するのを回避）ため，ここでは不要．
#
CONFIG_OPT="-o -Wno-unused-but-set-variable -o -DOMIT_CHECK_USTACK_OVERLAP"

#
# カーネルライブラリ使用時に追加するターゲット依存のオブジェクト
#  arm_m_gcc/common（core_kernel_impl/core_timer/core_support）＋
#  arm_m_gcc/mps2_an505（chip_kernel_impl）＋target（target_kernel_impl/target_timer）．
#  ※ HRP プロファイルでは common.sh が make 時に KERNEL_COBJS を上書きせず，
#    カーネルの Makefile.core/Makefile.chip/Makefile.target が自動付加する．
#    本変数は参考情報（USE_KERNEL_LIB=true 時のみ実効）．
#
KERNEL_COBJS_TARGET="objs/core_kernel_impl.o objs/core_timer.o objs/chip_kernel_impl.o objs/target_kernel_impl.o objs/target_timer.o"

#
# アプリケーションに追加するターゲット依存のオブジェクト
#
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
# makeに与えるオプション
#
MAKE_OPT="${TTSP_MAKE_OPT:-}"

#
# CPU例外モジュールの有無
#
EXC_MODULE="true"

#
# QEMU 実行の環境設定（環境変数で上書き可能）
#  QEMU_BIN   : qemu-system-arm のパス
#  QEMU_RUN_SEC : 1テストあたりの最大実行時間（秒。semihosting exit で通常はそれ以前に終了）
#
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
QEMU_RUN_SEC="${QEMU_RUN_SEC:-30}"

#
# 実行モジュールの実行（mps2-an505 / QEMU）
#
#  HRP の ELF "hrp" を qemu-system-arm -M mps2-an505 で実行する．カーネルは
#  ext_ker()→target_exit() で semihosting SYS_EXIT を発行し QEMU を停止する
#  （-semihosting-config enable=on 必須）．シリアルは -serial file で確実に捕捉
#  （pipe+timeout はブロックバッファで出力が欠落するため使わない）．
#  完了マーカ "All check points passed." を検出したら早期終了する．
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"

	if [ ! -f hrp ]; then
		echo "ERROR: kernel ELF 'hrp' not found. Build first." | tee $LOGFILE
		return 1
	fi
	rm -f $LOGFILE

	timeout $QEMU_RUN_SEC $QEMU_BIN -M mps2-an505 \
		-semihosting-config enable=on -kernel hrp -nographic \
		-serial file:$LOGFILE >/dev/null 2>&1

	cat $LOGFILE
}

#
# 並列実行用（ttsp_parallel_api.sh 用）：QEMU は多重起動可能だが，まずは逐次で確実に．
#
parallel_simulation()
{
	simulation
}
