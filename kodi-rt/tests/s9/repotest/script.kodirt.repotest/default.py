# kodi-rt: installs Kodi's binary add-ons from Kodi's own repository (the way x64/x86 users get them: our desktop
# builds don't ship them) and enables them; enabling a PVR client makes Kodi load its DLL at once. Results go to
# special://home/repotest-result.json and "kodi-rt repotest:" lines in kodi.log. Used by
# tests/s9/repo-addons-test.ps1.
import json
import time

import xbmc
import xbmcvfs

IDS = ['inputstream.adaptive', 'pvr.iptvsimple', 'inputstream.ffmpegdirect', 'inputstream.rtmp', 'vfs.rar',
       'vfs.libarchive']


def log(msg):
    xbmc.log('kodi-rt repotest: ' + msg, xbmc.LOGINFO)


def rpc(method, params):
    return json.loads(xbmc.executeJSONRPC(json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params})))


res = {}
for aid in IDS:
    t = time.time()
    if not xbmc.getCondVisibility('System.HasAddon(%s)' % aid):
        xbmc.executebuiltin('InstallAddon(%s)' % aid)
        while time.time() - t < 180 and not xbmc.getCondVisibility('System.HasAddon(%s)' % aid):
            if xbmc.getCondVisibility('Window.IsVisible(yesnodialog)'):
                xbmc.executebuiltin('SendClick(yesnodialog,11)')
            xbmc.sleep(500)
    res[aid] = {'installed': xbmc.getCondVisibility('System.HasAddon(%s)' % aid), 'seconds': round(time.time() - t, 1)}
    log('%s installed: %s' % (aid, res[aid]['installed']))
for aid in IDS:
    if not res[aid]['installed']:
        continue
    res[aid]['enable'] = rpc('Addons.SetAddonEnabled', {'addonid': aid, 'enabled': True}).get('result')
xbmc.sleep(5000)
for aid in IDS:
    d = rpc('Addons.GetAddonDetails', {'addonid': aid, 'properties': ['enabled', 'version', 'path']})
    res[aid]['details'] = d.get('result', {}).get('addon') or d.get('error')
    log('%s: %s' % (aid, json.dumps(res[aid])))
out = xbmcvfs.translatePath('special://home/repotest-result.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(res, f, indent=1)
log('done, results in ' + out)
