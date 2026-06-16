# RUNBOOK.md — AI実行ランブック（タスク→コマンド）

> **目的**：AIエージェントが TTSP3 を**摩擦なく操作**するための、「やりたいこと → 正確なコマンド列」の操作手引き。
> 規約・禁則の正本は [`AGENTS.md`](../AGENTS.md)、合否の正本は [`docs/STATUS.md`](STATUS.md)、能力差は [`docs/TARGETS.md`](TARGETS.md)、
> 用語は [`docs/GLOSSARY.md`](GLOSSARY.md)。本書は**手続き（how）**に特化する（what/why はそれらを参照）。
>
> ⚠ **大前提（[`AGENTS.md`](../AGENTS.md) §2 禁則）**：カーネル（`../asp3 ../fmp3 ../hrp3 ../hrmp3`）は**兄弟ディレクトリの SVN・読み取り専用**。
> テストが落ちても**カーネルを編集しない**（テスト側／ターゲット依存部／仕様差分を疑う）。本リポジトリ（ttsp3）は **git-only**。

---

## 0. 最初の3手（迷ったら）

1. **合否を知りたい** → [`docs/STATUS.md`](STATUS.md) を読む。**再計測しない**（§1 に合否・§2 にカバレッジ要約）。
2. **能力・非対応・ターゲットを知りたい** → [`docs/TARGETS.md`](TARGETS.md)。
3. **動かす** → 対話 `./ttb.sh` は自動化に不向き。**非対話スクリプト（`scripts/`）を使う**（本書 §2〜）。

---

## 1. 用語の最小セット（詳細は GLOSSARY）

| 略語 | 意味 |
|---|---|
| **TTG** | テストプログラム生成ツール（Ruby）。TESRY(yaml) → C/cfg を生成。`tools/ttg/` |
| **TESRY** | テスト記述データ（yaml）。`api_test/<PROFILE>/.../*.yaml` |
| **BB / bb** | API オートコード（20分割の auto_code_N）＋ check_library。ブラックボックス |
| **WB** | 手書きホワイトボックステスト（`wb_test/<PROFILE>/` または `*_W-*`） |
| **check_library** | ターゲット依存チェック（exception / interrupt / timer） |
| **gcov union** | 複数 OBJ_DIR の .gcda を `ttsp_gcov_report.py` で合算した分岐(C1)カバレッジ |
| **simt** | タイマドライバシミュレータ target。実機タイマでハングする時間系を決定論的に計測 |

---

## 2. カバレッジを計測する（最頻タスク）

> **計測条件の統一が重要**：ASP/FMP は元から `-fno-inline` 系を付与。HRP/HRMP は従来 `-DNDEBUG` のみだったため、
> **3プロファイル比較には `COPTS` にインライン抑制を渡す**（`-O2` の `static inline` 展開による分岐水増し＝wait.h 等を除去）。
> これを揃えないと分母（全分岐数）がズレて比較不能になる。

### プロファイル別の1行コマンド＋集計

| プロファイル | 計測コマンド | union 集計（数値の再生成） |
|---|---|---|
| **ASP** | `bash scripts/coverage_gcov_asp.sh all` | `python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*` |
| **FMP** | `bash scripts/coverage_gcov_fmp.sh all` | `python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ obj_fmp_gcov/check_library/* obj_fmp_gcov/api_test/auto_code_*` |
| **HRP (zybo)** | `COPTS="-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions" bash scripts/coverage_gcov_hrp.sh bb` | `python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/ obj_hrp_gcov/check_library/* obj_hrp_gcov/api_test/auto_code_*` |
| **HRMP** | `COPTS="-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions" bash scripts/coverage_gcov_hrmp.sh bb` | `python3 scripts/ttsp_gcov_report.py --filter /hrmp3/kernel/ obj_hrmp_gcov/check_library/* obj_hrmp_gcov/api_test/auto_code_*` |
| **HRP R5（MPU）** | `bash scripts/coverage_gcov_hrp_r5.sh bb` ※要 upstream QEMU aarch64・`xlnx-zcu102` | （ランナーが末尾に union を出力） |
| **HRP simt（SOM/時間系）** | `bash scripts/coverage_gcov_hrp_simt.sh` | （ランナーが末尾に union を出力。手動は §5 参照） |

- `coverage_gcov_*.sh` の引数：`smoke`（check_library のみ・数分）/ `bb`（+API auto-code 20分割）/ `all`（+WB）。
- **環境変数**：`OBJ_DIR`（作業dir）/ `API_DIV_NUM`（分割数 既定20）/ `QEMU_TIMEOUT`（秒）。
- `arm-none-eabi-gcov` を使う場合は集計コマンド頭に `GCOV=arm-none-eabi-gcov` を付ける（HRP/simt の例多数）。

