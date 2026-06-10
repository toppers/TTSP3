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
分岐カバレッジ(kernel/): 1369/1379 = 99.3%  (C1, 2026-06-10 NDEBUG + -O2インライン抑制計測、all モード、chg_ipm_f 追加後)
  ※bbモード（WBテストなし）: 1360/1379 = 98.6%（手書き WBテスト alarm/cyclic/mempfix/time_event/exception 含まず）
  ※WBテスト寄与: +9 分岐（bb 1360 → all 1369）。bb/all で分母 1379 が一致（インライン抑制によりビルド差が解消）
  ※インライン抑制移行後: wait.h 64→14・wait.c・task.c のインライン展開アーティファクトが解消（各 100% / 論理分岐がそのまま）
  ※chg_ipm_f.yaml 追加（BB）で interrupt.c chg_ipm 13/14→14/14（raster&&enater 自終了パス到達）
  ※残存未到達 10 分岐（all モード）: exception(1)/interrupt(2)/mutex(1)/task_refer(1)/time_event(4)/time_manage(1)
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
> WBテストは `bb` モード（1360/1379 = 98.6%）に対し **+9 分岐**を追加し、`all` モードで 1369/1379 = 99.3% に到達する。

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
| interrupt.c | 110/110 100% | 60 | 62 | 96.8% ◀ |
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
| **TOTAL** | **2454/2458 99.8%** | **1369** | **1379** | **99.3%** |

> ※ インライン抑制（`-fno-inline` 系）により wait.h は 64→14 分岐（旧 -O2 のインライン展開水増しが解消）、wait.c・task.c も論理分岐どおりに計測され各 100%。
> ※ インライン抑制で interrupt.c の実分岐が顕在化（58→62）、exception.c の xsns_dpn も 6→8 分岐に（論理分岐がそのまま見える）。

## API（関数）別 分岐カバレッジ

> 自動生成（`ttsp_gcov_report.py --by-function`、2026-06-10、-O2+インライン抑制、`all` モード 30ディレクトリ）。
> `◀` = 未到達分岐あり（詳細・到達不能理由は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部）。
> 再生成: `python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ --by-function obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_* obj_asp_gcov/api_test/wb_*`
>
> インライン抑制により内部 inline 関数（wait.h `make_wait` 等、task.c ヘルパ）が独立関数として計測される。旧 -O2 では呼出し元へ併合され見えなかった `clr_int`/`ras_int` の未到達分岐もここで顕在化している（`—` は分岐なし）。

