import json,pathlib,subprocess,unittest
R=pathlib.Path(__file__).resolve().parent.parent
class AITest(unittest.TestCase):
 def test_shortcut(self):
  data=json.loads((R/'config/shortcuts.json').read_text());self.assertEqual(len([x for x in data['bindings'] if x['id']=='ai-console']),1)
 def test_menu(self):
  data=json.loads((R/'menu/default.json').read_text());self.assertIn('ai',[s['id'] for s in data['sections']])
 def test_catalog(self):
  data=json.loads((R/'catalog/installers.json').read_text());self.assertIn('ai-codex',[x['id'] for x in data['installers']])
 def test_doctor(self):
  p=subprocess.run([str(R/'bin/bxcachy'),'ai','doctor'],capture_output=True,text=True);self.assertEqual(p.returncode,0,p.stderr)
 def test_shortcuts_validate(self):
  p=subprocess.run([str(R/'bin/shortcuts'),'validate'],capture_output=True,text=True);self.assertEqual(p.returncode,0,p.stderr)
if __name__=='__main__':unittest.main()
