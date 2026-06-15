# TTSP3 ターゲット依存部 — FMP / polarfire_soc_kit_gcc (PolarFire SoC, U54/RV64GC)

PolarFire SoC（Icicle Kit / Discovery Kit, 4×U54, RV64GC）向け FMP3 の TTSP3 ターゲット依存部。
実機を JTAG（openocd + gdb, SoftConsole 同梱）で起動し、API テストを実行する。
2026-06-15 に Icicle / Discovery 実機で API 全60群を実行・検証済み。

## ファイル

| ファイル | 役割 |
|---|---|
| `ttsp_target_test.c/.h` | ターゲット依存テスト処理/定義。RISC-V プリミティブ。 |
| `ttsp_target.cfg` | 追加コンフィグ（FUNC_TIME=false のため空＝IPI登録不要）。 |
| `ttsp_target.sh` | ビルド設定 + 実行 `simulation()`（実機 JTAG）。 |
| `configure.yaml` | TTG 環境設定。`all_gain_time: true`（func_time=false の必須対応）。 |

## 能力（capability）

- `FUNC_TIME=false` … CLINT mtimer を停止できない（時刻は常時進行 / all_gain_time）。
- `FUNC_INTERRUPT=false` … PLIC はソフトから割込みを発生できない。
- `FUNC_EXCEPTION=false` … 本版では CPU 例外モジュールは対象外。
- カバー: 純カーネル系 API（task/sem/flg/dtq/pdq/mtx/mpf/sys_manage 等）。
- `acquire_glock_wo_preempt` は FMP3 3.4.0 に無いため `ttsp_target_test.h` で `acquire_glock` へ別名定義。

## ビルド & 実行（API テスト）

前提: `ttsp3` の兄弟に `fmp3`（`ln -s fmp3_trunk ../fmp3` 等）。
ツールチェーン PATH: SoftConsole の `riscv-unknown-elf-gcc/bin`（`riscv64-unknown-elf-`）。

```sh
# ビルド（BOARD 指定は必須。ttsp_parallel_api.sh は env の TTSP_MAKE_OPT のみ make に渡す）
TTSP_TARGET_NAME=polarfire_soc_kit_gcc TTSP_MAKE_OPT="BOARD=MPFS_ICICLE_KIT" SKIP_RUN=1 \
  bash scripts/ttsp_parallel_api.sh ../fmp3 FMP obj_pf_api 96      # Discovery は BOARD=MPFS_DISCOVERY_KIT, DIV=64

# 実行（各 obj_pf_api/api_test/auto_code_N/ の fmp を JTAG ロード）
#   openocd（FlashPro5/6）→ gdb で reset init→load→set $pc=_start→continue
#   コンソール UART を cat してログ取得し "All check points passed." で判定
```

要点:
- **BOARD 指定必須**: 無いと既定 `MPFS_DISCOVERY_KIT`(USE_UART1) でビルドされ、Icicle 実機の UART と不一致になる。
- **DIV を大きく** + ビルドオプション `-Os` / `-DTARGET_HEAP_SIZE=8192`（`ttsp_target.sh` に設定済み）:
  生成 out.o が大きく L2-LIM(256KB) を超えるため。Icicle=DIV96、Discovery=DIV64 で約60群がビルド可。
- 出力経路: TTSP3 は `syslog`(LOG_NOTICE)。FMP の `library/FMP/test/tecsgen.cfg` は LOGTASK を作らないが、
  `syslog_initialize` 既定で全重要度が低レベル出力(target_fput_log)されるため LOGTASK 無しで出力される。

## コンソール（UART）

- **Icicle Kit**: 別チップ CP2108(`10c4:ea71`) の `ttyUSB0 = MMUART0`。`USE_UART0`。J9 ショートで JTAG 有効。
- **Discovery Kit**: FT4232 1個(FlashPro5 `1514:2008`)が JTAG(if0)+UART(if1-3) 兼用。`USE_UART1` → **`ttyUSB1 = MMUART1`**。
  Linux では ftdi_sio が UART を ttyUSB 化しないため udev 対処が必要
  （fmp3: `target/polarfire_soc_kit_gcc/setup_disco_uart_udev.sh` / `TTSP3_HOWTO.md` §4.5 参照）。

実機セットアップ・JTAG・トラブルシュートの詳細は FMP3 リポジトリの
`target/polarfire_soc_kit_gcc/TTSP3_HOWTO.md` を参照。

## 実機結果（2026-06-15, PRC_NUM=2, API 全60群）

| Kit | DIV | 結果 |
|---|---|---|
| Icicle | 96 | PASS=59 / FAIL=1 |
| Discovery | 64 | PASS=58 / FAIL=2 |

全 FAIL は `ASP_time_manage_adj_tim_*`（`FUNC_TIME=false`＝時刻常時進行に起因する既知乖離）のみで、
カーネルのバグではない（linux_gcc 同種）。FAIL 数の差は DIV による adj_tim ケースの群分布の違い。
