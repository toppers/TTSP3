#
#  TTSP3
#      TOPPERS Test Suite Package 3
#
#  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#
#  PolarFire SoC Discovery/Icicle Kit（U54 / RV64GC）FMP3 向け
#  TTSP3 ターゲット依存定義．実機を JTAG（openocd + gdb）で起動し，
#  UART(/dev/ttyUSB0) の出力を execute.log に取得して判定する．
#

#
#  アプリケーション名（生成実行ファイルは fmp）
#
APPLI_NAME="out"

#
#  アーキテクチャフォルダ（不要）
#
ARCH_PATH=

#
#  プロセッサ数（FMP）．api_test は 2PE 前提のため 2．
#
PROCESSOR_NUM=2

#
#  ターゲット依存APIの有無 [true: 有り，false: 無し]
#
FUNC_TIME="false"       # HWタイマ早送り非対応（CLINT mtimer の凍結手段なし）
FUNC_INTERRUPT="false"  # PLIC はソフトから割込み発生不可（int1 非対応）
FUNC_EXCEPTION="false"  # 本版では CPU例外モジュールは対象外（後日拡張可）

#
#  IRCアーキテクチャ（FMP）．PLIC＝グローバル．
#
IRC_ARCH="global"

#
#  TTGへの追加オプション
#
TTG_OPT=

#
#  コンフィギュレータへの追加オプション
#  polarfire のシステムサービス（syslog/banner/serial/serial_cfg/chip_serial/
#  logtask/mmuart）を取り込む．SDK 起動コードは Makefile.target が自動追加．
#  プロセッサ数は -DTNUM_PRCID=2．
#
CONFIG_OPT="-w -S syslog.o -S banner.o -S serial.o -S serial_cfg.o -S chip_serial.o -S logtask.o -S mmuart.o -O -DTNUM_PRCID=2 -O -DTARGET_HEAP_SIZE=8192 -o -Os -o -Wno-unused-but-set-variable"

#
#  ターゲット依存部でKERNEL_COBJSへ追加するオブジェクトファイル
#  （ASM の chip_support.o / core_support.o は Makefile.chip/core が
#    KERNEL_ASMOBJS として自動追加するため列挙不要）
#
KERNEL_COBJS_TARGET="objs/target_kernel_impl.o objs/chip_kernel_impl.o objs/plic_kernel_impl.o objs/mtimer.o objs/msi_ipi.o objs/core_kernel_impl.o"
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
#  make の追加オプション．ボード指定は Icicle Kit．
#  TTSP_MAKE_OPT で上書き追記可（例: GCOV計装）．
#
MAKE_OPT="BOARD=MPFS_ICICLE_KIT ${TTSP_MAKE_OPT:-}"

#
#  実行モジュールの実行をシェルスクリプトで実装済みか
#
EXC_MODULE="true"

#
#  実行モジュールの実行（ターゲット依存：実機 JTAG）
#
#  環境変数（任意）:
#    TTSP_SC_DIR   : SoftConsole のパス
#    TTSP_TTYUSB   : コンソール UART（既定 /dev/ttyUSB0）
#    TTSP_RUN_SECS : 1テストの最大実行秒（既定 55）
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"
	local SC="${TTSP_SC_DIR:-/home/honda/Microchip/SoftConsole-v2022.2-RISC-V-747}"
	local TTY="${TTSP_TTYUSB:-/dev/ttyUSB0}"
	local SECS="${TTSP_RUN_SECS:-55}"
	local GCC_BIN="$SC/riscv-unknown-elf-gcc/bin"

	#  openocd（GDBサーバ）が未起動なら起動する
	if ! grep -q "Listening on port 3333" "/tmp/ttsp_openocd.log" 2>/dev/null \
	   || ! pgrep -f "openocd.*microsemi-riscv" >/dev/null 2>&1
	then
		pkill -9 -f "openocd.*microsemi-riscv" 2>/dev/null
		pkill -9 fpServer 2>/dev/null
		sleep 2
		( LD_LIBRARY_PATH="$SC/openocd/bin:$SC/fpServer/lib" \
		  "$SC/openocd/bin/openocd" -c "set DEVICE MPFS" \
		  -f board/microsemi-riscv.cfg > /tmp/ttsp_openocd.log 2>&1 & )
		sleep 6
	fi

	#  GDB スクリプト
	cat > run.gdb <<-GDB
		set pagination off
		set confirm off
		set mem inaccessible-by-default off
		target extended-remote localhost:3333
		set architecture riscv:rv64
		file fmp
		monitor reset init
		load
		thread apply all set \$pc=_start
		continue
	GDB

	#  UART キャプチャ
	stty -F "$TTY" 115200 cs8 -cstopb -parenb -echo raw 2>/dev/null
	pkill -f "cat $TTY" 2>/dev/null
	sleep 0.5
	: > "$LOGFILE"
	cat "$TTY" > "$LOGFILE" 2>&1 &
	local CATPID=$!

	#  ロード＆実行（タイムアウトで打ち切り）
	timeout "$SECS" "$GCC_BIN/riscv64-unknown-elf-gdb" -q -batch -x run.gdb fmp \
		> gdb_run.log 2>&1

	sleep 1
	kill $CATPID 2>/dev/null

	cat "$LOGFILE"
}
