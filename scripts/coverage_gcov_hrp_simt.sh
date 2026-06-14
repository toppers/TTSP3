#!/bin/bash
#
#  TTSP3 HRP simt（タイマドライバシミュレータ）ターゲット用 時間系カバレッジランナー
#
#  zybo+simt（カーネル target = simtimer_zybo_z7_gcc）で，実機タイマ（zybo_z7_gcc）
#  では周期稼働中アイドルがハングして到達不能な「時間に依存する」カーネルコードを，
#  simt（simtim_advance／dly_tsk による決定論的時刻制御）で計測する．
#  対象は 2 系統を一括 union 集計する：
#    M1（SOM／時間区画スケジューリング = domain.c）
#       — TTSP テスト sys_manage/{chg_som,get_som,twd_som} を 1 テスト 1 バイナリで
#         ビルド（_kernel_twd_switch / _kernel_scyc_switch / _kernel_twdtimer_* 等）．
#    M5（標準 API tail の時間系 = time_manage.c / time_event.c）
#       — カーネル付属テスト simt_systim1〜4(+_64hrt) を simt でビルド/実行
#         （get_tim/set_tim/adj_tim/tmevtb_enqueue 等．alarm.c/cyclic.c も副次的に点灯）．
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

# kernel simt_systim 系は「All check points passed」後もカーネルが
# アイドル継続するため，マーカ検出で QEMU を早期終了して時間を節約する．
# （gcov dump はテスト完走時に flush 済み．）
run_qemu_marker() { # $1=dir
	( cd "$1" && rm -f objs/*.gcda
	  qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M \
		-serial null -serial mon:stdio -nographic -smp 1 -kernel hrp \
		< /dev/null > execute.log 2>&1 &
	  qpid=$!
	  for _i in $(seq 1 "$QEMU_TIMEOUT"); do
		if grep -q 'All check points passed\|Check point .* failed\|Assertion' execute.log 2>/dev/null; then
			break
		fi
		kill -0 "$qpid" 2>/dev/null || break
		sleep 1
	  done
	  sleep 1   # gcda flush を待つ
	  kill -TERM "$qpid" 2>/dev/null; wait "$qpid" 2>/dev/null )
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
#  2b) カーネル付属 simt_systim 系（M5 time 系底上げ）を simt でビルド/実行
#
#  time_manage.c / time_event.c は実時間 zybo+QEMU ではハングして到達不能だが，
#  simt なら simt_systim1〜4(+_64hrt) で大幅に底上げできる（COVERAGE_RAISE_PLAN.md
#  Method 5 ⑤）．これらはカーネル付属テスト（TTG/TESRY 経由ではない）のため，
#  カーネル configure.rb で 1 テスト 1 バイナリでビルドする．
#
#  HRT_CONFIG 対応：simt_systim1/2/3→CONFIG1，*_64hrt→CONFIG3，simt_systim4→CONFIG2．
#
echo "===== build & run: kernel simt_systim tests (M5 time, simt) ====="
# 注意：realpath で symlink を解決しない．SOM 群（ttb.sh 経由 ../hrp3）の gcno が
# .../work/hrp3/kernel/... を記録するため，systim 群も同じ未解決パスに揃えて
# union のフィルタ（/hrp3/kernel/）と共有カーネルファイルの突合を一致させる．
KSRC="$(cd .. && pwd -L)/hrp3"
INLINE_OPT="-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions -DNDEBUG"

systim_hrtcfg() { # $1=test名 → HRT_CONFIG マクロ
	case "$1" in
		*_64hrt)     echo "-DHRT_CONFIG3" ;;
		simt_systim4) echo "-DHRT_CONFIG2" ;;
		*)           echo "-DHRT_CONFIG1" ;;
	esac
}

for systim in simt_systim1 simt_systim2 simt_systim3 \
			  simt_systim1_64hrt simt_systim2_64hrt simt_systim3_64hrt \
			  simt_systim4; do
	test -f "$KSRC/test/${systim}.c" || { echo "SKIP $systim (no source)"; continue; }
	sdir="$OBJ_DIR/systim/${systim}"
	rm -rf "$sdir"; mkdir -p "$sdir"
	hrtcfg=$(systim_hrtcfg "$systim")
	(
		cd "$sdir"
		# テスト cfg を取り込み gcov ライブラリを追加した cfg
		printf 'INCLUDE("%s/test/%s.cfg");\nKERNEL_DOMAIN { ATT_MOD("libgcov.a"); ATT_MOD("librdimon.a"); }\n' \
			"$KSRC" "$systim" > gcov.cfg
		cp "$KSRC/test/test_pf.cdl" "${systim}.cdl"
		ruby "$KSRC/configure.rb" -T simtimer_zybo_z7_gcc -t \
			-a "$KSRC/test" -A "$systim" \
			-c "$(pwd)/gcov.cfg" -C "${systim}.cdl" -D "$KSRC" \
			-o "$hrtcfg -DSIMTIM_TEST $INLINE_OPT" > configure.log 2>&1
		# configure.rb は APPLNAME.o を APPL_COBJS に入れないため注入
		sed -i "s|^\tAPPL_CXXOBJS := \$|\tAPPL_CXXOBJS := ${systim}.o|; s|^\tAPPL_COBJS := \$|\tAPPL_COBJS := ${systim}.o|" Makefile
		make ENABLE_GCOV=true -j4 > build.log 2>&1
	)
	if [ -f "$sdir/hrp" ]; then
		run_qemu_marker "$sdir"
		echo "run systim/$systim ($hrtcfg): $(tr -d '\r' < "$sdir/execute.log" | grep -E 'All check points passed|failed|Assertion' | tail -1)"
		dirs="$dirs $sdir"
	else
		echo "BUILD FAIL: systim/$systim ($hrtcfg)"
		tail -6 "$sdir/configure.log" "$sdir/build.log" 2>/dev/null
	fi
done

#
#  3) gcov 集計（hrp3/kernel をフィルタ・行＋分岐C1の union）
#
echo ""
GCOV=arm-none-eabi-gcov python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ $dirs
