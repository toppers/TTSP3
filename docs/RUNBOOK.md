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

## 7b. M-profile ターゲット（mps2_an505/QEMU・ek_ra8m2/実機）

> **前提（カーネルの所在）**：M-profile 系の被テストカーネルは
> **`~/TOPPERS/asp3_tz_work/`**（git repo `exshonda/asp3_tz_work`）内の `asp3_3.7/`・`hrp3_3.4.2/`。
> 兄弟 SVN とは別管理。詳細は [`docs/WORKSPACE.md`](WORKSPACE.md)「第2ワークスペース」節・
> [`UPSTREAM_KERNEL.md`](../UPSTREAM_KERNEL.md) 参照。
> 確定結果（合否・per-case 分類）の正本は **[`docs/STATUS.md`](STATUS.md) §1b**（再計測しない）。
> コマンドは**本ワークスペース（`~/TOPPERS/TTSP3/work/ttsp3`）から実行できる**（2026-07-02 に HRP SIL で実証）。
> カーネルパスは**相対で** `../../../asp3_tz_work/<kernel>/` と渡す（**絶対パス不可**＝`sil_test.sh` 等が
> `${g_tree_level}` を前置するため、絶対パスだと configure.rb が見つからず「Makefile file is not exist」で失敗する）。
> ※台帳（`MPS2_API_STATUS.md`・`EK_RA8M2_TTSP3_STATUS.md`）中の `~/TOPPERS/ttsp3`＋`../ASP3_TZ/asp3_tz_work/` は
> **測定当時（2026-06-20〜22）の旧配置**。現在このマシンに第2クローンは無く、上記の読み替えで再現する。

### SIL ビルド＋QEMU 実行（mps2_an505・ASP または HRP）

```bash
cd ~/TOPPERS/TTSP3/work/ttsp3
export PATH=~/tools/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin:$PATH
export TTSP_TARGET_NAME=mps2_an505_gcc

# SIL ビルド（2=SIL テスト、1=continuous build、q=戻る×2）
# ASP の場合
printf '2\n1\nq\nq\n' | bash ttb.sh ../../../asp3_tz_work/asp3_3.7/ ASP obj_mps2_sil_asp
# HRP の場合
printf '2\n1\nq\nq\n' | bash ttb.sh ../../../asp3_tz_work/hrp3_3.4.2/ HRP obj_mps2_sil_hrp

# QEMU 実行（semihosting exit・シリアルをファイルへ捕捉）
# ASP: ELF 名は asp、HRP: hrp
qemu-system-arm -M mps2-an505 -semihosting-config enable=on \
    -kernel obj_mps2_sil_asp/sil_test/asp -nographic \
    -serial file:obj_mps2_sil_asp/sil_test/execute.log >/dev/null 2>&1

# 合否確認
grep 'All check points passed' obj_mps2_sil_asp/sil_test/execute.log && echo PASS || echo FAIL
```

- ELF 名は ASP=`asp`、HRP=`hrp`（`ttsp_target.sh` の `APPLI_NAME` 参照）。
- `ttsp_target.sh` の `simulation()` を使う場合は `cd <objdir>/sil_test && bash -c '. library/<PROF>/target/mps2_an505_gcc/ttsp_target.sh && simulation'`。

### API per-case 全件ビルド＋実行（mps2_an505）

1件＝1 ELF の per-case 全件計測は `scripts/ttsp_parallel_api.sh` を使う。
**`TTSP_TARGET_NAME` は必ず export**（落とし穴参照）。

