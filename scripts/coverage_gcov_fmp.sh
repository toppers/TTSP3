#!/bin/bash
#
#  TTSP3 FMP GCOVカバレッジ計測ランナー
#
#  FMP3側の GCOV 対応（ENABLE_GCOV=true，fmp3/target/zybo_z7_gcc の
#  Makefile.target / zybo_z7.ld / target_kernel_impl.c の対応版）を使い，
#  計装ビルド→QEMU実行→gcov集計（行＋分岐C1）を行う．
#  結果は scripts/ttsp_gcov_report.py で /fmp3/kernel/ にフィルタして統合する．
#
#  使い方:
#    ./scripts/coverage_gcov_fmp.sh [smoke|bb|all]
#      smoke: check_libraryのみ（既定．数分）
#      bb   : APIオートコード20分割も含む・BBテストのみ（並列ドライバ使用で数十分程度）
#      all  : bb に加え whitebox_archive/ の手書き WBテストも実行
#
#  環境変数:
#    OBJ_DIR      : ワークディレクトリ（既定 obj_fmp_gcov）
#    API_DIV_NUM  : bb/all時の分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 1800）
#
#  ビルドオプション:
#    -DNDEBUG を COPTS 環境変数として渡す（Makefile 側で展開される）．
#    assert() はデバッグ用マクロであり，カバレッジ計測対象から除外するため
#    NDEBUG を定義して無効化する（FMP3 t_stddef.h: #ifndef NDEBUG で制御）．
#
set -u
cd "$(dirname "$0")/.."

MODE="${1:-smoke}"
case "$MODE" in
	smoke|bb|all) ;;
	*) echo "ERROR: unknown mode '$MODE' (smoke|bb|all)"; exit 1 ;;
esac
OBJ_DIR="${OBJ_DIR:-obj_fmp_gcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"

test -d ../fmp3 || { echo "ERROR: ../fmp3 (sibling kernel) not found"; exit 1; }

# カバレッジ計測用コンパイルオプション（COPTS は環境変数として渡し，
# Makefile の "COPTS := -O2 $(COPTS)" 等で -O2 の後ろに展開される＝末尾の指定が優先）
#
#  (1) -DNDEBUG : assert() を無効化しカバレッジ計測対象から除外する
#       （assert 失敗パスはデバッグ用で，仕様適合性の分岐ではないため）
#
#  (2) インライン抑制（-fno-inline 系） : -O2 を維持したまま inline 展開のみ無効化する．
#       【理由】-O2 は wait.h 等の `static inline`（TOPPERS の Inline マクロ）関数を
#       多数の呼出し元へ展開する．gcov は展開後の各 call-site インスタンスを独立に
#       計測するため，同一ソース行の分岐数が水増しされ（例: wait.h 16→64 分岐），
#       一部インスタンスが「未到達」に見える計測アーティファクトを生む．さらに
#       bb/all でビルド差により分母が変動する．inline を抑制すると各 inline 関数は
#       1 実体として計測され，ソースの論理分岐がそのまま反映され，bb/all の分母も一致する．
#       -O0 ではなく -O2 を維持するのは，codegen を production 同等に保ち，
#       -O0 で観測された実行時クラッシュ・タイミング変化を避けるため．
#       （-finline-functions-called-once は -O2 で別途 inline するため併せて抑制）
export COPTS="${COPTS:+$COPTS }-DNDEBUG -fno-inline -fno-inline-functions-called-once -fno-inline-small-functions"

# NDEBUG フラグ変更後は旧 .o/.gcno が stale になるため削除して再コンパイルを強制する
echo "===== clean stale objects for NDEBUG rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true
find "$OBJ_DIR" -name "*.gcno" -delete 2>/dev/null || true

run_qemu() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda && timeout "$QEMU_TIMEOUT" qemu-system-arm \
		-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
		-nographic -smp 2 -kernel fmp < /dev/null > execute.log 2>&1 )
}

echo "===== build & run: check_library (GCOV instrumented) ====="
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_MAKE_OPT="ENABLE_GCOV=true" \
	bash ttb.sh ../fmp3/ FMP "$OBJ_DIR" > "/tmp/gcov_build_chk_$$.log" 2>&1
dirs=""
for d in exception interrupt timer; do
	dir=$OBJ_DIR/check_library/$d
	if [ ! -f "$dir/fmp" ]; then
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
		bash scripts/ttsp_parallel_api.sh ../fmp3/ FMP "$OBJ_DIR" "$DIV_NUM"
	for i in $(seq 1 "$DIV_NUM"); do
		dir=$OBJ_DIR/api_test/auto_code_$i
		[ -f "$dir/fmp" ] && dirs="$dirs $dir"
	done
fi

if [ "$MODE" = "all" ]; then
	REF_MK="$OBJ_DIR/api_test/auto_code_1/Makefile"
	if [ -f "$REF_MK" ] && find api_test/FMP wb_test/FMP -type d -name "*_W-*" 2>/dev/null | grep -q .; then
		echo "===== build & run: WB tests (manual, *_W-* dirs) ====="
		source ./configure.sh
		source "./library/FMP/target/${TARGET_NAME}/ttsp_target.sh"
		WB_KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/spin_lock.o"
		WB_APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
		while IFS= read -r wb_src; do
			wb_name=$(basename "$wb_src")
			wb_dir="$OBJ_DIR/api_test/wb_${wb_name}"
			mkdir -p "$wb_dir/objs"
			cp "$REF_MK" "$wb_dir/Makefile"
			cp "${wb_src}/out.c" "$wb_dir/out.c"
			cp "${wb_src}/out.h" "$wb_dir/out.h"
			cp "${wb_src}/out.cfg" "$wb_dir/out.cfg"
			# 任意: custom idle 注入（カーネルのアイドル経路を使う WB テスト用）．
			# WB ディレクトリに ttsp_custom_idle.inc があれば，その test のビルドに
			# 限り COPTS へ -include で注入する（fmp3 無改変・他テストへは波及しない）．
			# 例: xsns_dpn_W-b（exception.c p_my_pcb->p_runtsk==NULL）．
			wb_extra_copts=""
			if [ -f "${wb_src}/ttsp_custom_idle.inc" ]; then
				cp "${wb_src}/ttsp_custom_idle.inc" "$wb_dir/ttsp_custom_idle.inc"
				wb_extra_copts="-include $(cd "$wb_dir" && pwd)/ttsp_custom_idle.inc"
			fi
			( cd "$wb_dir" && COPTS="${COPTS}${wb_extra_copts:+ $wb_extra_copts}" \
				make ENABLE_GCOV=true -j4 \
				KERNEL_COBJS="$WB_KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
				APPL_COBJS="$WB_APPL_COBJS_COMMON $APPL_COBJS_TARGET" \
				> /tmp/gcov_build_wb_$$.log 2>&1 )
			if [ -f "$wb_dir/fmp" ]; then
				run_qemu "$wb_dir"
				last=$(tr -d '\r' < "$wb_dir/execute.log" | tail -1)
				echo "run wb/$wb_name: $last"
				dirs="$dirs $wb_dir"
			else
				echo "BUILD FAIL: wb/$wb_name"; tail -10 /tmp/gcov_build_wb_$$.log
			fi
		done < <(find api_test/FMP wb_test/FMP -type d -name "*_W-*" 2>/dev/null | sort)
	fi
fi

echo ""
python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ $dirs
