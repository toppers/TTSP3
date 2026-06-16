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
| HRP3 | 単一コア・保護 | 358/513 (69.8%) | 34/64 (53.1%) |
| HRMP3 | SMP `-smp 2`・保護 | 353/546 (64.7%) | 41/72 (56.9%) |

保護プロファイル（HRP/HRMP）が低いのは、保護コード（`svc_handler`・user ドメイン
`start_utask_r` 等）が kernel-domain の `check_library` では踏めないため（step3 参照）。

`core_support.S` の未到達域を特定すると、`check_library` だけでは踏めない代表経路は：

- **FPU 選択的コンテキスト保存**（`USE_ARM_FPU_SELECTIVE` ブロック）
- **多重例外**（`excpt_nest_count` / `exc_handler_3` 系）
- **一部 dispatch 変種**（特定の preempt/yield 経路）
- **（MP系）IPI・他PE起動・spinlock** 経路

これらは現状 API 全件でしか踏めないのが「時間がかかる」主因。本計画はこれを少数の
専用テストで回収する。

### 現状サマリ（4プロファイル横断・依存部 `.S`・2026-06-16）

| プロファイル | 構成 | check_library のみ | ＋共通スクラッチ | scratch 状況 |
|---|---|---|---|---|
| ASP3 | 単一コア | 81.4% / 65.0% | **92.0% / 80.0%** | 作成済（step1/2/Tier1/1.5/.data） |
| FMP3 | SMP `-smp 2` | 77.4% / 72.9% | **87.0% / —** | 作成済（step4・SMP＋移送） |
| HRP3 | 単一コア・保護 | 69.8% / 53.1% | — | 未作成（step5 候補） |
| HRMP3 | SMP `-smp 2`・保護 | 64.7% / 56.9% | — | 未作成（step5 候補） |

（数値は `行(C0) / 分岐(C1)`。`obj_*` は揮発のため本表が記録の正本。再生成は
`PROFILE=<P> bash scripts/coverage_asmcov_zybo.sh smoke`。）

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
3. ✅ 層2/fault 系を SIL で検証→**.S では無価値と判明し統合見送り**（下記「進捗 step3」）。
4. ✅（step4 一部）**FMP スクラッチ（SMP）を作成**＝スピンロック＋PE1→PE2 タスク移送を追加
   （下記「進捗 step4」）。残る user ドメイン（HRP/HRMP）対応は step5 に継続。
5. （step5）HRP/HRMP スクラッチの **user ドメイン/SVC 対応**（保護ドメイン・メモリオブジェクト
   cfg 追加）で `start_utask_r`/`svc_handler` を狙う。あるいは当該領域は API カバレッジに委ねる。

### 進捗（2026-06-16・step4＝FMP スクラッチ）

`library/FMP/check_library/dep_scratch/` を作成（ASP 版＋SMP 刺激）：

- FMP 固有：cfg は `CLASS(CLS_PRCn)` 構造、チェックポイントは **MP 版 `ttsp_mp_check_point(prcid,…)`**
  （基本版は FMP test lib に無い）。スピンロックは `CRE_SPN`（**CLASS 内必須**）＋`loc_spn/unl_spn`。
  移送対象タスクは **affinity [1,2] の `CLS_ALL_PRC1`** に置く（`CLS_PRC1` は PE1 限定で
  `mig_tsk` が E_PAR）。`mig_tsk` の prcid は 1 始まり。
- 効果（FMP 依存部 `.S`・`-smp 2`）：check_library 77.4% → **＋scratch で 行 87.0%（300/345）**。
  QEMU で `PE 1 : All check points passed`。
