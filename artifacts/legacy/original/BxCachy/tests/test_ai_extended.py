import json,pathlib,subprocess,tempfile,unittest,os
R=pathlib.Path(__file__).resolve().parent.parent
CLI=str(R/'bin/bxcachy')
class AIExtended(unittest.TestCase):
 def call(self,*args):
  with tempfile.TemporaryDirectory() as td:
   env={**os.environ,'HOME':td}
   return subprocess.run([CLI,'ai',*args],env=env,capture_output=True,text=True)
 def test_config_show(self):
  p=self.call('config','show');self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(json.loads(p.stdout)['agent'],'opencode')
 def test_config_path(self):
  p=self.call('config','path');self.assertEqual(p.returncode,0,p.stderr);self.assertIn('bxcachy/ai.json',p.stdout)
 def test_no_hyprland_dropdown(self):
  p=self.call('dropdown');self.assertNotEqual(p.returncode,0)
 def test_install_preview_claude(self):
  p=self.call('install','claude','--dry-run');self.assertEqual(p.returncode,0,p.stderr)
 def test_install_preview_lmstudio(self):
  p=self.call('install','lmstudio','--dry-run');self.assertEqual(p.returncode,0,p.stderr)
 def test_menu_actions(self):
  data=json.loads((R/'menu/default.json').read_text());items=next(s for s in data['sections'] if s['id']=='ai')['items'];ids={i['id'] for i in items};self.assertTrue({'ai-sessions','ai-config','ai-ollama-service','ai-lms-server'}<=ids)
if __name__=='__main__':unittest.main()
