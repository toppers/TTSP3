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
| interrupt.c | （§2-a）| `chg_ipm` retry パス（同型） |

> **注記（2026-06-10 レビュー）**: 旧版は本表に `time_manage.c | 1 | adj_tim 後処理` を含めていたが、これは誤り。`adj_tim` には `if (p_selftsk != p_schedtsk)` 型のディスパッチ分岐は無く、`time_manage.c` の `all` 残存 2 分岐は `adj_tim` の **64bit `EVTTIM` 折返し**（L174–178）で、案3（タイミングレース）では到達不能・simt スイートでのみ到達可能。詳細は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) §10。

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

---

## 7. 案3 の停止トリガー設計（確率的ループをどう終わらせるか）

案3 は確率的なので「いつ・どう止めるか」を決める必要がある。要点は **「ヒット検出」と「gcov ダンプ」を分けて考える**こと。gcov の .gcda はプログラム終了時（または `__gcov_dump()`）に書かれるため、**ブレークで止めてダンプ前に QEMU を kill するとカバレッジが残らない**のが最大の落とし穴。

### 7-1. 2つの停止トリガー案

| | 案A: 固定回数で終了 → オフライン判定 | 案B: ブレークでヒット検出 |
|---|---|---|
| 仕組み | PE1/PE2 を有限回ループ後に正常終了 → gcov を後で読む | GDB で対象分岐に BP → 発火で「到達」検知 |
| 外部ツール | **不要（純テスト）** | GDB 必須（＝案4相当） |
| 終了の決定性 | ◎ 反復数で確定的 | △ 発火タイミング依存 |
| ヒットの即時確認 | ✗（gcov を見るまで不明） | ◎ 即わかる |
| gcda 取りこぼし | なし（正常終了で必ずダンプ） | **BP で kill すると取りこぼす**（要対策） |
| CI適性 | ◎ そのまま | △ GDB連携 |

### 7-2. 推奨：基本は案A、確認/早期終了が要るとき案B

**案A（既定）**: 「一度でも分岐が taken されれば gcov に残る」ので**ライブ検出は不要**。両ループを有限回 → 正常終了 → 後段の `ttsp_gcov_report.py` で hit/miss を判定。miss なら反復数 N を増やして再実行。停止は反復カウンタで確定的。

設計上の必須事項：
- **両コアの停止協調**: 共有 `volatile bool done` を置き、PE1 が N 回後に `done=true`、PE2 は `while(!done){ sus_tsk; rsm_tsk; }` で抜ける。片方だけ終わると残りが回り続ける
- **デッドロック回避**: PE2 は `sus_tsk`→必ず `rsm_tsk` を対で回し、TASK1 を進ませ続ける
- **ウォッチドッグ上限**: 反復数とは別に `alarm`/`cyclic` か QEMU の `timeout` でハング時の絶対上限を設ける（無限ループ保険）
- **終了基準は反復回数を主に**: 壁時計時間は -O0 や host 負荷で揺れて非再現的。時間は保険の上限にのみ使う

**案B（早期終了/確認が要る場合・実体は案4）**:
- BP は**検出専用**にし、発火したら GDB から `set var done=1`（または `__gcov_dump()` 呼出し）→ **プログラムを正常終了させてから** .gcda を書かせる。**BP で即 kill しない**
- 稀な分岐で N が読めないとき、当たった瞬間に止められ、ヒットも即確定

### 7-3. 実務的な落としどころ

1. **開発時の計測ツールとして案B を一時利用**: BP で「初ヒットまで何反復か」を測り、N を決める
2. **本番テストは案A**（純ループ・固定 N ＋ウォッチドッグ）で CI のカバレッジ蓄積ジョブとして回す
3. 案A で安定して当たらない頑固な分岐だけ **案4（GDB scheduler-locking で決定的に強制）**へ escalate

要するに「時間待ち」より **「反復回数で確定終了 ＋ オフライン gcov 判定」** が再現性・CI適性で勝り、ブレークは **「検出 ＆ N 見積もりの計測器」** として使うのが綺麗。

---

## 8. 実測結果（-O2+インライン抑制 union, 2026-06-10）★案3 実証・寄与確定

### 8-0. ファイル管理（フォルダ構成）

タイミング（多コアレース）テストは `api_test/`・`wb_test/` と並ぶ**トップレベル `timing_test/`** で管理する（`coverage_gcov_fmp.sh` の `*_W-*` 自動収集対象外＝通常カバレッジ／CIゲートに混入しない）。正味で分岐を増やす2本のみを保持する。

