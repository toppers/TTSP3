# WHITEBOX_BASELINE.md — ASP3 kernel/ API別分岐カバレッジベースライン

> 計測日: 2026-06-08（初回）→ 2026-06-08 修正再計測  
> 方式: gcov（`python3 scripts/wb_branch_report.py <source>`）  
> 対象: ASP3 3.7.2 `kernel/`、APIオートコード 20グループ統合  
> 修正: `RAISE_CPU_EXCEPTION` を `0x06000010`（EQ条件付き，Z=0でスキップ）から
>        `0xf0500090`（ARMv7無条件未定義命令）に変更し，6グループのタイムアウトを解消。
>        all 20/20 グループ PASS。

## 全体サマリ

```
分岐カバレッジ(kernel/): 1336/1381 = 96.7%  (C1)   ← 未到達 45 分岐
  ※修正前: 1012/1405 = 72.0%（auto_code 6/20 タイムアウト起因）
```

### ファイル別サマリ（修正後）

| ファイル | 到達 | 全分岐 | C1 |
|---|---|---|---|
| alarm.c | 31 | 32 | 96.9% |
| cyclic.c | 35 | 36 | 97.2% |
| dataqueue.c | 152 | 152 | **100%** |
| eventflag.c | 119 | 120 | 99.2% |
| exception.c | 4 | 6 | 66.7% |
| interrupt.c | 56 | 58 | 96.6% |
| mempfix.c | 84 | 88 | 95.5% |
| mutex.c | 127 | 140 | 90.7% |
| pridataq.c | 148 | 148 | **100%** |
| semaphore.c | 76 | 76 | **100%** |
| startup.c | 4 | 4 | **100%** |
| sys_manage.c | 59 | 62 | 95.2% |
| task.c | 60 | 62 | 96.8% |
| task_manage.c | 90 | 92 | 97.8% |
| task_refer.c | 34 | 35 | 97.1% |
| task_sync.c | 118 | 118 | **100%** |
| task_term.c | 60 | 62 | 96.8% |
| time_event.c | 49 | 58 | 84.5% |
| time_manage.c | 21 | 22 | 95.5% |
| wait.c | 9 | 10 | 90.0% |

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
| `pol_flg` ◀ | 100% | 17/18 94% | 1 | L |
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
| `_kernel_dequeue_pridata` | 90% | — | — | — |
| `_kernel_send_pridata` | 100% | 4/4 100% | — | — |
| `_kernel_receive_pridata` | 100% | 6/6 100% | — | — |
| `snd_pdq` | 100% | 20/20 100% | — | — |
| `psnd_pdq` | 100% | 16/16 100% | — | — |
| `tsnd_pdq` ◀ | 100% | 20/24 83.3% | 4 | M |
| `rcv_pdq` | 100% | 18/18 100% | — | — |
| `prcv_pdq` | 100% | 12/12 100% | — | — |
| `trcv_pdq` ◀ | 93.1% | 20/22 90.9% | 2 | L |
| `ini_pdq` | 100% | 10/10 100% | — | — |
| `ref_pdq` | 100% | 8/8 100% | — | — |

### semaphore.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `_kernel_initialize_semaphore` | 100% | 2/2 100% | — | — |
| `sig_sem` ◀ | 100% | 13/14 92.9% | 1 | L |
| `wai_sem` ◀ | 100% | 12/14 85.7% | 2 | M |
| `pol_sem` | 100% | 10/10 100% | — | — |
| `twai_sem` ◀ | 91.3% | 16/18 88.9% | 2 | M |
| `ini_sem` ◀ | 100% | 8/10 80% | 2 | M |
| `ref_sem` ◀ | 53.3% | 3/8 37.5% | 5 | **H** |

### startup.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `sta_ker` | 100% | 2/2 100% | — | — |
| `ext_ker` | 100% | — | — | — |
| `_kernel_exit_kernel` | 100% | 2/2 100% | — | — |

