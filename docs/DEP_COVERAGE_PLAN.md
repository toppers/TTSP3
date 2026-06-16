# DEP_COVERAGE_PLAN.md — 依存部（arch/target）カバレッジ取得 計画

> ターゲット依存部（arch / target / chip）の網羅を、**API 全件（20分割×ビルド＋実行）に
> 頼らず短時間で**取得するための計画。規約の正本は [`AGENTS.md`](../AGENTS.md)（特に §2 禁則・
> §6 ターゲット依存部）。計測手順は [`RUNBOOK.md`](RUNBOOK.md) §2、ターゲット能力は
> [`TARGETS.md`](TARGETS.md)。
>
> 策定 2026-06-16。管理場所は **方針 C（ハイブリッド）** を採用（§5）。

---

## 1. 背景・動機

依存部の網羅は本来 API 全件が埋めるが、TTSP3 の API は auto-code 20分割×（ビルド＋QEMU 実行）
で時間がかかる。一方、依存部の「主要経路」はアーキ非依存に書ける部分が多く、少数の専用
テストで大半を踏める見込みがある。

**測定による裏付け**（`check_library` 3本＝exception/interrupt/timer のみでの手書き `.S` 行網羅、
asmcov 計測・2026-06-16）：

| プロファイル | 構成 | `.S` 行網羅(C0) | `.S` 分岐網羅(C1) |
|---|---|---|---|
| ASP3 | 単一コア | 254/312 (81.4%) | 26/40 (65.0%) |
| FMP3 | SMP `-smp 2` | 267/345 (77.4%) | 35/48 (72.9%) |
| HRMP3 | SMP `-smp 2` | 353/546 (64.7%) | 41/72 (56.9%) |

`core_support.S` の未到達域を特定すると、`check_library` だけでは踏めない代表経路は：

- **FPU 選択的コンテキスト保存**（`USE_ARM_FPU_SELECTIVE` ブロック）
- **多重例外**（`excpt_nest_count` / `exc_handler_3` 系）
- **一部 dispatch 変種**（特定の preempt/yield 経路）
- **（MP系）IPI・他PE起動・spinlock** 経路

これらは現状 API 全件でしか踏めないのが「時間がかかる」主因。本計画はこれを少数の
専用テストで回収する。

---

## 2. 対象（依存部ファイル）

zybo_z7 例（`ttsp_target.sh` の `KERNEL_COBJS_TARGET` 由来）：

- 手書きアセンブリ `.S`：`arch/arm_gcc/common/{start,core_support,gic_support}.S` → **asmcov** で計測
- C ファイル：`chip_kernel_impl.c` / `core_kernel_impl.c` / `gic_kernel_impl.c` / `pl310.c` /
  `target_kernel_impl.c` / `mpcore_kernel_impl.c` / `mpcore_timer.c` → **gcov** で計測

両者を依存部ファイルにフィルタして統合し、「依存部カバレッジ」を一つの指標にする。

---

## 3. 2層テスト構成

### 層1: 共通スクラッチテスト（全ターゲット共通・1本）

- **目的**: アーキ非依存に書ける「依存部の主要経路」を最小コストで踏む単一アプリ。
- **踏む対象**: 起動 → 多優先度タスクの dispatch/preempt/yield、割込み入口/出口（**多重割込み含む**）、
  CPU 例外（同期/非同期・**多重例外**）、**FPU コンテキスト切替**、SIL 基本（mem/IO/ロック）、
  （MP系のみ）**IPI・他PE起動・spinlock**。
- **位置づけ**: 既存 `check_library`（exception/interrupt/timer）を補完する「依存部スクラッチ」
  グループ。`check_library` の枠組み（ランナー・QEMU 実行・asmcov/gcov 集計）にそのまま乗る。
- **効果見込み**: §1 の未到達域（FPU・多重例外・dispatch 変種）を 1 本で回収し、API 全件なしで
  依存部網羅を大きく底上げ。

### 層2: 依存部ごとのテスト（ターゲット固有・少数）

- **目的**: 共通スクラッチで書けない/差のある経路。
- **例**: GIC vs NVIC、pl310 キャッシュ、MPU（HRP/HRMP）、特定例外番号・割込み属性、チップ固有初期化。
- **実現**: ターゲットごとに専用 cfg ＋刺激（既存 `ttsp_target_test.c` の7関数＝割込み/例外注入
  フック `ttsp_int_raise`/`ttsp_cpuexc_raise` 等を拡張）。

---

## 4. 計測フロー

1. 共通スクラッチ＋層2 を **`-gdwarf-4`** でビルド（asmcov のため。`.debug_line_str` 脱落回避）。
2. QEMU 実行（FMP/HRMP は **`-smp 2`**）。トレースは `cap_stream.py` でサイズ上限つき取得
   （timer 等のアイドルスピンによるログ膨張を抑制）。
3. **asmcov（.S）と gcov（C）を依存部ファイルにフィルタして統合**。
   - `.S`：`scripts/coverage_asmcov_zybo.sh` に「scratch」モード（共通スクラッチ＋層2 を対象）を追加。
   - C：既存 `scripts/coverage_gcov_*.sh` ＋ `ttsp_gcov_report.py` の `--filter` を依存部ファイルに。
4. 判定：依存部の C0/C1 がベースライン（API 全件）に対しどれだけ短時間で近づくかを指標化。

---

## 5. 管理場所の方針 — 採用: C（ハイブリッド）

被テスト RTOS 本体（`asp3/` 等）は **SVN・別管理・編集/コミット禁止（禁則①②）** が大前提。
そのうえで検討した3案：

