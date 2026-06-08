---
api: act_tsk
title: タスクの起動（act_tsk / iact_tsk）テストシート
profile: { ASP: false, FMP: true, HRP: false, HRMP: true }   # 本シートはFMP版。ASPは別シート(api_test/ASP/...)
spec_version: "TOPPERS統合仕様書 3.7.0"
base_tesry: "$Id: act_tsk.txt 67 2020-02-04 09:15:32Z fujisft-shigihara $（TTSP3 R3.1.0・仕様3.4.0由来）"
last_updated: "2026-06-08"
combinatorial_source: "act_tsk_matrix.md（act_tsk.xlsx を MarkItDown で md テーブル化）"
test_dir: "../act_tsk/"
changelog:            # シート単位の節目のみ（詳細は git log）。1イベント1行・コミット単位にしない
  - { date: 2026-06-08, change: "md化（act_tsk.txt $Id:67 を凍結継承）・仕様3.7基準化・トレーサビリティ表/組合せ表(xlsx)を追加", ref: git }
---

> **改変明記（ライセンス条件(2)）**：本ファイルは TTSP3 R3.1.0 の
> `api_test/FMP/task_manage/act_tsk/act_tsk.txt`（著作権：NCES名古屋大学／TOPPERSプロジェクト／
> Digital Craft／NEC Communication Systems／FUJI SOFT／Mitsuhiro Matsuura）を基に，
> 2026-06-08 に md 形式へ再構成し，準拠仕様の明示（3.7）・テスト実体へのリンク・
> 組合せ表（act_tsk.xlsx）のテキスト正本化を追加したもの。原著作権・利用条件・無保証規定は
> 元 `act_tsk.txt` のものを継承する。これは md化パイロット（act_tsk_new）であり，
> 確定後に正式配置・テンプレ化する。

# act_tsk テストシート（FMP・仕様3.7）

## 0. API仕様（準拠：統合仕様書 3.7.0）

| 項目 | 内容 |
|---|---|
| act_tsk | タスクの起動〔TI〕【NGKI3529】 |
| C言語API | `ER ercd = act_tsk(ID tskid)` |
| パラメータ | `ID tskid` 対象タスクのID番号 |
| リターン | `ER ercd` 正常終了（E_OK）またはエラーコード |

### エラーコード（NGKIトレーサビリティ）
| コード | 条件 | NGKI |
|---|---|---|
| E_CTX | CPUロック状態からの呼出し | 【NGKI1114】 |
| E_ID | tskidが有効範囲外 | 【NGKI1115】 |
| E_NOEXS | 対象タスクが未登録〔D〕 | 【NGKI1116】 |
| E_OACV | 対象タスクへの通常操作1が不許可〔P〕 | 【NGKI1117】 |
| E_QOVR | 起動要求キューイング数が TMAX_ACTCNT 超／TA_NOACTQUE | 【NGKI3528】 |

### 機能（要点）
- 対象タスクが休止状態：起動時初期化を行い実行できる状態へ【NGKI1118】
- 休止状態でなく非TA_NOACTQUE：起動要求キューイング数+1【NGKI3527】
- TA_NOACTQUE／キューイングが TMAX_ACTCNT 超：E_QOVR【NGKI3528】
- タスクコンテキストで tskid=TSK_SELF は自タスク【NGKI1121】
- 【補足】マルチプロセッサでは次回起動時の割付けプロセッサを設定しない（FMP固有挙動）

## 1. テスト設計：組合せの因子凡例（act_tsk.xlsx 由来）

FMP の act_tsk テストは多因子組合せ。ケースID `F-c-X-Y` 等の各次元は以下を表す
（凡例は `act_tsk.xlsx` の見出しから抽出。網羅条件は `act_tsk_matrix.csv` を正本とする）。

| 因子（次元） | 取り得るレベル（例） |
|---|---|
| 自プロセッサの状態 | 実行状態(自タスク)／ディスパッチ禁止状態／割込み優先度マスク非全解除／CPUロック状態／スピンロック取得中／非タスクコンテキスト実行時 |
| 対象タスクの状態 | 休止状態／休止状態でない／実行状態／実行可能状態／起床待ち／時間経過待ち／強制待ち状態[実行継続中]／セマフォ資源獲得待ち(タイムアウト無・有)／二重待ち状態 |
| 他プロセッサの状態 | 割付け先PEでの実行状態タスクの有無(有り／無し)／ディスパッチ保留状態でない |
| 事後状態（期待） | E_CTX／E_QOVR／起動要求キューイング数+1／実行可能状態となり同優先度の最後につながれる 等 |
| 対応ASPケースID | 各FMPケースが対応するASP版テストケース（例: a (EX_OTHER_PRC), c (EX_NEW_STATE)） |
| タグ | 【NGKI…】／EX_NEW_STATE／EX_OTHER_PRC |