| 関数 | ファイル | 行 C0 | 分岐 C1 | |
|---|---|---|---|---|
| `_kernel_initialize_alarm` | alarm.c | 10/10 | 2/2 |  |
| `sta_alm` | alarm.c | 18/18 | 10/10 |  |
| `stp_alm` | alarm.c | 16/16 | 8/8 |  |
| `ref_alm` | alarm.c | 17/17 | 10/10 |  |
| `_kernel_call_alarm` | alarm.c | 9/9 | 2/2 |  |
| `_kernel_initialize_cyclic` | cyclic.c | 14/14 | 4/4 |  |
| `sta_cyc` | cyclic.c | 17/17 | 10/10 |  |
| `stp_cyc` | cyclic.c | 16/16 | 10/10 |  |
| `ref_cyc` | cyclic.c | 17/17 | 10/10 |  |
| `_kernel_call_cyclic` | cyclic.c | 10/10 | 2/2 |  |
| `_kernel_initialize_dataqueue` | dataqueue.c | 12/12 | 2/2 |  |
| `_kernel_enqueue_data` | dataqueue.c | 7/7 | 2/2 |  |
| `_kernel_force_enqueue_data` | dataqueue.c | 9/9 | 4/4 |  |
| `_kernel_dequeue_data` | dataqueue.c | 7/7 | 2/2 |  |
| `_kernel_send_data` | dataqueue.c | 10/10 | 4/4 |  |
| `_kernel_force_send_data` | dataqueue.c | 8/8 | 2/2 |  |
| `_kernel_receive_data` | dataqueue.c | 16/16 | 6/6 |  |
| `snd_dtq` | dataqueue.c | 21/21 | 16/16 |  |
| `psnd_dtq` | dataqueue.c | 16/16 | 12/12 |  |
| `tsnd_dtq` | dataqueue.c | 24/24 | 20/20 |  |
| `fsnd_dtq` | dataqueue.c | 19/19 | 12/12 |  |
| `rcv_dtq` | dataqueue.c | 25/25 | 18/18 |  |
| `prcv_dtq` | dataqueue.c | 15/15 | 12/12 |  |
| `trcv_dtq` | dataqueue.c | 28/28 | 22/22 |  |
| `ini_dtq` | dataqueue.c | 20/20 | 10/10 |  |
| `ref_dtq` | dataqueue.c | 16/16 | 8/8 |  |
| `_kernel_initialize_eventflag` | eventflag.c | 9/9 | 2/2 |  |
| `_kernel_check_flg_cond` | eventflag.c | 7/7 | 6/6 |  |
| `set_flg` | eventflag.c | 30/30 | 16/16 |  |
| `clr_flg` | eventflag.c | 14/14 | 8/8 |  |
| `wai_flg` | eventflag.c | 26/26 | 24/24 |  |
| `pol_flg` | eventflag.c | 18/18 | 18/18 |  |
| `twai_flg` | eventflag.c | 29/29 | 28/28 |  |
| `ini_flg` | eventflag.c | 17/17 | 10/10 |  |
| `ref_flg` | eventflag.c | 15/15 | 8/8 |  |
| `xsns_dpn` | exception.c | 7/7 | 7/8 | ◀ |
| `dis_int` | interrupt.c | 16/16 | 8/8 |  |
| `ena_int` | interrupt.c | 16/16 | 8/8 |  |
| `clr_int` | interrupt.c | 16/16 | 9/10 | ◀ |
| `ras_int` | interrupt.c | 16/16 | 9/10 | ◀ |
| `prb_int` | interrupt.c | 15/15 | 8/8 |  |
| `chg_ipm` | interrupt.c | 20/20 | 14/14 |  |
| `get_ipm` | interrupt.c | 11/11 | 4/4 |  |
| `_kernel_initialize_mempfix` | mempfix.c | 11/11 | 2/2 |  |
| `_kernel_get_mpf_block` | mempfix.c | 12/12 | 2/2 |  |
| `get_mpf` | mempfix.c | 22/22 | 16/16 |  |
| `pget_mpf` | mempfix.c | 15/15 | 10/10 |  |
| `tget_mpf` | mempfix.c | 25/25 | 20/20 |  |
| `rel_mpf` | mempfix.c | 31/31 | 20/20 |  |
| `ini_mpf` | mempfix.c | 19/19 | 10/10 |  |
| `ref_mpf` | mempfix.c | 15/15 | 8/8 |  |
| `_kernel_initialize_mutex` | mutex.c | 11/11 | 2/2 |  |
| `_kernel_mutex_check_ceilpri` | mutex.c | 10/10 | 12/12 |  |
| `mutex_calc_priority` | mutex.c | 13/13 | 4/4 |  |
| `remove_mutex` | mutex.c | 8/8 | 3/4 | ◀ |
| `mutex_raise_priority` | mutex.c | 5/5 | 2/2 |  |
| `mutex_drop_priority` | mutex.c | 7/7 | 4/4 |  |
| `_kernel_mutex_acquire` | mutex.c | 7/7 | 2/2 |  |
| `_kernel_mutex_release` | mutex.c | 16/16 | 6/6 |  |
| `_kernel_mutex_release_all` | mutex.c | 6/6 | 2/2 |  |
| `loc_mtx` | mutex.c | 24/24 | 20/20 |  |
| `ploc_mtx` | mutex.c | 20/20 | 16/16 |  |
| `tloc_mtx` | mutex.c | 27/27 | 24/24 |  |
| `unl_mtx` | mutex.c | 19/19 | 14/14 |  |
| `ini_mtx` | mutex.c | 23/23 | 14/14 |  |
| `ref_mtx` | mutex.c | 16/16 | 10/10 |  |
| `_kernel_initialize_pridataq` | pridataq.c | 13/13 | 2/2 |  |
| `_kernel_enqueue_pridata` | pridataq.c | 18/18 | 6/6 |  |
| `_kernel_dequeue_pridata` | pridataq.c | 10/10 | — |  |
| `_kernel_send_pridata` | pridataq.c | 11/11 | 4/4 |  |
| `_kernel_receive_pridata` | pridataq.c | 19/19 | 6/6 |  |
| `snd_pdq` | pridataq.c | 23/23 | 20/20 |  |
| `psnd_pdq` | pridataq.c | 17/17 | 16/16 |  |
| `tsnd_pdq` | pridataq.c | 26/26 | 24/24 |  |
| `rcv_pdq` | pridataq.c | 26/26 | 18/18 |  |
| `prcv_pdq` | pridataq.c | 15/15 | 12/12 |  |
| `trcv_pdq` | pridataq.c | 29/29 | 22/22 |  |
| `ini_pdq` | pridataq.c | 21/21 | 10/10 |  |
| `ref_pdq` | pridataq.c | 16/16 | 8/8 |  |
| `_kernel_initialize_semaphore` | semaphore.c | 9/9 | 2/2 |  |
| `sig_sem` | semaphore.c | 22/22 | 14/14 |  |
| `wai_sem` | semaphore.c | 20/20 | 14/14 |  |
| `pol_sem` | semaphore.c | 15/15 | 10/10 |  |
| `twai_sem` | semaphore.c | 23/23 | 18/18 |  |
| `ini_sem` | semaphore.c | 17/17 | 10/10 |  |
| `ref_sem` | semaphore.c | 15/15 | 8/8 |  |
| `sta_ker` | startup.c | 13/13 | 2/2 |  |
| `ext_ker` | startup.c | 7/7 | — |  |
| `_kernel_exit_kernel` | startup.c | 5/5 | 2/2 |  |
| `rot_rdq` | sys_manage.c | 20/20 | 12/12 |  |
| `get_tid` | sys_manage.c | 9/9 | 4/4 |  |
| `get_lod` | sys_manage.c | 22/22 | 10/10 |  |
| `get_nth` | sys_manage.c | 26/26 | 12/12 |  |
| `loc_cpu` | sys_manage.c | 8/8 | 2/2 |  |
| `unl_cpu` | sys_manage.c | 8/8 | 2/2 |  |
| `dis_dsp` | sys_manage.c | 12/12 | 4/4 |  |
| `ena_dsp` | sys_manage.c | 17/17 | 10/10 |  |
| `sns_ctx` | sys_manage.c | 6/6 | — |  |
| `sns_loc` | sys_manage.c | 6/6 | — |  |
| `sns_dsp` | sys_manage.c | 6/6 | — |  |
| `sns_dpn` | sys_manage.c | 6/6 | 6/6 |  |
| `sns_ker` | sys_manage.c | 6/6 | — |  |
| `_kernel_initialize_task` | task.c | 20/20 | 6/6 |  |
| `primap_empty` | task.c | 2/2 | — |  |
| `primap_search` | task.c | 2/2 | — |  |
| `primap_set` | task.c | 3/3 | — |  |
| `primap_clear` | task.c | 3/3 | — |  |
| `_kernel_search_schedtsk` | task.c | 4/4 | — |  |
| `_kernel_make_runnable` | task.c | 8/8 | 6/6 |  |
| `_kernel_make_non_runnable` | task.c | 13/13 | 8/8 |  |
| `_kernel_make_dormant` | task.c | 10/10 | — |  |
| `_kernel_make_active` | task.c | 6/6 | — |  |
| `_kernel_change_priority` | task.c | 21/21 | 16/16 |  |
| `_kernel_rotate_ready_queue` | task.c | 9/9 | 8/8 |  |
| `_kernel_task_terminate` | task.c | 13/13 | 8/8 |  |
| `set_dspflg` | task.h | 4/4 | — |  |
| `act_tsk` | task_manage.c | 22/22 | 20/20 |  |
| `can_act` | task_manage.c | 16/16 | 10/10 |  |
| `get_tst` | task_manage.c | 28/28 | 20/20 |  |
| `chg_pri` | task_manage.c | 27/27 | 26/26 |  |
| `get_pri` | task_manage.c | 17/17 | 12/12 |  |
| `get_inf` | task_manage.c | 9/9 | 4/4 |  |
| `ref_tsk` | task_refer.c | 78/78 | 34/35 | ◀ |
| `slp_tsk` | task_sync.c | 18/18 | 10/10 |  |
| `tslp_tsk` | task_sync.c | 21/21 | 14/14 |  |
| `wup_tsk` | task_sync.c | 23/23 | 20/20 |  |
| `can_wup` | task_sync.c | 17/17 | 12/12 |  |
| `rel_wai` | task_sync.c | 20/20 | 12/12 |  |
| `sus_tsk` | task_sync.c | 27/27 | 24/24 |  |
| `rsm_tsk` | task_sync.c | 20/20 | 14/14 |  |
| `dly_tsk` | task_sync.c | 23/23 | 10/10 |  |
| `ext_tsk` | task_term.c | 17/17 | 10/10 |  |
| `ras_ter` | task_term.c | 29/29 | 22/22 |  |
| `dis_ter` | task_term.c | 11/11 | 4/4 |  |
| `ena_ter` | task_term.c | 14/14 | 8/8 |  |
| `sns_ter` | task_term.c | 6/6 | 4/4 |  |
| `ter_tsk` | task_term.c | 17/17 | 14/14 |  |
| `_kernel_initialize_tmevt` | time_event.c | 8/8 | — |  |
| `_kernel_tmevt_up` | time_event.c | 9/9 | 4/4 |  |
| `_kernel_tmevt_down` | time_event.c | 11/11 | 7/8 | ◀ |
| `tmevtb_insert` | time_event.c | 6/6 | — |  |
| `tmevtb_delete` | time_event.c | 16/16 | 6/6 |  |
| `tmevtb_delete_top` | time_event.c | 11/11 | 2/2 |  |
| `_kernel_update_current_evttim` | time_event.c | 13/14 | 3/4 | ◀ |
| `calc_current_evttim_ub` | time_event.c | 2/2 | — |  |
| `_kernel_set_hrt_event` | time_event.c | 10/11 | 5/6 | ◀ |
| `_kernel_tmevtb_register` | time_event.c | 3/3 | — |  |
| `_kernel_tmevtb_enqueue_reltim` | time_event.c | 7/7 | 4/4 |  |
| `_kernel_tmevtb_dequeue` | time_event.c | 7/7 | 4/4 |  |
| `_kernel_check_adjtim` | time_event.c | 6/6 | 8/8 |  |
| `_kernel_tmevt_lefttim` | time_event.c | 7/7 | 2/2 |  |
| `_kernel_signal_time` | time_event.c | 22/23 | 7/8 | ◀ |
| `set_tim` | time_manage.c | 12/12 | 4/4 |  |
| `get_tim` | time_manage.c | 12/12 | 4/4 |  |
| `adj_tim` | time_manage.c | 22/23 | 13/14 | ◀ |
| `fch_hrt` | time_manage.c | 9/9 | — |  |
| `_kernel_make_wait_tmout` | wait.c | 12/12 | 2/2 |  |
| `_kernel_wait_complete` | wait.c | 5/5 | — |  |
| `_kernel_wait_tmout` | wait.c | 10/10 | — |  |
| `_kernel_wait_tmout_ok` | wait.c | 9/9 | — |  |
| `wobj_queue_insert` | wait.c | 5/5 | 2/2 |  |
| `_kernel_wobj_make_wait` | wait.c | 6/6 | — |  |
| `_kernel_wobj_make_wait_tmout` | wait.c | 6/6 | — |  |
| `_kernel_init_wait_queue` | wait.c | 8/8 | 2/2 |  |
| `queue_insert_tpri` | wait.h | 8/8 | 4/4 |  |
| `make_wait` | wait.h | 6/6 | — |  |
| `make_non_wait` | wait.h | 9/9 | 2/2 |  |
| `wait_dequeue_wobj` | wait.h | 4/4 | 2/2 |  |
| `wait_dequeue_tmevtb` | wait.h | 4/4 | 2/2 |  |
| `wait_tskid` | wait.h | 3/3 | 2/2 |  |
| `wobj_change_priority` | wait.h | 5/5 | 2/2 |  |

