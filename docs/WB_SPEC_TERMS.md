# WB_SPEC_TERMS.md — ホワイトボックステスト 仕様用語辞書

WB テスト記述（note フィールド / txt ファイル）では，カーネル実装の内部変数名ではなく
統合仕様書（TOPPERS/ASP3 Kernel 統合仕様書）の用語を使う．
本ファイルは「実装変数名 → 仕様用語」の対応表．

---

## タスク状態フラグ

| 実装変数名 | 仕様用語 | 参照仕様 |
|---|---|---|
| `raster = true` | タスク終了要求フラグがセットされた状態 | NGKI3455 |
| `raster = false` | タスク終了要求フラグがクリアされた状態 | NGKI3455 |
| `dister = true` | タスク終了禁止状態 | NGKI3491 |
| `dister = false` | タスク終了禁止フラグがクリアされた状態 | NGKI3491 |
| `wupque = true`（wupcnt ≥ 1） | 起床要求キューイング数が0でない | NGKI1259 |
| `wupque = false`（wupcnt = 0） | 起床要求キューイング数が0 | NGKI1259 |
| `wupcnt = 1` | 起床要求キューイング数が1（ASP3では最大値 TMAX_WUPCNT=1） | NGKI1259 |

## プロセッサ・コンテキスト状態

| 実装／API 名 | 仕様用語 | 参照仕様 |
|---|---|---|
| `sense_context()=T` | 非タスクコンテキスト | NGKI3489 |
| `sense_lock()=T` | CPUロック状態 | NGKI3489 |
| `!dspflg` | ディスパッチ禁止状態 | NGKI3489 |
| `loc_cpu=true` | CPUロック状態（pre_condition 記述） | NGKI3489 |

## CHECK_DISPATCH 分岐（gcov br番号との対応）

`check.h` の `CHECK_DISPATCH()` は `if (sense_context() || sense_lock() || !dspflg)` に展開される．
gcov は各サブ条件を独立の分岐ポイントとしてカウントするため，br 番号は以下の通り：

| br 番号 | 分岐条件 | 仕様用語 |
|---|---|---|
| br[0]=0（false） | sense_context()=F | タスクコンテキスト（正常系） |
| br[1]=T | sense_context()=T | 非タスクコンテキスト → E_CTX |
| br[2]=0（false） | sense_lock()=F | CPUロック解除状態（正常系） |
| br[3]=T | sense_lock()=T | CPUロック状態 → E_CTX |
| br[4]=0（false） | dspflg=T（!dspflg=F） | ディスパッチ許可状態（正常系） |
| br[5]=T | !dspflg=T | ディスパッチ禁止状態 → E_CTX |

---

## note フィールド記述規約

```
note: 【<NGKI番号> / <カーネルバージョン>】<仕様用語による説明>
```

例：
```yaml
note: 【NGKI3455優先 / ASP3 3.7.2】タスク終了要求フラグがセットされた状態で起床要求キューイング数が1のとき，NGKI3455がNGKI1259より優先してE_RASTERを返し，起床要求キューイング数を消費しないこと
```

- `<カーネルバージョン>` は被テストカーネルのバージョン（例：`ASP3 3.7.2`）
- 実装変数名（`raster=T`，`wupcnt=1` など）は note には書かない．
  コメント行（`#`）や target_branch 記述では C コードの参照として使ってよい．
