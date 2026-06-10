# COVERAGE_RAISE_PLAN.md — FMP カバレッジ向上プラン（fmp3 編集可・前提）

> FMP3 `kernel/` の分岐カバレッジをさらに引き上げるための方法検討。
> **前提：被テストカーネル fmp3 の編集を許可**（通常は禁則②で不可。本プランは target/構成の追加・
> 変種ビルドのために fmp3 編集を認める特例前提）。2026-06-10 策定。
> 現状 → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)（all **1550/1597 = 97.1%**・残 47）、分類 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)。

---

## 0. 現状の到達余地（下表は Method B 着手前=残 52 時点の内訳。**Method B 適用後 = 残 47**）

| 分類 | 残 | 本プランでの扱い |
|---|---|---|
| interrupt.c（§2）| 17 | **Method C**：大半は構造的dead/SGIマクロ無/timing-affinity ＝ fmp3 編集でも閉じない |
| time_event.c §5-c 非TM-processor転送 | 約5 | **Method B**：`TOPPERS_TEPP_PRC` 変種で到達（最良コスパ）|
| time_event.c §5-d/§5-e（HRTCNT_BOUND / signal_time nocall）| 2 | **Method A**：simt（simulation timer）で到達 |
| time_manage.c §10 adj_tim 64bit 折返し | 2 | **Method A**：simt で到達（ASP 実証済の同型）|
| マルチコア遅延ディスパッチ残（§1・各所散在）| 数本 | timing_test（dis_dsp/chg_ipm の +2 は実証済・union外運用）|
| サブ優先度/防御コード/構造残 | 残り | 到達不能（防御的再チェック等）|

→ 本プランで現実的に追加到達できるのは **Method B（約5-6）＋ Method A（約4）＝ 約10 分岐**。
達成見込み：**52 → 約42、96.7% → 約97.4%**（うち Method B は **52→47 達成済**・96.7→97.1%、Method A 残 ~3）。interrupt.c 残（Method C）は構造的に閉じない。

---

## Method B：単一 TM-processor 構成変種で §5-c を到達 ★最優先 — ✅ 着手・PoC到達（2026-06-10）

> **進捗**：`wb_test/FMP/time_event/tepp1_W-a`（`-DTOPPERS_TEPP_PRC=0x1`）で **§5-c の 4 分岐
> （L168 init else / L583 `tmevtb_enqueue_reltim` 転送 / L627 dequeue 転送 ＋ tepp1_W-b で L546 enqueue 転送）を到達**・QEMU 緑。
> fmp3 は `target/zybo_z7_gcc/target_kernel.h` の `TOPPERS_TEPP_PRC` を `#ifndef` ガード化（既定 0x3 不変）、
> `coverage_gcov_fmp.sh` に `wb_extra_copts.txt` フックを追加。残 L522（`tmevtb_register`＝cyclic・PRC1限定）は構造的到達不能。旧記の
> L546 は tepp1_W-b（mig_tsk）で到達済。**`all` 再計測で確定：52→47**（time_event.c §5-c +4
> ＋ startup.c §9-b +1＝計+5。`all` 1545→1550/1597=97.1%。`ALL_COVERAGE.md`）。


### 機構
FMP は時刻イベント処理を行う PE を **`TOPPERS_TEPP_PRC`**（ビットマスク）で指定する。
- 定義：`fmp3/target/zybo_z7_gcc/target_kernel.h:40` … `#define TOPPERS_TEPP_PRC 0x3`（PRC1+PRC2）。
- `time_event.c` `initialize_tmevt`（L150-168）：自PEのビットが立たない場合 `p_my_pcb->p_tevtcb = NULL`。
- `p_tevtcb == NULL` の PE が時刻イベントを登録/操作すると **`p_pcb = P_TM_PCB`** へ転送
  （L522/546/583/627）＝ **§5-c の未到達分岐**。zybo 既定 0x3（全PE）では常に非NULL＝dead。

### 対象分岐（約5-6）
`time_event.c` L168（`p_tevtcb=NULL` 代入）/ L522 / L546 / L583 / L627（P_TM_PCB 転送）。

