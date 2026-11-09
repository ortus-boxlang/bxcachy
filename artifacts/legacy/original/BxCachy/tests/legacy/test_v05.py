import json, pathlib, subprocess, sys, tempfile, os, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Tests(unittest.TestCase):
 def call(self,*args,home=None):
  env=os.environ.copy(); env['HOME']=str(home or self.home)
  return subprocess.run([sys.executable,str(ROOT/'bin/shortcuts'),*args],env=env,text=True,capture_output=True)
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(); self.home=pathlib.Path(self.temp.name)
 def tearDown(self):self.temp.cleanup()
 def test_default_valid(self):self.assertEqual(self.call('validate').returncode,0)
 def test_generate_and_repeat(self):
  self.assertEqual(self.call('generate').returncode,0)
  path=self.home/'.config/hypr/cachyos-omarchy-keys.conf'; before=path.read_bytes()
  self.assertEqual(self.call('generate').returncode,0);self.assertEqual(path.read_bytes(),before)
 def test_set_binding(self):
  self.assertEqual(self.call('set','menu','SUPER+ALT','M').returncode,0)
  self.assertIn('SUPER ALT, M', (self.home/'.config/hypr/cachyos-omarchy-keys.conf').read_text())
 def test_duplicate_rejected(self):
  self.assertNotEqual(self.call('set','menu','SUPER','SPACE').returncode,0)
 def test_unmanaged_protected(self):
  path=self.home/'.config/hypr/cachyos-omarchy-keys.conf';path.parent.mkdir(parents=True);path.write_text('my bindings')
  self.assertNotEqual(self.call('generate').returncode,0);self.assertEqual(path.read_text(),'my bindings')
 def test_no_kde_files(self):
  self.assertEqual(self.call('generate').returncode,0)
  self.assertFalse((self.home/'.config/kglobalshortcutsrc').exists())
if __name__=='__main__':unittest.main()
