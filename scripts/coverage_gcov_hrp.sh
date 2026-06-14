#!/bin/bash
#
#  TTSP3 HRP GCOVカバレッジ計測ランナー
#
#  HRP3側の GCOV 対応（ENABLE_GCOV=true，hrp3/target/zybo_z7_gcc の
#  Makefile.target / target_kernel_impl.c の GCOV 対応版、および
#  target_ldscript.trb の .gcov_info 収集）を使い，計装ビルド→QEMU実行→
#  gcov集計（行＋分岐C1）を行う．結果は scripts/ttsp_gcov_report.py で
#  /hrp3/kernel/ にフィルタして統合する．
#
#  HRP は保護・単一コアのため QEMU は -smp 1（SMPなし）で実行する．
#  HRP の TECSコンポーネント化 syssvc 対応として，ビルドは方式A（COBJS 非上書き）
#  を用いる（docs/HRP/COVERAGE_STATUS.md）．ttb.sh / common.sh / ttsp_parallel_api.sh
#  が HRP 分岐を持つため，本スクリプトは ENABLE_GCOV を渡すだけでよい．
#
#  使い方:
#    ./scripts/coverage_gcov_hrp.sh [smoke|bb|all]
#      smoke: check_libraryのみ（既定．数分）
#      bb   : APIオートコード20分割も含む・BBテストのみ
#      all  : bb に加え手書き WBテスト（api_test/HRP/*/*_W-*/）も実行
#
#  環境変数:
#    OBJ_DIR      : ワークディレクトリ（既定 obj_hrp_gcov）
#    API_DIV_NUM  : bb/all時の分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 1800）
#
#  ビルドオプション:
#    -DNDEBUG を COPTS 環境変数として渡す（assert をカバレッジ対象から除外）．
#
set -u
cd "$(dirname "$0")/.."

MODE="${1:-smoke}"
case "$MODE" in
	smoke|bb|all) ;;
	*) echo "ERROR: unknown mode '$MODE' (smoke|bb|all)"; exit 1 ;;
esac
OBJ_DIR="${OBJ_DIR:-obj_hrp_gcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"

test -d ../hrp3 || { echo "ERROR: ../hrp3 (sibling kernel) not found"; exit 1; }

# assert を無効化してカバレッジ計測対象から除外する
export COPTS="${COPTS:+$COPTS }-DNDEBUG"

# NDEBUG フラグ変更後は旧 .o/.gcno が stale になるため削除して再コンパイルを強制する
echo "===== clean stale objects for NDEBUG rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true
find "$OBJ_DIR" -name "*.gcno" -delete 2>/dev/null || true

run_qemu() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" qemu-system-arm \
		-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
		-nographic -smp 1 -kernel hrp < /dev/null > execute.log 2>&1 )
}

echo "===== build & run: check_library (GCOV instrumented) ====="
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../hrp3/ HRP "$OBJ_DIR" > "/tmp/gcov_build_chk_$$.log" 2>&1
dirs=""
for d in exception interrupt timer; do
	dir=$OBJ_DIR/check_library/$d
	if [ ! -f "$dir/hrp" ]; then
		echo "retry build: check_library/$d"
		( cd "$dir" && make ENABLE_GCOV=true -j4 >> "/tmp/gcov_build_chk_$$.log" 2>&1 )
	fi
	if [ ! -f "$dir/hrp" ]; then
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
		bash scripts/ttsp_parallel_api.sh ../hrp3/ HRP "$OBJ_DIR" "$DIV_NUM"
	for i in $(seq 1 "$DIV_NUM"); do
		dir=$OBJ_DIR/api_test/auto_code_$i
		[ -f "$dir/hrp" ] && dirs="$dirs $dir"
	done
fi

