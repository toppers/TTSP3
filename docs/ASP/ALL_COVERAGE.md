# ALL_COVERAGE.md — ASP3 kernel/ 分岐カバレッジ（ALL = BBテスト + WBテスト）

> 計測日: 2026-06-10（`all` モード = BBテスト + WBテスト）  
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh all` → `python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/`）  
> 対象: ASP3 3.7.2 `kernel/`、APIオートコード 20グループ統合（all 20/20 PASS）  
> ※ 集計バグ修正済（union 方式）。per-API テーブルも同一ツール値で更新済み。  
>
> このファイルは **BBテスト + WBテストを統合した `all` モードの最終カバレッジ** と **BBテストの追加履歴** を記録する。  
> - BBテストのみのカバレッジ（ファイル別） → [`BB_COVERAGE.md`](BB_COVERAGE.md)  
> - BB未到達分岐の分析・WBテスト対応・残存未到達 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)（第1部=WBで到達 / 第2部=残存未到達）
>
> **計測条件（コンパイルオプション）:**  
> - `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）  
> - `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（assert 失敗パスは仕様適合性の分岐ではないため計測対象外）  
> - **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`） — `-O2` の `static inline`（`Inline` マクロ）展開により gcov が各 call-site を個別計測して分岐数が水増しされる（wait.h 16→64 等）アーティファクトを除去するため、`-O2` を維持したまま inline のみ抑制する。各 inline 関数を1実体として計測し、論理分岐がそのまま反映され、bb/all の分母も一致する（`-O0` は実行時クラッシュ・タイミング変化のため不採用）。詳細理由は [`BB_COVERAGE.md`](BB_COVERAGE.md) 計測条件を参照。

## 全体サマリ（gcov 全分岐, ttsp_gcov_report.py, union集計）

```
分岐カバレッジ(kernel/): 1368/1379 = 99.2%  (C1, 2026-06-10 NDEBUG + -O2インライン抑制計測、all モード)
  ※bbモード（WBテストなし）: 1359/1379 = 98.5%（手書き WBテスト alarm/cyclic/mempfix/time_event/exception 含まず）
  ※WBテスト寄与: +9 分岐（bb 1359 → all 1368）。bb/all で分母 1379 が一致（インライン抑制によりビルド差が解消）
  ※インライン抑制移行後: wait.h 64→14・wait.c・task.c のインライン展開アーティファクトが解消（各 100% / 論理分岐がそのまま）
  ※残存未到達 11 分岐（all モード）: exception(1)/interrupt(3)/mutex(1)/task_refer(1)/time_event(4)/time_manage(1)
  --- 旧 -O2（インライン展開あり）計測の履歴参考値 ---
  ※-O2 all: 1435/1471 = 97.6%（wait.h 49/64 等のインライン水増しを含む。分母が bb 1459 と不一致）
  ※NDEBUG適用前（参考）: 1386/1405 = 98.6%（assert失敗パスを含む）
  ※旧バグ版(max集計):      1059/1405 = 75.4%（グループ間 union が取れていなかった）
```

**2026-06-10 -O2 インライン抑制へ移行（計測方式変更, all 1435/1471 → 1368/1379）**:
- カバレッジ計測を `-O2` + インライン抑制（`-fno-inline` 系）に変更。`static inline` 展開による gcov 分岐水増しアーティファクト（wait.h 16→64 等）を除去し、bb/all の分母を一致させた。理由は [`BB_COVERAGE.md`](BB_COVERAGE.md) 計測条件を参照。
- 結果: wait.h 49/64→14/14、wait.c/task.c も 100%。全体 C1 は実態反映で 99.2% に。inline 抑制で interrupt.c の実分岐が顕在化（58→62 分岐、未到達 1→3）。
- `xsns_dpn_W-a`（`wb_test/ASP/exception/`）: `exception.c` の `kerflg==false` 短絡評価パスを WBテストで到達（`ATT_INI` 初期化ルーチン経由）

