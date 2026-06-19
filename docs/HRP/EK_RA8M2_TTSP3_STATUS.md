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

## ★大幅更新（2026-06-20 後半）: SIL が CP1〜22 まで実機 PASS

完全ビルド不能だった SIL を，以下の一連の修正で **実機 CP1〜22 まで通過**させた（hrp3/test 回帰ゼロ）。
残るは USER DOMAIN(DOM1) abort テスト CP24/25 と完了(CP26)のみ。

**コミット済み修正（asp3=asp3_tz_work, ttsp3=本リポ）**:
1. asp3 FSP パス SRCDIR化（SRCDIR外ビルド可能化）。
2. ttsp3 EXCNO_DABORT/PABORT マップ＋abort ハンドラ M-profile 移植（ビルド成立）。
3. asp3 **FAULTMASK クリア**（core_initialize）＝inirtn からの svc LOCKUP 解消（起動成功）。
4. asp3 **SIL_LOC_INT→BASEPRI**＝SIL_LOC_INT 中の svc エスカレート解消。
5. asp3 **sil_dly_nse で WDT リフレッシュ**＝ビジー待ち(ttsp_wait_check_point/wait_raise_int)の WDT 解消。
6. ttsp3 wait_raise_int を非タスク文脈(sns_ctx)でスキップ＋CYC 周期マクロ化(ek_ra8m2=3s)
   ＝ALARM/CYCLIC 文脈のライブロック解消（CP5-12 通過）。
7. asp3 **STEP2: タスク文脈 CPU 例外ハンドラのスレッドモード実行**＋nPRIV 昇格/復元，
   ttsp3 ttsp_cpuexc_hook の PC オフセット修正＝EXCEPTION フェーズ CP13-22 通過。

**残課題 USER DOMAIN abort の決定的根因（実機 halt+CFSR で確定）**:
- CFSR=0x00010092 → MMFSR=0x92 = MMARVALID|**MSTKERR**|**DACCVIOL**，MMFAR=**0x22000FD8**
  （= p_excinf，DOM1 の ustk 内。ttg_ustack=0x22000000, ustk=...0x22001000）。
- すなわち **CPU 例外処理（core_exc_entry/STEP2）が特権でユーザタスクの ustk へアクセスして
  MPU 違反**。`.ttg_stack_section` は `ATT_SEC(...,{TA_NOWRITE|TA_NOREAD,...})` で，DOM1 の
  ustk は DOM1 にのみ許可され，カーネル/特権文脈からはアクセス不可（MSTKERR=例外スタッキングの
  MPU 違反，DACCVIOL=stmfd の書込み違反）。
- **確定した修正**: ユーザドメイン CPU 例外は **sstk(.system_stack, 特権アクセス可) へ退避して処理**
  する（svc Part3 と同型。sil_user_task は sstk 割当済，STEP2 の nPRIV 昇格も対応済＝前提充足）。
  core_exc_entry のタスクパスで「ユーザドメインなら HW フレームを ustk→sstk へコピーし PSP=sstk で
  処理，復帰時に PC 等を ustk フレームへ反映して PSP=ustk へ戻す」を実装する。hrp3/test の mprot
  （ユーザドメイン MemManage）も同じ修正で前進する見込み。

**（旧記述）残課題: USER DOMAIN abort (CP24/25)**:
sil_user_task(ユーザドメイン)の sil_reb_mem(不正アドレス)→MemManage の処理で，core_exc_entry の
`stmfd r0!,{r1,lr}`(PC=0x…f6e)が **ユーザスタック(ustk=PSP)への書込みで再フォルト→HardFault**
(Excno=3, 停止 XPSR IPSR=4)。HW 例外フレーム(32B)は ustk に積めるが直下の +8B でフォルト。
ustk=4KB と十分なはずで，MPU 境界 or PSP 位置の要因を実機 PSP/ustk 実測で要特定。
**対応**: ユーザドメイン CPU 例外を **sstk へ退避して処理**する(svc Part3 と同型。sil_user_task は
sstk 割当済)。STEP2 の nPRIV 昇格は対応済(前提)。これは hrp3/test の mprot(ユーザドメイン MemManage)
にも共通の本丸。

## 旧・到達点（2026-06-20 前半）

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

