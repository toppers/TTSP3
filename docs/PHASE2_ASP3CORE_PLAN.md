# PHASE2_ASP3CORE_PLAN.md — asp3_core（CMake版ASP3）対応 立ち上げ詳細プラン

> Phase 1（標準ASP3 3.7.2 + zybo_z7_gcc を緑化・CI matrix・3.4→3.7差分・カバレッジ）が
> 実質完成したことを受け、次段階＝**CMake版 asp3_core への展開**の立ち上げ計画。
> 2026-06-10 策定。上位方針は [`../START.md`](../START.md) Phase 2、[`AGENTS.md`](../AGENTS.md) §6/§9。
> スコープ：asp3_core は **CMake版ASP3派生＝ASP系**のため、ASP3/FMP3 優先方針の範囲内。

---

## 0. ゴールと「信頼の基準点（trust anchor）」

- **最終ゴール**：標準ASP3で確立した TTSP3 の自己検証ループ（QEMU＋`execute.log` 判定）を、
  CMake版 asp3_core ＋ 新ターゲット **mps2_an521_gcc（Cortex-M33・QEMU）** の上で再現し、緑にする。
- **進め方の原則**（START.md と同じ）：**小さい緑を積み上げる**。各ステップを QEMU で閉じる
  自己検証ループとして確立してから次へ。「通るはず」で進めない（AGENTS.md §4）。

---

## 1. 前提ゲート（着手前に必須）

| ゲート | 内容 | 担当 |
|---|---|---|
| **G0. asp3_core 取得** | asp3_core リポジトリを取得し版固定。配置・URL・commit を `UPSTREAM_KERNEL.md` に記録。標準ASP3（`../asp3`）とは別ツリー（例 `../asp3_core`）に置く | 人間（URL確定） |
| **G1. v3.2.0 正式化** | Phase 1 完了点を `v3.2.0` としてタグ／GitHub Release（標準ASP3 3.7.2 zybo 緑＝引き渡し点）。Phase 2 はこの基準点から派生 | 人間（リリース判断） |
| **G2. ビルド系の事前調査** | asp3_core の CMake 構成（ターゲット記述・`libasp3.a` 生成・cfg/tecsgen の呼ばれ方）を読み、標準ASP3の `configure.rb`/Makefile 流との差分を把握 | AI |

> G0 が未充足のうちは S1 以降に着手できない（コード対象が存在しない）。本プランは G0 充足を前提に詳細化する。

---

## 2. 全体戦略：2つの「ブリッジ」

Phase 2 の技術的本質は、TTSP3（テスト側）と asp3_core（カーネル側）を繋ぐ2つの接続にある。

1. **ビルド系ブリッジ**：TTSP3 は現状 `ruby <OS_PATH>/configure.rb` でカーネルごと Makefile を生成し、
   テスト（`out.c`/`out.cfg`）とカーネルを一括ビルドする（Makefile流）。
   asp3_core は **CMake** で `libasp3.a`（カーネルライブラリ）を生成する流儀。
   → **asp3_core 側で `libasp3.a` を CMake ビルド → TTSP3 のテストをそれにリンク**する構成へ橋渡しする。
   TTSP3 既存の「Kernel Library」モード（`USE_KERNEL_LIB`＝`libkernel.a` リンク・現状未サポート）が
   雛形になるが、TTSP3 R3.1.0 では未サポートのため **asp3_core 用に再設計**する。
2. **ターゲット依存部ブリッジ**：ターゲット1個＝4ファイル（[`AGENTS.md`](../AGENTS.md) §6）。
   **`mps2_an521_gcc`（M33・QEMU）を既存 `lpc55s69evk_gcc`（M33）雛形から作成**する。

---

## 3. ステップ（各ステップ＝QEMUで閉じる小さい緑）

### S1. asp3_core 単体ブート確認（最初の関門・最重要）
- asp3_core 同梱の mps2_an521 サンプル（`sample1` 相当）を **CMake でビルド → QEMU で起動**し、
  `-M mps2-an521`（あるいは asp3_core 指定の machine）＋セミホスティングでシリアル出力を確認。
- 目的：**TTSP3 を絡める前に、asp3_core×CMake×QEMU の経路が成立することを単体で証明**する。
- 成果：QEMU 起動コマンド・必要パッチ（あれば）・タイマ（M33 は SysTick 系＝a9gtimer とは別）の確定。
  zybo の `a9gtimer` パッチ（[`patches/`](patches/)）に相当する mps2 側の手当ての要否をここで判定。

