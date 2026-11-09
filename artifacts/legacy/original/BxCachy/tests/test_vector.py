import pathlib, subprocess, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
CLI=ROOT/'bin/bxcachy-vector'
class VectorTests(unittest.TestCase):
 def test_doctor(self):
  p=subprocess.run([str(CLI),'doctor'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0)
  self.assertIn('Milvus',p.stdout)
 def test_help(self):
  p=subprocess.run([str(CLI),'--help'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0)
  self.assertIn('pgvector',p.stdout)
 def test_dispatch(self):
  p=subprocess.run([str(ROOT/'bin/bxcachy'),'vector','doctor'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0)
if __name__=='__main__':unittest.main()
