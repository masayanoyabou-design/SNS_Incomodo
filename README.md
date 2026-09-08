# Incomodo（インコモード）— 事前登録LP

「行かなきゃ、読めない。」あえて不便さを楽しむ、位置情報連動型スローコミュニケーションSNS「Incomodo」の、広告検証（スモークテスト）用ランディングページです。

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

- ロードマップの各タスクには `P1-1`〜`P4-5` の参照番号
- バックログの各課題には `B1`〜`B17` の参照番号

が付いているので、「P2-3が終わった」のように番号で指示できます。

## 技術スタック

- 単一HTMLファイル（Tailwind等のビルド不要、外部ライブラリ依存なし）
- フォント: Google Fonts（Noto Serif JP / Noto Sans JP / Special Elite）
- レスポンシブ対応（モバイルファースト）
