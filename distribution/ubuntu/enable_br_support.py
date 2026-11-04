"""Run the reviewed one-time BR migration using a Windows-protected credential.

No password is placed in command arguments, files, logs or remote history.
"""
from pathlib import Path
import hashlib
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'work/ssh-runtime'))
import paramiko

credential=Path.home()/'.codex/credentials/toque-microgate-192.168.101.24.dpapi'
command="$encrypted=(Get-Content -LiteralPath '"+str(credential).replace("'","''")+"' -Raw).Trim(); $secret=ConvertTo-SecureString $encrypted; $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret); try { [Console]::Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $secret.Dispose() }"
secret=subprocess.run(['pwsh.exe','-NoProfile','-NonInteractive','-Command',command],check=True,capture_output=True).stdout.decode('utf-8')
ssh=paramiko.SSHClient();ssh.load_host_keys(str(ROOT/'distribution/private/ubuntu_known_hosts'));ssh.set_missing_host_key_policy(paramiko.RejectPolicy())
digest=hashlib.sha256((ROOT/'distribution/ubuntu/apply-release.py').read_bytes()).hexdigest()
try:
    try:
        ssh.connect('192.168.101.24',username='microgate',key_filename=str(ROOT/'distribution/private/ubuntu_deploy_rsa'),look_for_keys=False,allow_agent=False,timeout=15)
    except paramiko.AuthenticationException:
        ssh.connect('192.168.101.24',username='microgate',password=secret,look_for_keys=False,allow_agent=False,timeout=15)
    stdin,out,err=ssh.exec_command("sudo -S -p '' -- /bin/sh /home/microgate/toque-deploy/install-br-support.sh "+digest,timeout=90)
    stdin.write(secret+'\n');stdin.flush();stdin.channel.shutdown_write()
    output=out.read().decode();error=err.read().decode();code=out.channel.recv_exit_status()
    print(output.strip())
    if code:
        print(error.replace(secret,'[redacted]').strip());raise SystemExit(code)
    _,out,err=ssh.exec_command('sha256sum /usr/local/sbin/toque-deploy',timeout=15)
    if out.read().decode().split()[0]!=digest:raise SystemExit('Installed helper verification failed')
    print('BR_SUPPORT_HASH_VERIFIED')
finally:
    secret='';ssh.close()