**2026-06-10 テスト整理（カバレッジ数値変化なし: 1434/1459 = 98.3%）**:
- `act_tsk_c-3.yaml` (BB) 追加 → `task_manage.c` L137 br[1] が bb モードでも到達（bb: 1425→1426）
- 旧 WBテスト `act_tsk_W-a` 削除（同ブランチを BB テストが担当）
- `mempfix_W-a/b` → `rel_mpf_W-a/b` にリネーム・`api_test/ASP/mempfix/rel_mpf/` に再配置
- `alarm_W-a`, `cyclic_W-a`, `time_event_W-a/b` を `api_test/ASP/` から `wb_test/ASP/` に移動
- `coverage_gcov_asp.sh`: WBテスト検索を `find` ベースに変更（両ディレクトリ対応）

**2026-06-09 追加した BBテスト（mutex.c WBテスト、全20グループ PASS）**:
- `ini_mtx_e.yaml` — 未ロックのミューテックスに ini_mtx（mutex.c L558 br[1]）
- `ini_mtx_f.yaml` — remove_mutex が非先頭要素を削除（mutex.c L227/L228 br）
- `unl_mtx_g-1.yaml` — 2つの異なる上限優先度ミューテックスを保持中に低い方を解除（mutex.c L263 FALSE）
- `unl_mtx_g-2.yaml` — 2つの同じ上限優先度ミューテックスを保持中に一方を解除（mutex.c L202, L265 FALSE）
- `unl_mtx_g-3.yaml` — 待ちタスクの優先度 ≥ 上限優先度 → 優先度上昇なし（mutex.c L315 br[1]）
- `unl_mtx_g-4.yaml` — 待ちタスクの優先度 < 上限優先度 → 優先度上昇あり（mutex.c L315 br[0]）
- `unl_mtx_g-5.yaml` — 非上限優先度ミューテックスを含む保持中に上限優先度ミューテックス解除（mutex.c L203 br[1]）
- `chg_pri_j-1.yaml` — ロック済みミューテックスリスト内の非上限優先度ミューテックス（mutex.c L161 FALSE）
- `chg_pri_j-2.yaml` — 待ちミューテックスが非上限優先度の場合（mutex.c L173 pos.2 FALSE）
- `chg_pri_j-3.yaml` — 待ちミューテックスが上限優先度で違反なし（mutex.c L173 pos.4 FALSE）

**2026-06-09 追加した BBテスト（全20グループ PASS）**:
- `ras_ter_g.yaml` — actcnt=1かつ再起動優先度が呼出しタスクより高い場合にディスパッチ発生（task_term.c L180 (f)分岐）
- `chg_ipm_e.yaml` — dis_dsp後にchg_ipm(TIPM_ENAALL)→enadsp=falseでdispatch不発（interrupt.c L369 (t)分岐）
- `get_mpf_k.yaml` — rel_mpf後のfreelist再利用によるget_mpf（mempfix.c L149 (f)分岐）

> **WBテスト（方式2: 手書き、`all` モードのみ）のカタログ・到達手法は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部を参照。**  
> WBテストは `bb` モード（1359/1379 = 98.5%）に対し **+9 分岐**を追加し、`all` モードで 1368/1379 = 99.2% に到達する。

**2026-06-08 追加した BBテスト（全20グループ PASS）**:
- `ena_dsp_b-3.yaml` — 割込み優先度マスク全解除でない場合のdspflgクリア（sys_manage.c L398 (t)分岐）
- `ena_dsp_b-4.yaml` — raster&&enater=T時の自タスク終了（sys_manage.c L400 (f)分岐）
- `ena_ter_c.yaml`   — raster&&dspflg=T時の自タスク終了（task_term.c L250 (t)分岐）

### ファイル別サマリ（gcov 全分岐、union集計、NDEBUG計測）