```bash
cd ~/TOPPERS/TTSP3/work/ttsp3
export PATH=~/tools/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin:$PATH

# ASP（DIV=1813・per-case 全件ビルド）
TTSP_TARGET_NAME=mps2_an505_gcc SKIP_RUN=1 PAR_GROUPS=12 MAKE_J=3 \
  bash scripts/ttsp_parallel_api.sh ../../../asp3_tz_work/asp3_3.7/ ASP obj_asp_mps2_api 1813

# HRP（DIV=1602・per-case 全件ビルド）
TTSP_TARGET_NAME=mps2_an505_gcc SKIP_RUN=1 PAR_GROUPS=12 MAKE_J=3 \
  bash scripts/ttsp_parallel_api.sh ../../../asp3_tz_work/hrp3_3.4.2/ HRP obj_hrp_mps2_api 1602

# 個別 QEMU 実行・分類（ASP の例。HRP は asp → hrp に読み替え）
for d in obj_asp_mps2_api/api_test/auto_code_*; do
    timeout 30 qemu-system-arm -M mps2-an505 -semihosting-config enable=on \
        -kernel "$d/asp" -nographic \
        -serial "file:$d/execute.log" >/dev/null 2>&1
    command grep -q 'All check points passed' "$d/execute.log" \
        && echo "$d PASS" || echo "$d FAIL"
done
```

- 結果の正本（確定分類・PASS/FAIL 内訳）：
  - ASP: [`library/ASP/target/mps2_an505_gcc/MPS2_API_STATUS.md`](../library/ASP/target/mps2_an505_gcc/MPS2_API_STATUS.md)
  - HRP: [`library/HRP/target/mps2_an505_gcc/MPS2_API_STATUS.md`](../library/HRP/target/mps2_an505_gcc/MPS2_API_STATUS.md)
- `ttsp_parallel_api.sh` は `exclude_tests.txt` を**自動適用**（M-profile 制約による除外は `library/<PROF>/target/mps2_an505_gcc/exclude_tests.txt` が正本。手動で除く必要はない）。
- 20分割でなく per-case 全件（ASP=DIV=1813、HRP=DIV=1602）で実行するのが M-profile 系の慣例。確定 PASS 数は `docs/STATUS.md §1b` を参照（再計測不要）。

### ek_ra8m2 実機（HRP・Cortex-M85）

実機接続（J-Link OB・VCOM `/dev/ttyACM0`・115200 8N1）が必要。**第2ワークスペース＋実機接続環境でのみ計測可能**。

```bash
cd ~/TOPPERS/TTSP3/work/ttsp3
export PATH=~/tools/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin:$PATH
export TTSP_TARGET_NAME=ek_ra8m2_gcc

# SIL ビルド
printf '2\n1\nq\nq\n' | bash ttb.sh ../../../asp3_tz_work/hrp3_3.4.2/ HRP obj_ekra8m2

# flash（J-Link CLI）
arm-none-eabi-objcopy -O ihex obj_ekra8m2/sil_test/hrp obj_ekra8m2/sil_test/hrp.hex
# JLinkExe -device R7KA8M2JF_CPU0 -if SWD -speed 4000 -autoconnect 1 -CommanderScript ...
# または ttsp_target.sh の simulation()（RA_SERIAL=/dev/ttyACM0 を渡す）

# シリアル受信（別ターミナルで）
cat /dev/ttyACM0
```

- ビルド・フラッシュ・シリアル受信の詳細手順は [`docs/HRP/EK_RA8M2_TTSP3_STATUS.md`](HRP/EK_RA8M2_TTSP3_STATUS.md)「ビルド／実行コマンド」節を参照（本節では要点とポインタのみ）。
- 現状（2026-06-20 確定）：SIL は **CP1〜27 全て実機 PASS**（"All check points passed"）。M2 メモリ保護・ドメインアクセス制御・CPU 例外ユーザ文脈復帰が実機で機能していることの実証（`STATUS.md §1b` 参照）。

### ⚠ 落とし穴（M-profile 固有）

