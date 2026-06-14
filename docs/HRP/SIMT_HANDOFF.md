# SIMT_HANDOFF.md — HRP simt ターゲット整備（M1 段階④(b) 解錠）引き継ぎ

> 目的：HRP3 の**時間区画スケジューリング（SOM）タイミングテスト**を CI で実行可能にするため、
> TTSP に **HRP 用シミュレーションタイマ（simt）ターゲット**を整備する。
> これにより Method 1 段階④(b)（`twd_switch`/`scyc_switch`/`twdtimer_stop`/dispatch/窓稼働中の E_OACV・E_MACV）が到達可能になる。
> 親計画：[`COVERAGE_RAISE_PLAN.md`](COVERAGE_RAISE_PLAN.md) Method 1。

## 1. なぜ必要か（確定済みの事実）

- M1 段階④(a)（error/state 変種）まで完了済み：**domain.c branch 6.7%→53.3%（48/90）**、chg_som 18/24・get_som 8/18、SOM隔離群9本緑（commit `8d5f03e`/`244ee62`/`8b974e7`）。
- 残り 42 分岐の大半は (b) タイミング依存。だが **zybo_z7_gcc + QEMU の実機タイマ路線では (b) は到達不能と実測確定**：
  - `somatr: TA_INISOM` で周期稼働起動＋`dly_tsk` すると、窓内に収まる 100ms（窓切替すら起こさない長さ）でも **QEMU がハング**。**gcov を外しても同様**＝性能でなくランタイム構造問題。
  - 周期を**開始するだけ**（`chg_som(SOM1)`）は緑。ハングは**周期稼働中にシステムがアイドル/待ちに入った瞬間**。
  - カーネル自身の実機タイマ版テスト（`test_tprot1`〜5）と同型の**カーネルドメイン CYCLIC 心拍**を付けても同じくハング。
  - 原因：zybo は HRT=MPCore グローバルタイマ・窓タイマ=MPCore プライベートタイマ・オーバラン=WDG（`hrp3/arch/arm_gcc/zynq7000/chip_timer.h`）。**周期稼働中の窓切替割込み/WDG の QEMU エミュレーションが非機能**。
- **解決策＝simt**：カーネルは `hrp3/test/simt_twd1.{c,cfg,h}` という**シミュレーションタイマ版** SOM テストを持つ。同じ `DEF_SCY`/`CRE_SOM`/`ATT_TWD` 構成を、テストが **`DO(simtim_advance(N))`** で時間を決定論的に進めて検証する（実機タイマ emulation に依存しない）。

## 2. ゴール

1. TTSP に **HRP simt ターゲット**（`library/HRP/target/<simt名>_gcc/` の4ファイル）を追加し、QEMU でビルド→実行→gcov 取得できる。
2. **`simtim_advance(N)`** を TESRY の `do` ステップで使えるようにする（SOM テストが窓境界を決定論的に跨げる）。
3. (b) テスト（`twd_switch`/`scyc_switch`/`twdtimer_stop`/dispatch/窓稼働中の E_OACV・E_MACV）を追加し domain.c を底上げ。

## 3. 既存資産（カーネル側 simt 基盤・**そのまま使える**）

