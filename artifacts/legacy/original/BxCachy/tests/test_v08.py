import importlib.machinery, pathlib, tempfile, unittest, json, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def module(name):return importlib.machinery.SourceFileLoader(name.replace('-','_'),str(ROOT/'bin'/name)).load_module()
class V08(unittest.TestCase):
 def test_catalog(self):
  ids={i['id'] for i in json.loads((ROOT/'catalog/installers.json').read_text())['installers']}
  self.assertTrue({'ai-claude','ai-lmstudio','desktop-clipboard','desktop-screenshot'}<=ids)
 def test_shortcut_conflicts(self):
  m=module('shortcuts');self.assertEqual(m.conflicts({'bindings':[]}),[])
 def test_vm_validation(self):
  m=module('bxcachy-vm');self.assertEqual(m.validate(dict(m.DEFAULT))['cpu'],'4')
  bad=dict(m.DEFAULT,web_port=22)
  with self.assertRaises(ValueError):m.validate(bad)
 def test_theme_palette(self):
  m=module('bxcachy-themes');self.assertIn('tokyo-night',m.THEMES)
 def test_profile_schema(self):
  m=module('bxcachy-profile');self.assertIn('ai.json',m.ALLOWED)
 def test_cli_help(self):
  for command in ('desktop','profile','theme'):
   p=subprocess.run([str(ROOT/'bin/bxcachy'),command,'--help'],capture_output=True,text=True)
   self.assertEqual(p.returncode,0,p.stderr)
if __name__=='__main__':unittest.main()