### ❌ 残: ALARM(CP5) 以降の all_test() で能動スピン／リセット（次の課題）
ALARM ハンドラ(almhdr→all_test)の sns_ker 直後（`test_of_SIL_LOC_INT()`→`wait_raise_int()`,
out.c 内 `[a]` 出力前）で停止。例外メッセージ無し。
- JLink halt（複数回）で **PC=0x0200B4BE（loc_cpu 相当: `mrs BASEPRI; msr BASEPRI_MAX #16`）,
  IPSR=0（タスク文脈）, PSP 設定済, CycleCnt 増加＝能動的スピン**。
- `wait_raise_int()`(out.c) はテスト割込み(TTSP_INTNO_A, 優先度 -15=最高)の発火を待つが，CPUロック
  /高優先度ハンドラ文脈では発火せず，`sil_dly_nse`(busy, svc 無→WDT 非リフレッシュ)ループに陥る。
  TASK 文脈では [a-k] 完走(CP2)するので，**特定文脈（ALARM/CYCLIC ハンドラ or CPUロック中）での
  割込み待ちが成立しない**ことが原因と推定。
- 候補対応: (a) ハンドラ/CPUロック文脈で成立しない割込み待ちサブテストを exclude_tests 相当で
  除外（sys_manage SOM 除外と同様）, (b) ネスト割込み（time-event-handler 文脈からの割込み
  プリエンプト＆resume）の挙動を実機検証, (c) wait_raise_int の busy 区間で WDT リフレッシュ。
- 参考: タイマ割込み優先度 INTPRI_TIMER=TMAX_INTPRI-1=-2（低）, TTSP_INTNO_A=-15（高）。

#### 実機 halt 詳細解析（2026-06-20・決定的）
スピン時（単一 JLink セッションで読取り・有効値）:
- PC=0x0200B4BE（loc_cpu 相当）, IPSR=0（タスク文脈）, **BASEPRI=0x10（CPUロック中）**,
  FAULTMASK=0, PRIMASK=0, CONTROL=0（特権）, CycleCnt 増加＝能動スピン。
- `int_flag`(0x2200a5e0)=0（割込み未発火）。
- NVIC: ISER0=0x0000000E（IRQ1-3=SCI8 のみ enable。**TTSP_INTNO_A=IRQ24 は未 enable**）,
  ISPR0=0（未 pending）, IRQ24 の IPR=0。
→ wait_raise_int 文脈で **テスト割込みが未 enable・未 pending かつ CPU ロック中**。

**構造的制約（重要）**: `TTSP_GE_TIMER_INTPRI = TMIN_INTPRI = -15`、その内部表現
`INT_IPM(-15)=0x10=field1` は **CPU ロックレベル IIPM_LOCK と同一**。M-profile では CPU ロック中
（BASEPRI=field1）に field≥1 の割込みは全てマスクされ、field0 は フォルト/SVCall 専用。よって
**「CPU ロック中／高優先度ハンドラ文脈で割込みを上げて発火を待つ」テスト（wait_raise_int を伴う
SIL_LOC_INT サブテスト）は M-profile では原理的に成立しない**（A-profile は別機構で成立）。
TASK 文脈[a-k]はロック解除後に待つので成立（CP2 通過実績）。

#### ★訂正診断（2026-06-20・step/halt+stack-walk で確定）
当初の「wait_raise_int/loc_cpu スピン」は **addr2line による誤帰属**だった。MSP のネスト
フレーム（EXC_RETURN 0xFFFFFFF1/0xFFFFFFF3 が複数＝多重ネスト）を addr2line で解決した
実際のコールチェーン:
`svc_call_trampoline`(タスクの svc) → **`r_gpt_ccmp_common_isr`**(GPT タイマ割込み・ネスト発火)
→ `target_hrt_handler` → `_kernel_signal_time`(時間イベント処理) → 時間イベントハンドラが
SIL `all_test` を実行 → `tHRPSVCBody_sSysLog_mask` / `tHRPSVCCaller_sSerialPort_eEntry_read`
(svc＋**低速 115200 シリアル出力**) → ロック/`clr_int` 系コードでスピン。
→ すなわち ALARM/CYCLIC 失敗は **多重ネスト割込み／再入問題**: GPT タイマ（および 100ms 周期の
CYC）が，シリアル律速で長時間かかる時間イベントハンドラ（all_test）の実行**中**にネスト発火し，
再入・スピンに陥る。単純な割込み優先度/マスクの問題ではない（CPUロック説は訂正）。
→ 切り分け継続には JLink `Step`（単一ステップ・secure でも可）で clr_int 系ループの r0/ISPR を
観測するか，時間イベントハンドラから重い all_test（特に大量シリアル出力）を呼ぶ TTSP 設計を
本ターゲット向けに見直す（再入を避ける）必要。