if [ "$MODE" = "all" ]; then
	REF_MK="$OBJ_DIR/api_test/auto_code_1/Makefile"
	if [ -f "$REF_MK" ] && compgen -G "api_test/HRP/*/*_W-*/" > /dev/null 2>&1; then
		echo "===== build & run: WB tests (manual, *_W-* dirs) ====="
		source ./configure.sh
		source "./library/HRP/target/${TARGET_NAME}/ttsp_target.sh"
		for wb_src in api_test/HRP/*/*_W-*/; do
			wb_name=$(basename "$wb_src")
			wb_dir="$OBJ_DIR/api_test/wb_${wb_name}"
			mkdir -p "$wb_dir/objs"
			cp "$REF_MK" "$wb_dir/Makefile"
			cp "${wb_src}out.c" "$wb_dir/out.c"
			cp "${wb_src}out.h" "$wb_dir/out.h"
			cp "${wb_src}out.cfg" "$wb_dir/out.cfg"
			( cd "$wb_dir" && make ENABLE_GCOV=true -j4 > /tmp/gcov_build_wb_$$.log 2>&1 )
			if [ -f "$wb_dir/hrp" ]; then
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

# ===== SOM（システム動作モード／時間区画）隔離ビルド群 =====
# DEF_SCY（システム周期）はシステム単一かつプログラム全域に効き、停止モードでは
# ユーザドメインの time event（alarm/cyclic）が発火しない。SOM テストは alarm/cyclic 等と
# 同居できず（後者がハング）、SOM 同士も DEF_SCY 単一のためマージ不可。よって
# **1テスト1バイナリ**で個別に TTG 生成→ビルド→QEMU 実行し、gcda を union 集計する。
# 通常 bb からは library/HRP/target/<TARGET>/exclude_tests.txt で除外済み。
if [ "$MODE" = "bb" ] || [ "$MODE" = "all" ]; then
	SOM_YAMLS=$(find api_test/HRP/sys_manage/chg_som api_test/HRP/sys_manage/get_som \
		-name '*.yaml' 2>/dev/null | sort)
	REF_MK="$OBJ_DIR/api_test/auto_code_1/Makefile"
	if [ -n "$SOM_YAMLS" ] && [ -f "$REF_MK" ]; then
		echo "===== build & run: SOM tests (isolated, 1 test/binary) ====="
		source ./configure.sh
		source "./library/HRP/target/${TARGET_NAME}/ttsp_target.sh"
		TTG_ABS=$(realpath "$TTG_BIN")
		SOM_TTG_OPT="-h --out_file_name out --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"
		for som_yaml in $SOM_YAMLS; do
			som_name=$(basename "$som_yaml" .yaml)
			som_abs=$(realpath "$som_yaml")
			som_dir="$OBJ_DIR/api_test/som_${som_name}"
			mkdir -p "$som_dir/objs"
			cp "$REF_MK" "$som_dir/Makefile"
			# TTG 生成 → out.cfg に libgcov/librdimon を ATT_MOD（保護カーネルの gcov
			# リンクで /DISCARD/ されるのを防ぐ。build_group と同じ処理）→ make
			( cd "$som_dir" \
				&& ruby "$TTG_ABS" $SOM_TTG_OPT "$som_abs" > result_ttg.log 2>&1 \
				&& { grep -q 'libgcov.a' out.cfg || \
					printf 'ATT_MOD("libgcov.a");\nATT_MOD("librdimon.a");\n' >> out.cfg; } \
				&& make ENABLE_GCOV=true -j4 > result_make.log 2>&1 )
			if [ -f "$som_dir/hrp" ]; then
				run_qemu "$som_dir"
				last=$(tr -d '\r' < "$som_dir/execute.log" | tail -1)
				echo "run som/$som_name: $last"
				dirs="$dirs $som_dir"
			else
				echo "BUILD FAIL: som/$som_name"
				tail -8 "$som_dir/result_ttg.log" "$som_dir/result_make.log" 2>/dev/null
			fi
		done
	fi
fi

echo ""
python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ $dirs
