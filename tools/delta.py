"""Build a deterministic, copy/literal binary delta. No game files are bundled."""
import gzip, hashlib, struct

def sha(data): return hashlib.sha256(data).hexdigest()

def make_delta(old, new):
    block=32
    index={old[i:i+block]:i for i in range(0,len(old)-block+1,16)}
    out=bytearray(b'ZHTCDEL1'+struct.pack('<I',len(new)))
    literal=bytearray();pos=0
    def flush():
        if literal:
            out.extend(b'L'+struct.pack('<I',len(literal))+literal);literal.clear()
    while pos<len(new):
        at=index.get(new[pos:pos+block])
        if at is None:
            literal.append(new[pos]);pos+=1;continue
        n=block
        while at+n+block<=len(old) and pos+n+block<=len(new) and old[at+n:at+n+block]==new[pos+n:pos+n+block]: n+=block
        while at+n<len(old) and pos+n<len(new) and old[at+n]==new[pos+n]: n+=1
        flush();out.extend(b'C'+struct.pack('<II',at,n));pos+=n
    flush();out.extend(b'E')
    return gzip.compress(out,compresslevel=9,mtime=0)

def apply_delta(old, packed):
    data=gzip.decompress(packed);assert data[:8]==b'ZHTCDEL1'
    size=struct.unpack_from('<I',data,8)[0];pos=12;out=bytearray()
    while True:
        op=data[pos:pos+1];pos+=1
        if op==b'E':break
        if op==b'C':
            at,n=struct.unpack_from('<II',data,pos);pos+=8
            assert at+n<=len(old);out.extend(old[at:at+n])
        else:
            assert op==b'L';n=struct.unpack_from('<I',data,pos)[0];pos+=4
            assert pos+n<=len(data);out.extend(data[pos:pos+n]);pos+=n
        assert len(out)<=size
    assert len(out)==size and pos==len(data)
    return bytes(out)