### 手書きアセンブリ(.S)の網羅（C0+C1・QEMU / gcov 非対応部）

gcov で計測できない手書きアセンブリ（`arch/arm_gcc/common/{start,core_support,gic_support}.S`）の
**命令/行網羅(C0) と分岐網羅(C1)** を QEMU 実行から取得する。原理は「実行された命令アドレス集合を
QEMU `-d` ログから収集し addr2line で `.S` の行へ逆マッピング／TB 遷移エッジで分岐の taken/fall を判定」。
ツールは `scripts/asmcov/`（`asm-coverage-demo` から無改変ベンダリング）、ランナーは下記。

```bash
bash scripts/coverage_asmcov_zybo.sh smoke              # ASP3 check_library のみ（数分）
bash scripts/coverage_asmcov_zybo.sh bb                 # + API auto-code 20分割を統合
PROFILE=HRP  bash scripts/coverage_asmcov_zybo.sh smoke # HRP（単一コア）
PROFILE=FMP  bash scripts/coverage_asmcov_zybo.sh smoke # FMP（SMP・-smp 2）
PROFILE=HRMP bash scripts/coverage_asmcov_zybo.sh smoke # HRMP（SMP・-smp 2）
```

- **4プロファイル対応**：`PROFILE=ASP|HRP|FMP|HRMP`（OS_PATH は既定でプロファイル別 `../asp3/` 等）。
  FMP/HRMP は **SMP（`-smp 2`）** で実行。C0 はコア順序非依存で SMP 安全、C1 は branchcov が
  `Trace <cpu>:` のコア番号でエッジ復元をコア別に分離（交錯ログでも偽エッジ混入なし）。コア数は `SMP_NCPU` で上書き可。

- 出力：`obj_asp_asmcov/asmcov/asmcov_merged.info`（DA+BRDA）、`.../html/index.html`（`genhtml --branch-coverage`）。
- **DWARF の要点**：gcc13.2 既定の DWARF5 だと `.debug_line_str` がリンク時に脱落し addr2line が `.S` の
  ファイル名を解決できない。ランナーは `COPTS=-gdwarf-4` を**自動付与**して回避する（カーネル/リンカ無改変）。
  注意：`-gdwarf-4` は env COPTS で渡す（`make COPTS=...` は `-mcpu` を消し `cpsid` がアセンブルエラー）。
- 各テストは別リンク＝アドレス非互換のため、テスト横断の統合は **`lcov -a`（行/分岐単位）** で行う
  （命令アドレスの単純 union は不可）。詳細・既知制約は `scripts/asmcov/README.md`。

### 関数別・未到達行を見る（深掘り時）

```bash
# 関数（API）別の分岐カバレッジ
GCOV=arm-none-eabi-gcov python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/domain.c --by-function <DIRS...>
# 完全未到達の行番号
GCOV=arm-none-eabi-gcov python3 scripts/ttsp_gcov_report.py --filter /hrp3/kernel/domain.c --uncovered <DIRS...>
```

### ⚠ union の鉄則（重要な落とし穴）

- **新旧ビルド混在の dir を union しない**。コンパイルフラグ違いの `.gcno` が混ざると**分母（全分岐数）が変動**して数値が信頼できなくなる（実例：90→100 に増加）。
- authoritative な数値が要るときは**フル再ビルド**（ランナーを通しで走らせる）してから集計する。`find OBJ_DIR -name '*.o' -delete` で stale を消すのも有効。

---

## 3. テストを実行/デバッグする

### 非対話で全グループ（並列）

```bash
# <OS_PATH> <PROFILE> <OBJ_DIR> [DIV_NUM]
./scripts/ttsp_parallel_api.sh ../asp3/ ASP obj_asp 20
./scripts/ttsp_parallel_api.sh ../hrp3/ HRP obj_hrp 20   # HRP は -smp 1（FMP/HRMP は -smp 2）
# 環境変数: PAR_GROUPS（並列群・既定10）, MAKE_J（群内make・既定4）
```

### CI 一式（合否のみ手早く）

```bash
scripts/ci_run.sh [ASP|FMP|HRP|HRMP] [zybo_z7_gcc]   # QEMU(Cortex-A9)前提
```

### 合否の根拠は必ず execute.log