### sys_manage.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `rot_rdq` ◀ | 100% | 10/12 83.3% | 2 | M |
| `get_tid` | 100% | 4/4 100% | — | — |
| `get_lod` ◀ | 100% | 9/10 90% | 1 | L |
| `get_nth` ◀ | 100% | 11/12 91.7% | 1 | L |
| `loc_cpu` | 100% | 2/2 100% | — | — |
| `unl_cpu` ◀ | 100% | 1/2 50% | 1 | M |
| `dis_dsp` | 100% | 4/4 100% | — | — |
| `ena_dsp` ◀ | 82.4% | 6/10 60% | 4 | M |
| `sns_ctx` | 0% | — | — | ※到達不能の可能性 |
| `sns_loc` | 100% | — | — | — |
| `sns_dsp` | 100% | — | — | — |
| `sns_dpn` ◀ | 100% | 5/6 83.3% | 1 | L |
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

### task_manage.c　← P1 作業中

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `act_tsk` ◀ | 100% | 18/20 90% | 2 | M |
| `can_act` ◀ | 100% | 9/10 90% | 1 | M |
| `get_tst` ◀ | 85.7% | 16/20 80% | 4 | **H** |
| `chg_pri` ◀ | 100% | 22/26 84.6% | 4 | M |
| `get_pri` ◀ | 100% | 9/12 75% | 3 | M |
| `get_inf` ◀ | 77.8% | 1/4 25% | 3 | **H** |

### task_refer.c

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `ref_tsk` ◀ | 94.9% | 32/35 91.4% | 3 | M |

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

| API | 行 C0 | 分岐 C1 | 未到達 | W |
|---|---|---|---|---|
| `ext_tsk` ◀ | 82.4% | 9/10 90% | 1 | L |
| `ras_ter` ◀ | 96.6% | 21/24 87.5% | 3 | M |
| `dis_ter` | 100% | 4/4 100% | — | — |
| **`ena_ter`** ◀ | **0%** | **0/8 0%** | **8** | **H ← 完全未テスト** |
| `sns_ter` ◀ | 100% | 3/4 75% | 1 | L |
| `ter_tsk` ◀ | 100% | 12/14 85.7% | 2 | M |

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

## 優先度 H の作業リスト（ホワイトボックステスト追加対象）

> ※ RAISE_CPU_EXCEPTION 修正（2026-06-08）後の再計測値。semaphore/pridataqが解消。

| # | ファイル | API | 分岐 C1 (修正後) | 未到達 | 状態 |
|---|---|---|---|---|---|
| 1 | mutex.c | `_kernel_mutex_check_ceilpri` | 41.7%→要再計測 | 要再計測 | 未着手 |
| 2 | mutex.c | `mutex_calc_priority` | 25.0%→要再計測 | 要再計測 | 未着手 |
| 3 | time_event.c | `_kernel_tmevt_down` | 50.0%→要再計測 | 要再計測 | 未着手 |
| 4 | mempfix.c | `ref_mpf` | 要再計測（file:95.5%） | 要再計測 | 未着手 |
| 5 | task_term.c | `ena_ter` | 要再計測（file:96.8%） | 要再計測 | 未着手 |
| 6 | task_manage.c | `get_inf` / `get_tst` | 要再計測（file:97.8%） | 要再計測 | **P1 作業中** |
| — | semaphore.c | `ref_sem` | **100%** → 解消 | 0 | ✓ 完了 |
| — | task_sync.c | 全API | **100%** → 解消 | 0 | ✓ 完了 |

## 更新手順

```bash
# ベースライン再計測（テスト追加後）
bash scripts/coverage_gcov_asp.sh full

# このファイルの数値を更新するスクリプト（参考）
python3 scripts/ttsp_gcov_report.py --filter /asp3/kernel/ \
    obj_asp_gcov/check_library/* obj_asp_gcov/api_test/auto_code_*
```

再計測後は各 API の数値と `状態` 列（未着手 / 対応中 / 完了 / 到達不能）を更新する。
