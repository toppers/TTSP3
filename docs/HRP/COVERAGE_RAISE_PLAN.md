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

## Method 4（中・要調査）：sys_manage tail ＋ m系の到達性調査

**対象**：sys_manage.c 96。
- **単一PE系 tail**（`rot_rdq` 15/16・`get_tid/get_did` 8/10・`get_lod` 17/20・`get_nth` 19/22・`dis_dsp` 7/8）
  ＝境界・エラー系の追加で回収（~20 分岐）。ttsp3 側。
- **m系**（`mrot_rdq` 0/26・`mget_lod` 0/28・`mget_nth` 0/30＝84分岐）＝`#ifdef TOPPERS_m*` でコンパイル済だが
  `schedno`（スケジューリング単位）指定 API。**HRP 単一スケジューリング単位での到達性を要調査**：到達可能なら
  schedno=自スケジューラのテスト追加（大ゲイン）、構造的単一なら到達不能として文書化（[`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)へ）。

**コスト**：中（tail）＋調査。**ゲイン**：中〜大（m系の判定次第）。

---

## Method 1（高コスト・手書きWBのみ）：SOM／時間区画スケジューリング — ★調査確定（2026-06-14）

**対象**：domain.c 84（最大の単一機能ギャップ）。`chg_som`/`get_som`/`_kernel_twd_*`（time window domain）/
`_kernel_scyc_*`（system cycle）/`_kernel_twdtimer_*` が**全 0%**。HRP3 3.4 に実在・コンパイル済み
（`hrp3/kernel/Makefile.kernel`：chg_som.o/get_som.o/twdsta.o/scycstart.o 等）。

**到達条件（調査で特定）**：`chg_som`/`get_som` は冒頭で **`CHECK_OBJ(system_cyctim != 0)`**（domain.c L577/L667,
NGKI5035/5065）。`system_cyctim` は既定 0（`domain.trb:83`）で、**静的に DEF_SCY（システム周期）＋ ATT_TWD
（タイムウィンドウのドメイン割当）を定義したときのみ非0**になる。現行テストは誰も定義しないため、到達するのは
E_OBJ 早期リターンのみ（＝現状 6/90）。残り 78 分岐は system cycle 定義が前提。
- 静的API: `ATT_TWD({ ID domid, ID somid, int_t twdord, PRCTIM twdlen, <通知方法> })`（user.txt L1268）。
  DEF_SCY が先に必要（無いと ATT_TWD 無視・NGKI5052）、保護ドメインの**外**に記述（E_RSATR・NGKI5041）。

**判定：到達可能だが TTG 非対応＝手書き WB cfg のみ。**
- ⛔ **TTG は SOM/タイムウィンドウ非対応**：`tools/ttg/common/bin/sys_state/` は CPUState/Domain/Memory のみで
  ATT_TWD/DEF_SCY の生成コードが無い。**標準 TESRY→TTG 経路は使えない**。
- ✅ 唯一の手段＝**手書き WB cfg**（`wb_test/HRP/domain/`）：DEF_SCY＋ATT_TWD で複数 SOM/タイムウィンドウを定義し、
  `chg_som(TSOM_STP→SOM1→SOM2)`/`get_som`/エラー系（E_CTX/E_ID不正somid/E_OACV）を駆動する out.cfg/out.c を手書き。
  ＋ coverage ハーネス（`coverage_gcov_hrp.sh` の WB 取り込み・ASP `wb_test/ASP/` に倣う）統合。
- ttsp3 側のみ（カーネル編集不要）。TTG 拡張（sys_state に TimeWindow 型追加）すれば自動生成も可能だが工数大。

**コスト**：**最大**（有効な system-cycle/time-window cfg の設計＋QEMU タイミング依存＋WB ハーネス統合）。
**ゲイン**：~50〜65 分岐（domain.c 6.7%→~60-75%、全体 +~2.5-3pp）。

> **推奨：M4（m系・標準TESRY・TTG不要・+90分岐）を先に実施し、M1 SOM は stretch goal** として後段
> （手書き WB か TTG 拡張）。M1 は「最大ゲイン」だが「最高コスト・手書きWB限定・タイミング依存」で ROI は M4 に劣る。

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
