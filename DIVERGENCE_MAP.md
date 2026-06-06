# DIVERGENCE_MAP.md — 差分台帳

> 2つの差分を管理する。
> A) **仕様差分**：TTSP3 R3.1.0（仕様3.4.0）↔ 被テスト標準ASP3（3.7.2）
> B) **改変台帳**：TTSP3 R3.1.0 upstream からの本リポジトリの変更

---

## A. 仕様差分 3.4.0 → 3.7.2（当面の主作業）

ASP3変更履歴から、TTSP3のテスト/TTG/TESRYに影響しうる項目。状態欄を埋めながら潰す。

| 仕様変更 | 由来 | 影響範囲 | 状態 |
|---|---|---|---|
| 高分解能タイマ64bit化（HRTCNT型変更） | 3.4→3.5 | 時刻/タイマテスト・ターゲット依存タイマ | **影響なし確認**（2026-06-06。timerチェック＋時刻系APIテスト緑。要QEMUパッチ＝C表） |
| 静的API末尾 `;` 必須化 | 3.4→3.5 | 生成cfg・TESRY | **影響なし確認**（2026-06-06。TTG 3.2.0の生成cfgで全1788ファイルのビルド成功） |
| モノトニックタイマ拡張パッケージ追加 | 3.4→3.5 | time_manage テスト（任意） | 対象外（R3.1.0スイートにテストなし・任意パッケージ） |
| サブ優先度の仕様変更 | 3.6→3.7 | task優先度系API・TTG（サブ優先度） | **影響なし確認**（2026-06-06。既存スイートの範囲。サブ優先度固有の新規テストは将来課題） |
| 優先度継承拡張パッケージ追加 | 3.6→3.7 | mutex 系（任意） | 対象外（任意パッケージ・既存mutex系テストは緑） |
| `CRE_XXX` のID衝突をエラー化 | 3.6→3.7 | 静的APIテスト（CRE_*のTESRY期待値） | **影響なし確認**（2026-06-06。コンフィグエラーテスト113/113 OK。TTG生成cfgはID一意で衝突せず） |
| objdumpダンプ形式対応 | 3.6→3.7 | cfg/ビルド（影響小） | **影響なし確認**（2026-06-06。全ビルド成功） |
| macOS/Linux POSIXシミュ追加 | 3.6→3.7 | 後段 host ターゲットで活用 | 後段 |

> **2026-06-06 全面実測**：ASP3 3.7.2 + zybo_z7_gcc + QEMU（要a9gtimerパッチ＝C表）で
> オートコード2202/2202・スクラッチ5/5・コンフィグエラー113/113 すべて緑。
> ただしツール側で ruby 3.x 対応が必要だった（B表のTTG改変）。
| ARMコア依存部見直し：`arm.c` 廃止（`arm.h`に統合） | 3.6→3.7 | `library/ASP/target/zybo_z7_gcc/ttsp_target.sh` の `KERNEL_COBJS_TARGET`（`objs/arm.o` 参照でリンク前に make が停止） | **対応済**（arm.o削除・改変明記。check_library 3モジュールのビルド成功を確認） |

> 3.5→3.6 の項目は `asp3/doc/version.txt` を確認して追記すること。
> 着手前に、3.7対応済みの公式TTSP3が無いか確認（重複作業回避）。

---

## B. 変更履歴（git移行以降）

TTSP3は**git-only管理**で、外部追従先（external upstream）は無い。
したがって本節は「upstream差分台帳」ではなく、**SVN由来のR3.1.0を起点とした変更の記録**（CHANGELOG的）。
詳細な履歴は git log / GitHub Releases が正本。ライセンス条件(2)「改変明記」の根拠も兼ねる。

