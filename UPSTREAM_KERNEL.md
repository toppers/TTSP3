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

> **2026-06-13 FMP3 POSIX依存部の上流追従＋退行修正（CI固定版 `223ed7e` には未反映）**：
> 上流 HRMP3 trunk r1247 の POSIX 公式修正（`arch/posix_gcc` の thread_ctrl／
> posix_kernel_impl ほか）を fmp3 作業コピーに適用（2026-06-07〜08 の暫定修正を置換え。
> EXCNO統一は上流未完成のため見送り）。公式が持ち込んだ退行
> （`terminate_thread` に追加された `pthread_cond_signal` が `ter_tsk_f_4_1_1` を
> タイミング依存で失敗させる。macOS では出ず Linux のみ＝遅延キャンセルの差）を
> **根本原因まで特定し，`suspend_thread` に `pthread_testcancel()` を1行追加して修正**
> （公式の signal は保持）。
> 検証：**zybo_z7_gcc `ci_run_fmp.sh` PASS=182/0**，**linux_gcc API 13/20**
> （ベースライン回復・安定）。再現＋修正案＝`../posix/posix_hrmp3_r1246/`。
> **上流確認**：HRMP3 trunk は **r1249** で同修正（`suspend_thread` に `pthread_testcancel()`）を
> 適用済みで，本 FMP3 修正は r1249 と関数本体一致＝FMP3 は r1249 追従済み（HRMP3 側追加対応不要）。
> 詳細は DIVERGENCE_MAP.md E節・fmp3 `target/linux_gcc/issues/`・`../posix/posix_hrmp3_r1246/`。
>
> **2026-06-14 上流 r1252 までの追従（CI固定版 `223ed7e` には未反映）**：
> 上流 HRMP3 trunk が r1247→**r1252** に進み，POSIX 依存部の追加修正を fmp3 作業コピーに適用。
> (1) r1252 デッドロック修正＝`posix_timer_itimer.c` の `sigalrm_handler` で `timer_mutex`
> ロック前に全シグナルをマスク（`pthread_sigmask_blockall`）し解放後に復元，
> (2) r1252 API整理＝`terminate_thread`／`preempt_thread` の未使用第1引数 `TPCB *` を削除
> （`activate_context` マクロ・`interrupt_sim.c` の呼び出しも更新），
> (3) r1248 の `pthread_testcancel` は 6/13 に先行導入済みで一致，r1249/r1250 は機能差なし。
> EXCNO 統一（r1234）は引き続き見送り。
> 検証：**linux_gcc `check_library/interrupt` PASS・API 13/20 を 5 周連続で同一に再現**
> （フレーク/ハングなし・`ter_tsk` 系緑）。詳細は DIVERGENCE_MAP.md E節「2026-06-14」。
>
> **2026-06-15 上流 r1254 までの追従（CI固定版 `223ed7e` には未反映）**：
> r1252→**r1254**。(1) r1253 デッドロック修正＝`thread_ctrl.c` の `start_dispatch_thread` で
> `thrcb_mutex` ロック前に全シグナルをマスクし解放後に復元、(2) r1254 はコメント・著作権年のみ
> （機能差なし）。検証：`check_library/interrupt` PASS・API 13/20 を 5 周連続で同一再現（回帰なし）。
> 詳細は DIVERGENCE_MAP.md E節「2026-06-15」。

## 検証済み環境（2026-06-06 緑確認・タグ v3.2.0-rc1）

- ASP3 3.7.2（上記ZIP） + `zybo_z7_gcc` + QEMU 11.0.0（**要 a9gtimer パッチ** `docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）
- arm-none-eabi-gcc 13.2 / ruby 3.2

> 更新時：版を改訂 → `DIVERGENCE_MAP.md` A表で差分を洗う → 緑に戻す。

## M-profile 系カーネル（第2ワークスペース管理・`~/TOPPERS/ttsp3`）

以下のカーネルは本ワークスペース（`~/TOPPERS/TTSP3/work/`）の兄弟 SVN とは**別管理**で、
第2ワークスペース（`~/TOPPERS/ttsp3`）の兄弟ディレクトリ `~/TOPPERS/ASP3_TZ/asp3_tz_work/` に置かれる。

| カーネル | パス | 系列 | 改変状態 | 使用ターゲット |
|---|---|---|---|---|
| ASP3 3.7 系 | `ASP3_TZ/asp3_tz_work/asp3_3.7/` | ASP3 3.7 | **無改変**（mps2 per-case 測定はカーネル無改変で実施） | mps2_an505_gcc（ASP / QEMU）、ek_ra8m2_gcc（ASP / 実機・SIL） |
| HRP3 3.4.2 系 + overlay `cw_hrp3_ra8m2` | `ASP3_TZ/asp3_tz_work/hrp3_3.4.2/` | HRP3 3.4.2 | **M-profile 向け修正あり**（rundom 設定・拡張SVC rundom 退避/復元・within_ustack 実装・svc nPRIV 分岐等）。EK-RA8M2 の M2 メモリ保護有効化に対応 | mps2_an505_gcc（HRP / QEMU）、ek_ra8m2_gcc（HRP / 実機） |

> 正確なリビジョン・パッチ詳細は各台帳を参照：
> - `library/ASP/target/mps2_an505_gcc/MPS2_API_STATUS.md`（ASP mps2 per-case 全件結果）
> - `library/HRP/target/mps2_an505_gcc/MPS2_API_STATUS.md`（HRP mps2 per-case 結果）
> - `docs/HRP/EK_RA8M2_TTSP3_STATUS.md`（EK-RA8M2 実機 SIL/API 結果・hrp3_3.4.2 改変内容詳細）
>
> これらのカーネルは本リポジトリにコミットしない（禁則①）。版の詳細は各台帳参照。

## FMP3 改変パッチ（カバレッジ計測専用・通常ビルド非適用）

通常ビルド・CI（`ci_run_fmp.sh`）は **無改変の `exshonda/fmp3@223ed7e`** で緑（PASS=182/0）。
以下はカバレッジ計測 Method B 用の任意パッチで、`coverage_gcov_fmp.sh all` の WB ビルド時のみ効く
（既定挙動不変）。fmp3 を編集する場合はライセンス条件（改変明記）を満たすこと。

| パッチ | 目的 | 既定挙動への影響 |
|---|---|---|
| `docs/patches/fmp3-tepp-prc-overridable.patch` | `target/zybo_z7_gcc/target_kernel.h` の `TOPPERS_TEPP_PRC` を `#ifndef` ガード化し COPTS 上書き可に。WB `tepp1_W-a`（`-DTOPPERS_TEPP_PRC=0x1`）で time_event.c §5-c 非TM-processor 転送（L168/L583/L627）を到達 | なし（未定義時 0x3 のまま）。`DIVERGENCE_MAP.md`／`docs/FMP/COVERAGE_RAISE_PLAN.md` |
