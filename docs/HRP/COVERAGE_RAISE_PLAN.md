# COVERAGE_RAISE_PLAN.md — HRP3 カバレッジ向上プラン

> 起点: 2026-06-14 実測（zybo_z7_gcc・ASP/FMP 同条件＝-O2＋インライン抑制、`bb`=`all`）
> **branch 82.0%（1991/2429）／line 89.5%（2989/3338）**。出典 [`ALL_COVERAGE.md`](ALL_COVERAGE.md)。
> 未到達 **438 分岐**。うち **363（83%）が 6 ファイルに集中**（下表）＝ここが伸びしろ。
> 前提: テスト追加は基本 ttsp3（git）側（TESRY/TTG）。カーネル(hrp3/SVN)編集が要る項目は明記（要ユーザ許可）。
> 旧分析 [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) は 2026-06-09 移行前の数値が混在＝本書が現状の正本。

## 0. 未到達の集中（per-function 実測・2026-06-14）

| ファイル | 到達/全 分岐 | 未到達 | 主因（per-function 実測） | 分類 |
|---|---|---|---|---|
| messagebuf.c | 113/218 51.8% | **105** | snd/psnd/tsnd/rcv/prcv/trcv/ini/ref_mbf が各 ~50%。正常系のみで待ち遷移・タイムアウト・E_OACV・キュー満杯/空・エラー系が未駆動 | test-design |
| sys_manage.c | 106/202 52.5% | **96** | `mrot_rdq`/`mget_lod`/`mget_nth`（m系・schedno指定）が各 0%（84分岐）。単一PE系は 80〜94% の tail | 要調査＋tail |
| domain.c | 6/90 6.7% | **84** | `chg_som`/`get_som`/`_kernel_twd_*`/`_kernel_scyc_*`/`_kernel_twdtimer_*` が全 0%。**SOM（システム動作モード＝時間区画スケジューリング）が丸ごと未テスト** | test-design（新カテゴリ） |
| mem_manage.c | 21/62 33.9% | **41** | `refer_memory`/`_kernel_ref_mem` 0%（ref_mem テスト皆無）、`probe_memory` 21% | test-design（新規） |
| time_event.c | 54/78 69.2% | **24** | `_kernel_tmevtb_enqueue`/`tmevt_proc_top` 0%、64bit境界・ヒープ多段＝内部状態依存（ASP/FMP 同傾向） | 一部到達不能 |
| memory.c | 7/20 35.0% | **13** | `_kernel_probe_mem_read` 0%（既存 prb_mem は write のみ）、`initialize_sections` 25% | test-design |
| （その他10+ファイル） | — | ~75 | 標準API（task/sem/flg/dtq/pdq/mtx/mpf/alm/cyc 等）の境界・エラー系の tail。各 0〜10 分岐 | test-design（tail） |

> **方針**：HRP 固有の保護/ドメイン/メモリ機能（domain/messagebuf/mem_manage/memory）が ASP/FMP に無い
> 大きな未テスト領域。standard API の tail は ASP/FMP の手法を移植。計測基盤の欠落（auto_code_19）も回復。

---

## Method 6（★即効・最優先）：auto_code_19 の gcov overlap を回復（計測基盤）

**現状**：gcov 計装時のみ `auto_code_19` が `memory objects overlap` で build 脱落（保護ドメインのコード/データが
計装で約2倍に膨張＋`.gcov_info` 追加で密配置と衝突）。**1グループ分の実行済みテストが計測に反映されていない**
（合否は非gcov で 20/20＝[`../STATUS.md`](../STATUS.md)）。

**機構**：R5（zcu102_r5_gcc）で実証済の手法を zybo に適用＝`ENABLE_GCOV=true` のときのみ DDR リージョンを
拡大／`.gcov_info` を専用領域へ配置して衝突回避（hrp3 `target/zybo_z7_gcc/target_mem.cfg`／ldscript）。
- **カーネル(hrp3/SVN)編集が必要**（R5 と同様・要ユーザ許可）。R5 で同型の `#ifdef TOPPERS_ENABLE_GCOV` 拡大が成功済。