| | A. TTSP3 一元管理 | B. 各RTOS依存部で管理 | **C. ハイブリッド（採用）** |
|---|---|---|---|
| テスト本体 | TTSP3 `library/<PROF>/target/<t>/` | RTOS `arch/target/test/` | 共通スクラッチ＝TTSP3／固有刺激＝TTSP3 target |
| 長所 | 集計・CI 集約、横断比較、RTOS 無改変 | 実装と同居で改版追従が容易 | 禁則を守りつつ差を target 記述で吸収 |
| 短所 | ターゲット知識を TTSP3 が持つ | **禁則に抵触**、横断集計が分散 | 能力宣言の二重管理に注意 |

### 採用方針 C の具体

- **共通スクラッチ・集計・判定・CI は TTSP3**（git 管理・単一ソース）。
- **ターゲット固有差は既存の `ttsp_target_test.{c,h,sh,cfg}` パターンで吸収**（TTSP3 内 `library/<PROF>/target/<target>/`）。
  この4ファイルは既に「TTSP3 が管理する依存部テスト適合層」として機能している。
- RTOS 依存部側の「能力・期待値」は仕様/ドキュメントから `ttsp_target.sh` の `FUNC_*` 能力フラグと
  `ttsp_target_test.h` に**宣言として写す**（RTOS 本体は無改変＝禁則①②維持）。

**根拠**: (1) TTSP3 はテストスイートそのもの、(2) 4ファイルが既に適合層として機能、
(3) RTOS は SVN・無改変が必須。所有・保守の自然さ（依存部と同居）の議論は
[`TARGET_LIBRARY_PLACEMENT.md`](TARGET_LIBRARY_PLACEMENT.md) を参照。

---

## 6. 実装ステップ（案）

1. ✅ **共通スクラッチを1本試作**（`library/ASP/check_library/dep_scratch/`）→ ASP で効果測定（下記「進捗」）。
2. ✅ FPU・dispatch 変種を踏むようスクラッチを調整（FPU 復帰経路 575/594 を回収・下記「進捗 step2」）。
3. 層2 のターゲット固有テスト＋例外/fault 系（SVC・abort）を追加（GIC/pl310/MPU/IPI/SIL fault 注入）。
4. 4プロファイル（ASP/HRP/FMP/HRMP）へ展開。FMP/HRMP は `-smp 2`。
   ※ HRP/HRMP のスクラッチは保護ドメイン・メモリオブジェクトの cfg 追加が要る。
5. gcov（C）と asmcov（.S）の依存部統合レポートを 1 コマンド化。
6. 「API 全件 vs スクラッチ＋層2」の網羅・所要時間を比較し、CI の既定計測を決める。

### 進捗（2026-06-16・step1 完了）

`dep_scratch`（porting §6＋arm §6.9 FPU を踏む単一アプリ）を作成し ASP で検証：

- QEMU で **13/13 チェックポイント PASS**。`coverage_asmcov_zybo.sh` に scratch 自動ビルド
  （既存 check_library ビルドを複製→`out.*` 差替→`-gdwarf-4`＋プロファイル別 COBJS で再リンク）を統合。
- 依存部 `.S` 網羅（ASP）：スクラッチ単独 行68.6%/分岐45.0%（**1本で大半**）。
  check_library のみ 81.4%/66.7% → **＋scratch で 83.3%/67.5%**（FPU 保存ブロック等を新規回収）。

### 進捗（2026-06-16・step2 完了）

step1 の残未到達を精査・調整した結果：

- **FPU 復帰経路 575/594 を回収**：zybo は `USE_ARM_FPU_ALWAYS`（選択保存ブロックは非
  コンパイル＝分母に無し。当初の「ARMv5 デッドコード」懸念は誤りで、`#if __TARGET_ARCH_ARM<6`
  分岐は非アセンブルなので DA にも出ず分母を汚さない）。残る FPU 行 575/594 は `ret_int_r`
  ＝**割込みで preempt されたタスクの復帰**経路。スクラッチに「割込みハンドラから
  `iact_tsk` で高優先タスクを起動」する刺激（`irq_task`）を追加し、main を IRQ 契機で
  preempt→`ret_int_r` 復帰させて 575/594 を**到達**（hit 確認）。
- 結果（ASP 依存部 `.S`）：check_library＋調整スクラッチで **行 84.0%（262/312）**。

**残未到達はすべて例外ハンドラ入口＝層2/SIL の領分**：
- SVC(714-722)／プリフェッチアボート(763-772)／データアボート(825-834)／例外復帰変種
  (1139-1344) は、`ttsp_cpuexc_raise` が EXCNO_A(未定義命令)/EXCNO_C(フェイタルデータ
  アボート) しか刺激できないため**スクラッチでは到達不能**。これらは SIL テスト
  （`docs/SIL_TEST.md`／prefetch abort 等の fault 注入）または層2のターゲット固有テストで
  カバーすべき＝**共通スクラッチ（層1）の自然な上限**。次は層2（step3）へ。

---

## 7. 対象外 / 検討継続

- 共通スクラッチで到達不能なタイミング依存経路（周期稼働中アイドル等）は simt 路線を要検討
  （既存 `coverage_gcov_hrp_simt.sh` の知見）。
- 分岐網羅(C1) の Thumb IT ブロック述語実行は asmcov の集計外（`scripts/asmcov/README.md`）。
  zybo の `.S` は ARM モードなので影響なし。
- ターゲット追加時の能力宣言（`FUNC_*`）の二重管理を避ける仕組みは運用で詰める。