| 場所 | 内容 |
|---|---|
| `hrp3/arch/simtimer/sim_timer.{c,h}` | **ソフトウェアで HRT/TWD/OVR を全エミュレート**。公開IF `simtim_advance(uint_t time)`（`sim_timer.h:139`）。`target_hrt_*`/`target_twdtimer_*`/`target_ovrtimer_*`/`target_custom_idle` を提供。 |
| `hrp3/arch/simtimer/tSimTimerCntl*.c`、`sim_timer_cntl.h` | simt 制御アダプタ（TECS）。 |
| `hrp3/target/simtimer_ct11mpcore_gcc/` | **完成済みの ARM + simt ターゲット**（target_timer.c/.cfg/.trb、target.cdl、Makefile.target に `SIMTIMERDIR=$(SRCDIR)/arch/simtimer` と `sim_timer.o`）。`TOPPERS_USE_QEMU` 対応。**TTSP HRP simt ターゲットの雛形**。 |
| `hrp3/target/simtimer_macos_xcode/` | host(macOS) simt 版（POSIX）。参考。 |
| `hrp3/test/simt_twd1.{c,cfg,h}` | **simt での SOM テスト実例**。`simt_twd1.h`：`SYSTEM_CYCLE 1000`/`TWD_DOM1_TIME 500`。`simt_twd1.c`：`DO(simtim_advance(499U))`→`(10U)`→`(1U)` と窓境界直前まで刻む。**(b) テスト設計の手本**。 |

## 4. TTSP 側の現状（接続先）

- TTSP HRP ターゲット雛形：`library/HRP/target/zybo_z7_gcc/`（`ttsp_target_test.{c,h}`・`ttsp_target.sh`・`ttsp_target.cfg`）。AGENTS.md §6 の4ファイル構成。
- **時間進行の plumbing は既にある**：
  - `library/HRP/target/zybo_z7_gcc/ttsp_target_test.c:88` `ttsp_target_gain_tick()`（zybo は GTC ビジーループで早送り＝実機タイマ前提）。
  - TTG：`tools/ttg/bin/builder/CBuilder.rb:379` で `#define ttsp_target_gain_tick() cal_svc(TTSP_FN_GAIN_TICK,…)`。`gain_time` variation／`is_all_gain_time_mode?`（`tools/ttg/bin/product/IntermediateCode.rb:122`）。テストデータ例 `tools/ttg/test/just_in_case/asp/gain_time_*.yaml`。
  - **→ simt ターゲットでは `ttsp_target_gain_tick`（または新 SVC）を `simtim_advance(固定tick)` に差し替えるのが素直**。ただし SOM 窓切替は「窓長ぴったりに進める」必要があり、固定 tick では粒度が粗い。**`simtim_advance(N)` に任意 N を渡せる do ステップ**（例 `do: { syscall: ttsp_simt_advance(N) }`）を新設するのが本命（`simt_twd1.c` の `DO(simtim_advance(N))` に相当）。
- SOM 隔離ビルド群：`scripts/coverage_gcov_hrp.sh` の「SOM tests (isolated, 1 test/binary)」節（`find api_test/HRP/sys_manage/{chg_som,get_som}`）。simt 版は別ランナー or 本節の simt 対応が要る。
- 既存 SOM テスト：`api_test/HRP/sys_manage/{chg_som,get_som}/*.yaml`（9本・全緑）。`exclude_tests.txt`（zybo）で通常bbから除外済み。

## 5. 推奨プラン（フェーズ・spike 先行）

### Phase 0：feasibility spike — ✅ **完了・成功（2026-06-14）**
**目的**：simt での SOM 窓切替が QEMU で動くことを最小コストで確認し、プロジェクト全体を de-risk。
**結果**：カーネルの `simt_twd1`（DEF_SCY/CRE_SOM/ATT_TWD＋HRP3 保護＋simtimer arch）を `simtimer_ct11mpcore_gcc`
で**ビルド成功→QEMU(realview-eb-mpcore)で「All check points passed.」（全22チェックポイント）**。
`simtim_advance(N)` で時間を決定論的に進める simt 方式は **QEMU でハングせず動く**ことを実証。**→ simt 路線確定（案A 有望）**。

