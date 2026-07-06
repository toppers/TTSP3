#
#  TTSP3
#      TOPPERS Test Suite Package 3
#
#  [新規] 2026-07-07: ESP32-S3-DevKitC-1（Xtensa LX7）向けターゲット設定。
#  zybo_z7_gcc（QEMU実行の構成）を雛形とし、実行系はESP32-S3ポート
#  （~/TOPPERS/esp32_s3/scripts/run_qemu.sh）と同じ Espressifフォーク
#  QEMU（esp32s3マシンタイプ）＋esptool elf2image/merge_binの手順に置換。
#
#  第一段階のスコープ（詳細はttsp_target_test.h参照）：
#   - PROCESSOR_NUM=1（シングルコア）
#   - FUNC_TIME/FUNC_INTERRUPT=true、FUNC_EXCEPTION=false
#     （フェイタルCPU例外機構が本ポートに無いため後回し。
#      polarfire_soc_kit_gcc＝RISC-V版と同じ判断）
#

#
# 実機 or QEMU
#
USE_QEMU=true

#
# アプリケーション名
#
APPLI_NAME="out"

#
# アーキテクチャフォルダ(必要な場合のみ)
#
ARCH_PATH=

#
# プロセッサ数(FMPカーネルのみ使用)
#
PROCESSOR_NUM=1

#
# ターゲット依存APIの有無
#
FUNC_TIME="true"        # システム時刻制御関数（CCOUNT/CCOMPARE0直接操作＋HRT凍結）
#
# [改変] 2026-07-07: 当初INT29（レベル3ソフトウェア割込み）をTTSP_INTNO_Aに
# 割り当てて有効化を試みたが、check_library/interruptがCP1で無応答となり
# 調査の結果、ESP32-S3のLevel-1割込み専用ディスパッチ機構（本ポートの
# _kernel_l1int_entry、xtos_exc_handler_table[EXCCAUSE_LEVEL1_INTERRUPT=4]
# 経由）はレベル1割込みしか捕捉できないと判明した。Xtensaのレベル2/3
# 割込みはEXCCAUSE経由ではなく専用の固定ベクタ（Level2/3InterruptVector）
# で処理され、本ポートはVECBASE非変更方針のためこの専用ベクタへの登録を
# 行っていない。ESP32-S3のソフトウェア割込みはINT7（レベル1）とINT29
# （レベル3）の2本のみで、INT7はSIOドライバ（sample1用UART対話コンソール）
# が使用中のため、TTSP3用に使えるレベル1ソフト割込みが実質無い。
# よってFUNC_INTERRUPT=falseとする（polarfire_soc_kit_gcc＝RISC-V版と
# 同じ判断。Level2/3専用ベクタへの対応は将来の拡張課題）。
#
FUNC_INTERRUPT="false"
FUNC_EXCEPTION="false"  # CPU例外発生関数（フェイタル例外機構が本ポート未対応のため）

#
# IRCアーキテクチャ(FMPカーネルのみ使用)
#
IRC_ARCH="local"

#
# TTGへの追加オプション
#
TTG_OPT=

#
# コンフィギュレータへの追加オプション
#
# TTSP3のFMP共通cfg（library/FMP/test/tecsgen.cfg）がsyssvc/serial.cfgを
# 必須でINCLUDEするため、対話シリアルドライバ一式（serial.o/serial_cfg.o/
# chip_serial_sio.o）が必要（実際にシリアルポートを開いて使うわけではないが、
# リンクは必須。sio_irdy_rcv/snd・serial_initializeの未定義参照を防ぐ）。
# [改変] 2026-07-07: SIOドライバ本体はchip_serial.c（target_fput_logのみ、
# 全ビルド常時リンク）からchip_serial_sio.cへ分離した（esp32_s3リポジトリ側
# の回帰修正、通常のFMP3機能テストがserial.cfgをINCLUDEしないため）。
# chip_serial.oは指定しない（Makefile.chipが自動的にSYSSVC_COBJSへ
# 追加するため、ここで重複指定すると multiple definition リンクエラーになる）。
# -DTOPPERS_QEMU は target_exit のセミホスティングSYS_exitを有効化し、
# ext_ker時にQEMUを自動終了させる（run_qemu.sh方式）。
#
#
# -mtext-section-literals: TTGが生成するAPIテストのout.cは非常に巨大
# （auto_code一片で20万行超）になり、既定のリテラルプール配置では
# l32rの到達範囲（±128KB程度）を超えて"dangerous relocation: l32r:
# literal target out of range"リンクエラーになる（-mlongcallsは関数
# 呼出しのcall→callx変換のみでl32rには効かない）。本オプションで
# リテラルを各関数の直前にインライン配置させ、範囲制約を回避する。
#
CONFIG_OPT="-w -S syslog.o -S banner.o -S serial.o -S serial_cfg.o -S chip_serial_sio.o -o -Wno-unused-but-set-variable -o -mtext-section-literals"
if [ "$USE_QEMU" == "true" ]
then
	CONFIG_OPT="$CONFIG_OPT -o -DTOPPERS_QEMU"
fi

