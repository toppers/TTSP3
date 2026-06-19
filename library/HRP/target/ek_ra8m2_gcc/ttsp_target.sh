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
#  [改変] 2026-06-19: zybo_z7_gcc 版をベースに，HRP3 の EK-RA8M2（Cortex-M85）
#  ターゲット向けに新規作成．QEMU 実行を J-Link 実機フラッシュ＋シリアル捕捉に
#  置き換え，KERNEL_COBJS_TARGET を arm_m_gcc/ek_ra8m2_gcc 構成に変更した．
#
#		ターゲット依存設定（EK-RA8M2 / Cortex-M85 用）
#

#
# 実機（EK-RA8M2 ボード）を使用する（QEMU は使わない）
#
USE_QEMU=false

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
#  arm_m_gcc/ra8m2_fsp（chip_kernel_impl）＋target（target_kernel_impl/target_timer）．
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
# J-Link / シリアルの環境設定（環境変数で上書き可能）
#  JLINK_SN   : J-Link OB のシリアル番号（ShowEmuList で確認）
#  JLINK_DEV  : J-Link デバイス名（RA8M2 は _CPU0 付きが必須）
#  RA_SERIAL  : ボード VCOM（SEGGER 側．Raspberry Pi Debugprobe の ttyACM0 と区別）
#  RA_BAUD    : シリアルボーレート（SCI8, 115200 8N1）
#  RA_RUN_SEC : シリアル捕捉時間（秒）
#
JLINK_SN="${JLINK_SN:-1087282565}"
JLINK_DEV="${JLINK_DEV:-R7KA8M2JF_CPU0}"
RA_SERIAL="${RA_SERIAL:-/dev/ttyACM1}"
RA_BAUD="${RA_BAUD:-115200}"
RA_RUN_SEC="${RA_RUN_SEC:-60}"
OBJCOPY_BIN="${OBJCOPY_BIN:-arm-none-eabi-objcopy}"

#
# 実行モジュールの実行（EK-RA8M2 実機・J-Link フラッシュ＋シリアル捕捉）
#
#  手順（docs/ek-ra8m2-cli-flash-recipe.md 準拠）：
#   1. HRP の ELF "hrp" を ihex（hrp.hex）へ変換する（make は hex を作らない）．
#   2. 先にシリアル（/dev/ttyACM1, 115200 8N1）を background で捕捉開始する
#      （JLink connect はボードをリセットするため，先に cat を上げておく）．
#   3. JLinkExe -CommanderScript で永続フラッシュ（loadfile hrp.hex）→ r → g．
#      ※ e2-server-gdb の load は MRAM 非永続なので使わない（JLinkExe loadfile が必須）．
#   4. 完了マーカ（"All check points passed."）検出か RA_RUN_SEC タイムアウトで終了．
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"
	HEXFILE=`pwd`"/hrp.hex"
	JCMD=`pwd`"/jflash.cmd"

	# 1. ELF -> ihex
	if [ ! -f hrp ]; then
		echo "ERROR: kernel ELF 'hrp' not found. Build first." | tee $LOGFILE
		return 1
	fi
	$OBJCOPY_BIN -O ihex hrp $HEXFILE

	# 2. シリアル捕捉を background 起動（JLink connect の前に）
	rm -f $LOGFILE
	( timeout $RA_RUN_SEC cat $RA_SERIAL > $LOGFILE 2>/dev/null ) &
	local catpid=$!
	sleep 1

	# 3. J-Link で永続フラッシュ→リセット→実行
	cat > $JCMD <<EOF
si SWD
speed 4000
SelectEmuBySN $JLINK_SN
device $JLINK_DEV
connect
loadfile $HEXFILE
r
g
exit
EOF
	JLinkExe -device $JLINK_DEV -CommanderScript $JCMD

	# 4. 完了マーカ検出 or タイムアウトで終了
	local waited=0
	while kill -0 $catpid 2>/dev/null; do
		if grep -q 'All check points passed\.' $LOGFILE 2>/dev/null; then
			sleep 1
			kill $catpid 2>/dev/null
			break
		fi
		sleep 2
		waited=$((waited + 2))
		if [ $waited -ge $RA_RUN_SEC ]; then
			break
		fi
	done
	wait $catpid 2>/dev/null

	cat $LOGFILE
}

#
# 並列実行用（ttsp_parallel_api.sh 用）：実機は1台のため逐次 simulation を流用する．
# 並列ビルド→逐次フラッシュ実行を呼出側で制御する想定．
#
parallel_simulation()
{
	simulation
}