| ファイル | 行 C0 | 到達分岐 | 全分岐 | C1 |
|---|---|---|---|---|
| alarm.c | 70/70 100% | 32 | 32 | **100%** |
| cyclic.c | 74/74 100% | 36 | 36 | **100%** |
| dataqueue.c | 253/253 100% | 152 | 152 | **100%** |
| eventflag.c | 165/165 100% | 120 | 120 | **100%** |
| exception.c | 7/7 100% | 7 | 8 | 87.5% ◀ |
| interrupt.c | 108/110 98.2% | 59 | 62 | 95.2% ◀ |
| mempfix.c | 150/150 100% | 88 | 88 | **100%** |
| mutex.c | 212/212 100% | 135 | 136 | 99.3% ◀ |
| pridataq.c | 244/244 100% | 148 | 148 | **100%** |
| semaphore.c | 121/121 100% | 76 | 76 | **100%** |
| startup.c | 25/25 100% | 4 | 4 | **100%** |
| sys_manage.c | 152/152 100% | 62 | 62 | **100%** |
| task.c | 114/114 100% | 52 | 52 | **100%** |
| task.h | 4/4 100% | — | — | （分岐なし） |
| task_manage.c | 119/119 100% | 92 | 92 | **100%** |
| task_refer.c | 78/78 100% | 34 | 35 | 97.1% ◀ |
| task_sync.c | 169/169 100% | 116 | 116 | **100%** |
| task_term.c | 94/94 100% | 62 | 62 | **100%** |
| time_event.c | 138/141 97.9% | 52 | 56 | 92.9% ◀ |
| time_manage.c | 55/56 98.2% | 21 | 22 | 95.5% ◀ |
| wait.c | 61/61 100% | 6 | 6 | **100%** |
| wait.h | 39/39 100% | 14 | 14 | **100%** |
| **TOTAL** | **2452/2458 99.8%** | **1368** | **1379** | **99.2%** |

> ※ インライン抑制（`-fno-inline` 系）により wait.h は 64→14 分岐（旧 -O2 のインライン展開水増しが解消）、wait.c・task.c も論理分岐どおりに計測され各 100%。
> ※ インライン抑制で interrupt.c の実分岐が顕在化（58→62）、exception.c の xsns_dpn も 6→8 分岐に（論理分岐がそのまま見える）。

## API（関数）別 分岐カバレッジ

> ⚠️ **注記（2026-06-10）**: 以下の per-API 詳細表は **旧 -O2（インライン展開あり）計測時の構造**で、分岐数の細値は -O2+インライン抑制での再計測後と一部異なる（wait.h 64→14、task.c 64→52、dataqueue 156→152 等）。**最新のファイル別 C1 は上表／[`BB_COVERAGE.md`](BB_COVERAGE.md) が正**。per-API 表は次回の手動再生成時に更新する。未到達分岐の最新の所在は下記「残存未到達分岐リスト」を参照。

`◀` = 未到達分岐あり。`W` 列 = ホワイトボックステストの優先度（H/M/L/—）。

### alarm.c

> 分岐 C1: 32/32 = **100%**（WBテスト `alarm_W-a` により L241 br[1] 到達済み）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_alarm` | 100% | 2/2 100% | — | — |
| `sta_alm` | 100% | 10/10 100% | — | — |
| `stp_alm` | 100% | 8/8 100% | — | — |
| `ref_alm` | 100% | 10/10 100% | — | — |
| `_kernel_call_alarm` | 100% | 2/2 100% | — | — |

### cyclic.c

> 分岐 C1: 36/36 = **100%**（WBテスト `cyclic_W-a` により L259 br[1] 到達済み）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_cyclic` | 100% | 4/4 100% | — | — |
| `sta_cyc` | 100% | 10/10 100% | — | — |
| `stp_cyc` | 100% | 10/10 100% | — | — |
| `ref_cyc` | 100% | 10/10 100% | — | — |
| `_kernel_call_cyclic` | 100% | 2/2 100% | — | — |

### dataqueue.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_dataqueue` | 100% | 2/2 100% | — | — |
| `_kernel_enqueue_data` | 100% | 2/2 100% | — | — |
| `_kernel_force_enqueue_data` | 100% | 4/4 100% | — | — |
| `_kernel_dequeue_data` | 100% | 2/2 100% | — | — |
| `_kernel_send_data` | 100% | 4/4 100% | — | — |
| `_kernel_force_send_data` | 100% | 2/2 100% | — | — |
| `_kernel_receive_data` | 100% | 6/6 100% | — | — |
| `snd_dtq` | 100% | 16/16 100% | — | — |
| `psnd_dtq` | 100% | 12/12 100% | — | — |
| `tsnd_dtq` | 100% | 20/20 100% | — | — |
| `fsnd_dtq` | 100% | 12/12 100% | — | — |
| `rcv_dtq` | 100% | 18/18 100% | — | — |
| `prcv_dtq` | 100% | 12/12 100% | — | — |
| `trcv_dtq` | 100% | 22/22 100% | — | — |
| `ini_dtq` | 100% | 10/10 100% | — | — |
| `ref_dtq` | 100% | 8/8 100% | — | — |

