# TARGET_LIBRARY_PLACEMENT.md — ターゲット依存部（library/）配置の設計検討

> `library/<PROFILE>/target/<TARGET>/` の TTSP ターゲット依存部を、**各カーネル（OS）のターゲット依存部側にも
> 置けるようにする**ための設計検討。採用方針＝**案C（ハイブリッド探索パス）**（2026-06-14 決定）。
> 規約の正本は [`AGENTS.md`](../AGENTS.md)（特に §2 禁則・§3 配置・§6 ターゲット依存部）。

---

## 1. 現状

TTSP のターゲット依存部は **TTSP3 git 内** `library/<PROFILE>/target/<TARGET>/` に 4(+α) ファイル：

| ファイル | 役割 |
|---|---|
| `ttsp_target_test.c` | 7関数（`ttsp_target_stop_tick`/`start_tick`/`gain_tick`、`ttsp_int_raise`/`ttsp_clear_int_req`、`ttsp_cpuexc_raise`/`ttsp_cpuexc_hook`） |
| `ttsp_target_test.h` | スタックサイズ・割込み/例外番号・優先度・SIL遅延・stkアクセサ等のマクロ |
| `ttsp_target.sh` | `USE_QEMU`・`KERNEL_COBJS_TARGET`/`APPL_COBJS_TARGET`・`FUNC_*` 等 |
| `ttsp_target.cfg` | テスト用ターゲット cfg |
| (任意) `configure.yaml` / `exclude_tests.txt` | TTG オプション・除外パターン |

スクリプトは **パス直書き**で参照（`scripts/ttsp_parallel_api.sh`）：
```
source ./library/$PROFILE_NAME/target/$TARGET_NAME/ttsp_target.sh
./library/$PROFILE_NAME/target/$TARGET_NAME/{configure.yaml,exclude_tests.txt}
```
カーネル（asp3 等）は SVN・別管理で、[`AGENTS.md`](../AGENTS.md) §2 禁則①②により **TTSP3 から所有/編集しない**。

---

## 2. 課題

- 新ターゲット追加のたびに TTSP3 を編集する必要がある（out-of-tree／asp3_core 派生ターゲットでは不便）。
- ターゲット支援を**カーネルのターゲット依存部と同梱**したい（所有・保守の自然さ）。
- だが同梱すると **2リポジトリ（ttsp3 git ＋ カーネル SVN）で契約を共有**することになり、版整合が難しい。

### 選択肢の比較
| 案 | 内容 | 版整合 | 禁則との関係 |
|---|---|---|---|
| A 現状維持 | ttsp3 が全保持 | 自明（単一正本） | 整合。新ターゲットは ttsp3 編集 |
| B カーネル側へ全面移設 | `<kernel>/target/<T>/` に同梱 | 難（2リポジトリ共有） | 禁則①②と所有権衝突（要改定） |
| **C ハイブリッド探索パス（採用）** | カーネル側 `<kernel>/target/<T>/ttsp/` を**優先**、無ければ ttsp3 既定にフォールバック | 契約版スタンプで機械化 | framework 正本性を維持しつつ拡張可 |

---

## 3. 採用方針：案C（ハイブリッド探索パス）

### 3.1 探索パス
スクリプトのターゲット依存部解決を「直書き」から「探索」に変更する。優先順：
1. **カーネル側**：`$OS_PATH/target/$TARGET_NAME/ttsp/`（カーネル SVN が任意で提供）
2. **TTSP3 既定**：`library/$PROFILE_NAME/target/$TARGET_NAME/`（フォールバック＝現状）

```sh
# 擬似コード（common.sh に集約する想定）
resolve_ttsp_target() {  # echo: 解決したディレクトリ
  local k="$OS_PATH/target/$TARGET_NAME/ttsp"
  local t="library/$PROFILE_NAME/target/$TARGET_NAME"
  if [ -f "$k/ttsp_target.sh" ]; then echo "$k"; else echo "$t"; fi
}
```
影響ファイル：`scripts/ttsp_parallel_api.sh`・`scripts/common.sh`・各 `coverage_gcov_*.sh`・`ttb.sh`
（現状 `./library/$PROFILE/target/$TARGET/...` を直書きしている全箇所を `resolve_ttsp_target` 経由に置換）。

### 3.2 インターフェース版スタンプ（版整合の要）
TTSP3 が **ターゲット依存部のインターフェース契約**（7関数＋必須マクロ）の正本を持ち、版番号を定義する：
- TTSP3 側：`library/ttsp_target_if.h`（新）に `#define TTSP_TARGET_IF_VERSION N`。
- カーネル側 ttsp ディレクトリの `ttsp_target_test.h` は対応する版を宣言：`#define TTSP_TARGET_IF_REQUIRED N`。
- ビルド/configure 時に `TTSP_TARGET_IF_VERSION == TTSP_TARGET_IF_REQUIRED` を検査（不一致は明示エラー）。
- 契約変更時に版を上げ、非互換を検出できるようにする。

### 3.3 版固定の記録
[`UPSTREAM_KERNEL.md`](../UPSTREAM_KERNEL.md) の版固定表に「カーネル側 ttsp 依存部が提供する IF版」を追記し、
「どのカーネル版がどの TTSP3 IF版と互換か」を記録（既存のカーネル版固定機構を流用）。

### 3.4 禁則の改定（前提・方針判断）
案C/B は「TTSP ターゲット依存部をカーネルツリーに置く」ため、現行 [`AGENTS.md`](../AGENTS.md) §2 禁則②
（カーネル無編集）と所有権が衝突する。**改定案**：
> 禁則②の例外：`<kernel>/target/<TARGET>/ttsp/` 配下の **TTSP ターゲット依存部**は TTSP 側の成果物であり、
> カーネル本体とは別物として配置・保守してよい（ただし TTSP3 git には取り込まず、カーネル SVN 側で管理）。
> 契約（IF版）の正本は TTSP3 が持つ。

---

## 4. 段階導入計画

1. **契約の明文化**：`library/ttsp_target_if.h`＋ `TTSP_TARGET_IF_VERSION`。既存 4 ターゲットに版宣言を付ける（後方互換・既定値）。
2. **探索パス導入**：`common.sh` に `resolve_ttsp_target` を実装し、直書き参照を全面置換。既定（ttsp3 側）動作は不変＝回帰なしを確認。
3. **パイロット**：1 ターゲット（例 asp3_core 系の新ターゲット）をカーネル側 `ttsp/` に置いて探索パス経由でビルド/緑を実証。
4. **UPSTREAM_KERNEL.md / AGENTS.md 反映**：版固定記録と禁則例外を明文化。

> 各段階で「既存（ttsp3 側）ターゲットが従来どおり緑」を [`docs/STATUS.md`](STATUS.md) 基準で確認してから次へ。

---

## 参照
- 配置・SVN・実dir地図：[`docs/WORKSPACE.md`](WORKSPACE.md)
- ターゲット依存部の構造：[`AGENTS.md`](../AGENTS.md) §6
- 版固定：[`UPSTREAM_KERNEL.md`](../UPSTREAM_KERNEL.md)