**再現レシピ（カーネル編集なし・/tmp で完結）**：
```sh
HRP3=$(realpath hrp3); TTSP=$(realpath ttsp3)
B=/tmp/simt_spike; rm -rf "$B"; mkdir -p "$B"; cd "$B"
# 1) configure：ターゲット=simtimer_ct11mpcore_gcc、app=simt_twd1、要 -DHRT_CONFIG1 -DSIMTIM_TEST
ruby "$HRP3/configure.rb" -T simtimer_ct11mpcore_gcc -A simt_twd1 -a "$HRP3/test" \
     -c "$HRP3/test/simt_twd1.cfg" -o "-DTOPPERS_USE_QEMU -DHRT_CONFIG1 -DSIMTIM_TEST"
# 2) app CDL：TECS テストサービス(check_point 等)を wire する手本 test_pf.cdl を APPLNAME.cdl として配置
cp "$HRP3/test/test_pf.cdl" ./simt_twd1.cdl
# 3) build
make
# 4) run（CT11MPCore = QEMU realview-eb-mpcore・semihosting）
qemu-system-arm -M realview-eb-mpcore -semihosting -m 256M -serial mon:stdio -nographic -kernel hrp
#   → "All check points passed."（semihosting 終了で qemu 終了コードは非0だがハングではない）
```
**ハマりどころ（解決済・記録）**：
- TECS app CDL が要る（APPLNAME.cdl）。`library/HRP/test/out.cdl` は SerialPort 前提で不足→
  **`hrp3/test/test_pf.cdl`（tTestService/tTestServiceAdapter＋SysLog＋Banner＋target.cdl）が正解**（check_point 等が解決）。
- `simt_twd1.c` は `-DHRT_CONFIG1`（TSTEP_HRTCNT 等の HRT 構成）と `-DSIMTIM_TEST` を**両方**要求（無いと #error）。
- 出力は低レベル PutLog（semihosting）。SerialPort セルは不要。

### Phase 1（カーネル側）：✅ **完了・gcov 検証まで成功（2026-06-14・案B＝zybo+simt 採用）**
ユーザ判断で**案B（zybo+simt・新ターゲット dir 方式）を採用**（gcov・QEMU・TTSP ツールを丸ごと再利用できるため）。
**カーネル新ターゲット `hrp3/target/simtimer_zybo_z7_gcc/`（SVN・未コミット・各ファイル冒頭に【改変】明記）を作成し、end-to-end 検証に成功**：

- **構成**：zybo_z7_gcc を `TARGETDIR2` として流用し、MPCore ハードウェアタイマ（`mpcore_timer.o`）の代わりに
  タイマドライバシミュレータ（`arch/simtimer/sim_timer.o` ＋ 本target の `target_timer.o`）を用いる。
  HRT＝MPCore グローバルタイマ割込み(27)、TWD＝プライベートタイマ割込み(29)、OVR＝ウォッチドッグ割込み(30)の
  番号を流用し、`raise_int()`（GIC set-pending/SGI）で simt から割込みを生成。**gcov・MMU・GIC・シリアル・起動部・
  リンカスクリプト(.gcov_info)は zybo を流用**。
- **作成ファイル**（14個）：Makefile.target / target_timer.{c,h,cfg} / target.cdl（SimTimerCntl 追加）/
  target_kernel.h（HRTCNT_BOUND・HRT_CONFIG）/ target_kernel_impl.h（TOPPERS_CUSTOM_IDLE）/
  target_stddef.h（TOPPERS_SIMTIMER）/ target_rename.{def,h}・target_unrename.h（simt 関数リネーム）/ MANIFEST 等。
- **検証結果**：
  1. `simt_twd1` を `simtimer_zybo_z7_gcc` でビルド→**QEMU `xilinx-zynq-a9` で「All check points passed.」（全22CP・ハングなし）**。
  2. **gcov 計装ビルド（`ENABLE_GCOV=true`＋`ATT_MOD("libgcov.a")/("librdimon.a")`）→ QEMU 緑 → .gcda 79個（domain.gcda 含む）取得**。
  3. `ttsp_gcov_report.py` で集計成功。**(b) の核心分岐が点灯**：`_kernel_twd_switch` 0→5/10、`_kernel_scyc_switch` 0→1/2、
     `_kernel_twdtimer_stop` 0→2/2、`_kernel_twdtimer_start` 1→2/2、`_kernel_twd_start` 5→7/10（実機タイマ zybo+QEMU では
     ハングで到達不能だった分岐）。＝**simt が (b) を解錠することを実証**。