### S2. ターゲット依存部 `library/ASP/target/mps2_an521_gcc/` 新設
- `lpc55s69evk_gcc`（M33）の4ファイルを雛形にコピーして mps2_an521 向けに調整：
  - `ttsp_target_test.h`：スタックサイズ・不正アドレス・割込み優先度/番号・例外番号・SIL遅延・stkアクセサ
  - `ttsp_target_test.c`：7関数（`ttsp_target_stop_tick`/`start_tick`/`gain_tick`、`ttsp_int_raise`/
    `ttsp_clear_int_req`、`ttsp_cpuexc_raise`/`ttsp_cpuexc_hook`）を mps2_an521 の割込み/例外/タイマに合わせて実装
  - `ttsp_target.sh`：`USE_QEMU=true`、QEMU machine、`FUNC_TIME/INTERRUPT/EXCEPTION`、ビルド連携
  - `ttsp_target.cfg`：テスト用ターゲットcfg
- ライセンスヘッダ・改変明記を保持（禁則③）。

### S3. ビルド系ブリッジ（CMake libasp3.a ↔ TTSP3 テスト）
- asp3_core の CMake で `libasp3.a` を生成する手順を TTSP3 のビルドフローに組み込む。
- cfg ツール（`cfg.rb`）・tecsgen が asp3_core のレイアウト（インクルードパス・`*.def`・kernel_cfg 生成）で
  正しく動くことを確認。標準ASP3と差があれば TTSP3 側のビルド構成（最小オーバーレイ／専用 OBJ_DIR）で吸収。
- 判定：1テスト（`specified_tesry` 相当）が **TTG生成 → cfg/tecsgen → libasp3.a リンク → 実行モジュール生成**
  まで通ること。

### S4. ターゲット依存チェックを mps2_an521 QEMU で緑（自己検証ループ確立）
- `ttb.sh` の `c`（Check the Functions for Target Dependent）＝ exception/interrupt/timer を QEMU 実行し緑化。
- これで **mps2_an521 上の自己検証ループ（execute.log 判定）が確立**＝以降の API 差分潰しを AI に任せられる状態。

### S5. API オートコードを mps2_an521 QEMU で緑
- zybo で緑の API 資産がそのまま動くか実行 → ターゲット特性差（スタック指定可否・割込み番号等）を潰す。
- 期待値がターゲット依存で割れる箇所は `DIVERGENCE_MAP.md`／本プランに記録（zyboでの既知差分と同じ運用）。

### S6. CI 追加
- `scripts/ci_run_*.sh` 相当の mps2_an521 ランナーを作成し、`.github/workflows/ci.yml` の matrix に追加
  （ASP/FMP zybo に並べて mps2_an521）。asp3_core は commit 固定で取得。

---

## 4. 横展開（S5 緑後）

mps2_an521 で緑＝CMakeブリッジが確立したら、同じ枠組みで他ターゲットへ：
- **pico（M33／RISC-V）**、**stm32mp257（A35）**、**host（linux_gcc）**。
- 各々ターゲット依存4ファイル追加＋QEMU/実機の実行手段確定。host は POSIX シミュ（FMP POSIX の実績を流用）。

---

## 5. リスク・未確定事項

- **(R1) CMake生成物と cfg.rb/tecsgen の整合**：インクルードパス・シンボル定義（`*_sym.def`）・
  kernel_cfg の生成順が標準ASP3と異なる可能性。S3 の最大の関門。
- **(R2) QEMU mps2-an521 のタイマ／セミホスティング**：M33 は SysTick 系。zybo の `a9gtimer` パッチ
  （高分解能タイマのQEMU不備）に相当する手当てが mps2 側で要るか S1 で判定。
- **(R3) asp3_core のディレクトリ規約**：`configure.rb` の有無、ターゲット記述の置き場が標準ASP3と違う。
  G2 で把握し、S3 の橋渡し設計に反映。
- **(R4) ライセンス**：asp3_core 由来物の再配布形態は TTSP3 とは別管理。改変明記・TOPPERS報告は人間が握る。

---

## 6. マイルストーンと判定基準

| MS | 内容 | 緑の判定 |
|---|---|---|
| MS1 | S1：asp3_core×mps2_an521 単体ブート | QEMU シリアルにサンプル出力 |
| MS2 | S3：1テストが asp3_core でビルド・実行 | 実行モジュール生成＋`execute.log` にチェックポイント |
| MS3 | S4：ターゲット依存チェック緑 | exception/interrupt/timer 全 `All check points passed.` |
| MS4 | S5：API オートコード緑 | zybo 同等の合格率（差分は文書化） |
| MS5 | S6：CI に mps2_an521 追加 | CI matrix で緑 |

> **次の一手（G0 充足後の着手点）**：S1（asp3_core 単体で mps2_an521 を QEMU ブート）。
> ここを超えれば自己検証ループの素地ができ、S2 以降は AI 主体で進められる。
