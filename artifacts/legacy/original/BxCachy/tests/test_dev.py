import json,pathlib,subprocess,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class DevTests(unittest.TestCase):
 def call(self,*args):return subprocess.run([str(ROOT/'bin/bxcachy-dev'),*args],text=True,capture_output=True)
 def test_plan_all(self):
  p=self.call('plan','all');self.assertEqual(p.returncode,0,p.stderr);self.assertIn('matchbox-quick-installer',p.stdout)
 def test_dry_remote(self):
  p=self.call('install','mvm','--dry-run');self.assertEqual(p.returncode,0,p.stderr);self.assertIn('DRY RUN',p.stdout)
 def test_version_validation(self):
  p=self.call('version','mvm','install');self.assertNotEqual(p.returncode,0)
 def test_java_plan(self):
  p=self.call('plan','java','--java-version','21');self.assertIn('jdk21-openjdk',p.stdout)
 def test_menu_entries(self):
  data=json.loads((ROOT/'menu/default.json').read_text());ids={x['id'] for s in data['sections'] for x in s['items']};self.assertTrue({'install-sdkman','install-java21','install-bvm','install-mvm'}<=ids)
if __name__=='__main__':unittest.main()
