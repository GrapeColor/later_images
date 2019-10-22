# Later Images

## 概要
Discord用のBOTで、Twitterの画像つきツイートがメッセージで送信された際に、2枚目以降の画像を送信します。  
NSFW指定のチャンネル以外で、センシティブコンテンツを含む画像つきツイートが送信された場合、応答しません。  
  
こちらソースコードを参考にさせて頂きました。  
https://loumo.jp/wp/archive/20180608120023/

## 導入方法
以下のリンクからサーバーに招待し、BOTに適切な権限を与えてください。  
https://discordapp.com/api/oauth2/authorize?client_id=629507137995014164&permissions=0&scope=bot

## 不具合
一部の画像つきツイートに反応しません。これはTwitter APIが一部のツイートに対してメディアエンティティを返さないために起こるもので、現時点では修正できません。
