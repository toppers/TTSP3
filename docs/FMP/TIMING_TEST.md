# TIMING_TEST.md — FMP マルチコア遅延ディスパッチパスのテスト到達方法 検討

> 作成: 2026-06-10
> 対象: FMP3 3.4.0 `kernel/`、zybo_z7_gcc (Cortex-A9 dual-core)、QEMU
> 関連: [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 §1（マルチコア遅延ディスパッチパス）/ §2-a

FMP 固有の「マルチコア遅延ディスパッチパス」（BB/WB いずれも未到達の約 17 分岐）を、
どうやってテストで到達させるかの検討記録。

---

## 1. 対象分岐とレースシナリオ

FMP では多くのカーネルAPIに以下のパターンが追加されている：

```c
lock_cpu();
acquire_glock();
...
if (p_selftsk != p_my_pcb->p_schedtsk) {
    release_glock();
    dispatch();
    ercd = E_OK;
    goto unlock_and_exit;    /* ← 未到達 */
}
```

到達には次のコア間レースが必要：

- **PE2 : TASK2 : `sus_tsk(TASK1)`** — `acquire_glock()` でジャイアントロックを取得
- **PE1 : TASK1 : `dis_dsp()`** — `lock_cpu()` で割込み禁止、`acquire_glock()` を試みるが PE2 が保持中で取得できずスピン
- **PE2 : TASK2 : `sus_tsk(TASK1)`** — `make_non_runnable()` で PE1 の `p_schedtsk` を TASK1 以外にし、`release_glock()`
- **PE1 : TASK1 : `dis_dsp()`** — `acquire_glock()` 取得 → `if (p_selftsk != p_my_pcb->p_schedtsk)` が真 → if 内（dispatch パス）を実行

### 影響範囲（約 17 分岐 / 8 ファイル）

| ファイル | 未到達分岐 | 未到達行（例） |
|---|---|---|
| alarm.c | 2 | `alm_cal` ハンドラ後処理 |
| cyclic.c | 2 | `cyc_cal` ハンドラ後処理 |
| mempfix.c | 2 | `rel_mpf` / `ini_mpf` |
| mutex.c | 2 | `unl_mtx`(L567-568), `ini_mtx`(L618-619) |
| sys_manage.c | 3 | `rot_rdq`(L277-278), `dis_dsp`(L604-606) |
| task_manage.c | 4 | `act_tsk`(L161-162), `mact_tsk`(L232-233) |
| task_term.c | 1 | `ter_tsk`(L374-375) |
| time_manage.c | 1 | `adj_tim` 後処理 |
| interrupt.c | （§2-a）| `chg_ipm` retry パス（同型） |

**従来の未到達理由**: TTSP3 の APIテストは 1タスク（少数タスク）が順次 API を呼ぶ構成で、QEMU で 2コア起動していても PE2 は `idle_loop` のみ実行し PE1 のスケジューリングを変更しない。そのため `p_selftsk == p_my_pcb->p_schedtsk` が常に成立する。

---

## 2. 前提の確認（重要）：QEMU は MTTCG で実並行

- 実行コマンド: `qemu-system-arm -M xilinx-zynq-a9 ... -smp 2`（`-accel` 指定なし）
- QEMU 11.0.0、Cortex-A9（ARMv7）は MTTCG（マルチスレッドTCG）対応 → **2コアは別ホストスレッドで物理的に並行実行される**

→ レースは「物理的に起こせない」のではなく、**テストプログラムが PE2 に競合動作をさせていないだけ**。PE2 に PE1 タスクへの `sus_tsk` 等を実行させれば、レースは自然発生し得る。これが対応方法の選択を左右する。

---

## 3. 対応方法の比較

### 案1: QEMU + GDB スクリプト（gdbstub + scheduler-locking）

標準 QEMU の gdbstub（`-s -S` / `-gdb`）に GDB を接続し、`set scheduler-locking on` でコア単位に実行制御。
PE1 を `acquire_glock` スピン直前で停止 → PE2 を `sus_tsk` 完了（`p_schedtsk` 変更 + `release_glock`）まで進める → PE1 を再開、という interleaving を決定的に強制。Python スクリプトで自動化可。

- **長所**: QEMU/カーネル無改変（禁則②③に整合）、標準ツール、**完全決定的**、gcov はそのまま収集される
- **短所**: 8ファイル/約17分岐ぶんのスクリプト段取りが必要、シンボル/行番号依存で脆い、CI に gdb 連携を組む手間

### 案2: QEMU にパッチを当ててコア間タイミングを制御

QEMU をフォークし、コア間実行タイミング制御フック（特定 PC でのyield、ランデブー機構等）を追加。

- **長所**: 一度作れば決定的
- **短所**: **フォーク維持コストが過大**（版追従・CI 用パッチ版QEMU 配布・再ビルド）、標準QEMU運用から逸脱。効果に見合わず**不採用推奨**

### 案3: 純粋な2コア・ストレスループ WBテスト（外部ツール不要）★推奨

MTTCG で実並行する事実を使い、外部制御なしでレースを自然発生させる：

- **PE1 タスク**: 対象API（`dis_dsp`/`rot_rdq`/`act_tsk` 等）を密ループで N 回呼ぶ
- **PE2 タスク**: PE1 のタスクに `sus_tsk`→`rsm_tsk`（または `chg_pri`）を密ループで叩き、`p_schedtsk` を反復的に書き換える
- gcov は「一度でも分岐が taken」されれば計上 → 両側密ループで glock 競合頻度を上げる

**要点**: PE1 が `acquire_glock` でスピン待ちに入った時点で PE2 が `sus_tsk` 内で `p_schedtsk` を変えて `release_glock` すれば、PE1 は次の取得で必ず差分を見る。「PE1 が待つ間に PE2 が変更」という順序は**競合そのものが生成する**ため、接触頻度を上げれば高頻度でヒットする見込み。

- **長所**: 純 TTSP3テスト・**外部ツールゼロ**・通常CIで実行・禁則①②③完全遵守・1パターンで複数API系統を一括カバー可
- **短所**: **確率的（非決定的）**。窓が極端に狭い分岐は当たりにくく、CI で**フレーキ**になり得る。反復回数の経験的調整が要る

### 案4: ハイブリッド（推奨運用）

案3 を主軸に広域カバー → ストレスループで安定して当たらない残り分岐のみ案1（GDB scheduler-locking）で決定的に仕留める。低コストの広域カバー＋頑固な分岐への決定的バックストップ。

---

## 4. 比較表

| 観点 | 案1 GDB | 案2 QEMUパッチ | 案3 ストレスループ | 案4 ハイブリッド |
|---|---|---|---|---|
| QEMU/カーネル改変 | 不要 | **QEMUフォーク** | 不要 | 不要 |
| 禁則①②③整合 | ○ | △（保守負担） | ◎ | ◎ |
| 決定性 | ◎ 完全 | ◎ | △ 確率的 | ◎（残りをGDPで補完） |
| CI移植性 | ○（gdb必要） | ×（patch版QEMU配布） | ◎ | ○ |
| 実装/保守コスト | 中（断片化・脆い） | **大（恒久保守）** | 小 | 中 |
| カバー効率 | 分岐ごとに段取り | 同左 | 1パターンで複数系統 | 高 |

---

## 5. 推奨

1. **まず案3を1分岐で試作**（例: PE1 `dis_dsp` 密ループ × PE2 `sus_tsk(TASK1)` 密ループ）して**実ヒット率を測る** — これが案3/案4の実現性を決める決定的実験。
2. 高頻度で当たれば**案3で大半をカバー**し、当たらない少数のみ**案1（GDB）で決定的に補完（案4）**。
3. **案1 > 案2**（標準ツール・無改変・決定的）。**案2 は不採用**（フォーク保守コスト過大）。
4. 非決定的なストレスループを CI の合否ゲートにするのは避け、**カバレッジ蓄積専用ジョブ**（緑/赤判定に使わない）として回すことでフレーキ対策とする。

---

## 6. 補足：実装上の注意（案3）

- WBテストは `CLASS(CLS_ALL_PRC1)`（PE1）と `CLASS(CLS_ALL_PRC2)`（PE2）に各タスクを配置（既存 `mig_tsk` テスト等が PE2 配置の前例）。
- PE2 が PE1 の実行中タスク（TASK1）を `sus_tsk` すると `make_non_runnable` で PE1 の `p_schedtsk` が変わり、PE1 へ dispatch 要求が飛ぶ → ドキュメント記載のシナリオが成立。
- TASK1 自身がループ中に suspend されるため、PE2 は `sus_tsk`→`rsm_tsk` を対で回し TASK1 のループを継続させる。
- gcov の gcda はプログラム終了時に書き出されるため、ループ中に一度でも分岐が taken されれば計上される。
- カーネルの critical section 内（`lock_cpu`〜`acquire_glock`）にはテストから手を入れられない（禁則②）。レース窓への介入は「もう一方のコアのタスク」からのみ可能 → 案3（PE2タスク）か案1（GDB）に限られる。