```
timing_test/FMP/sys_manage/dsp_race/     … dis_dsp dispatch race
timing_test/FMP/interrupt/chg_ipm_race/  … chg_ipm retry race (L383)
```

共通構造: PE1 `MAIN_TASK`（CLS_ALL_PRC1）が対象APIを `LOOP_N=100000` 回密ループ、PE2 `RACER_TASK`（CLS_ALL_PRC2）が `sus_tsk`/`rsm_tsk(MAIN_TASK)` で `p_schedtsk` を反復書換。実行は QEMU 11.0.0 `-smp 2`（MTTCG）、計測は本番と同じ **-O2 + インライン抑制**、停止は案A（固定 N → `done` → 正常終了 → オフライン gcov 判定）。

### 8-1. -ni union での正味寄与（+2 分岐）

採用済みの -O2+インライン抑制ビルドで、BB+WB の union に timing を加えた寄与：

| 指標 | 分岐 C1 |
|---|---|
| BB+WB（timing なし）| 1520/1597 (95.2%) |
| **BB+WB+timing** | **1522/1597 (95.3%)** |

> ⚠️ 上表の絶対値（1520/1522）は本計測時点（サブ優先度/interrupt 負テスト追加前）のもの。**現状の BB+WB は 1550/1597 = 97.1%**（[`ALL_COVERAGE.md`](ALL_COVERAGE.md)）で、timing の**正味寄与 +2 分岐（dis_dsp/chg_ipm L383）は不変**（timing は `all` union に常時は含めない運用）。timing を加えた現状はおよそ 1552/1597。

| timing test | 対象分岐 | 寄与 | 備考 |
|---|---|---|---|
| `dsp_race` | dis_dsp dispatch race | **+1**（3/4→4/4）| dis_dsp は自分でスケジュールを変えないため BB では到達不能＝timing 専用 |
| `chg_ipm_race` | chg_ipm retry race（L383）| **+1**（12/16→13/16）| 同上。retry 直後の `p_selftsk!=p_schedtsk` |
| ~~`mrot_rdq_race`~~ | mrot_rdq dispatch | **0 → 削除** | mrot_rdq の race 分岐は **BB が単核で網羅済み**（残 1 は context 経路 `request_dispatch_retint`＝非タスク文脈のみ）。寄与ゼロのため削除 |

全テスト All check points passed。LOOP_N=100000 で全完走（-ni でも timeout なし）。

### 8-2. 重要な知見：-ni では多コア dispatch の大半が BB で既に網羅

旧 -O2（インライン展開あり）計測では「マルチコア遅延ディスパッチ 未到達 ~30」と見えていたが、これは**インライン由来の分岐水増し・誤集計が主因**だった。-O2+インライン抑制で計測し直すと、`mrot_rdq`/`ena_dsp` 等の dispatch race 分岐は **BB テストが単核シナリオ（同／高優先度タスクの起床）で既に到達**しており、timing 技術が本当に必要なのは：

- **dis_dsp**（dispatch race）— 自身でスケジュールを変えないため BB では不可
- **chg_ipm**（retry race L383）— 同上

の 2 分岐に縮小した。`ena_dsp`/`mrot_rdq` の残存未到達は dispatch race ではなく **raster&&enater 自終了**や **context 経路**（別技術／構造的）である。

### 8-3. 切り分け：踏める分岐 / 構造的に dead な分岐

- **acquire_glock 後の「最初の」 `p_selftsk != p_schedtsk` 判定**（glock が競合し得た直後）は racer で踏める（dis_dsp / chg_ipm L383）。
- **glock を連続保持したままの「後続」再チェック**（chg_ipm L403/L405 等）は、間に `release_glock` が無く `p_schedtsk` が変わり得ない → **構造的到達不能**（racer でも踏めない）。
- **context 経路**（`request_dispatch_retint`、非タスク文脈の分岐）は task からのループでは到達できない。

### 8-4. 結論・運用

- 案3（純2コアストレスループ）は **実証済み**。外部ツールなしで dis_dsp / chg_ipm の dispatch race を高頻度ヒット（CI フレーキ懸念は実質なし）。
- ただし -ni 下での**正味寄与は +2 分岐**（多コア dispatch の大半は BB が網羅）。timing テストは `dsp_race`・`chg_ipm_race` の 2 本に整理。
- `timing_test/` は CI ゲート対象外（`*_W-*` 非該当で自動収集されない）。カバレッジ蓄積ジョブで union に加える運用。
- 再走: `bash /tmp/fmp_timing_run.sh` 相当（各 timing を -ni でビルド→QEMU -smp 2→`ttsp_gcov_report.py` で BB+WB と union）。
