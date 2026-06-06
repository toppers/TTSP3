# UPSTREAM_KERNEL.md — 被テストカーネルの版固定

> カーネル（asp3/fmp3/hrp3/hrmp3）は本リポジトリ外（兄弟ディレクトリ・別管理）。
> 「どの版でテストを緑にしたか」をここで固定・記録する。CIも同じ版を取得する。

## 取得方法

ASP3 は TOPPERS 公式の**簡易パッケージ（ZIP配布物）**で版を固定する（SVNチェックアウト不要）。
CI（`.github/workflows/ci.yml`）も同じURLから取得する。

| カーネル | 対応バージョン | 取得URL（版固定） | 配布物 |
|---|---|---|---|
| ASP3 | Release 3.7.2 | https://www.toppers.jp/download.cgi/asp3_zybo_z7_gcc-20260520.zip | asp3_zybo_z7_gcc-20260520.zip（ZYBO-Z7簡易パッケージ） |
| FMP3 | （記入） | （記入） | |
| HRP3 | （記入） | （記入） | |
| HRMP3 | （記入） | （記入） | |

TTSP3本体ベース：Release 3.1.0（統合仕様書 3.4.0 準拠）

## 検証済み環境（2026-06-06 緑確認・タグ v3.2.0-rc1）

- ASP3 3.7.2（上記ZIP） + `zybo_z7_gcc` + QEMU 11.0.0（**要 a9gtimer パッチ** `docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）
- arm-none-eabi-gcc 13.2 / ruby 3.2

> 更新時：版を改訂 → `DIVERGENCE_MAP.md` A表で差分を洗う → 緑に戻す。
