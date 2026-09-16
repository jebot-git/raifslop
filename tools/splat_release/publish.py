"""Publish the validated current release through a draft, checking upload hashes."""
from pathlib import Path
import hashlib, http.client, json, os, shutil, subprocess, urllib.parse

root=Path(__file__).resolve().parents[2]
version='v'+json.loads((root/'builds/splat-testing/release/build-manifest.json').read_text())['version']
repo='jebot-git/raifslop'
assets_dir=root/'builds/splat-testing/release'
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert subprocess.check_output(['git','describe','--exact-match','--tags','HEAD'],cwd=root,text=True).strip()==version
assert not subprocess.check_output(['git','status','--porcelain'],cwd=root), 'Working tree is not clean'
assert json.loads((assets_dir/'build-manifest.json').read_text())['commit']==commit
expected_files={line.split('  ',1)[1] for line in (assets_dir/'SHA256SUMS').read_text().splitlines()}
assert {p.name for p in assets_dir.iterdir()}==expected_files|{'SHA256SUMS'}
for line in (assets_dir/'SHA256SUMS').read_text().splitlines():
    digest,name=line.split('  ',1)
    with (assets_dir/name).open('rb') as stream:
        assert hashlib.file_digest(stream,'sha256').hexdigest()==digest, name
gh=os.environ.get('GH_BIN',shutil.which('gh') or 'gh')
token=subprocess.run([gh,'auth','token','--hostname','github.com'],capture_output=True,text=True,check=True,timeout=30).stdout.strip()
headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'RealAIFishing-release-builder'}

def api(method,path,data=None,allow_missing=False):
    body=json.dumps(data).encode() if data is not None else None
    connection=http.client.HTTPSConnection('api.github.com',timeout=60)
    connection.request(method,path,body=body,headers={**headers,'Content-Type':'application/json'})
    response=connection.getresponse();raw=response.read();status=response.status;connection.close()
    if allow_missing and status==404:return None
    if status>=300:raise SystemExit(f'GitHub API {method} {path}: {status} {raw.decode()[:500]}')
    return json.loads(raw) if raw else None

base='/repos/'+repo+'/releases'
release=api('GET',base+'/tags/'+version,allow_missing=True)
if release is None:
    # GitHub's tag endpoint omits drafts. Find an interrupted upload explicitly.
    page=1
    while True:
        candidates=api('GET',base+'?per_page=100&page='+str(page))
        release=next((item for item in candidates if item['tag_name']==version),None)
        if release is not None or len(candidates)<100:break
        page+=1
if release is None:
    release=api('POST',base,{'tag_name':version,'target_commitish':commit,'name':'Hybrid Splat Viewer '+version.removeprefix('v'),'body':(root/'docs'/('RELEASE_NOTES_'+version.removeprefix('v')+'.md')).read_text(),'draft':True,'prerelease':True})
assert release['draft'], 'Release already published; refusing to modify it'
expected=[]
for name in sorted(p.name for p in assets_dir.iterdir() if p.is_file()):
    path=assets_dir/name
    with path.open('rb') as f:digest='sha256:'+hashlib.file_digest(f,'sha256').hexdigest()
    expected.append((name,digest,path.stat().st_size))
    existing=next((a for a in release['assets'] if a['name']==name),None)
    if existing:
        assert existing.get('digest')==digest and existing['size']==path.stat().st_size, ('Existing asset differs',name)
        print('VERIFIED existing',name,flush=True);continue
    url=urllib.parse.urlparse(release['upload_url'].split('{',1)[0])
    assert url.scheme=='https' and url.netloc=='uploads.github.com'
    connection=http.client.HTTPSConnection(url.netloc,timeout=600)
    connection.putrequest('POST',url.path+'?'+urllib.parse.urlencode({'name':name}))
    for key,value in {**headers,'Content-Type':'application/octet-stream','Content-Length':str(path.stat().st_size)}.items():connection.putheader(key,value)
    connection.endheaders()
    print('UPLOADING',name,flush=True)
    with path.open('rb') as f:
        sent=0; milestone=25
        while chunk:=f.read(2*1024*1024):
            connection.send(chunk);sent+=len(chunk)
            if sent*100/path.stat().st_size>=milestone:
                print('TRANSFER',name,str(milestone)+'%',flush=True);milestone+=25
    response=connection.getresponse();raw=response.read();status=response.status;connection.close()
    if status!=201:raise SystemExit(f'Upload {name}: {status} {raw.decode()[:500]}')
    result=json.loads(raw)
    assert result.get('digest')==digest and result['size']==path.stat().st_size, ('Uploaded asset checksum mismatch',name)
    print('UPLOADED AND VERIFIED',name,flush=True)
release=api('GET',base+'/'+str(release['id']))
actual={(a['name'],a.get('digest'),a['size']) for a in release['assets']}
assert actual==set(expected), 'Release asset list differs from local manifest'
release=api('PATCH',base+'/'+str(release['id']),{'draft':False,'make_latest':'false','prerelease':True})
report={'url':release['html_url'],'version':version,'commit':commit,'assets':[{'name':a['name'],'sha256':a.get('digest'),'bytes':a['size']} for a in release['assets']]}
(root/'test-results/splat-release-published.json').write_text(json.dumps(report,indent=2)+'\n')
print('PUBLISHED',release['html_url'],flush=True)
