"""Print the launchd plist for the Mac mini downloader or the GUI notification monitor."""
import pathlib
import plistlib
import sys

role = sys.argv[1]
assert role in ('pull','observe','mini-observe')
root = pathlib.Path.home()/'.local/share/cuephys-backups/managed'
args = ['/usr/bin/python3',str(root/'bin/mac_worker.py'),'pull' if role=='pull' else 'observe']
if role == 'mini-observe':
    args.append('--local-pull')
plist = dict(Label='com.cuephys.backup.'+('pull' if role=='pull' else 'monitor'),
             ProgramArguments=args, StartInterval=60 if role=='pull' else 120,
             RunAtLoad=True, ProcessType='Background', Umask=0o077)
if role=='pull':
    plist['UserName'] = pathlib.Path.home().name
sys.stdout.buffer.write(plistlib.dumps(plist))
