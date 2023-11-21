#!/bin/bash

# 省略時値
servername='httphost.localdomain'
int_serial=01
server_serial=01

# Country Name, State, Organization Nameの指定
subj=`cat ./subj.txt`

if [ $# = 0 ]; then
    echo "DNS.1 name:$servername"
    # Extention [alt_names]のDNS.1を設定
    sed -e "s/dnsname1/$servername/" ext/server.cnf.template > ext/server.cnf
fi

if [ ! -z "$1" ]; then
    servername=$1
    echo "DNS.1 name:$servername"
    # Extention [alt_names]のDNS.1を設定
    sed -e "s/dnsname1/$servername/" ext/server.cnf.template > ext/server.cnf
fi
if [ ! -z $2 ]; then
    int_serial=$2
    echo "serial # for Int:$int_serial"
fi
if [ ! -z $3 ]; then
    server_serial=$3
    echo "serial # for server:$server_serial"
fi

# Extention [alt_names]のDNS.2を設定
if [ ! -z $4 ]; then
    servername2=$4
    echo "DNS.2 name:$servername2"
    # ext/server.cnfのDNS.1,DNS.2と一致させる
    sed -e "s/dnsname1/$servername/" ext/server.cnf.2.template > ext/server.cnf
    sed -i -e "s/dnsname2/$servername2/" ext/server.cnf
fi

#各種鍵の保管場所作成
dir=./workdir/
cadir=${dir}ca/
intdir=${dir}int/
serverdir=${dir}server/
mkdir -p ${cadir} ${cadir}private ${intdir} ${intdir}private ${serverdir} ${serverdir}/private

#プライベートルート証明書の作成
if [ ! -f ${cadir}private/cakey.pem ]; then
# 注意 openssl 3.0ではgenrsaは既にdeprecated https://www.openssl.org/docs/man3.0/man1/openssl-genrsa.html
openssl genrsa -out ${cadir}private/cakey.pem 2048
openssl req  -new -x509 -key ${cadir}private/cakey.pem -sha256 -days 3650 -extensions v3_ca -out ${cadir}cacert.pem -subj "$subj/CN=Example root CA"
openssl x509 -inform PEM -outform DER -in ${cadir}cacert.pem -out ${cadir}cacert.der
else 
  echo "cakey.pem already exists. Skipping root certificate creation."
fi

#中間証明書の作成
if [ ! -f ${intdir}private/intkey.pem ]; then
openssl genrsa -out ${intdir}private/intkey.pem 2048
openssl req -new -key ${intdir}private/intkey.pem -sha256 -outform PEM -keyform PEM -out ${intdir}int.csr -subj "$subj/CN=Example int CA"
openssl x509 -extfile ext/intca.cnf -req -in ${intdir}int.csr -sha256 -CA ${cadir}cacert.pem -CAkey ${cadir}private/cakey.pem -set_serial $int_serial  -extensions v3_ca  -days 3650 -out ${intdir}intcert.pem
openssl x509 -inform PEM -outform DER -in ${intdir}intcert.pem -out ${intdir}intcert.der
else 
  echo "intkey.pem already exists. Skipping intermediate certificate creation."
fi

#サーバ証明書の作成
openssl genrsa 2048 > ${serverdir}server.key
openssl req -new -key ${serverdir}server.key -outform PEM -keyform PEM  -sha256 -out ${serverdir}server.csr  -subj "$subj/CN=${servername}"
#openssl x509 -req -in ${serverdir}server.csr -sha256 -CA ${intdir}intcert.pem -CAkey ${intdir}private/intkey.pem -set_serial 01 -days 3650 -out ${serverdir}server.crt
openssl x509 -extfile ext/server.cnf -req -in ${serverdir}server.csr -sha256 -CA ${intdir}intcert.pem -CAkey ${intdir}private/intkey.pem -set_serial $server_serial -days 3650 -extensions v3_server -out ${serverdir}server.crt

# 主にWindows用
openssl pkcs12 -export -out ${serverdir}server.pfx -inkey ${serverdir}server.key -in ${serverdir}server.crt -passout pass:password

# 出力先を空にする
rm -fR ssl/*
# cert chain 
cat ${intdir}intcert.pem ${cadir}cacert.pem  > ssl/caint.crt
cat ${serverdir}server.crt ${intdir}intcert.pem ${cadir}cacert.pem > ssl/all.crt

cp ${serverdir}server.crt ssl/
cp ${serverdir}server.key ssl/
cp ${serverdir}server.pfx ssl/
cp ${cadir}cacert.der ssl/
cp ${intdir}intcert.der ssl/
cp ${intdir}intcert.pem ssl/
cp ${cadir}cacert.pem ssl/

#AWS ACMへ証明書をインポートする
#aws acm import-certificate --certificate file://${serverdir}server.crt --private-key file://${serverdir}server.key --certificate-chain file://${intdir}intcert.pem

echo 'int_serial:'$int_serial' server_serial:'$server_serial >> params/$servername.params