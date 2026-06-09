# 保護カーネルの GCOV(C1) 計測対応 — HRMP3 実装記録（HRP3 適用ガイド）

> 2026-06-09 記録。**HRMP3（保護＋マルチコア）に gcov(C1) 計測を導入した際の全変更点**をまとめる。
> HRP3（保護・単一コア）も同じ保護ドメイン／TECS／生成リンカスクリプト機構のため、本手順が
> ほぼそのまま適用できる（マルチコア固有の差分は本文に注記）。
>
> ASP3/FMP3（非保護）は静的リンカスクリプトで容易だが、**保護カーネルは MMU マッピングと
> 生成リンカスクリプト（ldscript.trb）が絡むため、本書の追加対応が必須**。
>
> 対象版：`hrmp3_3.4`（zybo_z7_gcc, QEMU `xilinx-zynq-a9`, arm-none-eabi 13.2）。
> 計測ランナーは `scripts/coverage_gcov_hrmp.sh`、集計は `scripts/ttsp_gcov_report.py`。

---

## 全体方針

arm-none-eabi 13.x の libgcov はフリースタンディング構成で `__gcov_exit`（ctor/dtor 終了ダンプ）を
持たない。そこで **`-fprofile-info-section` で各翻訳単位に `.gcov_info`（gcov_info 構造体ポインタ）を
生成させ、リンカで収集 → カーネル終了時に `__gcov_info_to_gcda()` で走査 → セミホスティング
（librdimon）で gcda を直接書き出す**方式を採る（ASP3/FMP3 と同方式）。

保護カーネル固有の核心は **「gcov が読み書きするメモリ（gcov_info ポインタ配列・カウンタ・ヒープ・
libgcov/librdimon コード）を、すべて MMU マッピング済み領域に置く」** こと。未マッピング領域に
落ちると、ダンプ（特権SVCモードで動作）が**変換フォールト**で停止する。

---

## 変更点①：カーネル `target/zybo_z7_gcc/Makefile.target`

`ENABLE_GCOV=true` 時の計装フラグを追加。**ライブラリ（-lgcov 等）はここに書かない**
（保護多パスリンクで順序が合わず strlen 等が未解決になる。解決は ldscript.trb の `GROUP()` に委ねる）。

```make
ifeq ($(ENABLE_GCOV),true)
	COPTS := $(COPTS) --coverage -fprofile-update=atomic -fprofile-info-section
	CDEFS := $(CDEFS) -DTOPPERS_ENABLE_GCOV
	LDFLAGS := $(LDFLAGS) -specs=rdimon.specs
	CLEAN_FILES := $(CLEAN_FILES) $(OBJDIR)/*.gcno $(OBJDIR)/*.gcda
endif
```

- `-fprofile-update=atomic`：マルチコアのカウンタ更新競合対策（HRP3 単一コアでは必須でないが無害）。
- `-specs=rdimon.specs`：セミホスティングのファイルI/O（fopen/fwrite）を有効化。

## 変更点②：カーネル `target/zybo_z7_gcc/target_kernel_impl.c`

ベアメタル gcov ランタイムを追加（FMP3 を雛形）。要点：

1. **`software_term_hook` の weak 定義を GCOV 時は無効化**（末尾の GCOV 版を使う）：
   ```c
   #ifndef TOPPERS_ENABLE_GCOV
   __attribute__((weak)) void software_term_hook(void) {}
   #endif
   ```
2. **`target_exit()` にマルチコアのダンプ同期ガード**（HRP3 単一コアでは不要、HRMP3 で必須）：
   QEMU 終了 SVC の直前に、マスタPE以外を停止させ、マスタPE の gcov ダンプ完了を待つ。
   ```c
   #ifdef TOPPERS_ENABLE_GCOV
   if (ID_PRC(get_my_prcidx()) != TOPPERS_TMASTER_PRCID) { while (true) ; }
   #endif
   ```
3. **末尾に `#ifdef TOPPERS_ENABLE_GCOV` で gcov ランタイム一式**を追加：
   - `_sbrk` を上書きし、ヒープを **`.bss` の静的配列**にする（**重要**：保護カーネルでは
     未マッピングのリンカ末尾領域はダンプ（特権）から書けない。`.bss` はカーネルドメインに
     マッピングされる）：
     ```c
     static char gcov_heap_pool[512 * 1024];
     void *_sbrk(int incr) { /* gcov_heap_pool から払い出す */ }
     ```
   - `.gcov_info` の境界 `__gcov_info_start/__gcov_info_end`（extern、リンカが定義）。
   - `__gcov_info_to_gcda()` 用コールバック（`gcov_filename_fn`=fopen、`gcov_dump_fn`=fwrite、
     `gcov_allocate_fn`=malloc）。
   - `toppers_gcov_start()`＝`initialise_monitor_handles()`（セミホスティング初期化）、
     `toppers_gcov_end()`＝`.gcov_info` 走査ダンプ。
   - `software_init_hook`/`software_term_hook`：マスタPE のみ start/end を呼ぶ。
     （`software_init_hook` は start.S から呼ばれる。semihosting 初期化に必須）

