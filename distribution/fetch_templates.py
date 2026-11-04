"""Fetch only the two Windows binaries from the official Godot template archive."""
import io
import pathlib
import urllib.request
import zipfile

URL = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'

class RemoteZip(io.RawIOBase):
    def __init__(self):
        response = urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'))
        self.url = response.url
        self.size = int(response.headers['Content-Length'])
        self.pos = 0
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos
    def read(self, size=-1):
        size = self.size - self.pos if size < 0 else min(size, self.size - self.pos)
        if size <= 0: return b''
        req = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{self.pos + size - 1}'})
        with urllib.request.urlopen(req, timeout=120) as response:
            if response.status != 206: raise RuntimeError('Server did not honor byte range')
            data = response.read()
        if len(data) != size: raise RuntimeError(f'Incomplete range: {len(data)} != {size}')
        self.pos += len(data)
        return data

if __name__ == '__main__':
    # Local path passed explicitly, to avoid assumptions about workspace layout.
    import sys
    target = pathlib.Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip()) as archive:
        for name in ('windows_release_x86_64.exe', 'windows_debug_x86_64.exe'):
            output = target / name
            if output.exists(): continue
            data = archive.read('templates/' + name)
            output.write_bytes(data)
            print(name, len(data), flush=True)