### eventflag.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_eventflag` | 100% | 2/2 100% | — | — |
| `_kernel_check_flg_cond` | 100% | 6/6 100% | — | — |
| `set_flg` | 100% | 16/16 100% | — | — |
| `clr_flg` | 100% | 8/8 100% | — | — |
| `wai_flg` | 100% | 24/24 100% | — | — |
| `pol_flg` | 100% | 18/18 100% | — | — |
| `twai_flg` | 100% | 28/28 100% | — | — |
| `ini_flg` | 100% | 10/10 100% | — | — |
| `ref_flg` | 100% | 8/8 100% | — | — |

### exception.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `xsns_dpn` ◀ | 100% | 4/6 66.7% | 2 | M |

### interrupt.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `dis_int` ◀ | 93.8% | 6/8 75% | 2 | M |
| `ena_int` ◀ | 100% | 7/8 87.5% | 1 | M |
| `clr_int` | 100% | 8/8 100% | — | — |
| `ras_int` | 100% | 8/8 100% | — | — |
| `prb_int` | 100% | 8/8 100% | — | — |
| `chg_ipm` ◀ | 90% | 13/14 92.9% | 1 | M |
| `get_ipm` | 100% | 4/4 100% | — | — |

### mempfix.c

> 分岐 C1: 90/90 = **100%**（WBテスト `rel_mpf_W-a/b` により L309/L310 br[0] 到達済み）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_mempfix` | 100% | 2/2 100% | — | — |
| `_kernel_get_mpf_block` | 100% | 2/2 100% | — | — |
| `get_mpf` | 100% | 16/16 100% | — | — |
| `pget_mpf` | 100% | 10/10 100% | — | — |
| `tget_mpf` | 100% | 20/20 100% | — | — |
| `rel_mpf` | 100% | 20/20 100% | — | — |
| `ini_mpf` | 100% | 10/10 100% | — | — |
| `ref_mpf` | 100% | 8/8 100% | — | — |

### mutex.c

> 分岐 C1: 137/138 = 99.3%（NDEBUG計測により assert 失敗パス除去、BBテスト ini_mtx_e/f 等追加後）  
> 残 1 箇所: L227 br[1]（remove_mutex NULL exit、構造的到達不能）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_mutex` | 100% | 2/2 100% | — | — |
| `_kernel_mutex_check_ceilpri` | 100% | 12/12 100% | — | — |
| `mutex_calc_priority` | 100% | 4/4 100% | — | — |
| `mutex_raise_priority` | 100% | 2/2 100% | — | — |
| `mutex_drop_priority` | 100% | 4/4 100% | — | — |
| `_kernel_mutex_acquire` | 100% | 2/2 100% | — | — |
| `_kernel_mutex_release` | 100% | 6/6 100% | — | — |
| `_kernel_mutex_release_all` | 100% | 4/4 100% | — | — |
| `loc_mtx` | 100% | 100% | — | — |
| `ploc_mtx` | 100% | 100% | — | — |
| `tloc_mtx` | 100% | 100% | — | — |
| `unl_mtx` | 100% | 100% | — | — |
| `ini_mtx` | 100% | 100% | — | — |
| `ref_mtx` | 100% | 100% | — | — |
| `remove_mutex`（内部） ◀ | 100% | — | 1 NULL exit(到達不能) | — |

### pridataq.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_pridataq` | 100% | 2/2 100% | — | — |
| `_kernel_enqueue_pridata` | 100% | 6/6 100% | — | — |
| `_kernel_dequeue_pridata` | 100% | — | — | — |
| `_kernel_send_pridata` | 100% | 4/4 100% | — | — |
| `_kernel_receive_pridata` | 100% | 6/6 100% | — | — |
| `snd_pdq` | 100% | 20/20 100% | — | — |
| `psnd_pdq` | 100% | 16/16 100% | — | — |
| `tsnd_pdq` | 100% | 24/24 100% | — | — |
| `rcv_pdq` | 100% | 18/18 100% | — | — |
| `prcv_pdq` | 100% | 12/12 100% | — | — |
| `trcv_pdq` | 100% | 22/22 100% | — | — |
| `ini_pdq` | 100% | 10/10 100% | — | — |
| `ref_pdq` | 100% | 8/8 100% | — | — |

