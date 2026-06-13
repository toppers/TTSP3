# AGENTS.md

> **TTSP3（TOPPERS Test Suite Package 3）** リポジトリにおける、全AIコーディングツール共通の正本。
> ツール固有ファイル（`CLAUDE.md` / `.clinerules` / `.cursorrules`）は本ファイルを参照すること。
> 本ファイルが規約・手順の**唯一の正本（single source of truth）**である。

> **🚀 開発をこれから始める場合は、まず `START.md` と `docs/WORKSPACE.md` を読むこと。**
> 特にカーネル（asp3/fmp3/hrp3/hrmp3）の配置（兄弟ディレクトリ）を理解してから着手する。

---

## 1. プロジェクト概要

TTSP3は、TOPPERS第3世代カーネル（ASP3 / FMP3 / HRP3 / HRMP3）の **API適合性・SIL適合性を網羅検証するテストスイート**。
テストプログラム生成ツール **TTG（TOPPERS Test Generator）**、テストデータ（TESRY）、ターゲット依存部から成る。

| 項目 | 内容 |
|---|---|
| ベース | TTSP3 Release 3.1.0（2020-03-23、統合仕様書 **3.4.0** 準拠） |
| 管理 | **GitHub（git）のみ**。従来のSVNから移行し、以後SVNは使わない（`docs/MIGRATION.md`） |
| 当面の目標 | git管理下で、標準ASP3 **3.7.2** + `zybo_z7_gcc` でテストを緑にする |
| 次段階 | asp3_core（CMake版）対応：ターゲット依存部 mps2_an521 / pico(M33) / host 追加 |
| 被テストカーネル | **ASP3 / FMP3 / HRP3 / HRMP3（いずれもSVN・別管理）**。本リポジトリには含めず兄弟ディレクトリに置く（§3） |
| ライセンス | TTSP3ライセンス（NCES名大／FUJI SOFT 他）。改変時は改変明記が条件 |

---

## 2. ⚠️ 禁則事項（作業前に必読）

### 禁則①：カーネルソース（asp3/fmp3/hrp3/hrmp3）を本リポジトリにコミットしないこと
asp3/fmp3/hrp3/hrmp3 は**別リポジトリ（SVN）で管理**され、本gitリポジトリの**兄弟ディレクトリ**に置かれる（§3）。
本リポジトリに取り込まない。`.gitignore` で誤コミットを防止済み。

### 禁則②：カーネルソースを本リポジトリ側から編集しないこと
テストのためにカーネルを書き換えない。テストが落ちたら、まずテスト側／ターゲット依存部／仕様差分を疑う。
カーネル本体の不具合と判断した場合は作業を止めて報告。

### 禁則③：TTSP3ライセンス表記を壊さないこと
各ソースの著作権・利用条件ヘッダを保持する。改変したファイルには**改変した旨**を記載（ライセンス条件(2)）。
GitHub公開＝ソース再配布なので条件(1)(2)(3)を満たすこと。

---

## 3. ディレクトリ配置（最重要）

**ワークスペースは「ttsp3 git ＋ 兄弟SVNカーネル」の並び**：

```
<workspace>/
├── ttsp3/      ← 本git リポジトリ（TTSP3本体＋本scaffold）。git-only
├── asp3/       ← SVNチェックアウト（標準ASP3 Release 3.7.2）
├── fmp3/       ← SVNチェックアウト（標準FMP3）
├── hrp3/       ← SVNチェックアウト（標準HRP3）
└── hrmp3/      ← SVNチェックアウト（標準HRMP3）
```

TTSP3の `configure.sh` は既定で **`OS_PATH="../asp3/"`**（FMP3=`../fmp3/`、HRP3=`../hrp3/`、HRMP3=`../hrmp3/`）を参照する。
**この相対参照に合わせて4カーネルを ttsp3 と同じ階層に置く**こと（試すプロファイルのみでよい）。パス変更は不要。

詳細・SVNチェックアウト手順・版固定は `docs/WORKSPACE.md` を参照。

---

## 4. ビルド & 実行

TTSP3はMakefileベース。`configure.sh` で対象を設定し、`ttb.sh` のメニューから実行する。

```bash
# 1) 対象設定（configure.sh を編集）
#    OS_PATH="../asp3/"        ← カーネル（兄弟ディレクトリ）
#    PROFILE_NAME="ASP"        ← ASP / FMP / HRP / HRMP
#    TARGET_NAME="zybo_z7_gcc" ← ターゲット依存部

# 2) メニュー実行
./ttb.sh
#   1: API Tests
#   2: SIL Tests        ※TTSP3では未サポート（user.txt (3.2)。sil_test/ は空）
#   c: Check the Functions for Target Dependent（例外/割込み/タイマ）
#   k: Kernel Library   ※TTSP3では未サポート（user.txt (10)）
```

### zybo_z7_gcc は QEMU 実行に対応
`library/ASP/target/zybo_z7_gcc/ttsp_target.sh` に **`USE_QEMU=true`** があり、
QEMU（`xilinx-zynq-a9`）でハードなし実行できる。結果は `execute.log` に出る。CIはこれを使う。