**コスト**：小（実証済手法の移植）。**ゲイン**：中（丸ごと1グループの実行分岐を計測へ反映。数十分岐見込み）。

---

## Method 2（大ゲイン・中コスト）：messagebuf 異常系/待ち/アクセス権

**対象**：messagebuf.c 105 分岐（最大の絶対ギャップ）。`api_test/HRP/sample/messagebuf/{snd,psnd,tsnd,rcv,prcv,trcv,ini,ref}_mbf`
は存在するが正常系のみ（各 wrapper ~50%）。

**機構**：既存 sample/messagebuf を正規 TESRY 化し、**ASP の dataqueue/pridataq テスト構造を踏襲**して
バリエーション追加：待ち遷移（タスク待ち→送受で起床）・`tsnd/trcv` のタイムアウト（`E_TMOUT`/ポーリング `E_TMOUT`）・
キュー満杯/空・`E_PAR`/`E_ID`/`E_OACV`（保護ドメイン跨ぎ）。
- ttsp3（git）側のみ。カーネル編集不要。

**コスト**：中。**ゲイン**：大（~50〜90 分岐）。

---

## Method 3（中ゲイン・中コスト）：ref_mem 追加 ＋ prb_mem read 方向

**対象**：mem_manage.c 41＋memory.c 13。`refer_memory`/`_kernel_ref_mem` 0%（**ref_mem テスト皆無**）、
`_kernel_probe_mem_read` 0%（既存 `api_test/HRP/memory/prb_mem/*` は write 方向のみ）。

**機構**：
- `api_test/HRP/memory/ref_mem/`（新規）＝`ref_mem` の保護ドメイン×アクセス権マトリクス（HRP の prb_mem を雛形）。
- prb_mem に `TPM_READ` 方向の変種追加（既存は `TPM_WRITE` 中心）。
- ttsp3（git）側のみ。

**コスト**：中。**ゲイン**：中（~50 分岐）。

---

## Method 4：sys_manage m系 — ★実装済（再実験成功・2026-06-14）sys_manage.c 52.5%→76.7%

**実装結果（堅牢なクローン手法・3 batch）**：sys_manage.c **52.5%→76.7%**（mrot_rdq 0→13/26・mget_lod 0→16/28・
mget_nth 0→18/30）、HRP 全体 87.1%→**89.4%**。**3 batch とも binaries 20/20・マージ安定・新規テスト全緑**。

- **batch1**（commit 434a07b）：既存緑テスト `get_lod`/`get_nth` の `_H_ex` を **`TDOM_SELF` 付与でクローン**（19件）。
  `mget_*(TDOM_SELF,...) ≡ get_*(...)` で期待値・状態が同一＝読取専用で caller running 維持＝マージ安定。→ 88.5%
- **batch2**（commit 0856b4f）：E_PAR（ASP get_*_b-1/b-2 クローン＋post に TASK1 running 明示）＋ mrot_rdq
  （rot_rdq_H-a クローン＋**非self回転** E_OK）。→ 89.0%
- **batch3**（commit 13c72c9）：E_MACV（get_tid_H-a パターン＝user ドメイン＋TTSP_MACV_ADDRESS）＋ mrot_rdq E_PAR。→ 89.4%

**前回 PoC 失敗の教訓と対策**：前回は自動生成テストがマージ不安定（T5_012/013）＋runtime 誤りで非収束→revert。
今回は **①既存の緑テストをクローン（期待値が保証される）②caller を必ず running に保つ（T5_012/013 を構造回避）
③小さく作って毎 batch ビルド検証** で、安定的に積み上げた。

**残（構造的に困難・未実装）**：mget_lod 12/28・mget_nth 12/30・mrot_rdq 13/26 の未到達＝
①**E_ID**（無効 DOMID が tmax_domid のcfg全体・マージ依存で確実な無効値を選べない。TTSP に invalid-domid マクロ無し）、
②**mrot_rdq dispatch 分岐**（self優先度回転＝caller が running→ready の状態変化でマージ脆弱）、
③**TDOM_KERNEL の値検証**・**非タスク文脈 E_CTX**（handler 起因でアクセス権検査順序が絡む）。
これらは ROI 低＋マージ安定性リスクのため見送り（必要なら TTG 側の split 改善とセットで）。

