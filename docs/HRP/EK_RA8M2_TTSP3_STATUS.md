# EK-RA8M2 (Cortex-M85 / HRP3) TTSP3 適合性テスト 状況

最終更新: 2026-06-20

対象カーネル: `/home/honda/TOPPERS/ASP3_TZ/asp3_tz_work/hrp3_3.4.2`（overlay `cw_hrp3_ra8m2`）。
実機: EK-RA8M2, J-Link OB S/N=1087282565, device R7KA8M2JF_CPU0, VCOM=/dev/ttyACM0（本機）, 115200 8N1。

## ビルド／実行コマンド

```bash
cd /home/honda/TOPPERS/ttsp3
export PATH=~/tools/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin:$PATH
export TTSP_TARGET_NAME=ek_ra8m2_gcc
# SIL ビルド（対話メニュー: 2=SIL, 1=continuous build, q, q）
printf '2\n1\nq\nq\n' | bash ttb.sh ../ASP3_TZ/asp3_tz_work/hrp3_3.4.2 HRP obj_ekra8m2
# 生成物: obj_ekra8m2/sil_test/hrp（ELF）
# 実行（実機・JLink loadfile→r;g、シリアル ttyACM0）:
cd obj_ekra8m2/sil_test && arm-none-eabi-objcopy -O ihex hrp hrp.hex
#   ※ RA_SERIAL=/dev/ttyACM0 を渡して ttsp_target.sh の simulation() を使うか手動で flash
```

## 到達点（2026-06-20）

### ✅ SIL テストがビルド可能になった（従来は完全にビルド不能）
3点の移植で解決（コミット済み）:
1. **FSP include パス**（asp3_tz_work `51e2d86`）: `../fsp`(CWD相対) → `$(SRCDIR)/../cw_hrp3_ra8m2/fsp`。
   SRCDIR 外（TTSP3）ビルドディレクトリから fsp/ を解決可能に。標準ビルド回帰なし。
2. **EXCNO_DABORT/PABORT マップ**（ttsp3 `912b6b6`, ttsp_target_test.h）: A-profile 例外を
   M-profile（MemManage#4 / BusFault#5）へ。out.cfg の DEF_EXC が未定義シンボルになるのを解消。
3. **out.c アボートハンドラの M-profile 移植**（ttsp3 `912b6b6`, `#ifdef __TARGET_PROFILE_M`）:
   A-profile はデータ/命令アボートが別例外だが M-profile は両方 MemManage(#4) に集約されるため、
   CFSR(MMFSR) の DACCVIOL/IACCVIOL で demux する単一ハンドラに変更。`stm sp,{lr}^`(バンク
   レジスタ・ARM-M非対応) と pc-=4(パイプラインオフセット) を除去。A-profile 版は #else で保持。

### ✅ 起動 LOCKUP を解消し SIL が大半まで実行（2026-06-20 追記）
カーネル側 2 修正（asp3_tz_work `0170b05`）で起動不能→**CP1〜5＋多数サブテスト実行**まで前進:
- **FAULTMASK クリア**（core_kernel_impl.c, core_initialize 末尾）: inirtn からの svc LOCKUP を解消。
- **SIL_LOC_INT→BASEPRI**（core_sil.h, 旧 cpuexc STEP1）: SIL_LOC_INT 中の svc(sns_ker)の
  PRIMASK エスカレートを解消。
実機到達: `=== test start from INIRTN ===` → sil_mem/sns_ker/SIL_LOC_INT[a] → **CP1**
→ `=== test start from TASK ===` → sil_dly_nse/sil_mem/sns_ker/SIL_LOC_INT[a-k] → **CP2**
→ TASK EXCEPTION skip → **CP3,CP4** → `=== test start from ALARM ===` → **CP5** → sil_mem/sns_ker。
hrp3/test 回帰なし（task1/sem1/mutex1/dtq1/flg1/calsvc PASS）。

### ❌ 残: ALARM 文脈 all_test() でサイレントリセット（次の課題）
ALARM ハンドラ(almhdr→all_test)の sns_ker 直後でリセット（例外メッセージ無し＝WDT/タイミング
or 非タスク文脈の所）。候補: (a) cyclic(CYC 100ms周期)が長い almhdr 実行中に nested 発火し
all_test 再入, (b) 非タスク(ハンドラ)文脈の SIL_LOC_INT サブテストの busy 区間で WDT リセット。
要: almhdr/all_test の非タスク文脈実行のタイミング・再入の調査。

### （旧記録）起動 LOCKUP の根本原因 — 解決済
- 症状: フラッシュ・起動後、シリアルに "12" のみ出力しバナー(tBannerMain)前で停止。
- JLink halt で **PC=0xEFFFFFFE（ARM-M LOCKUP）, PSP=0（タスク起動前）, LR=0x0201006B**。
- LR は `ttsp_initialize_test_lib`（.text_shared @0x02010060）の `bl syslog_msk_log` 直後。
- `syslog_msk_log`(0x200ec80) は `tHRPSVCCaller_sSysLog_eEntry_mask` へ **b.w** ＝ **svc 発行**
  （TECS 拡張サービスコール）。
- **根本原因**: `inirtn`（sil_test/HRP/out.c:386, ATT_INI 初期化ルーチン）が
  `ttsp_initialize_test_lib()`→`syslog_msk_log`→**svc** を発行する。inirtn は sta_ker 中の
  **タスク起動前・極初期文脈（MSP, p_runtsk=NULL 相当）**で走るため、この ARM-M 移植では
  そこからの svc が機能せず HardFault→二重フォルト→LOCKUP に至る。
- これは hrp3/test の cpuexc（非タスク文脈ハンドラからの svc 再エスカレート）と**同一ファミリ**＝
  「**非タスク文脈からのサービスコール未対応**」。inirtn は syslog_0 も呼ぶため、syslog_msk_log を
  回避しても次の syslog で同じ LOCKUP になる見込み。

## 次の一手（候補）
1. **カーネル: inirtn 文脈からの svc を機能させる**（svc_handler_nontask 経路で p_runtsk=NULL/
   早期文脈を扱えるようにする）。これが本丸（cpuexc 非タスク機構と共通）。要 HW デバッグ環境。
2. もしくは TTSP3 SIL の inirtn を最小化し、syslog/初期化を main_task 文脈へ移す（テスト構造変更）。
3. 上記で起動が通った後、ユーザドメイン DOM1 の SIL アクセステスト（CP24/25=アボートハンドラ内
   check_point）には、タスク文脈 CPU 例外ハンドラからの svc 対応（asp3_tz_work 側 cpuexc STEP1/2
   ＝branch `m2-cpuexc-thread-handler`）が前提となる見込み。

## 関連
- asp3_tz_work cpuexc 調査: `docs/hrp3-test-campaign-status.md`（B節）＋ branch `m2-cpuexc-thread-handler`。
- 共通の本質的課題: secure Cortex-M85 で「非タスク/CPU例外/初期化 文脈からの svc」が未対応。
  HW ブレークポイント不可のため proper debug access 下での機構実装が望ましい。