### 検証の鉄則
- テスト実行は次の順：**ターゲット依存チェック → API**
  （SILテスト・Kernel LibraryはTTSP3未サポートのため対象外。第1/2世代TTSPの機能でTTSP3 R3.1.0には含まれない）
- 「通るはず」で報告しない。`execute.log` の合否（`OK`／チェックポイント）を根拠にする

---

## 5. 仕様バージョン差分（3.4.0 → 3.7.2）

TTSP3 R3.1.0 は統合仕様書 **3.4.0** 準拠、被テストの標準ASP3は **3.7.2**。
この差分が当面の主作業。影響点と進捗は **`DIVERGENCE_MAP.md`** で管理する。

代表的な差分（ASP3変更履歴より）：
- 64bit高分解能タイマ（HRTCNT型変更）→ 時刻/タイマテスト
- `CRE_XXX` のオブジェクトID衝突をエラー化 → 静的APIテスト（TESRY）
- 静的API末尾 `;` 必須化 → 生成cfg / TESRY
- サブ優先度の仕様変更、モノトニックタイマ追加 → 該当APIテスト / TTG
- macOS/Linux POSIXシミュ追加（後段 host ターゲットで活用）

> 着手前に、**R3.1.0 より新しい公式TTSP3（3.7対応済み）が無いか確認**すること（重複作業回避）。

---

## 6. ターゲット依存部の構造

ターゲット1個＝`library/<PROFILE>/target/<target>_gcc/` の **4ファイル**：

| ファイル | 内容 |
|---|---|
| `ttsp_target_test.c` | 7関数：`ttsp_target_stop_tick`/`start_tick`/`gain_tick`、`ttsp_int_raise`/`ttsp_clear_int_req`、`ttsp_cpuexc_raise`/`ttsp_cpuexc_hook` |
| `ttsp_target_test.h` | スタックサイズ・不正アドレス・割込み優先度/番号・例外番号・SIL遅延・stkアクセサ |
| `ttsp_target.sh` | `USE_QEMU`、`FUNC_TIME/INTERRUPT/EXCEPTION`、`KERNEL_COBJS_TARGET` 等 |
| `ttsp_target.cfg` | テスト用ターゲットcfg |

現状の参照：`zybo_z7_gcc`（A9）、`lpc55s69evk_gcc`（**Cortex-M33**）、`nucleo_f401re_gcc`（M4）。
後段の asp3_core M33ターゲットは **`lpc55s69evk_gcc` を雛形**にする。

---

## 7. Git 運用（TTSP3はGitHubのみで管理）

TTSP3は従来**SVN管理**だったが、**今後はGitHub（git）でのみ管理する**。SVNへは戻さない。
被テストカーネル asp3/fmp3/hrp3/hrmp3 はSVNのまま（兄弟ディレクトリ・§3）で、**TTSP3本体とは管理系が異なる**点に注意。

```
main      ← 唯一の基準。常にビルド可能・テスト緑を維持
feat/*    ← 機能ブランチ（仕様差分対応・新ターゲット等）
```

- SVN→gitの移行は**一度だけ**（R3.1.0＋開発途中分を初期コミット）。手順は `docs/MIGRATION.md`
- TTSP3には外部追従先（external upstream）が無いため、**`upstream` 追従ブランチは持たない**。gitの履歴が記録の正本
- リリースはタグ / GitHub Releases（例：3.7対応版を `v3.2.0`）
- SVNの `$Id$` 等のキーワードは git では自動更新されない（移行時に凍結扱い・`docs/MIGRATION.md`）
- コミット規約：`<type>(<scope>): <summary>`（type: feat/fix/docs/test/chore、scope: ttg/tesry/target/sil/api/ci）
- 例：`fix(tesry): adapt CRE_TSK collision check for spec 3.7`

---

## 8. 参照ファイル索引

> **AIはまず `docs/STATUS.md`（現状の緑基準・既知残）と `docs/TARGETS.md`（ターゲット能力・非対応）を読む。**
> 合否判定はそこを参照（再計測しない）。実行は `scripts/ci_run*.sh`／`ttsp_parallel_api.sh` 経由
> （対話 `ttb.sh` のメニュー駆動は自動化に不向き）。

| やりたいこと | 読むファイル |
|---|---|
| **現状の合否基準・既知残（再計測の前にここ）** | **`docs/STATUS.md`** |
| **ターゲット能力・非対応・実行コマンド** | **`docs/TARGETS.md`** |
| ワークスペース配置・SVN手順 | `docs/WORKSPACE.md` |
| SVN→git 移行（一度だけ） | `docs/MIGRATION.md` |
| 開発の始め方・人間/AI分担 | `START.md` |
| 仕様差分(3.4→3.7)・改変台帳 | `DIVERGENCE_MAP.md` |
| ビルド・実行 | 本ファイル §4／`user.txt`（TTSP3公式マニュアル） |
| ターゲット依存部の追加 | 本ファイル §6／既存 `library/*/target/*` |
| CI | `.github/workflows/ci.yml` |

---

## 9. 参照

- TTSP3公式：https://www.toppers.jp/ttsp.html
- 統合仕様書 3.7.0：https://www.toppers.jp/docs/tech/tgki_spec-370/tgki_spec-370.html
- 後段の対象：asp3_core（CMake版ASP3派生・別リポジトリ）