> ケース名の接尾辞：`_ntc` / `_ten` は待ち状態タスクのタイムアウト有無等の変種
> （正確な意味は要確認。CSV正本化の際に列として明示する）。

## 2. 組合せマトリクス（正本：md テーブル）

- **正本**：[`act_tsk_matrix.md`](./act_tsk_matrix.md)（`act_tsk.xlsx` を **MarkItDown**
  （`markitdown[xlsx]`）で md テーブル化し、空列・改行を整形したもの。UTF-8 の md なので
  **文字化けせず**、diff/grep/CI解析・閲覧が容易）。
- **作成用**：[`../act_tsk/act_tsk.xlsx`](../act_tsk/act_tsk.xlsx)（人手編集用の作業コピー）
- 運用：Excelで編集 → **MarkItDown で md 再生成** → CI で「xlsx由来md vs コミット済md」を
  diff して未エクスポート編集を検出（ドリフト防止）。**正本は md**。
  - 変換コマンド例：`markitdown act_tsk/act_tsk.xlsx`（または pandas/openpyxl で空列除去整形）。
  - 注：CSV はExcelが既定でShift-JIS解釈し文字化けするため不採用。md に統一。

## 3. トレーサビリティ表（全ケース → テスト実体）

凡例：期待＝yaml の `ercd`（または `eruint`）。実体は `../act_tsk/` の yaml へのリンク。
（全77ケース。`_ntc`/`_ten` 変種を含む）

