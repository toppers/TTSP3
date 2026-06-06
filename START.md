# START.md — 開発の始め方と人間/AIの分担

> TTSP3 を git管理下に置き、**標準ASP3 3.7.2 + zybo_z7_gcc で緑にする**までの手順。
> その状態を信頼の基準点（trust anchor）にしてから、asp3_core 対応へ進む。

---

## 基本原則

AIには「自己検証ループ」と「参照パターン」が要る。
- **自己検証ループ**：zybo_z7_gcc を **QEMU（`xilinx-zynq-a9`）** で実行し、`execute.log` の合否で判定できる状態
- **参照パターン**：標準ASP3×zybo×公式構成で1度緑にした実績

判断軸：**QEMUで検証が閉じる作業はAIに任せられる。仕様差分の判断・実機・ライセンス対応は人間。**

---

## Phase 0：基準づくり（人間）

### ① git リポジトリ確立（SVN→git 移行・一度だけ）
- TTSP3は**今後GitHubのみで管理**する。現行SVNのTTSP3（R3.1.0＋開発途中分）を**一度だけ**gitへ移行し、初期コミットとする（手順は `docs/MIGRATION.md`）
- 以後SVNは使わない。**外部追従先が無いため `upstream` ブランチは作らない**（gitの履歴が正本）
- `main` を基準ブランチとし、本scaffold（AGENTS.md / START.md / docs/ / DIVERGENCE_MAP.md / .gitignore / CI）を配置
- 移行直後を `v3.1.0` 相当としてタグ付け（provenance記録）

### ② 兄弟ディレクトリにカーネル取得（SVN）
- `docs/WORKSPACE.md` に従い、`../asp3`（3.7.2）を SVN チェックアウト
- `UPSTREAM_KERNEL.md` にURL・リビジョン・バージョンを記録

### ③ 公式に新しいTTSP3が無いか確認
- R3.1.0 より後の、3.7対応済み公式TTSP3 が出ていないか確認（あれば差分取り込みで大幅短縮）

### ④ 最初の緑（QEMUで自己検証ループを作る）【最重要】
- `configure.sh`：`OS_PATH="../asp3/"` / `PROFILE_NAME="ASP"` / `TARGET_NAME="zybo_z7_gcc"`
- `zybo_z7_gcc/ttsp_target.sh`：`USE_QEMU=true`
- `./ttb.sh` で **ターゲット依存チェック → SIL → API** を実行
- 3.4→3.7差分で破綻する箇所を捕捉（`execute.log`・ビルドエラー）し、`DIVERGENCE_MAP.md` に列挙

ここまでを `v0.1.0`（標準ASP3 3.7.2 で緑）としてタグ付け＝**引き渡し点**。

---

## Phase 1：仕様差分を閉じ、CI化（AI主体・人間レビュー）

QEMUで回る自己検証ループができたので任せられる：

| タスク | 検証 | 人間の関与 |
|---|---|---|
| 3.4→3.7差分のテスト/TESRY/TTG修正 | QEMUで緑 | 仕様解釈をレビュー |
| ビルドエラー三分し・機械的修正 | ビルド成功 | 不要 |
| GitHub Actions（QEMU-zynq）CI構築 | CI実行 | 不要 |
| カバレッジ計測（非依存部100%目標） | カバレッジ出力 | 不要 |

差分対応の進め方：**SIL（安定）→ API（差分大）** の順。CRE系のID衝突エラー化・`;`必須化・64bit HRT・サブ優先度を順に潰す。

---

## Phase 2：asp3_core 対応（後段）

標準ASP3で緑になった後、CMake版 asp3_core へ広げる：
- ターゲット依存部 `mps2_an521_gcc`（M33・QEMU）を **`lpc55s69evk_gcc` 雛形**で追加
- TTSP3のMakefile流を asp3_core の CMake/`libasp3.a` にブリッジ
- pico(M33/RISC-V)・stm32mp257(A35)・host(linux_gcc) へ横展開

詳細は別途 asp3_core 側の計画に従う。

---

## 人間が握り続ける領域

- 3.4→3.7 の**仕様差分の判断**（テストの期待値が変わる箇所）
- zybo **実機**ブート（QEMUで足りない場合）
- TTSP3**ライセンス順守**と、改変版の**再配布形態のTOPPERS報告**
- TTG（テスト生成器）の方針変更
