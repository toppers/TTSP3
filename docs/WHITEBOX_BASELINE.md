# WHITEBOX_BASELINE.md — ASP3 kernel/ API別分岐カバレッジベースライン

> 計測日: 2026-06-09（最終）  
> 方式: gcov（`python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/`）  
> 対象: ASP3 3.7.2 `kernel/`、APIオートコード 20グループ統合（all 20/20 PASS）  
> ※ 集計バグ修正済（union 方式）。per-API テーブルも同一ツール値で更新済み。

## 全体サマリ（gcov 全分岐, ttsp_gcov_report.py, union集計）

```
分岐カバレッジ(kernel/): 1377/1405 = 98.0%  (C1, 2026-06-09 最終)
  ※mutex.c WBテスト追加後: 1377/1405 = 98.0%（mutex.c 97.2%, 残4は到達不能）
  ※act_tsk_W-a追加直後:    1366/1405 = 97.2%（task_manage.c 100%）
  ※ras_ter_g追加直後:      1363/1405 = 97.0%（chg_ipm_e/get_mpf_k 未追加）
  ※2026-06-08:             1362/1405 = 96.9%（ras_ter L180(f) 未到達）
  ※旧バグ版(max集計):      1059/1405 = 75.4%（グループ間 union が取れていなかった）
  ※BBテスト追加前:          1051/1405 = 74.8%（group17 失敗 + バグ）
  ※RAISE_CPU_EXCEPTION修正前: 1012/1405 = 72.0%（auto_code 6/20 タイムアウト起因）
```

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

**2026-06-09 追加した WBテスト（方式2: 手書き）**:
- `act_tsk_W-a` — TA_NOACTQUE属性タスクへのact_tsk→E_QOVR（task_manage.c L137 br[1]）
  配置: `api_test/ASP/whitebox/task_manage/act_tsk_W-a/`（out.c/h/cfg）

**2026-06-08 追加した BBテスト（全20グループ PASS）**:
- `ena_dsp_b-3.yaml` — 割込み優先度マスク全解除でない場合のdspflgクリア（sys_manage.c L398 (t)分岐）
- `ena_dsp_b-4.yaml` — raster&&enater=T時の自タスク終了（sys_manage.c L400 (f)分岐）
- `ena_ter_c.yaml`   — raster&&dspflg=T時の自タスク終了（task_term.c L250 (t)分岐）

### ファイル別サマリ（gcov 全分岐、union集計、最終値）

| ファイル | 行 C0 | 到達分岐 | 全分岐 | C1 |
|---|---|---|---|---|
| alarm.c | 70/70 100% | 31 | 32 | 96.9% ◀ |
| cyclic.c | 74/74 100% | 35 | 36 | 97.2% ◀ |
| dataqueue.c | 253/253 100% | 152 | 152 | **100%** |
| eventflag.c | 165/165 100% | 120 | 120 | **100%** |
| exception.c | 7/7 100% | 4 | 6 | 66.7% ◀ |
| interrupt.c | 108/110 98.2% | 57 | 58 | 98.3% ◀ |
| mempfix.c | 150/150 100% | 86 | 88 | 97.7% ◀ |
| mutex.c | 209/209 100% | 138 | 142 | 97.2% ◀ |
| pridataq.c | 243/244 99.6% | 148 | 148 | **100%** |
| semaphore.c | 121/121 100% | 76 | 76 | **100%** |
| startup.c | 25/25 100% | 4 | 4 | **100%** |
| sys_manage.c | 152/152 100% | 62 | 62 | **100%** |
| task.c | 110/111 99.1% | 60 | 62 | 96.8% ◀ |
| task.h | 4/4 100% | 2 | 2 | **100%** |
| task_manage.c | 119/119 100% | 92 | 92 | **100%** |
| task_refer.c | 78/78 100% | 34 | 35 | 97.1% ◀ |
| task_sync.c | 169/169 100% | 118 | 118 | **100%** |
| task_term.c | 94/94 100% | 64 | 64 | **100%** |
| time_event.c | 131/141 92.9% | 49 | 60 | 81.7% ◀ |
| time_manage.c | 55/56 98.2% | 21 | 22 | 95.5% ◀ |
| wait.c | 61/61 100% | 9 | 10 | 90.0% ◀ |
| wait.h | 38/38 100% | 15 | 16 | 93.8% ◀ |
| **TOTAL** | **2451/2451 100%** | **1377** | **1405** | **98.0%** |

