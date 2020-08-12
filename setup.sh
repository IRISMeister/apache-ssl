#!/bin/bash

# 下記サイトからの流用
# https://dev.classmethod.jp/articles/aws_certificate_create_inport/
# https://qiita.com/bashaway/items/ac5ece9618a613f37ce5

# ext/server.cnfのDNS.1と一致させること
domain='httphost.localdomain'

#各種鍵の保管場所作成
dir=~/testca/
cadir=${dir}ca/
intdir=${dir}int/
serverdir=${dir}server/
mkdir ${dir} ${cadir} ${cadir}private ${intdir} ${intdir}private ${serverdir} ${serverdir}/private

#プライベートルート証明書の作成
openssl genrsa -out ${cadir}private/cakey.pem 2048
openssl req  -new -x509 -key ${cadir}private/cakey.pem -sha256 -days 3650 -extensions v3_ca -out ${cadir}cacert.pem -subj "/C=JP/ST=Osaka/O=xxxcorp/CN=Example root CA"
openssl x509 -inform PEM -outform DER -in ${cadir}cacert.pem -out ${cadir}cacert.der

#中間証明書の作成
openssl genrsa -out ${intdir}private/intkey.pem 2048
openssl req -new -key ${intdir}private/intkey.pem -sha256 -outform PEM -keyform PEM -out ${intdir}int.csr -subj "/C=JP/ST=Osaka/O=xxxcorp/CN=Example int CA"
openssl x509 -extfile ext/intca.cnf -req -in ${intdir}int.csr -sha256 -CA ${cadir}cacert.pem -CAkey ${cadir}private/cakey.pem -set_serial 01  -extensions v3_ca  -days 3650 -out ${intdir}intcert.pem
openssl x509 -inform PEM -outform DER -in ${intdir}intcert.pem -out ${intdir}intcert.der

# cert chain for curl
cat ${intdir}intcert.pem ${cadir}cacert.pem  > ${dir}all.pem

#サーバ証明書の作成
openssl genrsa 2048 > ${serverdir}server.key
openssl req -new -key ${serverdir}server.key -outform PEM -keyform PEM  -sha256 -out ${serverdir}server.csr  -subj "/C=JP/ST=Osaka/O=xxxcorp/CN=${domain}"
#openssl x509 -req -in ${serverdir}server.csr -sha256 -CA ${intdir}intcert.pem -CAkey ${intdir}private/intkey.pem -set_serial 01 -days 3650 -out ${serverdir}server.crt
openssl x509 -extfile ext/server.cnf -req -in ${serverdir}server.csr -sha256 -CA ${intdir}intcert.pem -CAkey ${intdir}private/intkey.pem -set_serial 01 -days 3650 -extensions v3_server -out ${serverdir}server.crt

cp ${serverdir}server.crt ~/git/apache-ssl/conf/
cp ${serverdir}server.key ~/git/apache-ssl/conf/

#AWS ACMへ証明書をインポートする
#aws acm import-certificate --certificate file://${serverdir}server.crt --private-key file://${serverdir}server.key --certificate-chain file://${intdir}intcert.pem

