#!/usr/bin/env python3
"""Optional Android Firebase resources from the GOOGLE_SERVICES_JSON CI secret.
No service-account/private keys belong here. Existing build works without config.
Run after flutter create; equivalent resource values to the Google services plugin.
"""
import json, os, re
from pathlib import Path
from xml.sax.saxutils import escape

def main():
    raw = os.environ.get('GOOGLE_SERVICES_JSON', '').strip()
    if not raw:
        print('Firebase Android configuration missing: remote Push disabled; polling remains available.')
        return
    cfg = json.loads(raw)
    gradle = next(p for p in [Path('android/app/build.gradle.kts'),Path('android/app/build.gradle')] if p.exists())
    match = re.search(r'applicationId\s*(?:=\s*)?[\"\x27]([^\"\x27]+)',gradle.read_text())
    if not match: raise ValueError('Cannot resolve Android applicationId')
    package = match.group(1)
    clients = [c for c in cfg.get('client',[]) if c.get('client_info',{}).get('android_client_info',{}).get('package_name') == package]
    if len(clients)!=1: raise ValueError('Firebase Android package does not match this app')
    client=clients[0]; project=cfg['project_info']
    values={'google_app_id':client['client_info']['mobilesdk_app_id'], 'gcm_defaultSenderId':project['project_number'], 'project_id':project['project_id'], 'google_api_key':client['api_key'][0]['current_key']}
    if project.get('storage_bucket'): values['google_storage_bucket']=project['storage_bucket']
    target=Path('android/app/src/main/res/values/firebase_config.xml');target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'+''.join('  <string name="'+k+'" translatable="false">'+escape(str(v))+'</string>\n' for k,v in values.items())+'</resources>\n')
    print('Firebase Android resources configured for the matching application package.')
if __name__=='__main__': main()