- 「通るはず」で報告しない（[`AGENTS.md`](../AGENTS.md) §4）。各 `<dir>/execute.log` の末尾を見る（実マーカ書式は `library/*/test/ttsp_test_lib.c`）：
  - `All check points passed.` ＝緑（各CPは `Check point N passed.`）
  - ``## Assertion `...' failed at <file>:NN.`` / ``## Unexpected value V for `A == B' failed at out.c:NN.`` ＝赤（assert／値・状態の不一致）
  - `## Unexpected error <ERCD> detected at <file>:NN.` ＝想定外のエラーコード。`<ERCD>=E_OACV` は保護違反（HRP/HRMP の系統要因。**TESRY 移行で多くは解消済**＝[`docs/HRP/BB_UNREACHABLE.md`](HRP/BB_UNREACHABLE.md) §1。`E_SYS` は既存 flaky）
  - `## Unexpected check point N.` ＝シーケンス番兵。とくに **`N=0`** は**走ってはいけない番兵タスクが走った**（停止すべき操作が失敗）
  > ⚠ いずれも `## ` 接頭辞付き／末尾ピリオド付きが正書式。`Check point N failed` のような文字列は**存在しない**。grep するなら上記の逐語で。

### どのグループにどのテストが入ったか

```bash
# auto_code_N の構成テスト一覧（MANIFEST はグループdir内にある）
cat obj_<prof>_gcov/api_test/auto_code_<N>/MANIFEST_AUTO_CODE_<N>
```
> ⚠ パス注意：`obj_*/api_test/MANIFEST_AUTO_CODE_N`（誤）ではなく `obj_*/api_test/auto_code_N/MANIFEST_AUTO_CODE_N`（正）。

---

## 4. テストを追加する（TESRY → TTG）

1. **置き場所**：`api_test/<PROFILE>/<category>/<api>/<name>.yaml`。命名は既存に倣う（`*_H-a` 等。WBは `*_W-*`・WBの YAML 命名規則あり）。
2. **TTG の二重コピーに注意（重大な落とし穴）**：TTG は **`tools/ttg/common/`（生成＝gc_config）と `tools/ttg/ttc/`（検証＝attribute_check）の2系統**がある。
   新オブジェクト型や新属性を足すときは**両方**を直す。`ttc` 側 `attribute_check` の `case` に `when` を足し忘れると `abort(ERR_MSG)` で TTG が fatal になる。
3. **小さく作って毎回ビルド検証**：1〜数本追加するたびに該当プロファイルの coverage ランナー（または §5 の単体ビルド）で緑を確認。大量追加→まとめて検証は非収束になりやすい。
4. **TTG の整合性検査（マージ脆弱）**：`T5_012`/`T5_013` は「`do` に ercd 指定があれば後続 post で caller が running、無ければ running でない」を**マージ後の系列**で検査する。
   状態変化を伴うテスト（回転で caller running→ready 等）は分割の度に弾かれる。**堅牢策**：既存の緑テストをクローンし syscall を最小変更（例：HRP m系は `TDOM_SELF` を足すだけ）＋全 ercd テストの post に caller `tskstat: running` を明示。
5. **cfg-error テスト**：静的API(TESRY)が期待どおりコンフィグエラーを出すかを確認。
   `./scripts/ttsp_parallel_cfgerr.sh <OS_PATH> <PROFILE> <OBJ_DIR>`（各dir で make→期待エラーコードを grep）。

---

## 5. SOM / 時間系の simt 計測（HRP 固有・上級）

実機タイマ（zybo+QEMU）では**周期稼働中アイドル・窓切替・多段ヒープがハング**して到達不能。
target `simtimer_zybo_z7_gcc` ＋ `ttsp_simt_advance(N)`（決定論的に時刻を進める拡張SVC）で計測する。

```bash
# まとめて（M1 SOM + M5 時間系）
bash scripts/coverage_gcov_hrp_simt.sh
# 対象: api_test/HRP/sys_manage/{chg_som,get_som,twd_som}/*.yaml ＋ カーネル付属 simt_systim1〜4(+_64hrt)
```

### SOM テスト1本だけ手動ビルド（デバッグ recipe）