- **再現レシピ**：
  ```sh
  HRP3=$(realpath hrp3)
  cat > /tmp/B/spike_gcov.cfg <<EOF
  INCLUDE("$HRP3/test/simt_twd1.cfg");
  KERNEL_DOMAIN { ATT_MOD("libgcov.a"); ATT_MOD("librdimon.a"); }
  EOF
  ruby "$HRP3/configure.rb" -T simtimer_zybo_z7_gcc -A simt_twd1 -a "$HRP3/test" \
       -c /tmp/B/spike_gcov.cfg -o "-DTOPPERS_USE_QEMU -DHRT_CONFIG1 -DSIMTIM_TEST"
  cp "$HRP3/test/test_pf.cdl" ./simt_twd1.cdl
  make ENABLE_GCOV=true
  qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio -nographic -smp 1 -kernel hrp
  ```

#### Phase 2（TTSP 統合）— ✅ 完了（2026-06-14）：**domain.c branch 6.7%→65.6%**
> **専用ランナー `scripts/coverage_gcov_hrp_simt.sh` で SOM テスト全11本（chg_som/get_som/twd_som）を simt ターゲットで
> ビルド→QEMU→gcov union 集計し，domain.c を (a)＋(b) で一括計測：line 89.8%(168/187)・branch 65.6%(59/90)。
> 全11本緑。**（a)53.3%→(b)込み 65.6%へ＝simt の twd_som(twd_switch/scyc_switch) が +12pt 押上げ。****

- ✅ **TTSP target `library/HRP/target/simtimer_zybo_z7_gcc/` 作成**（zybo の4ファイルを複製・改変）：
  - `ttsp_target.sh`：`KERNEL_COBJS_TARGET` を `mpcore_timer.o`→`target_timer.o sim_timer.o` に変更、`CONFIG_OPT` に `-DHRT_CONFIG1` 付与。
    **`-DSIMTIM_TEST` は付けない**（カーネルの simt テスト専用＝hook_hrt_* を要求するため。TTSP テストは未定義でリンク不能）。
  - `ttsp_target_test.c`：`ttsp_target_gain_tick`→`simtim_advance(TTSP_SIMT_GAIN_STEP)`、`stop/start_tick` は no-op（simt は時刻制御済）。
- ✅ **パイプライン検証**：`TTSP_TARGET_NAME=simtimer_zybo_z7_gcc OBJ_DIR=obj_hrp_simt bash scripts/coverage_gcov_hrp.sh smoke`
  で **check_library exception/interrupt が「All check points passed」**（gcov 計装・QEMU xilinx-zynq-a9）。
  ＝**TTSP build→simt カーネル→QEMU→gcov の統合パイプラインが動作**。
- ✅ **`ttsp_simt_advance(N)` を TESRY do 語彙に追加**（精密 advance）：拡張SVC で `simtim_advance(N)` を呼ぶ．
  - `library/HRP/test/ttsp_test_lib.h`：`TTSP_FN_SIMT_ADVANCE (TTSP_FN_BASE + 121)`。
  - `tools/ttg/bin/builder/CBuilder.rb`：`#define ttsp_simt_advance(time) cal_svc(TTSP_FN_SIMT_ADVANCE,...)`（HRP 用 SVC 化ブロック）。
  - **ハンドラ・DEF_SVC は simt ターゲットのみ**（`ttsp_target_test.c`＝`svc_ttsp_simt_advance`／`ttsp_target.cfg`＝`DEF_SVC`／`ttsp_target_test.h`＝宣言）。
    非simt の `ttsp_target.cfg` は空なので他ターゲットに影響なし。
