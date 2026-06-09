# WB_COVERAGE.md — ASP3 kernel/ WBテスト（ホワイトボックステスト）カバレッジ

> 更新: 2026-06-09  
> 対象: ASP3 3.7.2 `kernel/`  
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh all`）  

このファイルは **手書き WBテスト（方式2）の寄与のみ** をまとめる。  
- BBテスト + WBテストを統合した最終カバレッジ → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)  
- WBテストでも到達しない残存分岐の分析 → [`WB_UNREACHABLE.md`](WB_UNREACHABLE.md)

**WBテストの位置づけ**: 自動生成 BBテスト（`bb` モード、1425/1459 = 97.7%）では到達できない分岐を、ソースを直接読んで設計した手書きテストで補う。WBテストを加えた `all` モードは 1434/1459 = 98.3%。

---

## WBテストによるカバレッジ寄与サマリ

WBテスト（方式2）は以下の 8 分岐を新規に到達させ、`bb` → `all` で **+9 分岐**（time_event の複合条件 L221 が 2 分岐相当）を追加する。

| ファイル | `bb` 分岐 | `all` 分岐 | 増分 | WBテスト |
|---|---|---|---|---|
| alarm.c | 31/32 | 32/32 | +1 | `alarm_W-a` |
| cyclic.c | 35/36 | 36/36 | +1 | `cyclic_W-a` |
| mempfix.c | 88/90 | 90/90 | +2 | `mempfix_W-a` / `mempfix_W-b` |
| task_manage.c | 91/92 | 92/92 | +1 | `act_tsk_W-a` |
| time_event.c | 48/56 | 52/56 | +4 | `time_event_W-a`（L221 複合条件×2 + L231）/ `time_event_W-b`（L302） |
| **合計** | **1425/1459 (97.7%)** | **1434/1459 (98.3%)** | **+9** | — |

> 補足: `adj_tim_W-a.yaml`（`api_test/ASP/time_manage/adj_tim/`）はホワイトボックス意図のテストだが **方式1（YAML 自動生成）** であり、`bb` モードに統合済み（check_adjtim L533 br[1] を到達済み）。本ファイルの方式2集計には含めない。

---

## WBテストカタログ（方式2: 手書き、`api_test/ASP/<API>/<name>/`）

| WBテスト | 対象分岐 | 内容 | 配置 |
|---|---|---|---|
| `alarm_W-a` | alarm.c L241 br[1] | 通知ハンドラが `iloc_cpu()` を保持して戻る → `lock_cpu()` スキップ | [out.c](../../api_test/ASP/alarm/alarm_W-a/out.c) |
| `cyclic_W-a` | cyclic.c L259 br[1] | 周期ハンドラが `iloc_cpu()` を保持して戻る → `lock_cpu()` スキップ | [out.c](../../api_test/ASP/cyclic/cyclic_W-a/out.c) |
| `mempfix_W-a` | mempfix.c L309 br[0] | `rel_mpf`: ミスアライメントポインタ → `E_PAR` | [out.c](../../api_test/ASP/mempfix/mempfix_W-a/out.c) |
| `mempfix_W-b` | mempfix.c L310 br[0] | `rel_mpf`: blkidx 範囲外 → `E_PAR` | [out.c](../../api_test/ASP/mempfix/mempfix_W-b/out.c) |
| `act_tsk_W-a` | task_manage.c L137 br[1] | `act_tsk`: `TA_NOACTQUE` 属性タスクへの起動 → `E_QOVR` | [out.c](../../api_test/ASP/task_manage/act_tsk_W-a/out.c) |
| `time_event_W-a` | time_event.c L221 / L231 | `tmevt_down`: 右子ノードなし + 早期 break（heap sift-down） | [out.c](../../api_test/ASP/time_event/time_event_W-a/out.c) |
| `time_event_W-b` | time_event.c L302 br[0] | `tmevtb_delete`: go-up パス（last < parent） | [out.c](../../api_test/ASP/time_event/time_event_W-b/out.c) |

---

# WBテスト到達分岐の詳細分析

> 各分岐について「分岐の意味」「`bb`（BBテスト）で未到達となる理由」「WBテストの到達手法」を示す。  
> **WBテストの妥当性**（テスト内容が分岐の意味を正しく検証しているか、手書きコストが妥当かなど）は、これをもとに人間が確認する。

---

## 1. alarm.c — `_kernel_call_alarm` L241 br[1]

**ソース** (`asp3/kernel/alarm.c` L235–243):
```c
unlock_cpu();                                                         /* L235 */
(*(p_almcb->p_alminib->nfyhdr))(p_almcb->p_alminib->exinf);          /* L238: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L241 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L241 br[1]（`sense_lock() == true`） | ハンドラが CPU ロック（`iloc_cpu()`）を保持したまま戻る → `lock_cpu()` はスキップ | `call_alarm` はハンドラを `unlock_cpu()` 後に呼び出し、戻り後に `sense_lock()` で CPU ロック状態を確認する。BB テストのハンドラは CPU ロックを操作せず、戻り時は常にロック解除状態（`sense_lock() == false`）になる。`iloc_cpu()` を保持して戻るシナリオは自動生成テストでは生成されない。 |

**WBテスト** [`alarm_W-a`](../../api_test/ASP/alarm/alarm_W-a/out.c): アラーム通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L241 br[1] を到達させる。

---

## 2. cyclic.c — `_kernel_call_cyclic` L259 br[1]

**ソース** (`asp3/kernel/cyclic.c` L253–261):
```c
unlock_cpu();                                                         /* L253 */
(*(p_cyccb->p_cycinib->nfyhdr))(p_cyccb->p_cycinib->exinf);          /* L256: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L259 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L259 br[1]（`sense_lock() == true`） | 周期ハンドラが CPU ロックを保持したまま戻る | §1（alarm.c L241）と同構造。`call_cyclic` も同一パターンで実装されており、BB テストでは非網羅。 |

**WBテスト** [`cyclic_W-a`](../../api_test/ASP/cyclic/cyclic_W-a/out.c): 周期通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L259 br[1] を到達させる。

---

## 3. mempfix.c — `rel_mpf` L309 / L310 br[0]

**ソース** (`asp3/kernel/mempfix.c` L307–311):
```c
CHECK_PAR(p_mpfcb->p_mpfinib->mpf <= blk);                                    /* L307 */
blkoffset = ((char *) blk) - (char *)(p_mpfcb->p_mpfinib->mpf);               /* L308 */
CHECK_PAR(blkoffset % p_mpfcb->p_mpfinib->blksz == 0U);                       /* L309 */
CHECK_PAR(blkoffset / p_mpfcb->p_mpfinib->blksz < p_mpfcb->unused);           /* L310 */
blkidx = (uint_t)(blkoffset / p_mpfcb->p_mpfinib->blksz);                     /* L311 */
```

`CHECK_PAR(cond)` は `cond` が偽のとき `E_PAR` を返す。L309 br[0] / L310 br[0] は各 CHECK_PAR の「偽（エラー）」分岐。

### 3-a. L309 br[0]（ミスアライメントポインタ → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L309 br[0]（`blkoffset % blksz != 0U` → E_PAR） | `rel_mpf` に渡すポインタがブロックサイズに整合しない | BB テストは常に `get_mpf` で取得したポインタを `rel_mpf` に渡す。`get_mpf` はブロックサイズ境界に整合したポインタのみ返すため、ミスアライメントポインタは自動生成テストでは発生しない。 |

**WBテスト** [`mempfix_W-a`](../../api_test/ASP/mempfix/mempfix_W-a/out.c): `get_mpf` で取得したブロックポインタにオフセットを加えたミスアライメントポインタを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

### 3-b. L310 br[0]（ブロックオフセット範囲外 → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L310 br[0]（`blkidx >= p_mpfcb->unused` → E_PAR） | `blkoffset / blksz` で得られる index が割当て済みブロック数を超過 | BB テストは正規ポインタのみ使用。プール管理領域外（`unused` を超えた index に対応する）アドレスを渡すケースは自動生成テストでは発生しない。 |

**WBテスト** [`mempfix_W-b`](../../api_test/ASP/mempfix/mempfix_W-b/out.c): プール末尾（`mpf + blksz * blkcnt`）を超えるアドレスを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

---

## 4. task_manage.c — `act_tsk` L137 br[1]

**ソース** (`asp3/kernel/task_manage.c` L135–142):
```c
if (TSTAT_DORMANT(p_tcb->tstat)) {
    ...                                                               /* 起動処理 */
}
else if ((p_tcb->p_tinib->tskatr & TA_NOACTQUE) != 0U || p_tcb->actque) {  /* L137 */
    ercd = E_QOVR;                                                    /* ［NGKI3528］*/
}
else {
    p_tcb->actque = true;                                             /* ［NGKI3527］*/
    ercd = E_OK;
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L137 br[1]（`TA_NOACTQUE` フラグあり → E_QOVR） | `TA_NOACTQUE` 属性タスクに `act_tsk` を呼ぶ（起動要求キューイング不可 → 即 E_QOVR）〔NGKI3528〕 | BB テストで生成されるタスクは `TA_NOACTQUE` 属性を持たない。`actque=true` ルート（既にキュー済み）は BB テストでカバーされているが、`TA_NOACTQUE` フラグによる短絡ルートは属性指定が必要であり、自動生成テストでは非網羅。 |

**WBテスト** [`act_tsk_W-a`](../../api_test/ASP/task_manage/act_tsk_W-a/out.c): `TA_NOACTQUE` 属性で生成した実行中タスクに `act_tsk` を呼んで `E_QOVR` が返ることを確認。

---

## 5. time_event.c — `tmevt_down` L221 / L231（`time_event_W-a`）

**ソース** (`asp3/kernel/time_event.c` L215–228):
```c
while ((child = LCHILD(index)) <= LAST_INDEX()) {             /* L215: 左子あり */
    if (child + 1 <= LAST_INDEX()                             /* L221: 右子の有無 + 早い方の選択 */
            && EVTTIM_LT(HEAP_NODE(child + 1)->evttim,
                                    HEAP_NODE(child)->evttim)) {
        child = child + 1;
    }
    if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) {        /* L231: break 判定 */
        break;
    }
    HEAP_NODE(index) = HEAP_NODE(child);
    HEAP_NODE(index)->index = index;
    index = child;
}
```

L221 は `child + 1 <= LAST_INDEX()`（右子の有無）と `EVTTIM_LT(...)`（左右どちらが早いか）の複合条件で、gcov 上は 2 分岐に展開される。

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L221（`child + 1 > LAST_INDEX()`） | 現レベルに左の子しか存在しない（右子ノードがヒープ末尾を超える） | BB テストのタイムイベント登録・削除パターンでは、`tmevt_down` が呼ばれる時点でヒープが常に当該レベルに右子を持つ形になる。「左子のみ」状態は特定の登録順序・数でのみ発生し、自動生成テストでは生成されない。 |
| L231 br[0]（`EVTTIM_LE(evttim, child->evttim)` が真 → break） | 挿入ノードの発生時刻が選択した子ノード以前 → 現在の `index` が挿入位置 | BB テストのパターンでは sift-down が末尾まで進むか 1 段のみで終わるため「中間で止まる」ケースが生じない。 |

**WBテスト** [`time_event_W-a`](../../api_test/ASP/time_event/time_event_W-a/out.c): 複数タイムイベントを特定の順序で登録・期限切れさせ、sift-down 時に右子が存在しないヒープ形状を手書きで構築。さらに挿入ノードが左子より早い発生時刻になるよう配置し、L221（右子なし）・L231（早期 break）を同一テスト実行で同時にカバー。

---

## 6. time_event.c — `tmevtb_delete` L302 br[0]（`time_event_W-b`）

**ソース** (`asp3/kernel/time_event.c` L298–320):
```c
event_evttim = HEAP_NODE(last_index)->evttim;
if (index > ROOT_INDEX                                         /* L300 */
        && EVTTIM_LT(event_evttim,                             /* L302 */
                    HEAP_NODE(parent = PARENT(index))->evttim)) {
    /* 最後尾ノードが削除位置の親より前 → 上方向に挿入位置を探す */
    HEAP_NODE(index) = HEAP_NODE(parent);
    HEAP_NODE(index)->index = index;
    index = tmevt_up(parent, event_evttim);
}
else {
    index = tmevt_down(index, event_evttim);  /* go-down */
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L302 br[0]（go-up 条件が真） | 削除ノードを最後尾ノードで置き換えた際、最後尾ノードの発生時刻が削除位置の親ノードより前 → ヒープ性質を回復するため上方向に移動 | BB テストの削除パターンでは、最後尾ノードが削除位置の親より後の時刻になるため常に go-down パスを通る。go-up が発生するには削除対象が「ヒープ下部の大きい値を持つノード」かつ最後尾が「比較的早い時刻」という特定の配置が必要。 |

**WBテスト** [`time_event_W-b`](../../api_test/ASP/time_event/time_event_W-b/out.c): ヒープ中間ノードの削除時に最後尾ノードの発生時刻が削除位置の親ノードより早くなるよう、複数タイムイベントの発生時刻と削除順序を手書きで設計。

---

## 更新手順

```bash
# WBテストを含む all モードで再計測
bash scripts/coverage_gcov_asp.sh all

# bb モード（WBテストなし）と比較して WB の寄与（差分）を確認
bash scripts/coverage_gcov_asp.sh bb
```

`all` と `bb` の差分が WBテストの寄与。WBテストを追加・変更した場合は本ファイルのカタログ・サマリ表・差分（+N 分岐）を更新する。