- **実行時マイグレーション（PE1→PE2）は機能する**。`dispatch_and_migrate`（core_support.S 283-）も
  **到達できる**。`USE_BYPASS_IPI_DISPATCH_HANDER` は「ディスパッチ IPI を irq_handler で
  バイパス（高速）処理する」最適化で、IPI 自体は機能する（`gic_kernel_impl.c` が
  `IPINO_DISPATCH` を処理）。**当初『構成的に到達不能』としたのは誤りだった**。

  到達の鍵は**待ち合わせ方**：
  - **`dly_tsk` ポーリング待ちは不可**。main が 2 tick ごとに起きて PE1 を回し続けると、
    （特に重い `-d` トレース下で）移送先 PE2 が走る時間を奪い、移送タスクが PE2 で完了しない。
  - **バリア同期（`ttsp_barrier_sync`）で待つと成立**。移送タスクを **main より高優先**で
    `act_tsk` して即起動→自己移送（`mig_tsk(TSK_SELF,2)`＋`dly_tsk` で一度ブロック）→PE2 で再開、
    PE2 上の移送タスクと main(PE1) を `ttsp_barrier_sync(phase, TNUM_PRCID)` で待ち合わせる。
    （バリアはマスタ PE で `sil_dly_nse` ビジー待ち＝同一 PE の低優先タスクは譲らないので、
    移送タスクは高優先で先に起動・移送させておくのが要点。）
  - 寝かせ移送（act→slp→`mig_tsk`→wup）も同様にバリアで待ち合わせて PE2 実行を確認。
  - 検証ログ：`self migration (mig_tsk TSK_SELF): now on PE2` / `PE 2 : Barrier sync phase: N`、
    `dispatch_and_migrate` 283/290/292/300 が hit。
- **マイグレーションのキューイング→ter_tsk 移送**も追加：非休止タスクへの `mact_tsk(tskid, prcid)`
  は起動をキューイング（`actque`/`actprc`）し、`ter_tsk` による終了時に `actprc` の PE へ移送して
  再起動する（kernel/task.c `task_terminate`）。MACT_TASK を高優先で起動→`slp_tsk`→`mact_tsk(,2)`
  でキューイング→`ter_tsk`→PE2 で再起動、をバリアで確認（`mact_tsk queued migration:
  reactivated on PE2`）。これで task_terminate の移送経路（C）も踏み、`.c` 網羅 77.5%→79.5%。
- 例外ハンドラは PE 付きログ＋**`xlog_sys(p_excinf)`** で例外フレーム（pc/cpsr/lr/r0-r3/
  nest_count/intpri）をダンプ（`core_kernel_impl.h` の公開関数）。
- **教訓**：API の `mig_tsk` テストはエラー系（`E_CTX` 等）のみで成功移送を検証しないため
  「API がパス＝移送 OK」とは言えないが、移送機能自体はカーネルで正しく動く。SMP の
  待ち合わせは `dly_tsk` ではなく**バリア同期**を使うこと。
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

### 進捗（2026-06-16・ASP Tier1＝カーネル管理外CPU例外）

ASP の残未到達（例外ハンドラ系）を仕分けし、確実に踏める **`nk_exc_handler`（カーネル
管理外CPU例外）** を回収：

- 仕組み：core_support.S は例外フレームの CPSR の I/F ビットがセット（CPUロック/全割込ロック
  中）なら `nk_exc_handler` へ分岐する（L992-993）。スクラッチに **`loc_cpu()` 中に
  `ttsp_cpuexc_raise(EXCNO_A)`** を1ブロック追加して踏む。nk 文脈はサービスコール不可のため
  例外ハンドラは静的カウンタで分岐し最小限（hook のみ）で復帰する。
- 効果（ASP 依存部 `.S`）：**84.0%/67.5% → 87.8%（274/312）/72.5%**。QEMU で全 CP 緑。

### 進捗（2026-06-16・ASP Tier1.5＝例外復帰側ディスパッチ）

`exc_handler_3` のディスパッチ経路＋`ret_exc_r` 復帰（1179/1181/1194-1197/1207）を回収：

- 仕組み：CPU例外ハンドラ（タスク文脈）から **`iact_tsk` で高優先タスク（`exc_task`）を起動**
  すると、例外出口で `p_runtsk != p_schedtsk` となりディスパッチが起きる（再開番地 `ret_exc_r`
  を保存）。`exc_task` 終了後に main が `ret_exc_r` 経由で復帰し FPU/レジスタ復帰も踏む。
- 効果（ASP 依存部 `.S`）：87.8% → **90.4%（282/312）/75.0%**。QEMU で全 CP 緑。

### 進捗（2026-06-16・ASP 初期値データ＝start.S の .data コピーループ）

`start.S` の起動時 ROM→RAM データ初期化コピー（DATA コピーループ 157/163-166）を回収：

