#!/bin/bash
#
#  TTSP3 HRMP GCOVカバレッジ計測ランナー
#
#  HRMP3側の GCOV 対応（ENABLE_GCOV=true，hrmp3/target/zybo_z7_gcc の
#  Makefile.target / target_kernel_impl.c の GCOV 対応版、および
#  arch/gcc/ldscript.trb の .gcov_info 収集）を使い，計装ビルド→QEMU実行→
#  gcov集計（行＋分岐C1）を行う．結果は scripts/ttsp_gcov_report.py で
#  /hrmp3/kernel/ にフィルタして統合する．
#
#  使い方:
#    ./scripts/coverage_gcov_hrmp.sh [smoke|bb|all]
#      smoke: check_libraryのみ（既定．数分）
#      bb   : APIオートコード20分割も含む・BBテストのみ
#      all  : bb に加え手書き WBテスト（api_test/HRMP/*/*_W-*/）も実行
#
#  環境変数:
#    OBJ_DIR      : ワークディレクトリ（既定 obj_hrmp_gcov）
#    API_DIV_NUM  : bb/all時の分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 1800）
#
#  ビルドオプション:
#    -DNDEBUG を COPTS 環境変数として渡す（assert をカバレッジ対象から除外）．
#
#  注意:
#    HRMP3 は TECS の初回 -include で stale な Makefile.tecsgen を掴むことがあり，
#    その場合は make を2回実行すると解消する（tecsgen が再生成）．本スクリプトは
#    ビルド失敗時に1回リトライする．
#
set -u
cd "$(dirname "$0")/.."

MODE="${1:-smoke}"
case "$MODE" in
	smoke|bb|all) ;;
	*) echo "ERROR: unknown mode '$MODE' (smoke|bb|all)"; exit 1 ;;
esac
OBJ_DIR="${OBJ_DIR:-obj_hrmp_gcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"

test -d ../hrmp3 || { echo "ERROR: ../hrmp3 (sibling kernel) not found"; exit 1; }

# assert を無効化してカバレッジ計測対象から除外する
export COPTS="${COPTS:+$COPTS }-DNDEBUG"

# NDEBUG フラグ変更後は旧 .o/.gcno が stale になるため削除して再コンパイルを強制する
echo "===== clean stale objects for NDEBUG rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true
find "$OBJ_DIR" -name "*.gcno" -delete 2>/dev/null || true

run_qemu() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" qemu-system-arm \
		-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
		-nographic -smp 2 -kernel hrmp < /dev/null > execute.log 2>&1 )
}

echo "===== build & run: check_library (GCOV instrumented) ====="
# 初回ビルド（TECS stale 対策で失敗時1回リトライ）
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../hrmp3/ HRMP "$OBJ_DIR" > "/tmp/gcov_build_chk_$$.log" 2>&1
dirs=""
for d in exception interrupt timer; do
	dir=$OBJ_DIR/check_library/$d
	if [ ! -f "$dir/hrmp" ]; then
		echo "retry build (TECS stale): check_library/$d"
		( cd "$dir" && make ENABLE_GCOV=true -j4 >> "/tmp/gcov_build_chk_$$.log" 2>&1 )
	fi
	if [ ! -f "$dir/hrmp" ]; then
		echo "BUILD FAIL: check_library/$d"; tail -20 "/tmp/gcov_build_chk_$$.log"
		exit 1
	fi
	run_qemu "$dir"
	last=$(tr -d '\r' < "$dir/execute.log" | tail -1)
	echo "run check_library/$d: $last"
	dirs="$dirs $dir"
done

if [ "$MODE" = "bb" ] || [ "$MODE" = "all" ]; then
	echo "===== build & run: API auto-code (${DIV_NUM}-way, GCOV, parallel) ====="
	TTSP_MAKE_OPT="ENABLE_GCOV=true" \
		bash scripts/ttsp_parallel_api.sh ../hrmp3/ HRMP "$OBJ_DIR" "$DIV_NUM"
	for i in $(seq 1 "$DIV_NUM"); do
		dir=$OBJ_DIR/api_test/auto_code_$i
		[ -f "$dir/hrmp" ] && dirs="$dirs $dir"
	done
fi

if [ "$MODE" = "all" ]; then
	REF_MK="$OBJ_DIR/api_test/auto_code_1/Makefile"
	if [ -f "$REF_MK" ] && compgen -G "api_test/HRMP/*/*_W-*/" > /dev/null 2>&1; then
		echo "===== build & run: WB tests (manual, *_W-* dirs) ====="
		source ./configure.sh
		source "./library/HRMP/target/${TARGET_NAME}/ttsp_target.sh"
		for wb_src in api_test/HRMP/*/*_W-*/; do
			wb_name=$(basename "$wb_src")
			wb_dir="$OBJ_DIR/api_test/wb_${wb_name}"
			mkdir -p "$wb_dir/objs"
			cp "$REF_MK" "$wb_dir/Makefile"
			cp "${wb_src}out.c" "$wb_dir/out.c"
			cp "${wb_src}out.h" "$wb_dir/out.h"
			cp "${wb_src}out.cfg" "$wb_dir/out.cfg"
			( cd "$wb_dir" && make ENABLE_GCOV=true -j4 > /tmp/gcov_build_wb_$$.log 2>&1 )
			if [ -f "$wb_dir/hrmp" ]; then
				run_qemu "$wb_dir"
				last=$(tr -d '\r' < "$wb_dir/execute.log" | tail -1)
				echo "run wb/$wb_name: $last"
				dirs="$dirs $wb_dir"
			else
				echo "BUILD FAIL: wb/$wb_name"; tail -10 /tmp/gcov_build_wb_$$.log
			fi
		done
	fi
fi

echo ""
python3 scripts/ttsp_gcov_report.py --filter /hrmp3/kernel/ $dirs