## 変更点③：カーネル `target/zybo_z7_gcc/target_mem.cfg` ★保護カーネルの核心

`.gcov_info`（gcov_info ポインタ配列）を**マッピング済みのカーネルドメインにロードして配置**する。

```c
#ifdef TOPPERS_ML_AUTO
...
KERNEL_DOMAIN {
	ATT_SEC(".gcov_info", { TA_NOWRITE|TA_KEEP, "DDR" });
}
#endif
```

- **`TA_NOWRITE` が決定的**：これにより `TA_MEMINI`（初期化済み＝**ロードされる**）が自動付与され、
  `.rodata_kernel`（PROGBITS, マッピング済み）に配置される。
  `TA_KEEP` のみだと NOLOAD の `.noinit_kernel`（NOBITS）に落ち、**ポインタ初期値がロードされず**
  ダンプが不正ポインタ参照でフォールトする（実際にこの罠にはまった）。
- `TA_KEEP`：`--gc-sections` 対策の KEEP 指定。
- 特権ダンプはカーネルドメインを読めるため、ここで十分（ユーザ書込み可能領域である必要はない）。
- 非GCOV時は `.gcov_info` 入力が無く空セクション（無害）。

## 変更点④：`target/zybo_z7_gcc/target_ldscript.trb`（新規）★保護カーネルの核心

**`arch/gcc/ldscript.trb`（共有arch）は変更しない。** 代わりに dummy ターゲットと同様に
`target/zybo_z7_gcc/target_ldscript.trb` を新規追加し、各パスの target trb から IncludeTrb する
（変更点⑤）。target_ldscript.trb は 2 つの関数を定義する。

**(1) `GenerateProvide(genFile)` フック** — `arch/gcc/ldscript.trb` が SECTIONS 生成前に
`if defined? GenerateProvide` で呼ぶ（zybo は既定で未定義のため、定義すれば呼ばれる）：
```ruby
def GenerateProvide(genFile)
  $modnameReplace["libc.a"]      = "*libc.a:"
  $modnameReplace["libgcov.a"]   = "*libgcov.a:"
  $modnameReplace["librdimon.a"] = "*librdimon.a:"
  $modnameReplace["libgcc.a"]    = "*libgcc.a:"
  genFile.add("\tPROVIDE(__gcov_info_start = __start_rodata_kernel_A1001);")
  genFile.add("\tPROVIDE(__gcov_info_end   = __end_rodata_kernel_A1001);")
  genFile.add("\tPROVIDE(end  = .);")
  genFile.add("\tPROVIDE(_end = .);")
end
```
- **`$modnameReplace` ワイルドカード化**：ツールチェーン書庫は `-l` 指定でフルパスに解決される。
  コンフィギュレータが出す非ワイルドカードの `libc.a(.text)` はフルパス書庫にマッチせず、
  GROUP で遅延に引かれたメンバ（`strlen` 等）が `.text_shared`（マッピング済み）に入らず
  未マッピング領域へ落ちて**ランタイムフォールト**する。`*libc.a:` でフルパスにマッチさせる。
  （`$modnameReplace` は core_*.trb が `={}` 初期化後、ldscript.trb のセクションループより前に
  本フックが呼ばれて追記される。）
- **`__gcov_info_start/end` のエイリアス**：変更点③の ATT_SEC により `.gcov_info` が単独で入る
  メモリオブジェクトの境界ラベル `__start_/__end_rodata_kernel_A1001`（コンフィギュレータ生成）に
  エイリアス。check_library と API 全分割で**同一ラベル＝安定**を確認済み。PROVIDE は SECTIONS の
  前に出るが、リンカのシンボル解決は大域的なので問題ない。
  ※他構成へ展開時は、生成された `cfg2_out.ld`/`cfg3_out.ld` の `.gcov_info` を含む
  `.rodata_kernel_*` の `__start_/__end_` ラベル名を確認して合わせること。
- `end`/`_end`：cfg2_out 中間リンクで librdimon の `_sbrk` が参照（実機では自前 `_sbrk` が優先）。

**(2) `GcovLdscriptAppendGroup()`** — ldscript.trb 実行後に各 target trb から呼び、
SECTIONS の後ろ（リンカスクリプト末尾）へ GROUP を追記する：
```ruby
def GcovLdscriptAppendGroup()
  $ldscript.add('GROUP( -lgcov -lrdimon -lc -lgcc )') if $ldscript
end
```
理由：保護多パスリンクはオブジェクトをリンカスクリプト経由で取り込むため、ライブラリを
コマンドライン（-T より前）に置くと順序が合わない。SECTIONS 後の `GROUP()` なら取り込んだ
オブジェクトより後に処理され `strlen` 等が解決される。フックには SECTIONS後の地点が無いため、
target trb 側で ldscript 生成後に本関数を呼ぶ。非GCOV時は参照が無く無害。

## 変更点⑤：`target/zybo_z7_gcc/target_{kernel,opt,mem}.trb`