#
# ターゲット依存部でKERNEL_COBJSへ追加するオブジェクトファイル
#
# TTSP3のmakeはKERNEL_COBJS/APPL_COBJSをコマンドライン引数で上書きする
# （common.sh）ため、通常のFMP3ビルド（Makefile.chip/Makefile.core/
# Makefile.target）が自動追加する分をここに明示的に列挙する必要がある
# （zybo_z7_gcc版のKERNEL_COBJS_TARGETと同じ理由）。
#   chip_kernel_impl.o, chip_ipi.o  : arch/xtensa_gcc/esp32s3/Makefile.chip
#   core_kernel_impl.o              : arch/xtensa_gcc/common/Makefile.core
#   target_kernel_impl.o, target_timer.o : target/esp32s3_devkitc_gcc/Makefile.target
#
KERNEL_COBJS_TARGET="objs/chip_kernel_impl.o objs/chip_ipi.o objs/core_kernel_impl.o objs/target_kernel_impl.o objs/target_timer.o"
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
# make depend / make の追加オプション(必要な場合のみ)
#
MAKE_OPT="${TTSP_MAKE_OPT:-}"

#
# 実行モジュールの実行をシェルスクリプトで実装済みか
#
EXC_MODULE="true"

#
# 実行モジュールの実行(ターゲット依存)
#
# ESP32-S3ポート本体のscripts/run_qemu.shと同じ手順：
#  ELF→esptool elf2image→merge_bin→Espressifフォーク版QEMU（esp32s3マシン）
#  起動。-serial stdioでUART出力を直接標準出力へ（パイプでログ取得）。
#  -semihosting＋CONFIG_OPTの-DTOPPERS_QEMUにより、ext_ker時にQEMUが
#  自動終了する（run_qemu.sh方式と同じ。QEMU終了＝テスト完了）。
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"
	local ESPTOOL="${TTSP_ESPTOOL:-$HOME/tools/espressif/python_env/idf5.5_py3.12_env/bin/python}"
	local QEMU
	QEMU=$(ls -d "$HOME"/tools/espressif/tools/qemu-xtensa/*/qemu/bin/qemu-system-xtensa 2>/dev/null | sort | tail -1)
	local TIMEOUT_SEC="${TTSP_QEMU_TIMEOUT:-60}"
	local WORKDIR
	WORKDIR=$(mktemp -d)

	if [ ! -x "$ESPTOOL" ]; then
		echo "esptool用Pythonが見つかりません: $ESPTOOL" | tee "$LOGFILE"
		rm -rf "$WORKDIR"
		return
	fi
	if [ -z "$QEMU" ] || [ ! -x "$QEMU" ]; then
		echo "QEMU(qemu-system-xtensa)が見つかりません" | tee "$LOGFILE"
		rm -rf "$WORKDIR"
		return
	fi

	"$ESPTOOL" -m esptool --chip esp32s3 elf2image \
		--flash_mode dio --flash_size 2MB --flash_freq 80m \
		-o "$WORKDIR/app.bin" fmp >/dev/null 2>&1

	"$ESPTOOL" -m esptool --chip esp32s3 merge_bin \
		--output "$WORKDIR/flash.bin" --fill-flash-size 2MB \
		--flash_mode dio --flash_freq 80m --flash_size 2MB \
		0x0 "$WORKDIR/app.bin" >/dev/null 2>&1

	timeout "$TIMEOUT_SEC" "$QEMU" -M esp32s3 -m 32M -semihosting \
		-drive file="$WORKDIR/flash.bin",if=mtd,format=raw \
		-nic user,model=open_eth -nographic \
		< /dev/null > "$LOGFILE" 2>&1

	rm -rf "$WORKDIR"
	cat "$LOGFILE"
}

#
# 並列API実行用のQEMU起動関数（scripts/ttsp_parallel_api.sh参照）
#
# 並列ドライバはターゲットが`parallel_simulation`関数を定義していれば
# （`declare -f parallel_simulation`で検出）、各auto_code_Nディレクトリを
# カレントディレクトリとして`bash -c parallel_simulation`で呼ぶ（zybo等の
# 既定パスはqemu-system-armへ直接ハードコードされておりXtensaでは使えない
# ため、本ポートは`parallel_simulation`を定義してこの経路を使う）。
# カレントディレクトリの$KERNEL_NAME（fmp）を実行し、execute.logへ出力する
# ことが呼び出し側の規約。simulation()と同じ手順（elf2image→merge_bin→
# QEMU起動）だが、echoでの追加出力はせずexecute.log生成のみ行う。
#
parallel_simulation()
{
	local ESPTOOL="${TTSP_ESPTOOL:-$HOME/tools/espressif/python_env/idf5.5_py3.12_env/bin/python}"
	local QEMU
	QEMU=$(ls -d "$HOME"/tools/espressif/tools/qemu-xtensa/*/qemu/bin/qemu-system-xtensa 2>/dev/null | sort | tail -1)
	local WORKDIR
	WORKDIR=$(mktemp -d)

	if [ ! -x "$ESPTOOL" ] || [ -z "$QEMU" ] || [ ! -x "$QEMU" ]; then
		echo "esptool/QEMUが見つかりません" > execute.log
		rm -rf "$WORKDIR"
		return
	fi

	"$ESPTOOL" -m esptool --chip esp32s3 elf2image \
		--flash_mode dio --flash_size 2MB --flash_freq 80m \
		-o "$WORKDIR/app.bin" fmp >/dev/null 2>&1

	"$ESPTOOL" -m esptool --chip esp32s3 merge_bin \
		--output "$WORKDIR/flash.bin" --fill-flash-size 2MB \
		--flash_mode dio --flash_freq 80m --flash_size 2MB \
		0x0 "$WORKDIR/app.bin" >/dev/null 2>&1

	"$QEMU" -M esp32s3 -m 32M -semihosting \
		-drive file="$WORKDIR/flash.bin",if=mtd,format=raw \
		-nic user,model=open_eth -nographic \
		< /dev/null > execute.log 2>&1

	rm -rf "$WORKDIR"
}
