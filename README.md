# Incomodo（インコモード）

「行かなきゃ、読めない。」あえて不便さを楽しむ、位置情報連動型スローコミュニケーションSNS「Incomodo」のリポジトリです。広告検証（スモークテスト）用のランディングページと、スマホアプリ本体（開発中）を含みます。

**公開URL：** https://snazzy-parfait-172aba.netlify.app

## ファイル構成

```
SNS_Incomodo/
├── index.html               LP本体（このまま公開できる単一HTMLファイル）
├── privacy.html             プライバシーポリシー
├── progress.html             開発ダッシュボード（ロードマップ・バックログ・進捗グラフ）
├── MANUAL.md                作業マニュアル（各作業の目的・手順・ハマりどころを記録。継続更新）
├── incomodo-lp-deploy.zip    Netlify Drop等にそのままアップロードできるデプロイ用ZIP
├── assets/                   index.htmlが参照する画像（アプリ画面モックアップ3枚）
├── ads/                      Meta広告用クリエイティブ（フィード用・ストーリーズ用）
├── app/                      スマホアプリ本体（Flutter + Firebase、開発中）
│   ├── lib/                  アプリのコード（models/・services/・providers/・screens/・widgets/ に分離）
│   ├── test/                 業務ルールの自動テスト（`flutter test` で実行）
│   └── firestore.rules       データベースのセキュリティルール
└── docs/                     元の仕様書
    ├── 要件定義.md
    └── LP作成用プロンプト.md
```

## LPを確認する

`index.html` をブラウザで直接開くだけで表示できます（サーバー不要）。

## LPを公開する（更新時の再デプロイ手順）

1. [Netlify Drop](https://app.netlify.com/drop) を開く
2. `incomodo-lp-deploy.zip` を解凍せずにそのままドラッグ＆ドロップ
3. Netlifyにログインしていれば、既存サイト（snazzy-parfait-172aba）を選んで上書きデプロイできる

匿名デプロイ（未ログイン）の場合、Netlifyの仕様上いったんパスワード保護がかかった状態で発行されます。「Claim your site」からアカウントに紐づけたうえで、サイト共有設定を **Public** に変更するとパスワードなしで誰でも見られるようになります。

**ZIPを作り直す際の注意（Windows）：** PowerShellの `Compress-Archive` は、`assets/` のようなサブフォルダを含むZIPを作るとパス区切り文字が `\`（バックスラッシュ）になってしまうことがあり、Netlify上で画像が404になる原因になります。作り直す場合は `System.IO.Compression.ZipArchive` を使い、エントリ名を明示的に `assets/xxx.jpg`（スラッシュ）で指定してください。

## 進捗管理

`progress.html` を開くと、LP公開からアプリリリースまでのロードマップと、解決すべき課題（バックログ）を確認できます。チェック状態はブラウザのlocalStorageに保存されます。

- ロードマップの各タスクには `P1-1`〜`P4-5` の参照番号（途中で分割したタスクは `P3-2B` のように末尾に英字）
- バックログの各課題には `B1`〜`B22` の参照番号

が付いているので、「P2-3が終わった」のように番号で指示できます。

## 技術スタック

**LP（index.html など）**
- 単一HTMLファイル（Tailwind等のビルド不要、外部ライブラリ依存なし）
- フォント: Google Fonts（Noto Serif JP / Noto Sans JP / Special Elite）
- レスポンシブ対応（モバイルファースト）

**アプリ（app/）**
- Flutter（Dart）で Android / iOS を1つのコードから開発
- Firebase（Authentication・Firestore〈東京リージョン〉・Storage）
- 状態管理: Riverpod（見た目とロジックを分離し、UIを後から差し替えやすくするため）
- 開発環境の構築手順・ハマりどころは `MANUAL.md` の10〜14章を参照
