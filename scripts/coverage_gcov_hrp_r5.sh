#!/bin/bash
#
#  TTSP3 HRP（zynqmp_r5_gcc / Cortex-R5）GCOVカバレッジ計測ランナー
#
#  HRP3 の zynqmp_r5_gcc ターゲット依存部に追加した GCOV 対応
#  （ENABLE_GCOV=true：Makefile.target の計装フラグ，target_kernel_impl.c の
#  __gcov_info_to_gcda ダンプ＋セミホスティング書き出し＋QEMU 終了，
#  target_ldscript.trb の GenerateProvide，chip_ldscript.trb の GenerateProvide
#  フック呼出し，target_mem.cfg の .gcov_info 配置）を使い，計装ビルド→
#  QEMU 実行→gcov 集計（行＋分岐C1）を行う．zybo 版（coverage_gcov_hrp.sh）の
#  R5/MPU・upstream QEMU 版．
#
#  zybo 版との差分：
#    - ターゲット＝zynqmp_r5_gcc（TTSP_TARGET_NAME で指定）
#    - QEMU＝upstream qemu-system-aarch64（11以降．xlnx-zcu102＋loader で R5 起動）
#      ※システムの qemu 8.2.2 では不可．環境変数 QEMU_UPSTREAM で上書き可
#    - R5 の target_exit がセミホスティングで QEMU を自動終了するため，
#      stall 検出は不要（単純な timeout で十分）
#
#  使い方:
#    ./scripts/coverage_gcov_hrp_r5.sh [smoke|bb|all]
#      smoke: check_libraryのみ（既定．数分）
#      bb   : APIオートコード20分割も含む・BBテストのみ
#      all  : bb に加え手書き WBテスト（api_test/HRP/*/*_W-*/）も実行
#
#  環境変数:
#    OBJ_DIR       : ワークディレクトリ（既定 obj_hrp_r5_gcov）
#    API_DIV_NUM   : bb/all時の分割数（既定 20）
#    QEMU_TIMEOUT  : QEMU 1実行のタイムアウト秒（既定 1800）
#    QEMU_UPSTREAM : upstream qemu-system-aarch64 のパス
#                    （既定 $HOME/qemu/qemu-11.0.0/build/qemu-system-aarch64）
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
OBJ_DIR="${OBJ_DIR:-obj_hrp_r5_gcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"
QEMU_UPSTREAM="${QEMU_UPSTREAM:-$HOME/qemu/qemu-11.0.0/build/qemu-system-aarch64}"

export TTSP_TARGET_NAME=zynqmp_r5_gcc

test -d ../hrp3 || { echo "ERROR: ../hrp3 (sibling kernel) not found"; exit 1; }
test -x "$QEMU_UPSTREAM" || { echo "ERROR: upstream QEMU not found: $QEMU_UPSTREAM"; exit 1; }

# assert を無効化してカバレッジ計測対象から除外する
export COPTS="${COPTS:+$COPTS }-DNDEBUG"

# NDEBUG フラグ変更後は旧 .o/.gcno が stale になるため削除して再コンパイルを強制する
echo "===== clean stale objects for NDEBUG rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true
find "$OBJ_DIR" -name "*.gcno" -delete 2>/dev/null || true

run_qemu() { # $1=dir
	# R5 の target_exit がセミホスティングで QEMU を自動終了する
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" "$QEMU_UPSTREAM" \
		-M xlnx-zcu102 -smp 6 -m 2G -nographic -semihosting \
		-global xlnx-zynqmp.boot-cpu=rpu-cpu[0] \
		-global cortex-r5f-arm-cpu.mp-affinity=0 \
		-device loader,file=hrp,cpu-num=4 \
		-serial null -serial mon:stdio < /dev/null > execute.log 2>&1 )
}

echo "===== build & run: check_library (GCOV instrumented, R5) ====="
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../hrp3/ HRP "$OBJ_DIR" > "/tmp/gcov_r5_build_chk_$$.log" 2>&1
dirs=""
for d in exception interrupt timer; do
	dir=$OBJ_DIR/check_library/$d
	if [ ! -f "$dir/hrp" ]; then
		echo "retry build: check_library/$d"
		( cd "$dir" && make ENABLE_GCOV=true -j4 >> "/tmp/gcov_r5_build_chk_$$.log" 2>&1 )
	fi
	if [ ! -f "$dir/hrp" ]; then
		echo "BUILD FAIL: check_library/$d"; tail -20 "/tmp/gcov_r5_build_chk_$$.log"
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
			( cd "$wb_dir" && make ENABLE_GCOV=true -j4 > /tmp/gcov_r5_build_wb_$$.log 2>&1 )
			if [ -f "$wb_dir/hrp" ]; then
				run_qemu "$wb_dir"
				last=$(tr -d '\r' < "$wb_dir/execute.log" | tail -1)
				echo "run wb/$wb_name: $last"
				dirs="$dirs $wb_dir"
			else
				echo "BUILD FAIL: wb/$wb_name"; tail -10 /tmp/gcov_r5_build_wb_$$.log
			fi
		done
	fi
fi

echo ""
python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ $dirs
