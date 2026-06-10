# UPSTREAM_KERNEL.md — 被テストカーネルの版固定

> カーネル（asp3/fmp3/hrp3/hrmp3）は本リポジトリ外（兄弟ディレクトリ・別管理）。
> 「どの版でテストを緑にしたか」をここで固定・記録する。CIも同じ版を取得する。

## 取得方法

ASP3 は TOPPERS 公式の**簡易パッケージ（ZIP配布物）**で版を固定する（SVNチェックアウト不要）。
FMP3 は **git管理版（`exshonda/fmp3`）**で版を固定する（SVN trunk からインポート＋TTSP3向け修正
を含む）。CI（`.github/workflows/ci.yml`）も同じ版を取得する。

| カーネル | 対応バージョン | 取得方法（版固定） | 配布物／コミット |
|---|---|---|---|
| ASP3 | Release 3.7.2 | https://www.toppers.jp/download.cgi/asp3_zybo_z7_gcc-20260520.zip | asp3_zybo_z7_gcc-20260520.zip（ZYBO-Z7簡易パッケージ） |
| FMP3 | Release 3.4.0 | `git clone git@github.com:exshonda/fmp3`（または https）。CIは commit で固定 | `223ed7e`（Import from svn fmp3_trunk rev 479．set_dspflg空キュー修正・POSIXポート修正等を含む。調査記録は fmp3 `issues/`） |
| HRP3 | （後回し） | — | HRMP3/HRP3対応は後回し（DIVERGENCE_MAP 開発方針） |
| HRMP3 | （後回し） | — | 同上 |

TTSP3本体ベース：Release 3.1.0（統合仕様書 3.4.0 準拠）

## 検証済み環境（2026-06-06 緑確認・タグ v3.2.0-rc1）

- ASP3 3.7.2（上記ZIP） + `zybo_z7_gcc` + QEMU 11.0.0（**要 a9gtimer パッチ** `docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）
- arm-none-eabi-gcc 13.2 / ruby 3.2

> 更新時：版を改訂 → `DIVERGENCE_MAP.md` A表で差分を洗う → 緑に戻す。

## FMP3 改変パッチ（カバレッジ計測専用・通常ビルド非適用）

通常ビルド・CI（`ci_run_fmp.sh`）は **無改変の `exshonda/fmp3@223ed7e`** で緑（PASS=182/0）。
以下はカバレッジ計測 Method B 用の任意パッチで、`coverage_gcov_fmp.sh all` の WB ビルド時のみ効く
（既定挙動不変）。fmp3 を編集する場合はライセンス条件（改変明記）を満たすこと。

| パッチ | 目的 | 既定挙動への影響 |
|---|---|---|
| `docs/patches/fmp3-tepp-prc-overridable.patch` | `target/zybo_z7_gcc/target_kernel.h` の `TOPPERS_TEPP_PRC` を `#ifndef` ガード化し COPTS 上書き可に。WB `tepp1_W-a`（`-DTOPPERS_TEPP_PRC=0x1`）で time_event.c §5-c 非TM-processor 転送（L168/L583/L627）を到達 | なし（未定義時 0x3 のまま）。`DIVERGENCE_MAP.md`／`docs/FMP/COVERAGE_RAISE_PLAN.md` |
