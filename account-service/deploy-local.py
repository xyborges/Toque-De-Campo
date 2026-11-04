from pathlib import Path
import shutil
root=Path.cwd(); private=Path('C:/xampp/toque-de-campo-private'); public=Path('C:/xampp/htdocs/toque-de-campo/accounts'); public.mkdir(exist_ok=True)
shutil.copy2(root/'account-service/api.php', public/'api.php')
(public/'.htaccess').write_text('Options -Indexes\n<FilesMatch "^(?!api\\.php$).+">\nRequire all denied\n</FilesMatch>\n',encoding='ascii')
conf=Path('C:/xampp/apache/conf/extra/toque-accounts-ssl.conf')
conf.write_text('''# Toque de Campo: HTTPS for the native accounts API.
<VirtualHost 192.168.101.227:443 127.0.0.1:443>
ServerName 192.168.101.227
DocumentRoot "C:/xampp/htdocs"
SSLEngine on
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4
SSLCertificateFile "C:/xampp/toque-de-campo-private/tls.crt"
SSLCertificateKeyFile "C:/xampp/toque-de-campo-private/tls.pem"
ErrorLog "C:/xampp/apache/logs/toque-accounts-error.log"
</VirtualHost>
''',encoding='ascii')
main=Path('C:/xampp/apache/conf/httpd.conf'); s=main.read_bytes(); include=b'Include conf/extra/toque-accounts-ssl.conf'
if include not in s:
 shutil.copy2(main, private/'httpd-before-accounts.conf')
 main.write_bytes(s+b'\r\n'+include+b'\r\n')
