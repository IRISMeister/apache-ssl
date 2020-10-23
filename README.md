# apache-ssl
Setup ssl for Apache and nginx on Ubuntu 18.04.

このレポジトリでは、[AWS上にて稼働中のInterSystems IRISの管理ポータルとの通信を暗号化する方法](https://jp.community.intersystems.com/node/480411/)で使用するソースコードと成果物を公開しています。

## 前提
openssl導入済み。  
(コンテナイメージのビルドをしたく無かったので、キー作成はDocker内で実行しません)
```bash
$ openssl version
OpenSSL 1.1.1  11 Sep 2018
```
docker導入済み。  
https://docs.docker.com/engine/install/ubuntu/  
(フレッシュな環境なら下記の導入方法が簡単)
```bash
$ curl -fsSL https://get.docker.com -o get-docker.sh
$ sudo sh get-docker.sh
$ sudo usermod -aG docker your-user
usermod反映のために再ログイン
```
docker-compose導入済み。  
https://docs.docker.com/compose/install/
```bash
$ docker-compose version
docker-compose version 1.26.2, build eefe0d31
docker-py version: 4.2.2
CPython version: 3.7.7
OpenSSL version: OpenSSL 1.1.0l  10 Sep 2019
```

## 導入方法
```bash
$ git clone https://github.com/IRISMeister/apache-ssl.git
$ cd apache-ssl
```

## サーバ証明書を作成
* 簡単な方法(いわゆるオレオレ証明書)
```bash
$ openssl req -x509 -nodes -days 1 -newkey rsa:2048 -subj /CN=* -keyout ssl/self-server.key -out ssl/self-server.crt
$ ls ssl
self-server.crt  self-server.key
```

* 自前のCA(いわゆるオレオレ認証局)を使用する方法  
必要であればブラウザ初回接続時のセキュリティ警告をなくせる。  
ホスト名をhttphost.localdomain以外に変更したい場合、ext/server.cnfのDNS.1及びsetup.shのdomain環境変数値を編集する。
```bash
$ ./setup.sh
$ ls ssl
all.crt  caint.crt server.crt  server.key
```
下記サイトを参考にさせていただいています。  
https://dev.classmethod.jp/articles/aws_certificate_create_inport/  
https://qiita.com/bashaway/items/ac5ece9618a613f37ce5  

## apache起動
setup.shを実行した事を前提にしています。  
実行前にIRISが起動していること確認。接続先のIRISが別ホストに存在する場合は[iris.conf](apache-conf/other/iris.conf)のURLを編集。
```bash
docker-compose up -d
```
## nginx起動
setup.shを実行した事を前提にしています。  
オレオレ証明書の場合は、docker-compose-nginx.ymlのコメント箇所を変更してください。
実行前にIRISが起動していること確認。接続先のIRISが別ホストに存在する場合は[ssl.conf](nginx-conf/ssl.conf)のURLを編集。
```bash
docker-compose -f docker-compose-nginx.yml up -d
```
注)(多少は高速になるのではないかという期待のもと)network_mode:"host"を使用しているため、apacheとの同時起動は不可です。必要に応じて適宜修正してください。

## エラー
下記のようなエラーが出る場合は、いったんコンテナを削除(docker-compose down)してから再実行。
```
ERROR: for apache-ssl_apache_1  Cannot start service apache: OCI runtime create failed: container_linux.go:349: starting container process caused "process_linux.go:449: container init caused \"rootfs_linux.go:58: mounting \\\"/conf/httpd.conf\\\" to rootfs \\\"/var/lib/docker/overlay2/9d242df810477b3937967434a6fa56bf84fcae54c12bd9a78b5a6e71fd2bb202/merged\\\" at \\\"/var/lib/docker/overlay2/9d242df810477b3937967434a6fa56bf84fcae54c12bd9a78b5a6e71fd2bb202/merged/usr/local/apache2/conf/httpd.conf\\\" caused \\\"not a directory\\\"\"": unknown: Are you trying to mount a directory onto a file (or vice-versa)? Check if the specified host path exists and is the expected type
```

FireFoxで下記のようなエラーが発生することがあります。
```
httphost への接続中にエラーが発生しました。You are attempting to import a cert with the same issuer/serial as an existing cert, but that is not the same cert.
エラーコード: SEC_ERROR_REUSED_ISSUER_AND_SERIAL
```
下記サイトを参考に対処してみてください。  
https://support.mozilla.org/en-US/kb/Certificate-contains-the-same-serial-number-as-another-certificate


## ホスト上でのテスト
オレオレ証明書の場合
```bash
curl --insecure https://localhost/csp/sys/UtilHome.csp
```
オレオレ認証局の場合
```bash
curl --cacert ~/testca/ca/cacert.pem https://httphost.localdomain/csp/sys/UtilHome.csp
```
アクセス成功の場合、下記のようなhtml(ログインページ)が出力されます。
```html
<html>
<head>
        <title>ログイン IRIS</title>
<link rel="icon" type="image/ico" href="portal/ISC_IRIS_icon.ico">
<script language="javascript">
        // called when page is loaded
        function pageLoad()
        {
```

## 手元のPCからのテスト
* ブラウザのセキュリティ警告が出ても良い場合  
手元のPCからChrome/FireFoxなどで下記URLにてアクセス可能であることを確認。  
https://apacheが起動しているホスト/csp/sys/UtilHome.csp  


* ブラウザのセキュリティ警告を出さないようにしたい場合  
1. 証明書をインポート  
FireFox：cacert.pem, intcert.pemを認証局証明書としてインポート  
Chrome:cacert.derを信頼されたルート証明機関,intcert.derを中間証明機関にそれぞれインポート。要再起動。  
2. 名前解決  
サーバ認証で使用しているホスト名とアクセスするホスト名(URL)が一致するように、実行するPCのhostsファイル(WindowsであればC:\Windows\System32\drivers\etc\hosts)に、下記のようにhttphost.localdomainを追加。
```
54.250.169.xxx httphost httphost.localdomain
```
3. 下記のURLにアクセス。  
https://httphost.localdomain/csp/sys/UtilHome.csp  

> apche/nginxをaws上のホストで稼働させている場合、インバウンドルールでhttps(port:443)を許可しないと接続出来ません。  

## 停止
```bash
docker-compose down
```

## 参考
apacheのコンテナからオリジナルのconfを抽出する方法　　
conf/httpd.conf, conf/extra/httpd-ssl.confの修正箇所は非常に少ないです。修正箇所を知るには下記で抽出したファイルとdiffをとってください。
```bash
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/httpd.conf > conf/httpd.conf
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/extra/httpd-ssl.conf > conf/extra/httpd-ssl.conf
```
