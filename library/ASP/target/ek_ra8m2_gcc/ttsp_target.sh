#!/bin/bash
#
#  TTSP3 ターゲット依存ビルド／実行スクリプト
#    プロファイル: ASP（TOPPERS/ASP3 3.7.2）
#    ターゲット  : ek_ra8m2_gcc（Renesas EK-RA8M2 / Cortex-M85 / 実機）
#
#  [由来] library/ASP/target/mps2_an505_gcc/ttsp_target.sh（QEMU 版）を雛形に，
#  library/HRP/target/ek_ra8m2_gcc/ttsp_target.sh（実機 J-Link フラッシュ）の
#  実機実行手順を取り込んだ．ASP3 は TECS-less・単一スタック・保護なしのため，
#  KERNEL_COBJS_TARGET は arm_m_gcc/ek_ra8m2_gcc 構成（core_*・target_*）に
#  FSP 一式を加えた構成へ変更している．
#
#  ※ common.sh / kernel_lib.sh は ASP プロファイルのビルドで
#    `make KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" ...` と
#    KERNEL_COBJS を破壊的に上書きする．このとき Makefile.target / Makefile.fsp
#    の `KERNEL_COBJS := $(KERNEL_COBJS) ...`（target_*・FSP_COBJS の追記）が
#    効かなくなるため，本ファイルの KERNEL_COBJS_TARGET に FSP オブジェクトを
#    すべて明示列挙する必要がある（列挙漏れはリンク時の undefined reference /
#    リセットベクタ欠落になる）．
#

USE_QEMU=false

# アプリケーションプログラム名（TTSP の生成 C/H/cfg 名）
APPLI_NAME="out"
ARCH_PATH=
PROCESSOR_NUM=1

FUNC_TIME="true"		# システム時刻制御関数（stop/start/gain_tick）
FUNC_INTERRUPT="true"	# 割込み発生関数（NVIC ソフトウェアペンディング）
FUNC_EXCEPTION="true"	# CPU例外発生関数（udf #0 = UsageFault）
IRC_ARCH="local"
TTG_OPT=

# コンフィギュレータ（configure.rb）に与えるオプション
#  ・ASP3 単一スタックのためユーザスタック重なり検査を無効化（OMIT_CHECK_USTACK_OVERLAP）
CONFIG_OPT="-o -Wno-unused-but-set-variable -o -DOMIT_CHECK_USTACK_OVERLAP"

#  ターゲット依存カーネルオブジェクト（make の KERNEL_COBJS 上書きで失われる分を補う）
#   ・arm_m_gcc/ek_ra8m2_gcc 構成: core_kernel_impl / target_kernel_impl / target_timer
#   ・FSP 一式（リセットベクタ・ブート・クロック・GPT・SCI 等）。fsp_gen/Makefile.fsp の
#     FSP_COBJS と一致させること（main.o は FSP の main＝boot 経路で，TTSP は main_task
#     タスクを使うため衝突しない）．
#   ※ core_support.o はアセンブリ（core_support.S）で Makefile.core が KERNEL_ASMOBJS へ
#     追加する．KERNEL_ASMOBJS は make の KERNEL_COBJS 上書きの影響を受けない（別変数）ため
#     ここには列挙しない．列挙すると `.o:%.c` 規則と `.o:%.S` 規則が衝突して
#     「No rule to make target core_support.c」になる．
KERNEL_COBJS_TARGET="objs/core_kernel_impl.o objs/target_kernel_impl.o objs/target_timer.o \
objs/board_init.o objs/board_leds.o \
objs/fsp_startup.o objs/system.o \
objs/bsp_clocks.o objs/bsp_common.o objs/bsp_delay.o objs/bsp_group_irq.o objs/bsp_guard.o \
objs/bsp_io.o objs/bsp_ipc.o objs/bsp_irq.o objs/bsp_macl.o objs/bsp_ospi_b.o \
objs/bsp_register_protection.o objs/bsp_sbrk.o objs/bsp_sdram.o objs/bsp_security.o \
objs/bsp_linker.o \
objs/r_gpt.o objs/r_ioport.o objs/r_sci_b_uart.o \
objs/common_data.o objs/hal_data.o objs/main.o objs/pin_data.o objs/vector_data.o \
objs/hal_entry.o"

APPL_COBJS_TARGET="objs/ttsp_target_test.o"
MAKE_OPT="${TTSP_MAKE_OPT:-}"
EXC_MODULE="true"

#  --- 実機（EK-RA8M2 / J-Link）フラッシュ＆実行パラメータ ---
JLINK_SN="${JLINK_SN:-1087282565}"
JLINK_DEV="${JLINK_DEV:-R7KA8M2JF_CPU0}"
RA_SERIAL="${RA_SERIAL:-/dev/ttyACM1}"
RA_BAUD="${RA_BAUD:-115200}"
RA_RUN_SEC="${RA_RUN_SEC:-60}"
OBJCOPY_BIN="${OBJCOPY_BIN:-arm-none-eabi-objcopy}"

#  ELF "asp" を ihex 化 → シリアル捕捉 background → JLinkExe で永続フラッシュ（loadfile）→ r → g．
#  （e2-server-gdb の load は MRAM 非永続なので使わない＝JLinkExe loadfile が必須．
#    JLink connect はボードをリセットするため，先に cat を上げておく．）
simulation()
{
	LOGFILE=`pwd`"/execute.log"
	HEXFILE=`pwd`"/asp.hex"
	JCMD=`pwd`"/jflash.cmd"
	if [ ! -f asp ]; then
		echo "ERROR: kernel ELF 'asp' not found. Build first." | tee $LOGFILE
		return 1
	fi
	$OBJCOPY_BIN -O ihex asp $HEXFILE
	rm -f $LOGFILE
	( timeout $RA_RUN_SEC cat $RA_SERIAL > $LOGFILE 2>/dev/null ) &
	local catpid=$!
	sleep 1
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

parallel_simulation()
{
	simulation
}