### semaphore.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_semaphore` | 100% | 2/2 100% | — | — |
| `sig_sem` | 100% | 14/14 100% | — | — |
| `wai_sem` | 100% | 14/14 100% | — | — |
| `pol_sem` | 100% | 10/10 100% | — | — |
| `twai_sem` | 100% | 18/18 100% | — | — |
| `ini_sem` | 100% | 10/10 100% | — | — |
| `ref_sem` | 100% | 8/8 100% | — | — |

### startup.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `sta_ker` | 100% | 2/2 100% | — | — |
| `ext_ker` | 100% | — | — | — |
| `_kernel_exit_kernel` | 100% | 2/2 100% | — | — |

### sys_manage.c

> 分岐 C1: 62/62 = **100%**（BBテスト ena_dsp_b-3/b-4 追加後）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `rot_rdq` | 100% | 12/12 100% | — | — |
| `get_tid` | 100% | 4/4 100% | — | — |
| `get_lod` | 100% | 10/10 100% | — | — |
| `get_nth` | 100% | 12/12 100% | — | — |
| `loc_cpu` | 100% | 2/2 100% | — | — |
| `unl_cpu` | 100% | 2/2 100% | — | — |
| `dis_dsp` | 100% | 4/4 100% | — | — |
| `ena_dsp` | 100% | 10/10 100% | — | — |
| `sns_ctx` | 100% | — | — | — |
| `sns_loc` | 100% | — | — | — |
| `sns_dsp` | 100% | — | — | — |
| `sns_dpn` | 100% | 6/6 100% | — | — |
| `sns_ker` | 100% | — | — | — |

### task.c（内部関数）