- **`TTSP_TARGET_NAME` の export 忘れ**：`ttsp_parallel_api.sh` のフェーズ1が `bash ttb.sh` の子プロセスを起動し、その中の `configure.sh` が `TARGET_NAME="${TTSP_TARGET_NAME:-zybo_z7_gcc}"` で**再解決**する。export しないと既定の **zybo_z7_gcc に化け**、per-case Makefile が `TARGET=zybo_z7_gcc` で生成されて `import("target.cdl")` が zybo を引き、**全件 MAKE FAIL**（`sSIOPort signature not found` ＋ tecsgen `__typeof__` 破綻＝mps2 の `-std=gnu17` が効かない）になる。スクリプト内は commit `2ed98f6` で `export` 対応済みだが、手動で `TTSP_TARGET_NAME=mps2_an505_gcc bash scripts/...` と渡す場合は**先に `export TTSP_TARGET_NAME=mps2_an505_gcc`** とする（インライン代入では子プロセスに引き継がれない）。
- **QEMU パッチ不要**：`mps2-an505` は zybo 系（`xilinx-zynq-a9`）で必要な a9gtimer パッチが不要。素の `qemu-system-arm` でよい。
- **HRP mps2 の check_library は int のみ**：M-profile 制約（BASEPRI によるロック中の svc が HardFault になる・gain_tick 非対応等）により、exc・timer は `exclude_tests.txt` で除外されており実行されない。int のみが対象。
- **`( ... && grep ... && ... )` サブシェル連鎖に注意**：`grep` がラッパになっている環境では `&&` チェーン内の `grep` 以降が消える（§6 落とし穴参照）。上記コマンド例のように `command grep` を使うか、チェーンを分離する。
- **FUNC_TIME（tick 制御）依存テストは要タイマ停止モードパッチ**：素の asp3_3.7 では
  stop_tick の凍結が raise_event/set_event の SysTick 再起動で解除され、`_ten` 系 api_test
  （約500件）と timer check が落ちる。`docs/patches/asp3-mps2_an505-target_timer-test-stop-mode.patch`
  をカーネル（`asp3_3.7/`）に適用してから測定する（適用で per-case 1807/1813・回帰 0）。
  HRP は同 hrp3 版＋ **r4 復元パッチ**（`hrp3-arm_m-nontask-extsvc-r4-restore.patch`＝非タスク文脈
  拡張 SVC の r4 破壊修正）も必要（適用で 1544/1601）。
- **asp3_tz_work の checkout ブランチに注意**：測定ベースラインは **main**（`1d2ba24`）。checkout が
  TZ 開発ブランチ `asp3-tz` のままだと asp3_3.7 に開発中変更（tz_gateway/ns_demo 等）が入り、
  ビルドは通っても **QEMU でブート後に無出力**になる（例外も発生しない）。checkout を動かさずに
  ベースラインを使うには `git -C ~/TOPPERS/asp3_tz_work archive main asp3_3.7 | tar -x -C /tmp/asp3_main`
  で展開し、その相対パスを ttb.sh に渡す（hrp3_3.4.2 は asp3-tz でも main と同一なのでそのままでよい）。
- **カーネルパスは相対・絶対不可**：`ttb.sh`/`sil_test.sh` は OS パスに `${g_tree_level}`（obj 階層分の `../`）を前置するため、**絶対パスを渡すと configure.rb 解決に失敗**し「Makefile file is not exist」で folder 作成が空振りする（エラーは握り潰される）。本ワークスペースからは `../../../asp3_tz_work/<kernel>/` と渡す。
- **CPU 例外ハンドラ（トランポリン文脈）から svc を発行しない**：HRP の CPU 例外ハンドラは
  cpuexc_thread_trampoline（Thread+MSP+特権）で走る。この文脈から `ttsp_check_point`（svc 経由
  syslog）を発行すると**カーネル時刻管理が壊れてライブロック**（「no time event is processed in
  hrt interrupt.」の氾濫）する。ハンドラでは PC 補正等の最小処理＋フラグ記録に留め、CP 発行は
  タスク文脈で行う（`sil_test/HRP/out.c` の 2026-07-02 修正が実例。QEMU の DACCVIOL/IACCVIOL
  自体は正しく発生する＝「QEMU がフォールトしない」と誤診しやすいので注意）。

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