- 仕組み：スクラッチに **非ゼロ初期値のグローバル変数**（`init_data = 0xDEADBEEF`）を1つ置く。
  `.data` セクションが非空（DATA_START != DATA_END）になり、起動時のコピーループ（と分岐 `blo`）
  が実行される。`.bss`（ゼロ初期化）では走らないため**非ゼロ初期値**が要点。
- 効果（ASP 依存部 `.S`）：90.4% → **92.0%（287/312）/80.0%**。`start.S` 33/34（残 1 のみ）。
- 残 25 行＝**ASP の構造的上限**：`pabort`/`fiq`/`dabort_handler_1`/`svc_handler`/`exc_handler_2`
  （保護フォルト/FIQ/SVC/ネスト例外）＋`start.S:hardware_init_hook` の弱定義（ターゲットが上書き
  するため到達不能）＋`sil_dly_nse1`。**ASP の実質上限 ≈ 92%**。

**（step2 時点の所見）残未到達はすべて例外ハンドラ入口＝層2/SIL の領分**：
- SVC(714-722)／プリフェッチアボート(763-772)／データアボート(825-834)／例外復帰変種
  (1139-1344) は、`ttsp_cpuexc_raise` が EXCNO_A(未定義命令)/EXCNO_C(フェイタルデータ
  アボート) しか刺激できないため**スクラッチでは到達不能**。これらは SIL テスト
  （`docs/SIL_TEST.md`／prefetch abort 等の fault 注入）または層2のターゲット固有テストで
  カバーすべき＝**共通スクラッチ（層1）の自然な上限**。次は層2（step3）へ。

### 進捗（2026-06-16・step3 調査＝SIL は .S 計測に統合しない結論）

層2（例外/fault 系）を SIL テストで埋められるか検証した結果、**SIL は依存部 `.S` の網羅を
増やさない**ことが判明（証拠ベースで SIL 統合を見送り）：

- **ASP**：保護なし＝MMU フォルトが起きず、SIL もアボートを誘発しない（`ttsp_cpuexc_raise`
  は EXCNO_A のみ使用）。SIL の `.S` 寄与は +1 行のみ。アボート/SVC ハンドラ入口は
  **ASP では構造的に到達不能**（意図的な致命 fault を起こさない限り）＝プロファイルの上限。
- **HRMP**（`-smp 2`・`-gdwarf-4` で SIL ビルド・実行で確認）：プリフェッチ/データアボート
  ハンドラ入口（741-843）は **check_library が既に踏んでいる**（HRMP の例外テストは保護対応で
  アボートを誘発）。よって SIL を足しても `.S` は 64.7%（353/546）から変化なし。

**HRMP の真の残り（192 行）の性格**（未到達行のラベル分布）：`start_utask_r`(20＝**ユーザ
ドメイン実行**)・`dispatch_and_migrate`(12＝**SMP タスク移送**)・`svc_handler`(9＝**拡張サービス
コール**)・`nk_exc_handler`/`exc_handler_3`/`irq_handler_2-3`（例外/割込みネスト変種）・
`fatal_dabort_handler`。これらは**保護ドメイン・PE 間移送・SVC** の経路で、kernel-domain
のみの check_library/共通スクラッチでは届かず、**多ドメイン/移送を伴うテスト（API 領域、
または step4 でスクラッチを user ドメイン対応に拡張）** が必要。

**結論**：層2 の「fault 注入」は HRMP では既に check_library がカバー済み・ASP では到達不能
のため、SIL の asm 計測統合は採用しない（SIL は SIL-API 適合性テストとしての価値は別途維持）。
残りの依存部 `.S` 向上は **step4＝スクラッチの user ドメイン/移送対応**（HRP/HRMP）が筋。

---

## 7. 対象外 / 検討継続

- 共通スクラッチで到達不能なタイミング依存経路（周期稼働中アイドル等）は simt 路線を要検討
  （既存 `coverage_gcov_hrp_simt.sh` の知見）。
- 分岐網羅(C1) の Thumb IT ブロック述語実行は asmcov の集計外（`scripts/asmcov/README.md`）。
  zybo の `.S` は ARM モードなので影響なし。
- ターゲット追加時の能力宣言（`FUNC_*`）の二重管理を避ける仕組みは運用で詰める。