## API（関数）別 分岐カバレッジ

`◀` = 未到達分岐あり。`W` 列 = ホワイトボックステストの優先度（H/M/L/—）。

### alarm.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_alarm` | 100% | 2/2 100% | — | — |
| `sta_alm` | 100% | 10/10 100% | — | — |
| `stp_alm` | 100% | 8/8 100% | — | — |
| `ref_alm` | 100% | 10/10 100% | — | — |
| `_kernel_call_alarm` ◀ | 100% | 1/2 50% | 1 | L |

### cyclic.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_cyclic` | 100% | 4/4 100% | — | — |
| `sta_cyc` | 100% | 10/10 100% | — | — |
| `stp_cyc` | 100% | 10/10 100% | — | — |
| `ref_cyc` | 100% | 10/10 100% | — | — |
| `_kernel_call_cyclic` ◀ | 100% | 1/2 50% | 1 | L |

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

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_mempfix` | 100% | 2/2 100% | — | — |
| `_kernel_get_mpf_block` | 100% | 2/2 100% | — | — |
| `get_mpf` ◀ | 100% | 15/16 93.8% | 1 | L |
| `pget_mpf` | 100% | 10/10 100% | — | — |
| `tget_mpf` ◀ | 100% | 18/20 90% | 2 | M |
| `rel_mpf` ◀ | 100% | 16/20 80% | 4 | M |
| `ini_mpf` | 100% | 10/10 100% | — | — |
| `ref_mpf` ◀ | 53.3% | 3/8 37.5% | 5 | **H** |

### mutex.c

> 分岐 C1: 138/142 = 97.2%（BBテスト ini_mtx_e/f, unl_mtx_g-1〜g-5, chg_pri_j-1〜j-3 追加後）  
> 残 4 箇所は構造的到達不能（L227 br[1]: remove_mutex NULL exit、L375/423/474: assert失敗パス）

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
| `loc_mtx` ◀ | 100% | — | 1 assert失敗 | — |
| `ploc_mtx` ◀ | 100% | — | 1 assert失敗 | — |
| `tloc_mtx` ◀ | 100% | — | 1 assert失敗 | — |
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

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_task` | 100% | 4/4 100% | — | — |
| `_kernel_search_schedtsk` | 100% | — | — | — |
| `_kernel_make_runnable` | 100% | 8/8 100% | — | — |
| `_kernel_make_non_runnable` ◀ | 100% | 10/12 83.3% | 2 | M |
| `_kernel_make_dormant` | 90% | 2/2 100% | — | — |
| `_kernel_make_active` | 100% | — | — | — |
| `_kernel_change_priority` | 100% | 16/16 100% | — | — |
| `_kernel_rotate_ready_queue` ◀ | 100% | 9/10 90% | 1 | L |
| `_kernel_task_terminate` | 100% | 10/10 100% | — | — |

### task_manage.c

> 分岐 C1: 92/92 = 100%（act_tsk_W-a (WB) で L137 br[1] 到達済み、2026-06-09）

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

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_tmevt` | 100% | — | — | — |
| `_kernel_tmevt_up` | 100% | 4/4 100% | — | — |
| `_kernel_tmevt_down` ◀ | 63.6% | 4/8 50% | 4 | **H** |
| `tmevtb_insert` | 100% | — | — | — |
| `tmevtb_delete` ◀ | 81.2% | 5/6 83.3% | 1 | L |
| `tmevtb_delete_top` | 100% | 2/2 100% | — | — |
| `_kernel_update_current_evttim` ◀ | 92.9% | 3/4 75% | 1 | L |
| `_kernel_set_hrt_event` ◀ | 90.9% | 5/6 83.3% | 1 | L |
| `_kernel_tmevtb_register` | 100% | — | — | — |
| `_kernel_tmevtb_enqueue_rel` | 100% | 4/4 100% | — | — |
| `_kernel_tmevtb_dequeue` | 100% | 4/4 100% | — | — |
| `_kernel_check_adjtim` ◀ | 100% | 7/8 87.5% | 1 | L |
| `_kernel_tmevt_lefttim` | 100% | 2/2 100% | — | — |
| `_kernel_signal_time` ◀ | 95.7% | 9/12 75% | 3 | M |

### time_manage.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `set_tim` | 100% | 4/4 100% | — | — |
| `get_tim` | 100% | 4/4 100% | — | — |
| `adj_tim` ◀ | 95.7% | 12/14 85.7% | 2 | M |
| `fch_hrt` | 100% | — | — | — |

### wait.c / wait.h（内部関数）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_make_wait_tmout` ◀ | 100% | 3/4 75% | 1 | L |
| `_kernel_wait_complete` | 100% | — | — | — |
| `_kernel_wait_tmout` | 100% | 2/2 100% | — | — |
| `_kernel_wait_tmout_ok` | 100% | — | — | — |
| `wobj_queue_insert` | 100% | 2/2 100% | — | — |
| `_kernel_wobj_make_wait` | 100% | — | — | — |
| `_kernel_wobj_make_wait_tmout` | 100% | — | — | — |
| `_kernel_init_wait_queue` | 100% | 2/2 100% | — | — |
| `queue_insert_tpri` (wait.h) | 100% | 4/4 100% | — | — |
| `make_wait` (wait.h) | 100% | — | — | — |
| `make_non_wait` (wait.h) ◀ | 100% | 3/4 75% | 1 | L |
| `wait_dequeue_tmevtb` (wait.h) | 100% | 2/2 100% | — | — |
| `wait_tskid` (wait.h) | 100% | 2/2 100% | — | — |
| `wobj_change_priority` (wait.h) | 100% | 2/2 100% | — | — |

