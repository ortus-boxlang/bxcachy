import json, pathlib, subprocess, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
def call(*args):
 return subprocess.run([str(ROOT/'bin/bxcachy'),*args],text=True,capture_output=True,timeout=10)
class V085(unittest.TestCase):
 def test_first_run_plan(self):
  p=call('first-run','plan');self.assertEqual(p.returncode,0,p.stderr);self.assertIn('Base packages',p.stdout)
 def test_desktop_keys_plan(self):
  p=call('desktop-keys','plan');self.assertEqual(p.returncode,0,p.stderr);self.assertIn('SUPER SHIFT',p.stdout)
 def test_apps_categories(self):
  for cat in ('desktop-list','tui-list','web-list'):
   with self.subTest(cat=cat):self.assertEqual(call('apps',cat).returncode,0)
 def test_optional_not_base(self):
  p=call('apps','optional-list');self.assertEqual(p.returncode,0);self.assertIn('obs-studio',p.stdout)
 def test_menu_json(self):
  data=json.loads((ROOT/'menu/default.json').read_text());self.assertTrue(any(s['id']=='system-tools' for s in data['sections']))
if __name__=='__main__':unittest.main()