- ✅ **(b) テスト `api_test/HRP/sys_manage/twd_som/twd_som_W-a.yaml`**（`exclude_tests.txt` で通常bb除外）：
  TA_INISOM＋窓(twdlen 500/scytim 1000)＋`ttsp_simt_advance(N)` で境界跨ぎ。simt ターゲットで**ビルド緑・gcov 取得**し、
  **`_kernel_scyc_switch` 0→1/2・`scyc_start` 3/4・`twdtimer_*`・`twd_start` 5/10 を TTSP フレームワーク経由で点灯**を確認。
  ＝**ttsp_simt_advance 機構が end-to-end で動作**（TESRY→simt→QEMU→gcov）。
- ✅ **`twd_switch` 点灯（dly_tsk＝idle 文脈・2026-06-14）**：`twd_som_W-b.yaml`＝`ttsp_simt_advance` の代わりに
  カーネルドメインタスクが **`dly_tsk(N)` で休止→システムがアイドル→`target_custom_idle` がシミュレーション時刻を
  次イベントへ進める**ため、窓境界(500)でウィンドウ切替割込みが **idle 文脈(dspflg真)で発火**＝`_kernel_twd_switch`
  **0→13/16 line・3/6 branch**、`twd_start` 5→7/10、`scyc_switch` 1/2、domain.c **31→38.9% branch**。
  ＝**TTSP フレームワーク経由で (b) の本丸 twd_switch を点灯**（simt＋dly_tsk）。
  - 知見：時間進行を **SVC（タスク稼働中）でやると窓切替が twd_switch を経ない**が、**dly_tsk（アイドル）だと
    custom_idle 経由で twd_switch が発火**する。(b) 窓切替テストは **dly_tsk 型**が本命。`ttsp_simt_advance(N)` は
    scyc/overrun 等の明示制御に有用（W-a）。
- ✅ **`set_dspflg` 1/4→3/4（dis_dsp 中の保留切替・2026-06-14）**：`twd_som_W-d.yaml`＝周期稼働中に `dis_dsp()`→窓内に
  収まる `ttsp_simt_advance`→`ena_dsp()` で `set_dspflg` の **pending 両偽（if-F＋elseif-F）経路**を点灯（chg_som_H-g が
  pending_scycswitch=true の if-T を既達）。domain.c **65.6→67.8%(61/90)**。
  - **残 1/4＝`else if(pending_twdswitch)` TRUE＝構造的に到達不能（2026-06-14 調査確定）**：
    pending_twdswitch=true は **ウィンドウ切替割込みが dspflg 偽のときに twd_switch の else を通る**必要があるが：
    - SVC(`ttsp_simt_advance`)経由の advance は dis_dsp 中でも窓切替割込みを twd_switch へ届けない（W-c で twd_switch 0/16）。
    - idle(`dly_tsk`)advance は dspflg 真（W-b で if 側 13/16）。`dis_dsp` はタスク文脈専用（ハンドラでは E_CTX）。
    - **アラーム発火＋窓切替の同時刻**も試したが、(a) TTG が T5_005/013（caller の活性/ercd 検査）で弾く、(b) simt の
      `target_custom_idle` は**次イベントを1つずつ発火しハンドラ完了後に次へ進む**ため、ハンドラ実行(dspflg偽)中に
      別の窓切替割込みを重ねられない＝**同時刻イベントの dspflg 偽コインシデンスが作れない**。
    - **決定的事実：カーネル自身の `hrp3/test/simt_twd1` でも set_dspflg は 0/4**（twd_switch 13/16 は到達するが pending 系は未到達）。
      ＝upstream の SOM テストでも未カバーの corner case。本 TTSP テスト群は **3/4** で **upstream(0/4)を上回る**。
    → **set_dspflg elseif-T は到達不能として文書化**（実機 or 多重割込みネスト等の別アーキ前提が要る）。
- **残（小）**：twd_switch/scyc_switch の残 branch（複数窓・SOM 切替・dispatch）、set_dspflg の elseif-T（上記）。