---

## 残存未到達分岐リスト（2026-06-09 最終）

> 全 28 箇所（1377/1405 = 98.0%）。未到達数の多い順。

| # | ファイル | C1 | 未到達 | 主な未到達行・内容 |
|---|---|---|---|---|
| 1 | time_event.c | 81.7% | 11 | L221/231(ヒープdown処理), L302/390/439, L533(adj_tim負), L588/589(assert), L624 |
| 2 | mutex.c | 97.2% | 4 | L227 br[1](remove_mutex NULL exit, 到達不能), L375/423/474 br[0](assert失敗, 到達不能) |
| 3 | exception.c | 66.7% | 2 | `xsns_dpn`（構造的到達不能: kerflg恒真 / task文脈+p_runtsk=NULL矛盾） |
| 4 | task.c | 96.8% | 2 | `assert` 失敗パス（L268/L274、構造的到達不能） |
| 5 | mempfix.c | 97.7% | 2 | `rel_mpf`(L309/L310: 不正ブロックオフセット), `tget_mpf`/`ref_mpf` 要確認 |
| 6 | alarm.c | 96.9% | 1 | `_kernel_call_alarm`: nfyhdr内でloc_cpu呼出し後に割込みブロック → WBテスト要 |
| 7 | cyclic.c | 97.2% | 1 | `_kernel_call_cyclic`: 同上 |
| 8 | task_refer.c | 97.1% | 1 | `ref_tsk` L131 br[10]（switch JT境界チェック、構造的到達不能） |
| 9 | time_manage.c | 95.5% | 1 | `adj_tim` 32bit折返し（HRTCNT_BOUND越え）→ 困難 |
| 10 | wait.c | 90.0% | 1 | `_kernel_make_wait_tmout` assert失敗パス（構造的到達不能） |
| 11 | wait.h | 93.8% | 1 | `make_non_wait` assert失敗パス（構造的到達不能） |
| 12 | interrupt.c | 98.3% | 1 | `chg_ipm` L371: raster&&enater=T時の自終了（pre_condition制約で到達不能） |

**BBテストで解消済み（100%到達）**：

| ファイル・API | BBテスト | 状態 |
|---|---|---|
| sys_manage.c | ena_dsp_b-3/b-4 | **100%** |
| task_term.c (`ena_ter`) | ena_ter_c | **100%** |
| task_term.c (`ras_ter` L180) | ras_ter_g | **100%** |
| interrupt.c (`chg_ipm` L369) | chg_ipm_e | 57/58 (**98.3%**、L371残1: 到達不能) |
| mempfix.c (`_kernel_get_mpf_block` L149) | get_mpf_k | 86/88 (**97.7%**、残2) |
| task_manage.c (`act_tsk` L137 br[1]) | act_tsk_W-a (WB・方式2) | **100%** |
| semaphore.c, dataqueue.c, eventflag.c, pridataq.c, task_sync.c | 既存テスト | **100%** |

## 更新手順

```bash
# ベースライン再計測（テスト追加後）
bash scripts/coverage_gcov_asp.sh full

# このファイルの数値を更新するスクリプト（参考）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

再計測後は各 API の数値と `状態` 列（未着手 / 対応中 / 完了 / 到達不能）を更新する。