```bash
export TTSP_TARGET_NAME=simtimer_zybo_z7_gcc
export COPTS="-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions -DNDEBUG"
OBJ_DIR=obj_hrp_simt
REF_MK="$OBJ_DIR/check_library/exception/Makefile"   # 先に simt ランナーを1回通すと生成される
source ./configure.sh >/dev/null 2>&1
source "./library/HRP/target/${TTSP_TARGET_NAME}/ttsp_target.sh"
TTG_ABS=$(realpath "$TTG_BIN")
OPT="-h --out_file_name out --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"
yaml=$(realpath api_test/HRP/sys_manage/twd_som/<NAME>.yaml)
dir="$OBJ_DIR/check_library/som_<NAME>"; rm -rf "$dir"; mkdir -p "$dir/objs"; cp "$REF_MK" "$dir/Makefile"
# 注1: && チェーンにせず文を分離する（サブシェルで cwd を保ちつつ各ステップを順に実行）。
# 注2: libgcov 判定は `command grep`（実 grep バイナリ）を使う＝§6「grep ラッパ」回避。
( cd "$dir"
  ruby "$TTG_ABS" $OPT "$yaml" > result_ttg.log 2>&1
  command grep -q 'libgcov.a' out.cfg || printf 'KERNEL_DOMAIN {\n\tATT_MOD("libgcov.a");\n\tATT_MOD("librdimon.a");\n}\n' >> out.cfg
  make ENABLE_GCOV=true -j4 > result_make.log 2>&1
  rm -f objs/*.gcda
  timeout 120 qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio -nographic -smp 1 -kernel hrp < /dev/null > execute.log 2>&1 )
tail -3 "$dir/execute.log"
```

- **REF_MK 流用**：生成 Makefile の SRCDIR が相対パスのため、テストdir は REF_MK（`check_library/exception`）と**同じ階層の深さ**に置く。
- **gcov リンク**：`out.cfg` に `ATT_MOD("libgcov.a"); ATT_MOD("librdimon.a");` を足さないと `__gcov_merge_add ... discarded section` でリンク失敗。
- **配置は exclude_tests.txt 連動**：`library/HRP/target/zybo_z7_gcc/exclude_tests.txt` に `sys_manage/chg_som`・`get_som` を登録済み＝通常 bb から自動除外され、simt 隔離群へ自動収集される（追加設定不要）。

### カーネル付属 simt_systim（M5 時間系）

`configure.rb` でビルドするが、**`configure.rb` は `APPLNAME.o` を `APPL_COBJS` に入れない**ため Makefile に sed 注入が必要：
`sed -i "s|^\tAPPL_COBJS := \$|\tAPPL_COBJS := <test>.o|" Makefile`。HRT_CONFIG：`simt_systim1/2/3→-DHRT_CONFIG1`・`*_64hrt→-DHRT_CONFIG3`・`simt_systim4→-DHRT_CONFIG2`。

---

## 6. Gotchas（落とし穴集・実体験ベース）

> 「なぜか動かない／数値が合わない」の典型。多くは**仕様どおりの挙動**だが初見では詰まる。

### 計測・集計
- **union 新旧混在で分母が変動** → フル再ビルドで authoritative 値を取る（§2 鉄則）。
- **COPTS インライン抑制を揃えないと 3 プロファイル比較不能**（分母が wait.h 等で水増し）。
- **QEMU の `-smp` はプロファイルで異なる**：**HRP のみ `-smp 1`**（単一コア保護）。**ASP も単一コア**。**FMP・HRMP は `-smp 2`**（マルチコア。HRMP は "HR+**MP**"＝マルチプロセッサ保護）。coverage_gcov_*.sh が自動で正しい値を渡す。
- **auto_code_14/17/19 は gcov 計装時のみビルド不成立**（`memory objects overlap`＝gcov固有）。zybo は M6（`.gcov_info` 専用リージョン・SVN r1336）で 19 を回復済。非計装では正常。

### HRP/HRMP 保護仕様
- **E_OACV 早期終了が支配的**：ASP由来テストがユーザドメインから sus_tsk/ter_tsk 等を呼び、`sysstat2_acvct`/対象 acptn2 不足で E_OACV。HRP3 3.3→3.4 のアクセス許可仕様変更に TESRY 未追従が真因（[`docs/HRP/BB_UNREACHABLE.md`](HRP/BB_UNREACHABLE.md) §1、移行手順 [`docs/HRP/TESRY_MIGRATION.md`](HRP/TESRY_MIGRATION.md)）。
- **HRP m系（mrot_rdq/mget_*）の schedno は保護ドメインID**（FMP/HRMP はプロセッサ）。`mget_*(TDOM_SELF,...) ≡ get_*(...)`。

### TTG / TESRY
- **TTG は common/ttc の二重コピー**（§4-2）。両方直す。
- **dormant タスクに tskpri は付けられない**（`T3_TSK007`）。
- **多段 do は各 do_N に post_condition_N が必須**（`T1_013`）。
- **TestScenario.rb はスケジューラを模擬しない**（author 指定状態の整合のみ検証）。SOM 等の動的挙動は TTG にモデル化不要。

