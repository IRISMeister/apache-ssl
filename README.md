# apache-ssl
Setup ssl for apache on Ubuntu 18.04.

## 前提
openssl導入済み。  
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
$ openssl req -x509 -nodes -days 1 -newkey rsa:2048 -subj /CN=* -keyout conf/server.key -out conf/server.crt
```

* 自前のCA(いわゆるオレオレ認証局)を使用する方法
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
pushd /etc/ssl # move here 
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
cp /etc/ssl/httphost/server.crt conf/
sudo cp /etc/ssl/httphost/server.key conf/
```

おまけ  
ブラウザにCAを認識させるためには、下記のフォーマット変換が必要です。
```bash
sudo openssl x509 -inform PEM -outform DER -in /etc/ssl/myCA/cacert.pem -out /etc/ssl/myCA/cacert.der
```
Windowsであれば、cacert.derを「ルート証明書ストア」に登録する。

## apache起動
IRISが起動していること確認。接続先のIRISが別ホストに存在する場合はiris.confのURLを編集。
```bash
docker-compose up -d
```

下記のようなエラーが出る場合は、いったんコンテナを削除(docker-compose down)してから再実行。
```
ERROR: for apache-ssl_apache_1  Cannot start service apache: OCI runtime create failed: container_linux.go:349: starting container process caused "process_linux.go:449: container init caused \"rootfs_linux.go:58: mounting \\\"/conf/httpd.conf\\\" to rootfs \\\"/var/lib/docker/overlay2/9d242df810477b3937967434a6fa56bf84fcae54c12bd9a78b5a6e71fd2bb202/merged\\\" at \\\"/var/lib/docker/overlay2/9d242df810477b3937967434a6fa56bf84fcae54c12bd9a78b5a6e71fd2bb202/merged/usr/local/apache2/conf/httpd.conf\\\" caused \\\"not a directory\\\"\"": unknown: Are you trying to mount a directory onto a file (or vice-versa)? Check if the specified host path exists and is the expected type
```

## ホスト上でのテスト
```bash
オレオレ証明書の場合
curl --insecure https://localhost/csp/sys/UtilHome.csp
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

## 手元のPCからのテスト
* 警告が出ても良い場合  
手元のPCからChrome/FireFoxなどで下記URLにてアクセス可能であることを確認。  
https://ec2のパブリックDNS/csp/sys/UtilHome.csp  


* 警告を出さないようにしたい場合  
ルート証明書ストアにcacert.derを追加。  
サーバ認証されているホスト名とURLが一致するように、実行するPCのhostsファイル(C:\Windows\System32\drivers\etc\hosts)に、下記のようにhttphost.localdomainを追加。
```
54.250.169.xxx httphost httphost.localdomain
```

繋がらない場合は、インバウンドルールにhttps(port:443)が存在していることを確認。なければ追加。  
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
