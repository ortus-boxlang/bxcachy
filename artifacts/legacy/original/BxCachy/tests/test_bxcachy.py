import json,os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Tests(unittest.TestCase):
 def runbin(self,name,*args,home=None):
  env=os.environ.copy();env['HOME']=str(home or pathlib.Path.home())
  return subprocess.run([str(ROOT/'bin'/name),*args],capture_output=True,text=True,env=env)
 def test_default_runner_system(self):
  with tempfile.TemporaryDirectory() as d:
   r=self.runbin('bxcachy-runner','show',home=d);self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(json.loads(r.stdout)['provider'],'system')
 def test_runner_provider_changes(self):
  with tempfile.TemporaryDirectory() as d:
   self.assertEqual(self.runbin('bxcachy-runner','set','rofi',home=d).returncode,0)
   self.assertEqual(json.loads(self.runbin('bxcachy-runner','show',home=d).stdout)['provider'],'rofi')
 def test_system_launch_noninvasive(self):
  with tempfile.TemporaryDirectory() as d:
   r=self.runbin('bxcachy-runner','launch',home=d);self.assertEqual(r.returncode,2)
 def test_shortcuts_exclude_launcher(self):
  with tempfile.TemporaryDirectory() as d:
   r=self.runbin('shortcuts','list',home=d);self.assertEqual(r.returncode,0,r.stderr);self.assertNotIn('launcher',r.stdout)
 def test_shortcut_generation_is_separate(self):
  with tempfile.TemporaryDirectory() as d:
   r=self.runbin('shortcuts','generate',home=d);self.assertEqual(r.returncode,0,r.stderr)
   p=pathlib.Path(d)/'.config/hypr/bxcachy-keys.conf';self.assertTrue(p.exists());self.assertIn('SUPER ALT, SPACE',p.read_text());self.assertFalse((pathlib.Path(d)/'.config/hypr/hyprland.conf').exists())
 def test_json_catalogs(self):
  for p in (ROOT/'config').glob('*.json'):json.loads(p.read_text())
  json.loads((ROOT/'menu/default.json').read_text())
if __name__=='__main__':unittest.main()
