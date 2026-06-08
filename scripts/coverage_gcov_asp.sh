#!/bin/bash
#
#  TTSP3 ASP GCOVカバレッジ計測ランナー
#
#  ASP3側の GCOV 対応（ENABLE_GCOV=true，asp3/target/zybo_z7_gcc の
#  Makefile.target / zybo_z7.ld / target_kernel_impl.c の対応版）を使い，
#  計装ビルド→QEMU実行→gcov集計（行＋分岐C1）を行う．
#  結果は scripts/ttsp_gcov_report.py で /asp3/kernel/ にフィルタして統合する．
#
#  使い方:
#    ./scripts/coverage_gcov_asp.sh [smoke|full]
#      smoke: check_libraryのみ（既定．数分）
#      full : APIオートコード20分割も含む（並列ドライバ使用で数十分程度）
#
#  環境変数:
#    OBJ_DIR      : ワークディレクトリ（既定 obj_asp_gcov）
#    API_DIV_NUM  : full時の分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 1800）
#
set -u
cd "$(dirname "$0")/.."

MODE="${1:-smoke}"
OBJ_DIR="${OBJ_DIR:-obj_asp_gcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"

test -d ../asp3 || { echo "ERROR: ../asp3 (sibling kernel) not found"; exit 1; }

run_qemu() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" qemu-system-arm \
		-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
		-nographic -smp 1 -kernel asp < /dev/null > execute.log 2>&1 )
}

echo "===== build & run: check_library (GCOV instrumented) ====="
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../asp3/ ASP "$OBJ_DIR" > "/tmp/gcov_build_chk_$$.log" 2>&1
dirs=""
for d in exception interrupt timer; do
	dir=$OBJ_DIR/check_library/$d
	if [ ! -f "$dir/asp" ]; then
		echo "BUILD FAIL: check_library/$d"; tail -20 "/tmp/gcov_build_chk_$$.log"
		exit 1
	fi
	run_qemu "$dir"
	last=$(tr -d '\r' < "$dir/execute.log" | tail -1)
	echo "run check_library/$d: $last"
	dirs="$dirs $dir"
done

if [ "$MODE" = "full" ]; then
	echo "===== build & run: API auto-code (${DIV_NUM}-way, GCOV, parallel) ====="
	TTSP_MAKE_OPT="ENABLE_GCOV=true" \
		bash scripts/ttsp_parallel_api.sh ../asp3/ ASP "$OBJ_DIR" "$DIV_NUM"
	for i in $(seq 1 "$DIV_NUM"); do
		dir=$OBJ_DIR/api_test/auto_code_$i
		[ -f "$dir/asp" ] && dirs="$dirs $dir"
	done
fi

echo ""
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ $dirs
