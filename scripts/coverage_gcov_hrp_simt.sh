#!/bin/bash
#
#  TTSP3 HRP simt（タイマドライバシミュレータ）ターゲット用 SOM カバレッジランナー
#
#  zybo+simt（カーネル target = simtimer_zybo_z7_gcc）で，時間区画スケジューリング
#  （SOM）のテストを 1 テスト 1 バイナリでビルド→QEMU 実行→gcov 集計する．
#  実機タイマ（zybo_z7_gcc）では周期稼働中アイドルがハングして到達不能だった
#  (b)（_kernel_twd_switch / _kernel_scyc_switch / _kernel_twdtimer_* 等）を，
#  simt（simtim_advance／dly_tsk による決定論的時刻制御）で計測する．
#
#  使い方:
#    ./scripts/coverage_gcov_hrp_simt.sh
#
#  環境変数:
#    OBJ_DIR      : ワークディレクトリ（既定 obj_hrp_simt）
#    QEMU_TIMEOUT : QEMU 1 実行のタイムアウト秒（既定 120）
#
#  前提:
#    - カーネル side の simt ターゲット hrp3/target/simtimer_zybo_z7_gcc が存在
#    - TTSP side の library/HRP/target/simtimer_zybo_z7_gcc が存在
#    - QEMU = システムの qemu-system-arm（xilinx-zynq-a9）
#
#  対象テスト:
#    api_test/HRP/sys_manage/{chg_som,get_som,twd_som}/*.yaml
#    （chg_som/get_som は通常 bb の SOM 隔離群でも計測するが，simt でも実行して
#      domain.c の (a)+(b) を一括 union 集計する．twd_som は simt 専用＝
#      ttsp_simt_advance / dly_tsk で窓・周期境界を跨ぐ (b) テスト．）
#
#  注意:
#    - check_library は REF_MK 生成と simt ターゲット検証のため exception のみ
#      ビルド/実行する．timer は simt の gain_tick が窓スケールに不適のため除外．
#    - カーネル(hrp3)編集は不要（TTSP 側のみ）．simt カーネル target の追加は
#      別途 SVN（hrp3/target/simtimer_zybo_z7_gcc・docs/HRP/SIMT_HANDOFF.md）．
#
set -u
cd "$(dirname "$0")/.."

OBJ_DIR="${OBJ_DIR:-obj_hrp_simt}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"

export TTSP_TARGET_NAME=simtimer_zybo_z7_gcc

test -d ../hrp3 || { echo "ERROR: ../hrp3 (sibling kernel) not found"; exit 1; }
test -d hrp3/target/simtimer_zybo_z7_gcc 2>/dev/null || \
test -d ../hrp3/target/simtimer_zybo_z7_gcc || {
	echo "ERROR: hrp3/target/simtimer_zybo_z7_gcc が無い（simt カーネル target 未配置）"; exit 1; }
test -d library/HRP/target/simtimer_zybo_z7_gcc || {
	echo "ERROR: library/HRP/target/simtimer_zybo_z7_gcc が無い（TTSP simt target 未配置）"; exit 1; }

# assert を無効化＋ASP/FMP と同条件のインライン抑制でカバレッジ計測
export COPTS="${COPTS:+$COPTS }-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions -DNDEBUG"

echo "===== clean stale objects for NDEBUG rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true
find "$OBJ_DIR" -name "*.gcno" -delete 2>/dev/null || true

run_qemu() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" qemu-system-arm \
		-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
		-nographic -smp 1 -kernel hrp < /dev/null > execute.log 2>&1 )
}

#
#  1) check_library exception を simt でビルド/実行（REF_MK 生成・ターゲット検証）
#
#  ttb.sh の check メニュー: 'c' → 2(exception) → 1 → r r → q
#  （timer=4 は simt でハングするため使わない）
#
echo "===== build & run: check_library/exception (simt, GCOV instrumented) ====="
printf 'c\n2\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../hrp3/ HRP "$OBJ_DIR" > "/tmp/simt_chk_$$.log" 2>&1

REF_MK="$OBJ_DIR/check_library/exception/Makefile"
if [ ! -f "$REF_MK" ]; then
	echo "ERROR: REF_MK 生成失敗（check_library/exception ビルド失敗）"
	tail -25 "/tmp/simt_chk_$$.log"
	exit 1
fi

dirs=""
cdir="$OBJ_DIR/check_library/exception"
if [ -f "$cdir/hrp" ]; then
	echo "run check_library/exception: $(tr -d '\r' < "$cdir/execute.log" 2>/dev/null | tail -1)"
	dirs="$dirs $cdir"
fi

#
#  2) SOM テスト（chg_som/get_som/twd_som）を 1 テスト 1 バイナリで
#
echo "===== build & run: SOM tests on simt (1 test/binary) ====="
source ./configure.sh
source "./library/HRP/target/${TARGET_NAME}/ttsp_target.sh"
TTG_ABS=$(realpath "$TTG_BIN")
SOM_TTG_OPT="-h --out_file_name out --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"

SOM_YAMLS=$(find api_test/HRP/sys_manage/chg_som \
				api_test/HRP/sys_manage/get_som \
				api_test/HRP/sys_manage/twd_som \
				-name '*.yaml' 2>/dev/null | sort)

for som_yaml in $SOM_YAMLS; do
	som_name=$(basename "$som_yaml" .yaml)
	som_abs=$(realpath "$som_yaml")
	# REF_MK（check_library/exception）と同じディレクトリ深さに置く
	# （生成 Makefile の SRCDIR が相対パスのため深さを合わせる必要がある）
	som_dir="$OBJ_DIR/check_library/som_${som_name}"
	rm -rf "$som_dir"; mkdir -p "$som_dir/objs"
	cp "$REF_MK" "$som_dir/Makefile"
	( cd "$som_dir" \
		&& ruby "$TTG_ABS" $SOM_TTG_OPT "$som_abs" > result_ttg.log 2>&1 \
		&& { grep -q 'libgcov.a' out.cfg || \
			printf 'KERNEL_DOMAIN {\n\tATT_MOD("libgcov.a");\n\tATT_MOD("librdimon.a");\n}\n' >> out.cfg; } \
		&& make ENABLE_GCOV=true -j4 > result_make.log 2>&1 )
	if [ -f "$som_dir/hrp" ]; then
		run_qemu "$som_dir"
		echo "run som/$som_name: $(tr -d '\r' < "$som_dir/execute.log" | tail -1)"
		dirs="$dirs $som_dir"
	else
		echo "BUILD FAIL: som/$som_name"
		tail -8 "$som_dir/result_ttg.log" "$som_dir/result_make.log" 2>/dev/null
	fi
done

#
#  3) gcov 集計（hrp3/kernel をフィルタ・行＋分岐C1の union）
#
echo ""
GCOV=arm-none-eabi-gcov python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ $dirs