| ケースID | 期待 | NGKI | テスト実体 |
|---|---|---|---|
| `F-a-1` | E_CTX | 【NGKI1114】 | [`act_tsk_F-a-1.yaml`](../act_tsk/act_tsk_F-a-1.yaml) |
| `F-a-2` | E_CTX | 【NGKI1114】 | [`act_tsk_F-a-2.yaml`](../act_tsk/act_tsk_F-a-2.yaml) |
| `F-a-3` | E_CTX | 【NGKI1114】 | [`act_tsk_F-a-3.yaml`](../act_tsk/act_tsk_F-a-3.yaml) |
| `F-b-1` | E_QOVR | 【NGKI3528】 | [`act_tsk_F-b-1.yaml`](../act_tsk/act_tsk_F-b-1.yaml) |
| `F-b-2` | E_QOVR | 【NGKI3528】 | [`act_tsk_F-b-2.yaml`](../act_tsk/act_tsk_F-b-2.yaml) |
| `F-b-3` | E_QOVR | 【NGKI3528】【NGKI1121】 | [`act_tsk_F-b-3.yaml`](../act_tsk/act_tsk_F-b-3.yaml) |
| `F-c-1-1` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-1.yaml`](../act_tsk/act_tsk_F-c-1-1.yaml) |
| `F-c-1-1_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-1_ntc.yaml`](../act_tsk/act_tsk_F-c-1-1_ntc.yaml) |
| `F-c-1-1_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-1_ten.yaml`](../act_tsk/act_tsk_F-c-1-1_ten.yaml) |
| `F-c-1-2` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-2.yaml`](../act_tsk/act_tsk_F-c-1-2.yaml) |
| `F-c-1-2_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-2_ntc.yaml`](../act_tsk/act_tsk_F-c-1-2_ntc.yaml) |
| `F-c-1-2_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-2_ten.yaml`](../act_tsk/act_tsk_F-c-1-2_ten.yaml) |
| `F-c-1-3` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-3.yaml`](../act_tsk/act_tsk_F-c-1-3.yaml) |
| `F-c-1-3_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-3_ntc.yaml`](../act_tsk/act_tsk_F-c-1-3_ntc.yaml) |
| `F-c-1-3_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-3_ten.yaml`](../act_tsk/act_tsk_F-c-1-3_ten.yaml) |
| `F-c-1-4` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-4.yaml`](../act_tsk/act_tsk_F-c-1-4.yaml) |
| `F-c-1-4_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-4_ntc.yaml`](../act_tsk/act_tsk_F-c-1-4_ntc.yaml) |
| `F-c-1-5` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-5.yaml`](../act_tsk/act_tsk_F-c-1-5.yaml) |
| `F-c-1-5_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-5_ntc.yaml`](../act_tsk/act_tsk_F-c-1-5_ntc.yaml) |
| `F-c-1-6` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-6.yaml`](../act_tsk/act_tsk_F-c-1-6.yaml) |
| `F-c-1-6_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-1-6_ntc.yaml`](../act_tsk/act_tsk_F-c-1-6_ntc.yaml) |
| `F-c-2` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-2.yaml`](../act_tsk/act_tsk_F-c-2.yaml) |
| `F-c-2_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-2_ntc.yaml`](../act_tsk/act_tsk_F-c-2_ntc.yaml) |
| `F-c-2_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-2_ten.yaml`](../act_tsk/act_tsk_F-c-2_ten.yaml) |
| `F-c-3` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-3.yaml`](../act_tsk/act_tsk_F-c-3.yaml) |
| `F-c-3_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-3_ntc.yaml`](../act_tsk/act_tsk_F-c-3_ntc.yaml) |
| `F-c-3_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-3_ten.yaml`](../act_tsk/act_tsk_F-c-3_ten.yaml) |
| `F-c-4` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-4.yaml`](../act_tsk/act_tsk_F-c-4.yaml) |
| `F-c-4_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-4_ntc.yaml`](../act_tsk/act_tsk_F-c-4_ntc.yaml) |
| `F-c-4_ten` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-4_ten.yaml`](../act_tsk/act_tsk_F-c-4_ten.yaml) |
| `F-c-5` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-5.yaml`](../act_tsk/act_tsk_F-c-5.yaml) |
| `F-c-5_ntc` | E_OK | 【NGKI1118】 | [`act_tsk_F-c-5_ntc.yaml`](../act_tsk/act_tsk_F-c-5_ntc.yaml) |
| `F-d-1` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-1.yaml`](../act_tsk/act_tsk_F-d-1.yaml) |
| `F-d-1_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-1_ntc.yaml`](../act_tsk/act_tsk_F-d-1_ntc.yaml) |
| `F-d-1_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-1_ten.yaml`](../act_tsk/act_tsk_F-d-1_ten.yaml) |
| `F-d-2-1` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-1.yaml`](../act_tsk/act_tsk_F-d-2-1.yaml) |
| `F-d-2-1_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-1_ntc.yaml`](../act_tsk/act_tsk_F-d-2-1_ntc.yaml) |
| `F-d-2-1_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-1_ten.yaml`](../act_tsk/act_tsk_F-d-2-1_ten.yaml) |
| `F-d-2-2` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-2.yaml`](../act_tsk/act_tsk_F-d-2-2.yaml) |
| `F-d-2-2_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-2_ntc.yaml`](../act_tsk/act_tsk_F-d-2-2_ntc.yaml) |
| `F-d-2-2_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-2_ten.yaml`](../act_tsk/act_tsk_F-d-2-2_ten.yaml) |
| `F-d-2-3` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-3.yaml`](../act_tsk/act_tsk_F-d-2-3.yaml) |
| `F-d-2-3_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-3_ntc.yaml`](../act_tsk/act_tsk_F-d-2-3_ntc.yaml) |
| `F-d-2-3_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-3_ten.yaml`](../act_tsk/act_tsk_F-d-2-3_ten.yaml) |
| `F-d-2-4` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-4.yaml`](../act_tsk/act_tsk_F-d-2-4.yaml) |
| `F-d-2-4_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-4_ntc.yaml`](../act_tsk/act_tsk_F-d-2-4_ntc.yaml) |
| `F-d-2-4_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-2-4_ten.yaml`](../act_tsk/act_tsk_F-d-2-4_ten.yaml) |
| `F-d-3` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-3.yaml`](../act_tsk/act_tsk_F-d-3.yaml) |
| `F-d-3_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-3_ntc.yaml`](../act_tsk/act_tsk_F-d-3_ntc.yaml) |
| `F-d-3_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-3_ten.yaml`](../act_tsk/act_tsk_F-d-3_ten.yaml) |
| `F-d-4-1` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-1.yaml`](../act_tsk/act_tsk_F-d-4-1.yaml) |
| `F-d-4-1_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-1_ntc.yaml`](../act_tsk/act_tsk_F-d-4-1_ntc.yaml) |
| `F-d-4-1_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-1_ten.yaml`](../act_tsk/act_tsk_F-d-4-1_ten.yaml) |
| `F-d-4-2` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-2.yaml`](../act_tsk/act_tsk_F-d-4-2.yaml) |
| `F-d-4-2_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-2_ntc.yaml`](../act_tsk/act_tsk_F-d-4-2_ntc.yaml) |
| `F-d-4-2_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-4-2_ten.yaml`](../act_tsk/act_tsk_F-d-4-2_ten.yaml) |
| `F-d-5` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-5.yaml`](../act_tsk/act_tsk_F-d-5.yaml) |
| `F-d-5_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-5_ntc.yaml`](../act_tsk/act_tsk_F-d-5_ntc.yaml) |
| `F-d-5_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-5_ten.yaml`](../act_tsk/act_tsk_F-d-5_ten.yaml) |
| `F-d-6-1` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-1.yaml`](../act_tsk/act_tsk_F-d-6-1.yaml) |
| `F-d-6-1_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-1_ntc.yaml`](../act_tsk/act_tsk_F-d-6-1_ntc.yaml) |
| `F-d-6-2` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-2.yaml`](../act_tsk/act_tsk_F-d-6-2.yaml) |
| `F-d-6-2_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-2_ntc.yaml`](../act_tsk/act_tsk_F-d-6-2_ntc.yaml) |
| `F-d-6-3` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-3.yaml`](../act_tsk/act_tsk_F-d-6-3.yaml) |
| `F-d-6-3_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-3_ntc.yaml`](../act_tsk/act_tsk_F-d-6-3_ntc.yaml) |
| `F-d-6-4` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-4.yaml`](../act_tsk/act_tsk_F-d-6-4.yaml) |
| `F-d-6-4_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-4_ntc.yaml`](../act_tsk/act_tsk_F-d-6-4_ntc.yaml) |
| `F-d-6-4_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-4_ten.yaml`](../act_tsk/act_tsk_F-d-6-4_ten.yaml) |
| `F-d-6-5` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-5.yaml`](../act_tsk/act_tsk_F-d-6-5.yaml) |
| `F-d-6-5_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-5_ntc.yaml`](../act_tsk/act_tsk_F-d-6-5_ntc.yaml) |
| `F-d-6-5_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-d-6-5_ten.yaml`](../act_tsk/act_tsk_F-d-6-5_ten.yaml) |
| `F-e-1` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-1.yaml`](../act_tsk/act_tsk_F-e-1.yaml) |
| `F-e-1_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-1_ntc.yaml`](../act_tsk/act_tsk_F-e-1_ntc.yaml) |
| `F-e-1_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-1_ten.yaml`](../act_tsk/act_tsk_F-e-1_ten.yaml) |
| `F-e-2` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-2.yaml`](../act_tsk/act_tsk_F-e-2.yaml) |
| `F-e-2_ntc` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-2_ntc.yaml`](../act_tsk/act_tsk_F-e-2_ntc.yaml) |
| `F-e-2_ten` | E_OK | 【NGKI3527】 | [`act_tsk_F-e-2_ten.yaml`](../act_tsk/act_tsk_F-e-2_ten.yaml) |

## 4. 3.4→3.7 仕様差分メモ

- act_tsk 自体のエラー仕様（E_CTX/E_ID/E_NOEXS/E_OACV/E_QOVR）は 3.4→3.7 で本質変更なし
  （zybo FMP autocode で全緑＝期待値が現3.7挙動と一致）。
- 関連：不正クラスID→E_ID 化（cfg-error側）、サブ優先度/NGKI3682 は別API（CRE_MTX）。
  全体差分は [`../../../../DIVERGENCE_MAP.md`](../../../../DIVERGENCE_MAP.md) A表／
  [`../../../../docs/SPEC37_PLAN.md`](../../../../docs/SPEC37_PLAN.md)。

## 関連
- 元シート（参考・非md）：[`../act_tsk/act_tsk.txt`](../act_tsk/act_tsk.txt)
- テスト実体ディレクトリ：[`../act_tsk/`](../act_tsk/)
- 差分台帳：DIVERGENCE_MAP.md ／ 計画：docs/SPEC37_PLAN.md