> 分岐 C1: 64/64 = **100%**（NDEBUG計測により assert 失敗パス除去）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_task` | 100% | 100% | — | — |
| `_kernel_search_schedtsk` | 100% | — | — | — |
| `_kernel_make_runnable` | 100% | 100% | — | — |
| `_kernel_make_non_runnable` | 100% | 100% | — | — |
| `_kernel_make_dormant` | 90% | 100% | — | — |
| `_kernel_make_active` | 100% | — | — | — |
| `_kernel_change_priority` | 100% | 100% | — | — |
| `_kernel_rotate_ready_queue` | 100% | 100% | — | — |
| `_kernel_task_terminate` | 100% | 100% | — | — |

### task_manage.c

> 分岐 C1: 92/92 = **100%**（BBテスト `act_tsk_c-3`（YAML 自動生成、2026-06-10）により L137 br[1] 到達済み。旧 WBテスト `act_tsk_W-a` は削除）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `act_tsk` | 100% | 20/20 100% | — | — |
| `can_act` | 100% | 10/10 100% | — | — |
| `get_tst` | 100% | 20/20 100% | — | — |
| `chg_pri` | 100% | 26/26 100% | — | — |
| `get_pri` | 100% | 12/12 100% | — | — |
| `get_inf` | 100% | 4/4 100% | — | — |

### task_refer.c

> 分岐 C1: 34/35 = 97.1%（残 1 箇所: `ref_tsk` L131 br[10]、switch の未使用待ち状態コード）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `ref_tsk` ◀ | 100% | 34/35 97.1% | 1 | L |

### task_sync.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `slp_tsk` | 100% | 10/10 100% | — | — |
| `tslp_tsk` | 100% | 14/14 100% | — | — |
| `wup_tsk` | 100% | 20/20 100% | — | — |
| `can_wup` | 100% | 12/12 100% | — | — |
| `rel_wai` | 100% | 14/14 100% | — | — |
| `sus_tsk` | 100% | 24/24 100% | — | — |
| `rsm_tsk` | 100% | 14/14 100% | — | — |
| `dly_tsk` | 100% | 10/10 100% | — | — |

### task_term.c

> 分岐 C1: 64/64 = 100%（`ras_ter_g.yaml` 追加により L180 (f) 到達済み、2026-06-09）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `ext_tsk` | 100% | 10/10 100% | — | — |
| `ras_ter` | 100% | 24/24 100% | — | — |
| `dis_ter` | 100% | 4/4 100% | — | — |
| `ena_ter` | 100% | 8/8 100% | — | — |
| `sns_ter` | 100% | 4/4 100% | — | — |
| `ter_tsk` | 100% | 14/14 100% | — | — |

### time_event.c

> 分岐 C1: 52/56 = **92.9%**（WBテスト `time_event_W-a/b` により L221/L231/L302 等到達済み）  
> 残 4 箇所: L390/L439（64bit折返し・HRTCNT_BOUND 実用的到達不能）、L624（spurious HRT 割込み）、tmevt_down 内部状態依存 ×1

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_tmevt` | 100% | — | — | — |
| `_kernel_tmevt_up` | 100% | 4/4 100% | — | — |
| `_kernel_tmevt_down` ◀ | ≈81.8% | 7/8 87.5% | 1（内部状態依存・到達困難） | — |
| `tmevtb_insert` | 100% | — | — | — |
| `tmevtb_delete` | 100% | 6/6 100% | — | — |
| `tmevtb_delete_top` | 100% | 2/2 100% | — | — |
| `_kernel_update_current_evttim` ◀ | 92.9% | 3/4 75% | 1 L390(64bit EVTTIM 折返し) | L |
| `_kernel_set_hrt_event` ◀ | 90.9% | 5/6 83.3% | 1 L439(HRTCNT_BOUND=4G ticks) | L |
| `_kernel_tmevtb_register` | 100% | — | — | — |
| `_kernel_signal_time` ◀ | 95.7% | 7/8 87.5% | 1 L624(空ヒープ割込み) | L |
| `_kernel_tmevtb_enqueue_rel` | 100% | 4/4 100% | — | — |
| `_kernel_tmevtb_dequeue` | 100% | 4/4 100% | — | — |
| `_kernel_check_adjtim` | 100% | 8/8 100% | — | — |
| `_kernel_tmevt_lefttim` | 100% | 2/2 100% | — | — |

### time_manage.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `set_tim` | 100% | 4/4 100% | — | — |
| `get_tim` | 100% | 4/4 100% | — | — |
| `adj_tim` ◀ | 95.7% | 12/14 85.7% | 2 | M |
| `fch_hrt` | 100% | — | — | — |

### wait.c / wait.h（内部関数）