**非緑残**：auto_code_3（`ASP_mutex_tloc_mtx`）等は **m系 非起因の既存 flaky**（[`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) §3）。

### （参考）到達性の調査結果

**対象**：sys_manage.c 96。m系（`mrot_rdq` 0/26・`mget_lod` 0/28・`mget_nth` 0/30＝84分岐）＋単一PE系 tail（~12分岐）。

**到達性 判定：到達可能（schedno=保護ドメインID）。** `#ifdef TOPPERS_m*` でコンパイル済み
（`hrp3/kernel/Makefile.kernel` L119-120）。HRP では第1引数 `ID schedno` は **DOMID** として解釈される
（FMP/HRMP は schedno=プロセッサ。`sys_manage.c` mrot_rdq L251-265 が TDOM_KERNEL/TDOM_SELF/VALID_DOMID と突合）。
0% の原因は不在APIではなく **HRP 用 m系テストが皆無**（m系 yaml は FMP/HRMP ツリーのみで HRP build に含まれない）。
PoC で実測：m系テストを書くと mrot_rdq/mget_lod/mget_nth が到達し sys_manage.c 52.5%→~83%（+~60分岐）を確認済み。

**実装は deferred（自動生成テストの品質が不足）**：エージェント自動生成の m系テストは、
(a) **マージ安定性**＝状態変化を伴う rotation テスト（mrot_rdq は呼出しタスクが running→ready）で、TTG が
グループ統合時に「後続 post_condition で caller が running か」を検査する `T5_012`/`T5_013`（ercd 指定有無で
表裏）に抵触し、分割の度に別群が build 失敗（収束しない）。(b) E_ID（無効 DOMID の選定）・load 計数・
非タスク文脈 E_CTX 等の **runtime 期待値**に複数の誤り。→ **正しく実装するには post_condition を
マージ安定（caller を確実に running に保つ／rotation は非self優先度を回す等）に再設計し、各 runtime 期待値を
HRP セマンティクスで検証する必要**（PoC は一旦 revert）。

**コスト**：中〜大（再設計＋反復ビルド検証）。**ゲイン**：~60-90分岐（sys_manage.c 52.5%→~83-98%）。
**次着手時の要点**：①全 ercd テストの post に `caller: tskstat: running` を明示（T5_012/013 回避）、
②mrot_rdq は TASK1 が running を保つ優先度/構成にする、③E_ID は確実に無効な DOMID（TTSP に invalid-domid
マクロが無いため要工夫）、④非タスク文脈 E_CTX のチェック順序（HRP は acptn 検査との順序に注意）。

---

## Method 1（中規模・TTG組み込み可能）：SOM／時間区画スケジューリング — ★PoC実装・検証完了（2026-06-14）

> **PoC 結果サマリ（2026-06-14）**：TTG 拡張＋chg_som/get_som テストを実装し**単体で緑**を確認。
> domain.c **branch 6.7%(6/90)→~41%(37/90 union)**（chg_som 0→13/24・get_som 0→6/18＋scyc/twd 機構が点灯）。
> bb 全体は **20/20 binaries build OK**（既存テストのビルド回帰なし）。
> ⚠ **重大な統合制約を発見**：`DEF_SCY` は**プログラム全域**に効き、ユーザドメインのタイムイベント（alarm/cyclic）を
> ウィンドウ駆動のヒープへ移すため、**停止モードでは発火しない**。結果 **SOM テストを既存の
> ユーザドメイン alarm/cyclic テストと同一バイナリにマージすると後者がハング**する（auto_code_2/11 で実証）。
> よって**段階③以降は SOM テスト専用の隔離ビルド群**が必要（下記「PoC 実施結果」参照）。詳細は本節末尾。

**対象**：domain.c 84（最大の単一機能ギャップ）。`chg_som`/`get_som`/`_kernel_twd_*`（time window domain）/
`_kernel_scyc_*`（system cycle）/`_kernel_twdtimer_*` が**全 0%**。HRP3 3.4 に実在・コンパイル済み
（`hrp3/kernel/Makefile.kernel`：chg_som.o/get_som.o/twdsta.o/scycstart.o 等）。

**到達条件（調査で特定）**：`chg_som`/`get_som` は冒頭で **`CHECK_OBJ(system_cyctim != 0)`**（domain.c L577/L667,
NGKI5035/5065）。`system_cyctim` は既定 0（`domain.trb:83`）で、**静的に DEF_SCY（システム周期）＋ ATT_TWD
（タイムウィンドウのドメイン割当）を定義したときのみ非0**になる。現行テストは誰も定義しないため、到達するのは
E_OBJ 早期リターンのみ（＝現状 6/90）。残り 78 分岐は system cycle 定義が前提。
- 静的API: `ATT_TWD({ ID domid, ID somid, int_t twdord, PRCTIM twdlen, <通知方法> })`（user.txt L1268）。
  DEF_SCY が先に必要（無いと ATT_TWD 無視・NGKI5052）、保護ドメインの**外**に記述（E_RSATR・NGKI5041）。

**実装結果（2026-06-14・commit 67f6012 PoC＋94e1a3f 隔離ビルド群）**：TTG に新オブジェクト型3種
（`SYSTEM_CYCLE`/`SYSTEM_OPERATION_MODE`/`TIME_WINDOW`→`DEF_SCY`/`CRE_SOM`/`ATT_TWD`）を追加（`SystemCycle.rb`）。
chg_som/get_som テスト＋**SOM 隔離ビルド群**（DEF_SCY 単一＝1テスト1バイナリ・通常bbからは exclude_tests.txt で除外し
ハング回避・gcda union）で **domain.c 6.7%→44.4%（chg_som 13/24・get_som 6/18・scyc/twd/twdtimer 点灯）、HRP 全体
89.4%→90.8%**。カーネル無編集。**残**：`_kernel_twd_switch`/`scyc_switch`/`twdtimer_stop`（0%）は周期タイマが
ウィンドウ境界を**実際に跨ぐ**時に動くため、時間を進める追加テスト（TA_INISOM で初期SOM起動＋十分な twdlen 経過）が必要。

**判定（2026-06-14 TTG 組み込み再調査）：TTG への組み込みが可能（中規模）。手書きWB限定ではない。**
- 当初「TTG 非対応＝手書きWBのみ」と判定したが、TTG 内部を精査して**組み込み可能**と再判定。
- ⭐ **最大の障壁（スケジューラのモデル化）は不要**：`tools/ttg/ttc/bin/test_scenario/TestScenario.rb` は
  スケジューラを**シミュレートせず**、author 指定状態の**整合性検証のみ**（T5_012/013 等）。よって SOM の
  時間区画スケジューリングを TTG に実装する必要はなく、author がテストで期待状態を書けばよい。
- **必要な実装**（`sys_state/Domain.rb`(166行)・`Memory.rb` を雛形に）:
  ①新オブジェクト型 `type: SYSTEM_CYCLE`（→`DEF_SCY`）＋ `type: TIME_WINDOW`（→`ATT_TWD({domid,somid,twdord,
  twdlen,通知})`）の sys_state モジュール（common=cfg生成／ttc=シナリオ）＝**中**、②`CommonModule.rb` に
  `TSR_OBJ_SYSTEM_CYCLE/TIME_WINDOW`＋`TSR_PRM_SOMID/TWDORD/TWDLEN`＋型リスト＝**小**、③`tools/ttg/ttc/bin/
  kwalify/kwalify.schema.yaml` に新 type/フィールド＝**小**、④`chg_som`/`get_som` は通常 syscall（既存 `do:` で生成可）＝**小**。
- ttsp3 側のみ（カーネル編集不要）。

**コスト**：中（数日。新オブジェクト型2つ＋登録＋スキーマ）。**ゲイン**：domain.c 6.7%→最大~83%（~78分岐）。
**残る難所（TTG でなくテスト設計側）**：
- `chg_som`/`get_som` の分岐（~42）＝周期を静的定義すれば直接呼出し（STP→SOM1→SOM2＋エラー系）で**容易に到達**。
- `_kernel_twd_*`/`_kernel_scyc_*`/`twdtimer`（~36）＝周期タイマが実チックしてウィンドウ切替時に動くため、
  時間を進める **タイミング依存テスト**（alarm/cyclic 同様）が必要＝**やや難**。

> **段階案**：①SYSTEM_CYCLE/TIME_WINDOW 型を TTG に追加 → ②chg_som/get_som 静的テスト（~42分岐・容易）
> → ③twd/scyc タイミングテスト（~36分岐・要調整）。**手書きWB より保守性が高く SOM テストが TESRY 一級市民になる**。
> （旧案＝手書き WB cfg `wb_test/HRP/domain/` も依然 stretch goal として可。TTG 組み込みが本筋。）

### PoC 実施結果（2026-06-14・実装＋検証完了）

**実装（ttsp3 git 側のみ・カーネル編集なし）**：
- **新オブジェクト型 3 種**（手順は 2 種としていたが、`ATT_TWD` の `somid` が `CRE_SOM` 生成の SOM を参照し、
  `chg_som(somid)` も有効 SOM を要するため `SYSTEM_OPERATION_MODE` を追加）：
  - `SYSTEM_CYCLE`（`scytim`）→ `DEF_SCY({scytim});`
  - `SYSTEM_OPERATION_MODE`（`somatr`/`nxtsom`）→ `CRE_SOM(somid, {somatr[, nxtsom]});`
  - `TIME_WINDOW`（`domid`/`somid`/`twdord`/`twdlen`）→ `ATT_TWD({domid, somid, twdord, twdlen});`
  いずれも保護ドメインの**外**へ emit（`IMC_NO_DOMAIN`）。
- `tools/ttg/common/bin/CommonModule.rb`：`TSR_OBJ_*`／`TSR_PRM_SCYTIM/SOMATR/NXTSOM/DOMID/SOMID/TWDORD/TWDLEN`／
  API マクロ `DEF_SCY/CRE_SOM/ATT_TWD`／`GRP_DEF_OBJECT_HRP`（＋HRMP）に登録。
- 新規 `tools/ttg/{common,ttc}/bin/sys_state/SystemCycle.rb`（Memory.rb を雛形に 3 クラス）。
- `tools/ttg/common/bin/test_scenario/Condition.rb`：ファクトリ登録＋`require`＋参照不可リストに追加。
- **kwalify スキーマ編集は不要だった**（手順④は誤り）：`kwalify.schema.yaml` は Kwalify ライブラリの**メタスキーマ**で
  あり、TESRY のオブジェクト型ゲートは Ruby の `GRP_DEF_OBJECT_HRP` が担う（`PreCondition.rb:74-88` で `.keys()` を参照）。
- テスト：`api_test/HRP/sys_manage/chg_som/chg_som_H-a.yaml`（停止→SOM1→停止の 2 段 `do`・各 E_OK）、
  `get_som/get_som_H-a.yaml`（停止モードで `get_som`→`TSOM_STP`）。呼出しタスクは**カーネルドメイン**（`domain:` 省略）で
  実行し `sysstat1` 既定値（`TACP_KERNEL`）で許可（`SAC_SYS` 不要）。

**検証結果**：
- **bb 20/20 binaries build OK**（161s）。私の変更による**ビルド回帰なし**。
- **単体（隔離）実行で両テスト緑**：chg_som-only / get_som-only いずれも `All check points passed`。
- **カバレッジ（domain.c・per-function gcov）**：
  | 関数 | baseline | chg_som単体 | get_som単体 |
  |---|---|---|---|
  | `_kernel_chg_som` | 0/24 | **13/24 (94% line)** | 0/24 |
  | `_kernel_get_som` | 0/18 | 0/18 | **6/18 (100% line)** |
  | `_kernel_scyc_start` | 0/4 | 2/4 | – |
  | `_kernel_twd_start` | 0/10 | 5/10 | – |
  | `_kernel_twdtimer_start/control` | 0 | 1/2・3/8 | – |
  | domain.c 全体 branch | **6/90 (6.7%)** | 31/90 | 12/90 |
  - 2 テスト union ≈ **37/90 (41.1%) branch / 112/187 (59.9%) line**。chg_som が周期開始経路
    （`scyc_start`/`twd_start`/`twdtimer`）まで点灯させた点が大きい。

**⚠ 発見した統合制約（段階③以降の設計に必須）**：
1. **`DEF_SCY` はプログラム全域**：定義すると**全ユーザドメイン**のタイムイベントが
   `tmevt_heap_kernel`（HRT 割込み `signal_time()` が処理）から**ドメイン別/idle ヒープ**へ移る。これらは
   タイムウィンドウ駆動（`twd_start`/`scyc_start`）でしか処理されず、**停止モードでは発火しない**
   （`time_event.c:signal_time` は kernel ヒープのみ・`domain.c:twd_start` が idle/per-dom ヒープ処理）。
   → 既存の**ユーザドメイン alarm/cyclic テストと同一バイナリにマージすると当該テストが永久待ち→ハング**
   （bb の auto_code_2＝get_som と auto_code_11＝chg_som がともに alarm テストで停止、他 18 群は緑＝実証）。
2. **`chg_som` のモード切替は周期境界まで遅延**：`chg_som(somid)` は `p_nxtsom` を設定するだけで `p_cursom` は
   次のシステム周期境界まで変わらない（停止→初回のみ即 `scyc_start`）。よって `chg_som(TSOM_STP)` 直後でも
   `get_som` は旧 SOM を返す。**chg_som と get_som を同一バイナリに同居させると get_som の期待値が崩れる**
   （TTG はテストをキー昇順で実行＝chg_som が先）。

**→ 段階③（bb 統合）の必須対応**：`DEF_SCY` を含むテストを**専用の隔離ビルド群**（共有 20分割から除外し
SOM 専用 auto_code を別建て）にする。ビルド基盤側の小改修（`scripts/ttsp_parallel_api.sh` の manifest 分配 or
`exclude_tests.txt` 併用で SOM 専用群を生成）が要る。隔離群内でも chg_som と get_som は別バイナリ/別群にするか、
get_som を chg_som より前に実行する構成にする。**TTG 拡張・テスト記述自体は完成しており、残りは配置（隔離）のみ**。

**次の拡張（段階③詳細・~36分岐）**：未到達は `_kernel_get_som`/`_kernel_chg_som` のエラー系分岐
（`E_CTX`/`E_OBJ`/`E_ID`/`E_OACV`/`E_MACV`＝負テスト）と `scyc_switch`/`twd_switch`/`set_dspflg`/`twdtimer_stop`
（周期タイマを実チックさせ**ウィンドウ切替を起こすタイミング依存テスト**＝alarm/cyclic 雛形）。
これらは上記「隔離ビルド群」前提で追加する。

**注意**：カーネル(hrp3)編集は不要（TTG＝ttsp3 git 側のみ）。`DEF_SCY` が無いと `ATT_TWD`/`CRE_SOM` は無視される。

#### 段階④ 着手メモ（chg_som/get_som 残分岐のカーネル順・2026-06-14 分析）

現状 chg_som 13/24・get_som 6/18。配置は `api_test/HRP/sys_manage/{chg_som,get_som}/`（exclude_tests.txt の
`sys_manage/chg_som`・`get_som` パターンで通常bb除外＆SOM隔離群入り＝**追加設定不要**）。caller は running 維持（T5_012/013 回避）。

- **chg_som のチェック順**（domain.c L576-）：`CHECK_TSKCTX_UNL`(E_CTX) → `CHECK_OBJ(system_cyctim!=0)`(E_OBJ※SOM定義時成立) →
  `somid==TSOM_STP` 分岐 or `CHECK_ID(VALID_SOMID)`(E_ID) → `CHECK_ACPTN(sysstat1_acvct.acptn1)`(E_OACV) →
  `if(p_cursom==NULL && p_sominib!=NULL)`（STP→SOM＝周期開始） / `else`（SOM→SOM・SOM→STP） → `dspflg` true/false → `p_runtsk!=p_schedtsk`(dispatch)。
  → 追加変種：①E_CTX（アラームハンドラ呼出）②E_ID（不正 somid＝CRE_SOM 数+1）③E_OACV（sysstat1 通常操作1 不許可ドメイン）
  ④**SOM→SOM**（CRE_SOM 2つ＋各 TIME_WINDOW、chg_som(SOM1)→chg_som(SOM2)→STP＝else 経路・dspflg 分岐）⑤dispatch 分岐（SOM 切替で実行タスク変化）。
- **get_som のチェック順**（domain.c L666-）：`CHECK_TSKCTX_UNL`(E_CTX) → `CHECK_OBJ` → `CHECK_MACV_WRITE(p_somid)`(E_MACV) →
  `CHECK_ACPTN(acptn4)`(E_OACV) → `*p_somid = (p_cursom==NULL)? TSOM_STP : SOMID(p_cursom)`。
  → 追加変種：①E_CTX ②E_MACV（TTSP_MACV_ADDRESS）③E_OACV ④**SOM 稼働中**（chg_som(SOM1) 後に get_som＝`p_cursom!=NULL` 側で SOMID 返り。現状 STP 側のみ）。
- **(b) twd/scyc 点灯**：`SYSTEM_OPERATION_MODE` に `somatr: TA_INISOM`（起動時から周期稼働）＋ TIME_WINDOW 複数、
  時間を十分進めて（dly_tsk 等で twdlen 超）ウィンドウ境界を跨がせる → `twd_switch`/`scyc_switch`/`twdtimer_stop` 発火（alarm/cyclic タイミングテスト同様）。

---

## Method 5（小ゲイン）：standard API の tail（ASP WB 技法の移植）

- **exception.c** xsns_dpn 7/10 → ASP の `wb_test/ASP/exception/xsns_dpn_W-b`（custom idle で `p_runtsk==NULL` 到達）を
  `wb_test/HRP/` へ移植 → +3。
- **time_event.c / time_manage.c** の 64bit 境界・ヒープ多段（`tmevtb_enqueue`/`tmevt_proc_top` 等）→ ASP は simt
  （simulation timer）で到達。**HRP simt は未整備**のため一部のみ（WB の custom idle で届く範囲）。残は到達不能文書化。
- standard API（task/sem/flg/dtq/pdq/mtx/mpf/alm/cyc）の各 tail（~75 分岐の一部）→ 既存カテゴリへ境界/エラー変種追加。

**コスト**：小〜中。**ゲイン**：小（~15〜30 分岐、構造的到達不能が多い）。

---

## 対象外（構造的到達不能・WB 不要）

- `svc_table.c` の `no_support` スタブ群（実コード行が無い）
- 単一コア確定分岐（HRP は単一コア）
- `-O2` インライン展開アーティファクト（既にインライン抑制で除去済）

---

## 推奨着手順（ROI順）

| 順 | Method | ゲイン目安 | コスト | カーネル編集 |
|---|---|---|---|---|
| 1 | **M6** auto_code_19 回復 | 中（実証済・即効） | 小 | 要（hrp3 zybo・R5同型） |
| 2 | **M2** messagebuf 異常系 | 大 ~50-90 | 中 | 不要 |
| 3 | **M3** ref_mem＋prb_mem read | 中 ~50 | 中 | 不要 |
| 4 | **M4** sys_manage tail＋m系調査 | 中〜大 | 中 | 不要 |
| 5 | **M1** SOM/時間区画 | 最大 ~70 | 大（要TTG） | 不要 |
| 6 | **M5** standard tail/ASP WB移植 | 小 | 小 | 不要 |

**到達目標（目安）**：M2+M3+M4tail+M6 で **82% → 90%前後**（保護/メモリ/messagebuf の正常系・異常系回収）。
さらに M1（SOM）到達で **92〜94%**。ASP(99.3%)/FMP(97.1%) 並みは SOM・m系の構造的到達性次第。

> 関連：[`ALL_COVERAGE.md`](ALL_COVERAGE.md)（現状）／[`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)（未到達分析）／
> [`COVERAGE_R5.md`](COVERAGE_R5.md)／[`../STATUS.md`](../STATUS.md)（合否）。
> 手法参考：ASP `wb_test/ASP/`＋`docs/ASP/BB_UNREACHABLE.md`、FMP `docs/FMP/COVERAGE_RAISE_PLAN.md`。
