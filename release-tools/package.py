#!/usr/bin/env python3
"""Package the locally verified binaries, notices, and corresponding sources."""
from pathlib import Path
import tarfile, shutil, hashlib, json
root=Path(__file__).resolve().parent.parent
out=root/'releases'
name='openwrt-usb-airplay-0.1.0-aarch64-musl'
stage=out/name
stage.mkdir(exist_ok=True)
shutil.copytree(root/'dist',stage/'app',dirs_exist_ok=True,ignore=shutil.ignore_patterns('SHA256SUMS'))
for f in ('install.sh','uninstall.sh'):shutil.copy2(root/'release-tools'/f,stage/f)
shutil.copy2(root/'openwrt/airplay-usb.init',stage/'airplay-usb.init')
shutil.copytree(root/'licenses',stage/'licenses',dirs_exist_ok=True)
shutil.copy2(root/'README.md',stage/'README.md')
# Preserve license and notice files verbatim from dependency source archives.
for archive in sorted((out/'source-inputs').iterdir()):
 if archive.suffix not in ('.gz','.xz','.bz2') or archive.name.startswith('aports-'):continue
 with tarfile.open(archive) as tf:
  for member in tf.getmembers():
   base=Path(member.name).name.lower()
   if member.isfile() and (base.startswith(('copying','license','notice','copyright'))):
    target=stage/'licenses'/archive.name/member.name
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(tf.extractfile(member).read())
components={'libusb':'1.0.28-r0 LGPL-2.1-or-later','libsoxr':'0.1.3-r7 LGPL-2.1-or-later','libconfig':'1.7.3-r3 LGPL-2.1-or-later','libpopt':'1.19-r4 MIT','libcrypto':'3.5.9-r0 Apache-2.0','libgomp':'14.2.0-r6 GPL-3.0-or-later WITH GCC-exception-3.1','shairport-sync':'4.3.6 046b59851315f706d8e449fb9305e9f029811a71','libmaru':'9a2ac0635f12485f15d68b90eed3f60ab9a86123 + src/libmaru/device-adaptation.patch LGPL-2.1-or-later'}
(stage/'COMPONENTS.json').write_text(json.dumps(components,indent=2)+'\n')
(stage/'NOTICE.txt').write_text('Experimental device-specific build. New project code has no separate open-source license grant. Upstream copyright and license terms remain applicable. Bundled shared libraries can be replaced in app/lib. Corresponding dependency sources and Alpine recipes are distributed in dependency-sources.tar.gz; local modified sources/build scripts are in the matching project source archive. System musl/Avahi/DBus libraries are external requirements and not included.\n')
rows=[]
for p in sorted(stage.rglob('*')):
 if p.is_file():
  p.chmod(0o644)
  rows.append(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(stage)}')
(stage/'SHA256SUMS').write_text('\n'.join(rows)+'\n')
for rel in ('install.sh','uninstall.sh','app/run.sh','app/maru-player','app/shairport-sync'): (stage/rel).chmod(0o755)
with tarfile.open(out/f'{name}.tar.gz','w:gz') as tf:tf.add(stage,arcname=name)
with tarfile.open(out/'dependency-sources.tar.gz','w:gz') as tf:tf.add(out/'source-inputs',arcname='dependency-sources')
print('Packaged',name)
