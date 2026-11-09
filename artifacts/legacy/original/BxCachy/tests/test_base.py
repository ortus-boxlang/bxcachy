import pathlib, subprocess, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class BaseTests(unittest.TestCase):
 def test_plan_does_not_install(self):
  p=subprocess.run([str(ROOT/'bin/bxcachy'),'base','plan'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0,p.stderr)
  self.assertIn('jdk21-openjdk',p.stdout)
  self.assertIn('Plan only',p.stdout)
 def test_requires_consent(self):
  p=subprocess.run([str(ROOT/'bin/bxcachy'),'base','install'],capture_output=True,text=True)
  self.assertNotEqual(p.returncode,0)
 def test_doctor(self):
  p=subprocess.run([str(ROOT/'bin/bxcachy'),'base','doctor'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0)
