# apache-ssl
Setup ssl for apache on Ubuntu 18.04.

## 前提
apacheを起動するサーバのホスト名はhttphost.localdomainでクライアントからこのホスト名で到達可能であるとする。  
openssl導入済み。  
docker導入済み。  
```bash
$ hostname -f
httphost.localdomain
$ openssl version
OpenSSL 1.1.1  11 Sep 2018
```

## 導入方法
```bash
$ git clone https://github.com/IRISMeister/apache-ssl.git
$ cd apache-ssl
```

## サーバ証明書を作成
### 簡単な方法(いわゆるオレオレ証明書)
```bash
$ openssl req -x509 -nodes -days 1 -newkey rsa:2048 -subj /CN=* -keyout conf/server.key -out conf/server.crt
```

### 自前のCA(いわゆるオレオレ認証局)を使用する方法
(必要であれば)ブラウザ警告をなくせる。  
必要に応じて[dn]セクションのxxになっている箇所を編集
```bash
sudo mkdir -p /etc/ssl/myCA/private
sudo mkdir /etc/ssl/httphost
sudo cp extv3/csr.cnf /etc/ssl/myCA
sudo cp extv3/csr.ext /etc/ssl/httphost
sudo vi /etc/ssl/myCA/csr.cnf
```
opensslにてCAを構成する。以下、実行例。
```bash
sudo openssl req -x509 -nodes -newkey rsa:2048 -out /etc/ssl/myCA/cacert.pem -keyout /etc/ssl/myCA/private/cakey.pem -config /etc/ssl/myCA/csr.cnf -days 3650
tree --charset=C /etc/ssl/myCA
/etc/ssl/myCA
|-- cacert.pem
|-- csr.cnf
`-- private
    `-- cakey.pem
```
サーバ証明書を発行する。以下、実行例。  
(存在しなければ)適当な設定でdemoCAをセットアップ。
```bash
/usr/lib/ssl/misc/CA.pl -newca
```
以下、上記で作成されたCA(demoCA)は使用しませんが、/etc/ssl/demoCA下のindex.txtなどは流用します。
```bash
sudo openssl req -new -sha256 -nodes -newkey rsa:2048 -out /etc/ssl/httphost/server.csr -keyout /etc/ssl/httphost/server.key -config /etc/ssl/myCA/csr.cnf
cd /etc/ssl # move here 
sudo openssl ca -in httphost/server.csr -out httphost/server.crt -cert myCA/cacert.pem -keyfile myCA/private/cakey.pem -extfile httphost/csr.ext -days 3650
tree --charset=C httphost
httphost
|-- csr.ext
|-- server.crt
|-- server.csr
`-- server.key
cat demoCA/index.txt
V       230807033745Z           76565CB133C25E2B4E7D4D3788E98046D23C589A        unknown /C=JA/ST=Osaka/O=zzz/OU=zz/CN=foo@bar
V       300805034708Z           76565CB133C25E2B4E7D4D3788E98046D23C589B        unknown /C=xx/ST=xx/O=xx/OU=xx/CN=httphost.localdomain/emailAddress=yyy@yyy
popd
```
おまけ  
ブラウザにCAを認識させるためには、下記のフォーマット変換が必要です。
```bash
sudo openssl x509 -inform PEM -outform DER -in /etc/ssl/myCA/cacert.pem -out /etc/ssl/myCA/cacert.der
```
Windowsであれば、cacert.derを「ルート証明書ストア」に登録する。

## サーバ証明書をapacheに適用する
confに上書きcopyする
```bash
cp /etc/ssl/httphost/server.crt conf/
sudo cp /etc/ssl/httphost/server.key conf/
```
## apache起動
IRISが起動していること確認。接続先のIRISが別ホストに存在する場合はiris.confのURLを編集。
```bash
docker-compose up -d
```

## テスト
```bash
オレオレ証明書の場合
curl --insecure https://httphost.localdomain/csp/sys/UtilHome.csp
オレオレ認証局の場合
curl --cacert /etc/ssl/myCA/cacert.pem https://httphost.localdomain/csp/sys/UtilHome.csp
<html>
<head>
        <title>ログイン IRIS</title>
<link rel="icon" type="image/ico" href="portal/ISC_IRIS_icon.ico">
<script language="javascript">
        // called when page is loaded
        function pageLoad()
        {
```

警告が出ますが、PCからChrome/FireFoxなどで上記URLにアクセス可能です。  
vscode+objectscript拡張からhttps:"true"で接続可能です。

## 停止
```bash
docker-compose down
```

## 参考
apacheのコンテナからオリジナルのconfを抽出する方法
```bash
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/httpd.conf > conf/httpd.conf
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/extra/httpd-ssl.conf > conf/extra/httpd-ssl.conf
```