### 手順
1. **変種 target を追加**（fmp3 編集）：`fmp3/target/zybo_z7_tepp1_gcc/` を zybo_z7_gcc から複製し
   `TOPPERS_TEPP_PRC = 0x1`（PRC1 のみ）に。あるいは TTSP3 側ビルドで `COPTS`/専用 cfg ヘッダにより
   `TOPPERS_TEPP_PRC` を上書き（fmp3 無改変で済むなら望ましい・要 cfg 機構確認）。
2. **テスト**：PE2 から**タイムアウト系 API**（`tslp_tsk`/`dly_tsk`/`twai_sem`/`twai_flg` 等）を発行し、
   PE2 で時刻イベント登録 → TM master(PRC1) へ転送させる。
   ※注意：`alarm.trb`/`cyclic.trb`（L64/L76）は「クラスの割付けPEが TEPP の部分集合」を要求するため、
   `TOPPERS_TEPP_PRC=0x1` では **アラーム/周期ハンドラは PRC1 限定**。§5-c は PE2 のタスクタイムアウトで踏む。
3. **gcov 計測**：`coverage_gcov_fmp.sh` を変種 target で回し `time_event.c` §5-c の到達を確認。

### コスト／ゲイン
- コスト **中**（target 変種 1 つ＋タイムアウトテスト数本）。fmp3 編集は `target_kernel.h` 1 行（または cfg 上書き）。
- ゲイン **約5-6 分岐**。FMP 固有で ASP に前例なし＝新規価値。

---

## Method A：FMP simt（simulation timer）ターゲットで時刻 64bit 系を到達 — ⏸ 保留（feasibility 評価済 2026-06-10）

> **feasibility 調査の結論（2026-06-10）：ROI 不足のため保留**。
> - **対象4分岐は simt 必須が確定**：`TMAX_RELTIM=4,000,000,000` が `HRTCNT_BOUND=4,000,000,002`（`mpcore_timer.h`）
>   の**直下に意図設計**＝API経由で §5-d（`set_hrt_event` の `hrtcnt > HRTCNT_BOUND`）を踏めない。
>   `EVTTIM` は uint32（`tmevt.h`・`!USE_64BIT_HRTCNT`）、§10 `adj_tim` 64bit 折返しは HRT 直接操作が前提。
>   ＝zybo 実タイマでのショートカット不可。
> - **ASP simt の実体**：`asp3/arch/simtimer/tSimTimerCntl.c`（**TECS ベースのソフトHRTコンポーネント**）＋
>   `ct11mpcore` チップ ＋ `simt_systim*` テストの3点セット。
> - **FMP の障壁**：`fmp3/arch/` は arm_gcc/gcc/posix_gcc/tracelog のみで **`arch/simtimer` が存在しない**。
>   ゼロから移植が必要で、かつ FMP のマルチプロセッサ時刻モデル（TM master・PE毎ヒープ・IPI転送）への
>   適合＋TECS 連携が絡む＝**大規模・高リスク**。
> - **ゲインは +4 分岐（47→43、97.1→97.4%）**＝大規模移植に見合わない。
> - 当該4分岐（§5-d/§5-e/§10×2）は `ALL_COVERAGE.md`/`BB_UNREACHABLE.md` で
>   **「simt 到達可能・FMP未実施」と正当に分類済**（ASP と同じ扱い）。現状の記述は誤りではない。
> ⇒ **着手しない**。将来 asp3_core(Phase 2) で simt 同型基盤が整う場合に再評価する。

### 機構（ASP3 の simt を FMP へ移植）※以下は将来着手する場合の設計メモ
ASP3 は `simtimer_ct11mpcore_gcc`（simulation timer・HRT を任意操作）＋ 自前テスト `simt_systim1-4`/`_64hrt`
（`HRT_CONFIG1/2/3`・`SIMTIM_TEST`）で、zybo 実 GIC タイマでは到達不能な時刻分岐を C1 到達している
（`scripts/simt_coverage/` ＋ `docs/ASP/BB_UNREACHABLE.md` 第3部）。
**ct11mpcore＝ARM11 MPCore＝マルチプロセッサ**なので FMP に自然適合する。

### 対象分岐（約4）
- `time_manage.c` §10 `adj_tim` 64bit `EVTTIM` 折返し（2・ASP では simt で `adj_tim` 14/14 到達済）。
- `time_event.c` §5-d `HRTCNT_BOUND` 超（L474）/ §5-e `signal_time` nocall（L757）。
- （波及）`update_current_evttim`/`set_hrt_event` の 64bit 系。

