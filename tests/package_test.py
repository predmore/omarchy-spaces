import json,re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class PackageTests(unittest.TestCase):
    def test_manifest_and_license(self):
        manifest=json.loads((ROOT/'manifest.json').read_text())
        self.assertEqual(manifest['id'],'predmore.spaces')
        self.assertEqual(manifest['schemaVersion'],1)
        for value in manifest['entryPoints'].values():
            self.assertFalse(Path(value).is_absolute())
            self.assertNotIn('..',Path(value).parts)
            self.assertTrue((ROOT/value).is_file())
        self.assertIn('MIT License',(ROOT/'LICENSE').read_text())
    def test_text_sinks_are_plain(self):
        for file in ROOT.glob('*.qml'):
            # Every QML Text in this plugin is a leaf with no nested QML objects.
            for block in re.findall(r'\bText\s*\{([^{}]*)\}',file.read_text(),re.S):
                self.assertRegex(block,r'textFormat:\s*Text.PlainText',f'{file.name}: unsafe Text sink')
    def test_package_has_no_local_capture_or_absolute_home_paths(self):
        for file in ROOT.rglob('*'):
            if '.git' in file.parts or '__pycache__' in file.parts:continue
            self.assertFalse(file.is_symlink(),f'Symlink: {file}')
            if not file.is_file():continue
            self.assertNotIn(file.suffix.lower(),{'.png','.jpg','.jpeg','.mp4','.qslog'},f'Unexpected desktop capture: {file}')
            text=file.read_text()
            self.assertNotRegex(text,r'/home/[a-zA-Z][^/\s]*/',f'Personal absolute home path: {file}')
            if file.suffix in {'.qml','.js','.lua'} and file.parent==ROOT:
                self.assertNotIn('caleb.overview',text)
if __name__=='__main__':unittest.main()
