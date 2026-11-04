<?php
$dir='C:/xampp/toque-de-campo-private';
$conf=$dir.'/openssl.cnf';
file_put_contents($conf,"[ req ]\ndistinguished_name=dn\nx509_extensions=v3\nprompt=no\n[ dn ]\nCN=192.168.101.227\nO=Toque de Campo\n[ v3 ]\nsubjectAltName=IP:192.168.101.227,IP:127.0.0.1,DNS:localhost\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\nextendedKeyUsage=serverAuth\n");
if (!is_file($dir.'/tls.pem')) {
 $key=openssl_pkey_new(['private_key_bits'=>3072,'private_key_type'=>OPENSSL_KEYTYPE_RSA,'config'=>$conf]);
 if (!$key) throw new Exception(openssl_error_string());
 $csr=openssl_csr_new(['commonName'=>'192.168.101.227'],$key,['config'=>$conf,'digest_alg'=>'sha256']);
 $crt=openssl_csr_sign($csr,null,$key,3650,['config'=>$conf,'x509_extensions'=>'v3','digest_alg'=>'sha256']);
 openssl_pkey_export_to_file($key,$dir.'/tls.pem',null,['config'=>$conf]);openssl_x509_export_to_file($crt,$dir.'/tls.crt');
}
if (!is_file($dir.'/signing.pem')) {
 $key=openssl_pkey_new(['private_key_bits'=>3072,'private_key_type'=>OPENSSL_KEYTYPE_RSA,'config'=>$conf]);
 openssl_pkey_export_to_file($key,$dir.'/signing.pem',null,['config'=>$conf]);
 file_put_contents($dir.'/signing-public.pem',openssl_pkey_get_details($key)['key']);
}
echo "ACCOUNT_KEYS_READY\n";
