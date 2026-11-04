#!/usr/bin/python3
import datetime,pathlib,sqlite3,tarfile,time
folder=pathlib.Path('/var/backups/toque-de-campo')
folder.mkdir(parents=True,exist_ok=True,mode=0o700)
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
source=sqlite3.connect('file:/var/lib/toque-de-campo/accounts/accounts.sqlite?mode=ro',uri=True)
dest=sqlite3.connect(str(folder/('accounts-'+stamp+'.sqlite')))
source.backup(dest);dest.close();source.close()
with tarfile.open(folder/('keys-'+stamp+'.tar.gz'),'w:gz') as archive:
 for path in ['/var/lib/toque-de-campo/accounts/signing.pem','/etc/toque-de-campo/tls','/etc/toque-de-campo/service-token']:
  archive.add(path,arcname=path.lstrip('/'))
for path in folder.iterdir():
 if path.is_file() and path.name.startswith(('accounts-','keys-')) and time.time()-path.stat().st_mtime>14*86400:path.unlink()
print('Accounts and keys backup completed')