#### 残：Phase 2 続き — 次セッション
1. **TTSP target** `library/HRP/target/simtimer_zybo_z7_gcc/`（4ファイル）：zybo の TTSP target を複製し、`ttsp_target_test.{c,h}`・
   `ttsp_target.sh`（`OS_TARGET=simtimer_zybo_z7_gcc`・USE_QEMU・gcov）・`ttsp_target.cfg`。`ttsp_target_gain_tick`→`simtim_advance`。
   ただし TTG 生成テスト（out.c）は `-DHRT_CONFIG1 -DSIMTIM_TEST` が要る＋app CDL に tTestService 不要（TTSP は ttsp_check_point）
   →TTSP の out.cdl（SerialPort 型）で良いか要確認（kernel test の test_pf.cdl とは別系統）。
2. **`simtim_advance(N)` を TESRY do 語彙へ**：`simt_twd1.c` の `DO(simtim_advance(N))` 相当。TTG の `gain_time`/`ttsp_target_gain_tick`
   （`CBuilder.rb:379`）を simt 用に N 指定可能化、or 専用 `ttsp_simt_advance(N)`。
3. **ランナー** `coverage_gcov_hrp_simt.sh`（R5 の `coverage_gcov_hrp_r5.sh` 雛形）：SOM テストを simt ターゲットでビルド/実行/gcov union。
4. **(b) テスト追加**：TA_INISOM＋複数 TIME_WINDOW＋`simtim_advance` で窓境界跨ぎ、ユーザドメイン窓稼働中の E_OACV/E_MACV/dispatch。

> ### （参考）当初の2案併記（Phase 0 時点）
- **案A（ct11mpcore ベース・カーネル編集なし・★Phase0で実証）**：`library/HRP/target/simtimer_ct11mpcore_gcc/`（TTSP4ファイル）を新設し、カーネル `simtimer_ct11mpcore_gcc` を使う。app CDL は `hrp3/test/test_pf.cdl` 型（TTSP の test framework=`ttsp_check_point` を使うなら TTSP 版 out.cdl を test_pf 型に作り替え）。QEMU=`realview-eb-mpcore`。gcov ツール（`scripts/`・`ttsp_gcov_report.py`）を realview-eb-mpcore 用に適応（**要検証**：ARM11/realview で gcov 計装＋.gcov_info 収集が動くか。zybo の `GCOVINFO` リージョン対策は target 依存＝ct11mpcore 版の target_mem/ldscript 調整が要るかも）。時間進行は `ttsp_target_gain_tick`→`simtim_advance`、ただし窓境界ぴったりに刻むため**任意 N を渡せる do ステップ**（Phase 2）が本命。
- **案B（zybo+simt・要カーネル編集＝禁則②・要ユーザ許可）**：新カーネル target `hrp3/target/simtimer_zybo_z7_gcc/`（zybo の MMU/保護はそのまま、timer だけ simt へ）。R5 移植（commit 94e1a3f 系・memory 参照）と同型の「カーネル編集は改変明記・ユーザ許可」フロー。TTSP の gcov 基盤（zynq-a9 QEMU）をそのまま使えるのが利点。
- 既存 `coverage_gcov_hrp.sh` の SOM 隔離群を simt ターゲットでも回せるよう分岐（または `coverage_gcov_hrp_simt.sh` 新設。R5 の `coverage_gcov_hrp_r5.sh` が雛形）。

### Phase 2：`simtim_advance(N)` を TESRY do 語彙に
- `do: { id: TASK1, syscall: <simt advance> }` で任意 N を進められる仕組み。`simt_twd1.c` の `DO(simtim_advance(N))` 相当。
- 候補：①既存 `gain_time` を simt で `simtim_advance` にマップ＋N 指定可能化、②専用 `ttsp_simt_advance(N)` SVC/関数を CBuilder で定義し TESRY から呼ぶ。TTG 改変は `CBuilder.rb`/`IntermediateCode.rb`/`CommonModule.rb`（既存 `gain_time` 周辺）。

