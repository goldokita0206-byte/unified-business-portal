統合業務ポータルシステム 仕様書
作成日: 2026 年 10 月 19 日
版: v1.0
構成: ローカルオンリー／インターネット非依存（モデル初回 DL 除く）
1. システム概要
1.1 目的
社内・現場・行政向け 6 業務モジュールを単一ポータルに集約し、ローカル AI（Ollama） と連携して業務効率化を実現するシステム。データはすべて PC 内に保管され、外部流出しない。
1.2 特長
✅ インターネット不要（初回モデル取得時のみ必要）
✅ データは JSON ファイルとして平文保存・編集容易
✅ Ollama による自然言語アシスタント常駐
✅ 役割別表示制御により利用者に応じた画面を提供
2. 動作環境
表
項目	仕様
OS	Windows 10/11
Web サーバー	内蔵サーバー（ポート: 8080）
AI エンジン	Ollama v0.34.2（ポート: 11434）
対応ブラウザ	各種モダンブラウザ（Chrome/Edge 推奨）
通信	ローカルループバックのみ（localhost）
必要ソフト	Ollama、PowerShell（標準搭載）
3. フォルダ構成
plaintext
統合業務ポータルシステム画面集/
├── index.html                  トップポータル
├── sales_crm.html              営業支援CRM
├── factory_portal.html         現場・生産管理
├── public_sector_portal.html   公共・行政管理
├── corporate_management.html    コーポレート管理
├── company_portal.html         社内申請ポータル
├── client_portal.html          社外連携ポータル
│
├── assets/
│   └── js/
│       └── data_manager.js     保存・読込共通処理
│
├── *.php                       サーバー側API
│   save_data.php               データ保存
│   list_data.php               ファイル一覧取得
│   load_data.php               データ読込
│
├── data/                       データルート
│   ├── sales/                  営業データ
│   ├── production/             生産データ
│   ├── public/                 公共データ
│   ├── corporate/              コーポレートデータ
│   ├── application/            社内申請データ
│   ├── partner/                社外連携データ
│   └── portal/                 トップページ用（手動作成）
│
├── start_server.ps1            Webサーバー起動
├── create_data_system.ps1      データ機能一括構築
└── 保存読込機能_追加用.txt      各画面貼付用テンプレート
4. 業務モジュール一覧
表
No	モジュール名	ファイル名	保存先カテゴリ	主な管理項目
1	営業支援 & CRM	sales_crm.html	sales	顧客情報・商談・見積・予実
2	現場・生産管理	factory_portal.html	production	工程・工数・設備点検・不具合報告
3	公共・行政業務管理	public_sector_portal.html	public	政策・入札・予算・補助金申請
4	コーポレート管理	corporate_management.html	corporate	資産・人事・備品・経理
5	社内ポータル & 申請	company_portal.html	application	決裁・経費・勤怠・FAQ
6	社外・クライアント連携	client_portal.html	partner	契約・見積・進捗共有
5. データ管理仕様
5.1 保存形式
ファイル形式: JSON（UTF-8）
命名規則: {カテゴリ}_{YYYY-MM-DDTHH-MM-SS}.json
構造例:
json
{
  "顧客ID": "C001",
  "顧客名": "○○商事",
  "担当者": "田中",
  "更新日時": "2026/10/19 01:00:00"
}
5.2 機能詳細
表
機能	処理内容
保存	フォーム入力値を JSON に変換し、タイムスタンプ付きでファイル出力
一覧表示	対象カテゴリ内の JSON ファイルを降順でプルダウン表示
読込	選択された JSON を読み込み、同名フォーム項目に自動代入
バックアップ	data/ フォルダをコピーするだけで完全複製
5.3 実装方法
各 HTML の</body>直前に保存読込機能_追加用.txtの内容を貼り付け、CATEGORYを対応文字列に置換。
javascript
Run
const CATEGORY = "sales";  // 各モジュールに対応
フォームには<form id="mainForm">を付与することで自動収集対象となる。
6. AI 連携仕様
6.1 接続先
Ollama: http://localhost:11434/api/generate
モデル: llama3 → 推奨llama3.2（軽量・高速）
通信方式: ローカル HTTP（CORS 要調整）
6.2 起動手順
powershell
# サーバー起動（常駐）
ollama serve

# 対話開始（別ウィンドウ）
ollama run llama3.2
初回実行時はモデル自動ダウンロードあり。以降はオフラインで動作。
6.3 ポータル連携
画面右下の🤖ボタンからチャットウィンドウ展開
入力→送信で Ollama へリクエスト
応答はストリーミング表示（stream:falseにて一括表示に変更可）
7. 起動・運用手順
7.1 サーバー起動
powershell
cd 統合業務ポータルシステム画面集
.\start_server.ps1
「ポート 8080 使用中」= 正常稼働中 ✅
アクセス先: http://localhost:8080/
ログイン: admin / Admin@2026
7.2 役割切替
トップページ上部セレクターから表示内容を制御：
表
役割	表示モジュール
管理者	全 6 モジュール
一般社員	営業・コーポレート・社内申請
現場作業員	生産管理・社内申請
行政職員	公共管理・社内申請
社外パートナー	社外連携のみ
7.3 停止手順
Web サーバー：起動 PowerShell ウィンドウを閉じる
Ollama: ollama serve のウィンドウを閉じる
対話: /bye を入力して終了
8. セキュリティ・データ保護
表
項目	仕様
データ所在	すべてローカル PC 内
暗号化	通信なし／ファイル暗号化なし（必要に応じ手動対応）
アクセス制御	ログイン ID / パスワード（簡易認証）
インターネット	原則未接続（モデル初回取得除く）
バックアップ	data/フォルダのコピーで世代管理推奨
9. 今後の拡張案
🔲 フォーム項目追加：<form id="mainForm">配下にname属性付き要素を追加するだけで対応可
🔲 削除機能：ファイル直接削除、またはdelete_data.php追加で実装
🔲 検索機能：data/内 JSON を横断検索
🔲 承認フロー：ステータス管理・通知機能
🔲 画像添付：data/配下にimages/を設けてファイルパス管理
以上が現時点でのシステム仕様書となります。必要に応じて項目の追加・変更を行ってください。