#### step/状態レジスタ精査（2026-06-20・追補）
スピン時の全状態: PC=0x0200B4BE（clear/lock 領域の `mrs BASEPRI`）, **BASEPRI=0x10（CPUロック中）**,
FAULTMASK=0, PRIMASK=0, CONTROL=0(特権/MSP)。**割込み pending/active 皆無**（ISPR0/1=0, IABR0/1=0）。
→ ハード割込みストームではなく，**CPUロック下のソフトウェア・ライブロック**（clear/lock 系コードの
ループが抜けない）。JLink `Step` はこの箇所で毎サイクル同一 PC を返し命令単位トレース不可のため，
確定には**ループ出口アドレスへの BKPT 手動パッチ**(w2 <addr> 0xBE00)での観測が必要。
disasm 上のループ(0x200b4a0–0x200b4de): ICPR クリア→ロック→ISPR 再読込→`tst`→ビット残存かつ
r0≠15 なら `subs r0,#16` して再試行。ISPR は halt 時 0 のため出口条件と矛盾＝addr2line の関数帰属
(`_kernel_clr_int`)が不正確で別の inline 関数の可能性も含め，BKPT トレースでの再確認が必要。

#### ★最終診断（2026-06-20・全レジスタ確認で確定）
スピン時の全レジスタ: R2=**0x40322000（GPT タイマ周辺機器領域）**, R6/R7=0x0200D338/334(rodata表),
R4=R5=2(索引), BASEPRI=0x10。nm は 0x0200b460 を `_kernel_clr_int` と示すが，書込み先が GPT で
あり call chain も `r_gpt_ccmp_common_isr`→`target_hrt_handler`→`_kernel_signal_time` のため，
スピンは **HRT/GPT の時間イベント処理経路**にある（NVIC 割込みクリアではない）。
`target_hrt_set_event`(target_timer.c:124) は過去時刻を正しく処理（:136-138 で即時要求）するため
単純な「過去時刻プログラミング」バグではない。
→ **真因＝イベント駆動 HRT のキャッチアップ・ライブロック**: SIL テストは **ALARM ハンドラと
100ms 周期 CYC ハンドラの両方**で重い `all_test`（大量の 115200 シリアル出力）を実行する。1 ハンドラの
実行が周期(100ms)を超えるため，時間イベントが処理速度より速く積み上がり，`signal_time`/HRT が
即時再要求を繰り返して追いつけず，CPU ロック下でライブロック → WDT リセット。
→ **ターゲット負荷限界**（イベント駆動 HRT＋低速シリアル＋重いハンドラ）であり，単純なカーネルバグ
ではない。

**対応案（更新）**:
- 本ターゲット向けに SIL テストの CYC 周期を延長（100ms→十分大）か，ALARM/CYCLIC 文脈の all_test の
  シリアル出力を削減（負荷を周期内に収める）。test/config 側の調整＝TTSP の target 適合化。
- もしくはイベント駆動 HRT が過負荷時に古い時間イベントをまとめて処理/間引く設計にする（カーネル側・大）。

**旧・対応案**:
1. ALARM/CYCLIC（ハンドラ）文脈および CPU ロック中の wait_raise_int サブテストを，本ターゲット用に
   out.c で M-profile ガード（#ifdef __TARGET_PROFILE_M）して skip するか、TTSP の exclude 機構へ。
   sys_manage SOM 除外（simt 専用）と同じ「ターゲット非対応テストの除外」方針。
2. もしくは TTSP_INTNO_A を field0 では出せない以上、ハンドラ/ロック文脈の当該サブテストは
   構造的に対象外と整理。

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
