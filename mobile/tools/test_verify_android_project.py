import contextlib
import io
from pathlib import Path
import shutil
import tempfile
import unittest
from verify_android_project import ANDROID, verify

class AndroidDistributionTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'android'
        shutil.copytree(ANDROID,self.root)

    def test_complete_platform(self):
        with contextlib.redirect_stdout(io.StringIO()): verify(self.root)

    def test_missing_manifest_is_rejected(self):
        (self.root/'app/src/main/AndroidManifest.xml').unlink()
        with self.assertRaisesRegex(ValueError,'AndroidManifest'): verify(self.root)

    def test_v1_embedding_is_rejected(self):
        p=self.root/'app/src/main/AndroidManifest.xml'
        p.write_text(p.read_text().replace('android:value="2"','android:value="1"'))
        with self.assertRaisesRegex(AssertionError,'embedding v2'): verify(self.root)

    def test_missing_network_resource_is_rejected(self):
        (self.root/'app/src/main/res/xml/network_security_config.xml').unlink()
        with self.assertRaisesRegex(ValueError,'network_security_config'): verify(self.root)

    def test_missing_wrapper_is_rejected(self):
        (self.root/'gradle/wrapper/gradle-wrapper.jar').unlink()
        with self.assertRaisesRegex(ValueError,'gradle-wrapper.jar'): verify(self.root)

if __name__=='__main__': unittest.main()
