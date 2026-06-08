# WHITEBOX_BASELINE.md — ASP3 kernel/ API別分岐カバレッジベースライン

> 計測日: 2026-06-09（最終）  
> 方式: gcov（`python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/`）  
> 対象: ASP3 3.7.2 `kernel/`、APIオートコード 20グループ統合（all 20/20 PASS）  
> ※ 集計バグ修正済（union 方式）。per-API テーブルも同一ツール値で更新済み。

## 全体サマリ（gcov 全分岐, ttsp_gcov_report.py, union集計）

```
分岐カバレッジ(kernel/): 1363/1405 = 97.0%  (C1, 2026-06-09 最終)
  ※2026-06-08:             1362/1405 = 96.9%（ras_ter L180(f) 未到達）
  ※旧バグ版(max集計):      1059/1405 = 75.4%（グループ間 union が取れていなかった）
  ※BBテスト追加前:          1051/1405 = 74.8%（group17 失敗 + バグ）
  ※RAISE_CPU_EXCEPTION修正前: 1012/1405 = 72.0%（auto_code 6/20 タイムアウト起因）
```

**2026-06-09 追加した BBテスト（全20グループ PASS）**:
- `ras_ter_g.yaml` — actcnt=1かつ再起動優先度が呼出しタスクより高い場合にディスパッチ発生（task_term.c L180 (f)分岐）

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
| interrupt.c | 108/110 98.2% | 56 | 58 | 96.6% ◀ |
| mempfix.c | 148/150 98.7% | 85 | 88 | 96.6% ◀ |
| mutex.c | 204/209 97.6% | 127 | 142 | 89.4% ◀ |
| pridataq.c | 243/244 99.6% | 148 | 148 | **100%** |
| semaphore.c | 121/121 100% | 76 | 76 | **100%** |
| startup.c | 25/25 100% | 4 | 4 | **100%** |
| sys_manage.c | 152/152 100% | 62 | 62 | **100%** |
| task.c | 110/111 99.1% | 60 | 62 | 96.8% ◀ |
| task.h | 4/4 100% | 2 | 2 | **100%** |
| task_manage.c | 119/119 100% | 91 | 92 | 98.9% ◀ |
| task_refer.c | 78/78 100% | 34 | 35 | 97.1% ◀ |
| task_sync.c | 169/169 100% | 118 | 118 | **100%** |
| task_term.c | 94/94 100% | 64 | 64 | **100%** |
| time_event.c | 131/141 92.9% | 49 | 60 | 81.7% ◀ |
| time_manage.c | 55/56 98.2% | 21 | 22 | 95.5% ◀ |
| wait.c | 61/61 100% | 9 | 10 | 90.0% ◀ |
| wait.h | 38/38 100% | 15 | 16 | 93.8% ◀ |
| **TOTAL** | **2429/2451 99.1%** | **1363** | **1405** | **97.0%** |

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
| `chg_ipm` ◀ | 90% | 12/14 85.7% | 2 | M |
| `get_ipm` | 100% | 4/4 100% | — | — |

### mempfix.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_mempfix` | 100% | 2/2 100% | — | — |
| `_kernel_get_mpf_block` ◀ | 83.3% | 1/2 50% | 1 | M |
| `get_mpf` ◀ | 100% | 15/16 93.8% | 1 | L |
| `pget_mpf` | 100% | 10/10 100% | — | — |
| `tget_mpf` ◀ | 100% | 18/20 90% | 2 | M |
| `rel_mpf` ◀ | 100% | 16/20 80% | 4 | M |
| `ini_mpf` | 100% | 10/10 100% | — | — |
| `ref_mpf` ◀ | 53.3% | 3/8 37.5% | 5 | **H** |