| 起点/対象 | 変更種別 | 理由 | 状態 |
|---|---|---|---|
| TTSP3 R3.1.0（SVN由来） | 取り込み | git初期コミット（provenance。`docs/MIGRATION.md`） | 移行時 |
| （scaffold追加） | NEW | AGENTS/START/CI 等のgit管理基盤 | 済 |
| `library/ASP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | ASP3 3.7.0で廃止された `arm.c` 由来の `objs/arm.o` を `KERNEL_COBJS_TARGET` から削除 | 済（2026-06-06） |
| `tools/ttg/common/bin/CommonModule.rb` | 改変 | ruby 3.x対応：curses不在時に端末幅80へフォールバック／`Fixnum`→`Integer`（2箇所） | 済（2026-06-06） |
| `tools/ttg/common/bin/Config.rb` | 改変 | ruby 3.x対応：ruby 3.2で削除された `Object#=~` 対策にString判定ガード追加（3箇所） | 済（2026-06-06） |
| `scripts/ci_run.sh` | NEW（scaffold置換） | 非対話CIランナー実装：ttb.shを標準入力駆動でビルド→QEMU実行→合否判定（smoke/full） | 済（2026-06-06） |
| `.github/workflows/ci.yml` | 改変（scaffold具体化） | ASP3をZIP配布物で版固定取得、QEMU 11+a9gtimerパッチをソースビルド＆キャッシュ、ci_run.sh実行 | 済（2026-06-06） |
| `scripts/coverage_run.sh` `scripts/ttsp_coverage.py` `docs/COVERAGE.md` | NEW | カーネル非依存部の行カバレッジ計測（QEMU drcovプラグイン方式・ターゲット無計装）。初回計測 97.5% | 済（2026-06-06） |
| `library/FMP/test/ttsp_test_lib.c` | 改変 | FMP3 3.4.0対応：`make_non_runnable` のシグネチャ変更（3引数→2引数）に追従 | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | FMP3 3.4.0対応：`objs/arm.o` 削除（arm.c廃止）／`-S serial_cfg.o` 追加（serial設定データの分離先） | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target_test.h` | 改変 | FMP3 3.4.0対応：`TTSP_IPI_INTNO` を 0x1e（PPI）→ 0x04（SGI 4）に変更。`gicd_raise_sgi` はSGIのみ発行可能でPPI指定はSGI 14誤発火になるため（カーネルはSGI 0〜3使用） | 済（2026-06-06） |
| `tools/ttg/common/bin/process_unit/Execption.rb` | 改変 | FMP3 3.4.0対応：FMPでは `DEF_EXC` を例外発生PE専用クラス（`CLS_PRC<n>`）へ生成（コンフィギュレータが割付け可能プロセッサ＝例外発生PEを要求。マイグレーション可能クラス配置はE_RSATR）。固定クラス配置は旧FMP3でも正当＝後方互換 | 済（2026-06-06） |
| `api_test/FMP/staticAPI/DEF_ICS/DEF_ICS_F-{d-1-1,d-1-2,d-2,e,f-1-1,f-1-2,f-2}/out.cfg` | 改変 | FMP3 3.4.0対応：手書きcfg内の `DEF_EXC` を固定クラス `CLS_PRC1/CLS_PRC2` ブロックへ移動（上記TTG対応と同根） | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target.sh`（MAKE_OPT） | 改変 | `MAKE_OPT` を環境変数 `TTSP_MAKE_OPT` で上書き可能に（`ENABLE_GCOV=true` 投入用） | 済（2026-06-06） |
| `scripts/coverage_gcov_fmp.sh` `scripts/ttsp_gcov_report.py` | NEW | FMP GCOVカバレッジ計測（行＋分岐C1）。fmp3側のGCOV対応（メンテナ管理・`docs/COVERAGE.md` 参照）が前提 | 済（2026-06-06） |
| `scripts/ttsp_parallel_api.sh` | NEW | APIオートコードのグループ並列ドライバ（TTG＋make -j＋QEMUを並列化。ビルド約160分→約2分@32コア）。初回計測: FMP kernel/ 行96.4%・分岐81.5% | 済（2026-06-06） |
| api_test/* TESRY | 改変 | 3.4→3.7仕様差分対応 | 予定 |
| tools/ttg | 改変 | 3.7仕様への生成対応 | 予定 |
| library/*/target/* | NEW/改変 | asp3_core向けターゲット依存部追加（後段） | 後段 |

---

## C. 実行環境（QEMU）起因の課題

仕様差分でもTTSP3改変でもない、QEMUデバイスモデルと実機の挙動差。

| 課題 | 内容 | 対応 | 状態 |
|---|---|---|---|
| a9gtimer がENABLEビット無視でカウンタ前進 | QEMU 11.0.0 `hw/timer/a9gtimer.c` の `a9_gtimer_get_update()` がタイマ無効時もカウンタ読出し値を仮想時刻から計算するため、`ttsp_target_stop_tick()`（GTC停止）・`ttsp_target_gain_tick()`（COUNT書込み）が効かず timer チェックが失敗 | QEMU側にパッチ（`docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）。無効時は保持値 `s->counter` を返す＝実機準拠 | **対応済**（2026-06-06、timer チェック全パス確認） |

> パッチ適用手順：`cd ~/qemu/qemu-11.0.0 && patch -p1 < <ttsp3>/docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch && cd build && ninja qemu-system-arm`
> CIでQEMUを取得する場合も同パッチの適用が必要。

---

## D. FMP3対応の未解決課題

| 課題 | 内容 | 状態 |
|---|---|---|
| `sta_alm_d` 系テストのレース失敗 | `ASP_alarm_sta_alm_d_*`（QEMU -smp 2）で、pre-setupの `msta_alm(1000)→stp_alm` 直後に `sta_alm(3)` を発行すると、`ref_alm` が `almstat=TALM_STP`/`lefttim=0` を返し失敗（20グループ中3グループの先頭で再現）。**`stp_alm` 直後に `sil_dly_nse(TTSP_SIL_DLY_NSE_TIME)` 1回を挟むだけで5/5回安定パス**（`sta_alm` 側は無改変）。pre-setupが残す処理中HRTイベント/割込みと直後の `sta_alm` の競合が原因とみられ、**FMP3 3.4.0カーネルの `stp_alm`/`sta_alm` 間のレースの可能性**（実機でも窓は存在しうる）。再現: `api_test/ASP/alarm/sta_alm/sta_alm_d-2.yaml` 単体をFMP/QEMU(-smp 2)で実行 | **未解決**（カーネルメンテナ判断待ち。2026-06-06） |

---

## 更新手順

1. **カーネル**更新時は `UPSTREAM_KERNEL.md` の版を更新し、A表で影響を洗う（カーネルはSVN・別管理）
2. **TTSP3本体**はgit-onlyのため外部マージは無い。変更はPR→`main`、節目で **GitHub Releases/タグ**
3. 改変ファイルには改変した旨を明記（ライセンス条件(2)）