> wait.c: 8/8 = **100%**（NDEBUG により assert 失敗パス除去）  
> wait.h: 49/64 = 76.6%（NDEBUG+O2 インライン展開増加によるアーティファクト。  
>   論理的カバレッジは両分岐とも確認済み。詳細は BB_UNREACHABLE.md 第2部 §5 wait.h 参照）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_make_wait_tmout` | 100% | 100% | — | — |
| `_kernel_wait_complete` | 100% | — | — | — |
| `_kernel_wait_tmout` | 100% | 2/2 100% | — | — |
| `_kernel_wait_tmout_ok` | 100% | — | — | — |
| `wobj_queue_insert` | 100% | 2/2 100% | — | — |
| `_kernel_wobj_make_wait` | 100% | — | — | — |
| `_kernel_wobj_make_wait_tmout` | 100% | — | — | — |
| `_kernel_init_wait_queue` | 100% | 2/2 100% | — | — |
| `queue_insert_tpri` (wait.h) | 100% | 100% | — | — |
| `make_wait` (wait.h) | 100% | — | — | — |
| `make_non_wait` (wait.h) | 100% | 100% | — | — |
| `wait_dequeue_wobj` (wait.h) ◀ | 100% | — | インライン展開アーティファクト | — |
| `wait_dequeue_tmevtb` (wait.h) | 100% | 2/2 100% | — | — |
| `wait_tskid` (wait.h) | 100% | 2/2 100% | — | — |
| `wobj_change_priority` (wait.h) | 100% | 2/2 100% | — | — |

---

## 残存未到達分岐リスト（2026-06-10 `all` モード、-O2+インライン抑制）

> 全 11 箇所（1368/1379 = 99.2%、`all` モード）。未到達数の多い順。  
> ※ 旧 -O2 計測で 15 箇所を占めていた wait.h のインライン展開アーティファクトは inline 抑制で解消済み（現 14/14 = 100%）。  
> **各分岐の詳細分析（到達不能理由・分類）は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 を参照。**

| # | ファイル | C1 | 未到達 | 主な未到達行・内容 |
|---|---|---|---|---|
| 1 | time_event.c | 92.9% | 4 | L391/L440(実用的到達不能), L625(タイミング依存), tmevt_down 内部状態依存 ×1 |
| 2 | interrupt.c | 95.2% | 3 | `chg_ipm` L372/L373(raster&&enater=T時の自終了, 到達困難) + 1（inline抑制で顕在化した dispatch 系） |
| 3 | exception.c | 87.5% | 1 | `xsns_dpn` p_runtsk==NULL（構造的到達不能・テスト文脈） |
| 4 | mutex.c | 99.3% | 1 | `remove_mutex` NULL exit（構造的到達不能） |
| 5 | task_refer.c | 97.1% | 1 | `ref_tsk` switch JT境界チェック（構造的到達不能） |
| 6 | time_manage.c | 95.5% | 1 | `adj_tim` 64bit折返し → 実用的到達不能 |

**BBテスト・WBテストで解消済み（100%到達）**：

> `(BB・方式1)` = YAML 自動生成テスト、`(WB・方式2)` = 手書き WBテスト。WBテストの到達手法は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部を参照。

| ファイル・API | テスト（BB/WB） | 状態 |
|---|---|---|
| sys_manage.c | ena_dsp_b-3/b-4 (BB・方式1) | **100%** |
| task_term.c (`ena_ter`) | ena_ter_c (BB・方式1) | **100%** |
| task_term.c (`ras_ter` L180) | ras_ter_g (BB・方式1) | **100%** |
| interrupt.c (`chg_ipm` L369) | chg_ipm_e (BB・方式1) | 57/58 (**98.3%**、L371残1: 到達不能) |
| mempfix.c (`_kernel_get_mpf_block` L149) | get_mpf_k (BB・方式1) | 86/88 (97.7%、残2) |
| mempfix.c (`rel_mpf` L309 br[0]) | rel_mpf_W-a (WB・方式2、`api_test/ASP/mempfix/rel_mpf/`) | **100%** |
| mempfix.c (`rel_mpf` L310 br[0]) | rel_mpf_W-b (WB・方式2、`api_test/ASP/mempfix/rel_mpf/`) | **100%** |
| alarm.c (`_kernel_call_alarm` L241 br[1]) | alarm_W-a (WB・方式2、`wb_test/ASP/alarm/`) | **100%** |
| cyclic.c (`_kernel_call_cyclic` L259 br[1]) | cyclic_W-a (WB・方式2、`wb_test/ASP/cyclic/`) | **100%** |
| task_manage.c (`act_tsk` L137 br[1]) | act_tsk_c-3 (BB・方式1 YAML 自動生成、2026-06-10 追加) | **100%** |
| time_event.c (`tmevtb_delete` L302 br[0]) | time_event_W-b (WB・方式2、`wb_test/ASP/time_event/`) | **100%** |
| time_event.c (`tmevt_down` L221 br[1]+L231 br[0]) | time_event_W-a (WB・方式2、`wb_test/ASP/time_event/`) | **到達済み** |
| time_event.c (`check_adjtim` L533 br[1]) | adj_tim_W-a.yaml (WB・方式1、api_test/ 配下で **有効のまま**) | 8/8 **100%** |
| semaphore.c, dataqueue.c, eventflag.c, pridataq.c, task_sync.c | 既存テスト (BB・方式1) | **100%** |

## 更新手順

```bash
# ベースライン再計測（テスト追加後）
bash scripts/coverage_gcov_asp.sh all

# このファイルの数値を更新するスクリプト（参考）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

再計測後は各 API の数値と `状態` 列（未着手 / 対応中 / 完了 / 到達不能）を更新する。