### Phase 3：(b) テスト追加（simt 上）
- 雛形＝`simt_twd1.c`。`somatr: TA_INISOM`＋複数 TIME_WINDOW（DOM1 twdord1・DOM2 twdord2 等）。`do_*` で `simtim_advance` を窓長ぴったりに刻んで窓境界を跨ぐ → `twd_switch`/`scyc_switch`/`twdtimer_stop`/dispatch。
- 窓稼働中のユーザドメイン呼出し（TASK1 を DOM1 に置き、DOM1 窓稼働中に `chg_som`/`get_som`）→ **E_OACV/E_MACV**（(a) で不可だった分。`VIOLATE_ACPTN` はユーザドメイン呼出し必須＝`COVERAGE_RAISE_PLAN.md` 段階④メモ参照）。
- 各追加は **SOM隔離群（simt）で1テスト1バイナリ・緑＋domain.c per-function 上昇**を毎回検証（(a) と同じ作法）。

## 6. 重要な決定・リスク

- **カーネル編集の要否**：案A は不要（既存 simtimer_ct11mpcore_gcc 利用）。案B は要（禁則② → **着手前にユーザ許可**。R5 と同様に改変明記）。
- **QEMU machine 差**：ct11mpcore（realview 系）か zynq-a9 か。gcov 取得（`arm-none-eabi-gcov` JSON 集計＝`scripts/ttsp_gcov_report.py`）が両者で動くか要確認。zybo の gcov overlap 対策（`GCOVINFO` リージョン・memory §M6）は target 依存。
- **simt と保護ドメイン**：simt_twd1 は HRP3（保護＋SOM）で動く実例なので両立は確認済み。
- **TECS**：HRP は syssvc が TECS 化（方式A）。simt ターゲットの target.cdl/MANIFEST を正しく取り込むこと（ct11mpcore のものを参照）。

## 7. 現在のリポジトリ状態（このセッション終了時点）

- ブランチ：`main`。直近コミット：
  - `3d76f00` docs M1(b) 解決の道筋＝simt（本調査）
  - `d1c8eaa` docs M1(b) は zybo+QEMU で到達不能と確定
  - `8b974e7` M1 段階④(a) batch3（chg_som dspflg=false）
  - `244ee62` M1 段階④(a) batch2（E_CTX）
  - `8d5f03e` M1 段階④(a) batch1（E_ID/E_OBJ/短絡/get_som稼働中）
  - `67f6012` feat M1 SOM TTG 組み込み PoC（型 SYSTEM_CYCLE/SYSTEM_OPERATION_MODE/TIME_WINDOW）
- 未コミットの試作は revert 済（hang する TA_INISOM+dly/CYCLIC 心拍テストは削除）。SOM テストは 9本（全緑）が正。
- TTG 拡張済み（型3種）：`tools/ttg/common/bin/sys_state/SystemCycle.rb`、`tools/ttg/{common,ttc}` 各所、`CommonModule.rb`。

## 8. まず読むべきファイル（新セッション）

1. 本書（全体像）→ [`COVERAGE_RAISE_PLAN.md`](COVERAGE_RAISE_PLAN.md) Method 1（特に「⛔(b)は到達不能」節と段階④メモ）。
2. `hrp3/test/simt_twd1.{c,cfg,h}`（(b) の手本）＋ `hrp3/arch/simtimer/sim_timer.h`（simtim_advance）。
3. `hrp3/target/simtimer_ct11mpcore_gcc/`（ターゲット雛形）。
4. `library/HRP/target/zybo_z7_gcc/`（TTSP ターゲット雛形）＋ `scripts/coverage_gcov_hrp.sh`（SOM 隔離群）＋ `scripts/coverage_gcov_hrp_r5.sh`（新ターゲット追加の前例）。