リンカスクリプトは 3 パスで生成される（pass2: `core_kernel.trb`→`cfg2_out.ld`、
pass3: `core_opt.trb`→`cfg3_out.ld`、memパス: `core_mem.trb`→`ldscript.ld`）。各パスは別プロセスの
ため、3 つの target trb すべてで、リンカスクリプト生成（`IncludeTrb` core依存部）の**前**に
`IncludeTrb("target_ldscript.trb")`（フック定義）、**後**に `GcovLdscriptAppendGroup()`（GROUP追記）を置く：
```ruby
IncludeTrb("target_ldscript.trb")   # 前: GenerateProvide フック定義
IncludeTrb("chip_kernel.trb")        # （target_opt.trb は core_opt.trb / target_mem.trb は core_mem.trb）
GcovLdscriptAppendGroup()            # 後: GROUP 追記
```

---

## TTSP3 側の変更（本リポジトリ・コミット済み）

| ファイル | 変更 |
|---|---|
| `library/HRMP/target/zybo_z7_gcc/ttsp_target.sh` | `MAKE_OPT="${TTSP_MAKE_OPT:-}"`（`ENABLE_GCOV=true` を make へ伝播。ASP/FMP と同様） |
| `library/HRMP/check_library/{exception,interrupt,timer}/out.cfg` | 末尾に `ATT_MOD("libgcov.a")`/`ATT_MOD("librdimon.a")`（保護ドメイン配置。未リンク時は無害） |
| `scripts/coverage_gcov_hrmp.sh` | 計測ランナー（smoke/bb/all、`-smp 2`、`--filter /hrmp3/kernel/`、`-DNDEBUG`） |
| `scripts/ttsp_parallel_api.sh` | HRMP 対応：KERNEL_COBJS/APPL_COBJS、TTGフラグ `-H`、`-smp`、**TTG生成 out.cfg への lib 追記**（GCOV時のみ `ATT_MOD("libgcov.a")`/`("librdimon.a")` を追記。TTGは libc.a までしか出さないため） |

> 注：`library/HRMP/test/ttsp_obj_tail*.cfg` にも追記したが、API の out.cfg は TTG が独自生成する
> ため未使用。API は `ttsp_parallel_api.sh` の追記で対応している。

---

## ハマりどころ（順に解決した実録）

1. `ENABLE_GCOV` が make に伝わらない → ttsp_target.sh の `MAKE_OPT` 未対応（ASP/FMPのみだった）。
2. `__gcov_merge_add`/`_open` が `/DISCARD/` で破棄 → libgcov/librdimon を ATT_MOD で保護ドメインへ。
3. `strlen` 未解決（リンク順序）→ 末尾 `GROUP()`。
4. `strlen` が discarded（フルパス書庫不一致）→ `$modnameReplace` のワイルドカード化。
5. `end` 未定義（cfg2_out の librdimon _sbrk）→ ldscript で `PROVIDE(end)`、自前 _sbrk は静的配列化。
6. **ダンプが特権モードで動くが `.gcov_info` 等が未マッピングでフォールト** → CPSR=0xd3(SVC) を実測し、
   原因が権限でなく**未マッピング**と特定。`.gcov_info` を ATT_SEC でマッピング済みドメインへ。
7. `.gcov_info` が NOLOAD に落ちポインタ未ロード → **`TA_NOWRITE`** で初期化済み(ロード)データに。

---

## 計測手順

```bash
# check_library のみ（速い・基盤確認）
bash scripts/coverage_gcov_hrmp.sh smoke
# check_library + API 20分割
bash scripts/coverage_gcov_hrmp.sh bb
```

ダンプ成功時は QEMU が正常終了し、各テストの `objs/*.gcda` が生成され、
`/hrmp3/kernel/` のカバレッジが集計される。

---

## 計測結果と付随して修正したバグ

`bb` 計測：**line 75.4% / branch 63.7%**（2026-06-09）。

当初 24%/13% で頭打ちだったが、原因は gcov ではなく **IPI割込みバグ**：
ティック更新用 `TTSP_IPI_INTNO=0x001e`（PPI）が `gicd_raise_sgi()` の GICD_SGIR
INTIDフィールド（4bit）で `0x1e&0xF=14` に折り返され SGI 14 が誤発火→未登録割込み
（`core_kernel_impl.c` default_int_handler）→緊急停止していた。`0x0004`（SGI 4、FMP と同じ）
に修正（`library/HRMP/target/zybo_z7_gcc/ttsp_target_test.h`）して解消。
※診断手法：`default_int_handler(uint32_t intno)` に一時変更＋ `core_support.S` の
ハンドラ呼出し直前に `mov r0, r4`（割込み番号）を一時追加して intno=14 を特定（確認後リバート）。

残る向上余地（gcov 無関係）：一部テストが E_OACV（保護違反）で途中終了、HRMP固有ファイル
（messagebuf/domain/spin_lock 等）の低カバレッジ。詳細は `docs/HRMP/COVERAGE_STATUS.md`。
