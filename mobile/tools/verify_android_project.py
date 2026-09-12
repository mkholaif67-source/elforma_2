#!/usr/bin/env python3
"""Check the distributed Android platform before Flutter/Gradle or packaging."""
from pathlib import Path
import hashlib
import re
import sys
import wave
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'android'
NS = '{http://schemas.android.com/apk/res/android}'

def verify(root=ANDROID):
    required = ['settings.gradle.kts', 'build.gradle.kts', 'gradle.properties',
                'gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar',
                'gradle/wrapper/gradle-wrapper.properties', 'app/build.gradle.kts',
                'app/src/main/AndroidManifest.xml',
                'app/src/main/kotlin/com/elforma/elforma/MainActivity.kt',
                'app/src/main/res/xml/network_security_config.xml']
    missing = [name for name in required if not (root / name).is_file()]
    if missing:
        raise ValueError('Android platform incomplete: ' + ', '.join(missing))
    manifest = ET.parse(root / 'app/src/main/AndroidManifest.xml').getroot()
    app = manifest.find('application')
    assert app is not None, 'Missing Android application'
    assert any(n.get(NS+'name')=='flutterEmbedding' and n.get(NS+'value')=='2'
               for n in app.findall('meta-data')), 'Flutter Android embedding v2 is required'
    activity = app.find('activity')
    assert activity is not None and activity.get(NS+'name')=='.MainActivity'
    assert activity.get(NS+'exported')=='true'
    kotlin=(root / 'app/src/main/kotlin/com/elforma/elforma/MainActivity.kt').read_text()
    assert 'io.flutter.embedding.android.FlutterActivity' in kotlin
    assert 'package com.elforma.elforma' in kotlin
    gradle=(root / 'app/build.gradle.kts').read_text()
    assert 'namespace = "com.elforma.elforma"' in gradle
    assert 'applicationId = "com.elforma.elforma"' in gradle
    assert 'isCoreLibraryDesugaringEnabled = true' in gradle
    assert 'desugar_jdk_libs:2.1.4' in gradle
    resources=root/'app/src/main/res'
    styles={node.get('name') for file in resources.glob('values*/*.xml')
            for node in ET.parse(file).getroot() if node.tag=='style'}
    assert {'LaunchTheme','NormalTheme'} <= styles
    # Every local XML resource referenced by the manifest must be packaged.
    for node in manifest.iter():
        for value in node.attrib.values():
            match=re.fullmatch(r'@(xml|drawable|mipmap)/([a-z0-9_]+)',value)
            if match:
                kind,name=match.groups()
                assert any(resources.glob(f'{kind}*/{name}.*')),f'Missing resource {value}'
    for file in resources.rglob('*.xml'): ET.parse(file)
    for name in ['reminder_alert','workout_alert','promo_alert']:
        with wave.open(str(resources/'raw'/f'{name}.wav')) as sound:
            assert sound.getnframes()>0, f'Empty notification sound {name}'
    jar=root/'gradle/wrapper/gradle-wrapper.jar'
    assert hashlib.sha256(jar.read_bytes()).hexdigest()=='7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172', 'Unexpected Gradle 8.14 wrapper'
    with zipfile.ZipFile(jar) as archive:
        assert archive.testzip() is None
        assert 'org/gradle/wrapper/GradleWrapperMain.class' in archive.namelist()
    print('Android platform verified: embedding v2, resources, notification audio, Gradle wrapper and app identity')

if __name__=='__main__':
    try: verify()
    except (AssertionError,ValueError,ET.ParseError) as error:
        sys.exit(f'FAIL: {error}')