### SOM 時間区画（domain.c）
- **DEF_SCY はプログラム全域に効く**：停止モードではユーザドメインの time event（alarm/cyclic）が発火しない → SOM テストを既存 time event テストと同一バイナリにマージすると後者がハング。**SOM は隔離ビルド群が必須**（§5）。
- **通知ハンドラ（ATT_TWD の notify）は窓のドメイン文脈で走る** → 通知先オブジェクトはその窓ドメインから到達可能要（KERNEL 専用だと cfg で `E_OACV: ... cannot be accessed from DOM1 in ATT_TWD`）。**共有オブジェクト**（`domain: NONE` + `access1-4: TACP_SHARED`）にする。
- **通知先に TNFY_ACTTSK で二次タスクを起動しない**：auto生成の二次タスクのボディは `check_point(0)`（走ってはいけない番兵）。起動すると失敗する。受動オブジェクト（共有セマフォ＝TNFY_SIGSEM 等）を使う。
- **通知の発火タイミング**：`TA_INISOM` は起動時（pre 検証前）に発火し dormant 期待と矛盾する。**`do` ステップ内の `chg_som` で発火**させ post_condition で検証する。
- **simt の `target_custom_idle` は次イベントを1つずつ発火**（ハンドラ完了後に次へ）＝**同時刻コインシデンスが作れない**。`set_dspflg` の elseif-T（dspflg 偽での窓切替）等は到達不能（upstream `simt_twd1` も 0/4）。
- **窓切替(twd_switch)は dly_tsk(idle文脈)型が本命**、scyc/overrun の明示制御は `ttsp_simt_advance(N)` 型（[`docs/HRP/SIMT_HANDOFF.md`](HRP/SIMT_HANDOFF.md)）。

### シェル環境（AIエージェント特有）
- **`grep` がラッパ関数になっている環境がある**（Claude Code 等は `grep` を `ugrep` ラッパ関数に置換）。この関数は**サブシェル `( )` 内で `exec` により自プロセスを置換**するため、`( ... && grep ... && ... )` のように `grep` を `&&` チェーン途中に置くと**そこで以降の処理（make/qemu等）が消えて失敗**する（実害：§5 の旧 recipe がこれで壊れていた）。
  - 回避：①`&&` チェーンにせず**文を分離**する ②スクリプト用途では **`command grep`**（実バイナリ）を使う。`grep -c` 等の読み取りは通常問題ないが、**`( )` 内の `&&` チェーンに grep を混ぜない**のが安全。
- `run_in_background` と `nohup &` の**二重背景化**でランチャが即終了し誤通知になる。どちらか一方にする。

---

## 7. 禁則の再掲（[`AGENTS.md`](../AGENTS.md) §2 が正本）

- ❌ カーネル（asp3/fmp3/hrp3/hrmp3）を本リポジトリに**コミットしない**／**編集しない**。
- ❌ TTSP3 ライセンス表記を壊さない。改変ファイルには**改変明記**。
- ⭕ 例外的にカーネル側を触る許可が出た場合（例：R5 ターゲット依存部・zybo gcov 基盤）は**改変明記**し、**SVN 側はユーザがコミット**（ttsp3 git には入れない）。

---

## 8. 関連ファイル索引

| 目的 | ファイル |
|---|---|
| 規約・禁則の正本 | [`AGENTS.md`](../AGENTS.md) |
| 合否（PASS/FAIL）の正本 | [`docs/STATUS.md`](STATUS.md) |
| ターゲット能力・非対応 | [`docs/TARGETS.md`](TARGETS.md) |
| 用語 | [`docs/GLOSSARY.md`](GLOSSARY.md) |
| 配置・SVN手順 | [`docs/WORKSPACE.md`](WORKSPACE.md) |
| gcov 計装（保護カーネル） | [`docs/HRP3_GCOV.md`](HRP3_GCOV.md) |
| HRP 未到達分析・E_OACV 真因 | [`docs/HRP/BB_UNREACHABLE.md`](HRP/BB_UNREACHABLE.md) |
| HRP カバレッジ向上計画 | [`docs/HRP/COVERAGE_RAISE_PLAN.md`](HRP/COVERAGE_RAISE_PLAN.md) |
| 依存部カバレッジ取得 計画 | [`docs/DEP_COVERAGE_PLAN.md`](DEP_COVERAGE_PLAN.md) |
| HRP simt（SOM/時間系）引き継ぎ | [`docs/HRP/SIMT_HANDOFF.md`](HRP/SIMT_HANDOFF.md) |
| 仕様差分(3.4→3.7)・改変台帳 | [`DIVERGENCE_MAP.md`](../DIVERGENCE_MAP.md) |