### 手順
1. **FMP `ct11mpcore_gcc` target を整備**（fmp3 編集）：標準 FMP3 upstream に存在すれば import、
   無ければ `asp3/target/{ct11mpcore_gcc,simtimer_ct11mpcore_gcc}` ＋ fmp3 `arch/arm_gcc` から移植
   （MPCore 多PE起動・GIC・タイマ）。FMP のマルチプロセッサ起動に対応させるのが要点。
2. **`simtimer_ct11mpcore_gcc`（FMP版）**：simulation timer オーバーレイ（`SIMTIM_TEST`・HRT 任意操作）。
3. **simt テスト移植**：`asp3/test/simt_systim{1-4}{,_64hrt}.c` を FMP 用に複製し、
   **TM master PE（PRC1）で時刻テストを実行**する多PE cfg に調整。
4. **gcov 機構複製**：`scripts/simt_coverage/{ct11mpcore_gcov.ld,gcov_dump.c,simt_suite.sh}` を FMP 用に複製
   （filter `/fmp3/kernel/`）。
5. **実行**：`qemu-system-arm -M realview-eb-mpcore -semihosting -nographic -smp N -kernel fmp`。

### コスト／ゲイン
- コスト **大**（新 target＋chip 起動＋テスト移植＋多PE 対応）。fmp3 編集（target 追加）必要。
- ゲイン **約4 分岐**。ASP に実装・実証の前例があるため設計リスクは中。

---

## Method C：interrupt.c 残 17 — fmp3 編集でも大半は閉じない（文書化）

精査済（[`BB_UNREACHABLE.md §2`](BB_UNREACHABLE.md)）：
- `check_intno_clear()`/`check_intno_raise()` は GIC で**無条件 `return(true)`** → 複合 `&&` の false アーム
  （L268/L307 各 br4）は構造的 dead。閉じるにはカーネルロジック改変＝**カバレッジの意味を失う**ため不可。
- `VALID_INTNO_*` の **SGI 節**：SGI（MASK 0-15）用のテスト用 `INTNO` マクロが無い（SGI は `IPINO_DISPATCH`
  等カーネル内部 IPI 専用）。SGI 負テストは IPI と衝突しうるため非推奨。
- `chg_ipm` L383（dispatch retry）＝timing（`chg_ipm_race` で到達実証済・union外）。
- `chg_ipm` L392（`task_terminate` 返値）＝CPU アフィニティ依存。**任意**：`mig_tsk` で対象タスクの割付けPEを
  変えてから終了要求＋`chg_ipm(TIPM_ENAALL)` で到達を試行可能（1 分岐・低価値）。

→ 推奨：**Method C は文書化のみ**。L392 のみ任意で affinity テストを試行。

---

## まとめ・推奨着手順

| 順 | Method | ゲイン | コスト | fmp3 編集 |
|---|---|---|---|---|
| 1 | **B（単一TM-processor変種）** | ~5-6 | 中 | target_kernel.h 1行（or cfg上書き） |
| – | ~~A（FMP simt ターゲット）~~ ⏸保留 | ~4 | 大 | target 新設（ROI不足・feasibility 評価済）|
| – | C（interrupt.c） | ~0-1 | – | 文書化のみ |

- **Method B から着手**を推奨（FMP固有・最良コスパ・小さな変種で済む）。
- **Method A は保留**（simt-arch 移植が大規模・+4分岐で ROI 不足。feasibility 評価＝本節冒頭）。
- 到達実績：**Method B 達成 52→47（97.1%）**。Method A（+~4・約97.4%）は ROI 不足で保留。timing_test の +2（dis_dsp/chg_ipm L383）を union に
  含めれば追加で +2。
- **検証**：いずれも変種ビルドの gcov を `ttsp_gcov_report.py --filter /fmp3/kernel/` で集計し、
  本流（zybo all）とは別トラックで union（simt_coverage と同じ「参考トラック」運用）。
- **改変記録**：fmp3 を編集する場合は変更点を `UPSTREAM_KERNEL.md`／`DIVERGENCE_MAP.md` に明記し、
  ライセンス条件（改変明記）を満たすこと。標準 FMP3 への取込み可否は別途判断。
