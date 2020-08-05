# apache-ssl
Setup ssl for apache on Ubuntu 18.04.

## 前提
apacheを起動するサーバのホスト名はirishost.localdomainであるとする。
```bash
$ hostname -f
irishost.localdomain
```
opensslにてCA構成済みとする。
```bash
root@irishost:/etc/ssl# openssl version
OpenSSL 1.1.1  11 Sep 2018
root@irishost:/etc/ssl# /usr/lib/ssl/misc/CA.pl -newca
```

## オレオレ証明書を作成
以下、プロンプト$はログインユーザ、root@irishost:~#はrootユーザでの実行。

```bash
$ git clone https://github.com/IRISMeister/apache-ssl.git
CAに合わせて[dn]セクションのxxxになっている箇所を編集
$ vi extv3/ext3.csr.cnf
$ sudo mkdir /etc/ssl/irishost
$ sudo cp extv3/* /etc/ssl/irishost
$ sudo su -
root@irishost:~# cd /etc/ssl
root@irishost:/etc/ssl# ls irishost
ext3.csr.cnf  ext3.ext
root@irishost:/etc/ssl# openssl req -new -sha256 -nodes -out irishost/ext3.csr -newkey rsa:2048 -keyout irishost/ext3.key -config irishost/ext3.csr.cnf
root@irishost:/etc/ssl# openssl ca -in irishost/ext3.csr -out irishost/ext3.pem -cert /etc/ssl/demoCA/cacert.pem -keyfile /etc/ssl/demoCA/private/cakey.pem -extfile irishost/ext3.ext -days 3650
root@irishost:/etc/ssl# ls irishost/
ext3.csr  ext3.csr.cnf  ext3.ext  ext3.key  ext3.pem
```
confに上書きcopyする
```bash
$ cp /etc/ssl/irishost/ext3.pem conf/server.crt
$ sudo cp /etc/ssl/irishost/ext3.key conf/server.key
```

## 起動・停止
```bash
$ docker-compose up -d
$ docker-compose down
```

## テスト
```bash
$ curl --cacert /etc/ssl/demoCA/cacert.pem https://irishost.localdomain/
<html>
    <body>
        hello
    </body>
</html>
$ 
```
## 参考
コンテナからオリジナルのconfを抽出する方法
```bash
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/httpd.conf > conf/httpd.conf
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/extra/httpd-ssl.conf > conf/extra/httpd-ssl.conf
```