### mutex.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_mutex` | 100% | 2/2 100% | — | — |
| `_kernel_mutex_check_ceilpri` ◀ | 70% | 5/12 41.7% | 7 | **H** |
| `mutex_calc_priority` ◀ | 76.9% | 1/4 25% | 3 | **H** |
| `mutex_raise_priority` | 100% | 2/2 100% | — | — |
| `mutex_drop_priority` ◀ | 100% | 2/4 50% | 2 | M |
| `_kernel_mutex_acquire` | 100% | 2/2 100% | — | — |
| `_kernel_mutex_release` ◀ | 93.8% | 5/6 83.3% | 1 | L |
| `_kernel_mutex_release_all` | 100% | 2/2 100% | — | — |
| `loc_mtx` ◀ | 100% | 20/22 90.9% | 2 | M |
| `ploc_mtx` ◀ | 100% | 17/18 94.4% | 1 | L |
| `tloc_mtx` ◀ | 100% | 22/26 84.6% | 4 | M |
| `unl_mtx` | 100% | 14/14 100% | — | — |
| `ini_mtx` ◀ | 95.7% | 12/14 85.7% | 2 | M |
| `ref_mtx` ◀ | 56.2% | 7/10 70% | 3 | M |

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

> 分岐 C1: 91/92 = 98.9%（残 1 箇所: `act_tsk` L137 br[1]、TA_NOACTQUE 属性タスクへの再起動要求）

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `act_tsk` ◀ | 100% | 19/20 95% | 1 | M |
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

## 残存未到達分岐リスト（2026-06-08 最終）

> 全 43 箇所（1362/1405 = 96.9%）。未到達数の多い順。

| # | ファイル | C1 | 未到達 | 主な未到達行・内容 |
|---|---|---|---|---|
| 1 | mutex.c | 90.7% | 13 | L161/173(ceiling優先度), L202/227(whileループ), L228/263/265(drop処理), L315/558 他 |
| 2 | time_event.c | 84.5% | 9 | L221/231(ヒープdown処理), L302/390/439, L533(adj_tim負), L588/589(assert), L624 |
| 3 | interrupt.c | 96.6% | 2 | 要 wb_branch_report 確認 |
| 4 | exception.c | 66.7% | 2 | `xsns_dpn`（CPU例外コンテキスト外・CPU非ロック、計2分岐） |
| 5 | task.c | 96.8% | 2 | 要 wb_branch_report 確認 |
| 6 | mempfix.c | 96.6% | 3 | 要 wb_branch_report 確認 |
| 7 | alarm.c | 96.9% | 1 | `_kernel_call_alarm` |
| 8 | cyclic.c | 97.2% | 1 | `_kernel_call_cyclic` |
| 9 | task_refer.c | 97.1% | 1 | `ref_tsk` L131 br[10]（switch未使用ケース） |
| 10 | task_manage.c | 98.9% | 1 | `act_tsk` L137 br[1]（TA_NOACTQUE属性タスクへの再起動） |
| 11 | task_term.c | 98.4% | 1 | `ras_ter` L180 br[0]（dispatch不要パス、到達不能） |
| 12 | time_manage.c | 95.5% | 1 | 要 wb_branch_report 確認 |
| 13 | wait.c | 90.0% | 1 | 要 wb_branch_report 確認 |
| 14 | wait.h | 93.8% | 1 | 要 wb_branch_report 確認 |

**BBテストで解消済み（100%到達）**：

| ファイル | 状態 |
|---|---|
| sys_manage.c | **100%** — ena_dsp_b-3/b-4 で完了 |
| task_term.c (`ena_ter`) | **100%** — ena_ter_c で完了 |
| semaphore.c, dataqueue.c, eventflag.c, pridataq.c, task_sync.c | **100%** — 既存テストで到達済み |

## 更新手順

```bash
# ベースライン再計測（テスト追加後）
bash scripts/coverage_gcov_asp.sh full

# このファイルの数値を更新するスクリプト（参考）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

再計測後は各 API の数値と `状態` 列（未着手 / 対応中 / 完了 / 到達不能）を更新する。
