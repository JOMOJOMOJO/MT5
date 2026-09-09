"""Reconstruct exact hashed source dependencies from each run's owning commit.

Git may normalize CRLF. Only a byte representation matching the run SHA is
accepted. This does not modify any source or worktree file.
"""
import argparse,hashlib,subprocess,zipfile,csv,io
from pathlib import Path


def main():
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
    root=Path.cwd();lines=(a.run/'source_hashes.txt').read_text(encoding='utf-8-sig').splitlines()
    commit=next(x.split('=',1)[1] for x in lines if x.startswith('source_commit='))
    dest=a.run/'exact_source_bundle.zip'
    if dest.exists():raise SystemExit('Bundle already exists; preserve evidence')
    files=[];rows=[]
    for line in lines:
        if '  ' not in line:continue
        expected,path=line.split('  ',1);path=Path(path)
        if path.suffix not in ('.mqh','.mq5'):continue
        relative=path.relative_to(root).as_posix()
        data=subprocess.run(['git','show',f'{commit}:{relative}'],check=True,stdout=subprocess.PIPE).stdout
        lf=data.replace(b'\r\n',b'\n')
        candidates=[data,lf,lf.replace(b'\n',b'\r\n')]
        # Existing files can contain mixed line endings after historical patches.
        # Accept their exact bytes only when content also matches the owning commit.
        current=path.read_bytes() if path.exists() else b''
        if current.replace(b'\r\n',b'\n')==lf:candidates.append(current)
        matched=next((x for x in candidates if hashlib.sha256(x).hexdigest().upper()==expected),None)
        if matched is None:raise SystemExit(f'Cannot reconstruct exact source: {relative}')
        files.append((relative,matched));rows.append(dict(path=relative,owning_commit=commit,sha256=expected,status='EXACT_MATCH'))
    with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in files:
            info=zipfile.ZipInfo(name,(2026,9,9,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,data)
        stream=io.StringIO();w=csv.DictWriter(stream,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
        info=zipfile.ZipInfo('source_inventory.csv',(2026,9,9,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,stream.getvalue())
    print(f'Exact source bundle {len(files)} dependencies: {dest}')


if __name__=='__main__':main()
