# Later Images

## 概要
Discord用のBOTで、Twitterの画像つきツイートがメッセージで送信された際に、2枚目以降の画像を送信します。  
基本的には「[twitter-photo-getter](https://loumo.jp/wp/archive/20180608120023/)」の派生BOTですが、以下の相違点があります。  
- NSFWが指定されていないチャンネルで、センシティブコンテンツを含むツイートに反応しない。
- BOTが反応したメッセージが削除された際は、BOTが送信したメッセージも削除。
- DiscordがEmbedを埋め込まないメッセージには反応しない。
- URLの頭に`!`を付けたメッセージには反応しない。

## 導入方法
このBOTは個人が無償で運用しているBOTです。  
予告なく運用を終了したり、仕様が変更される可能性があります。  
導入に際しては**自己責任**でお願いします。  

以下のリンクからサーバーに招待し、BOTに適切な権限を与えてください。  
https://discordapp.com/api/oauth2/authorize?client_id=629507137995014164&permissions=0&scope=bot  
  
必要最低限の権限が初めから付与されたリンクはこちらになります。  
https://discordapp.com/api/oauth2/authorize?client_id=629507137995014164&permissions=84992&scope=bot