## 残存未到達分岐リスト（2026-06-10 `all` モード、-O2+インライン抑制）

> 全 10 箇所（1369/1379 = 99.3%、`all` モード）。未到達数の多い順。  
> ※ 旧 -O2 計測で 15 箇所を占めていた wait.h のインライン展開アーティファクトは inline 抑制で解消済み（現 14/14 = 100%）。  
> ※ `chg_ipm` の raster&&enater 自終了分岐は `chg_ipm_f.yaml`（BB）で到達済み（11→10）。  
> **各分岐の詳細分析（到達不能理由・分類）は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 を参照。**

| # | ファイル | C1 | 未到達 | 主な未到達行・内容 |
|---|---|---|---|---|
| 1 | time_event.c | 92.9% | 4 | L391/L440(実用的到達不能), L625(タイミング依存), tmevt_down 内部状態依存 ×1 |
| 2 | interrupt.c | 96.8% | 2 | `clr_int`/`ras_int` ×各1（GIC で `check_intno_clear/raise` 恒真 → 構造的到達不能）|
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
| interrupt.c (`chg_ipm` L369 dispatch不発) | chg_ipm_e (BB・方式1) | — |
| interrupt.c (`chg_ipm` raster&&enater 自終了) | chg_ipm_f (BB・方式1、2026-06-10 追加) | **14/14 100%** |
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
