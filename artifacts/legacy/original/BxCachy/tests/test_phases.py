import importlib.machinery,json,pathlib,subprocess,sys,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class PhaseTests(unittest.TestCase):
 def test_catalog_valid(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/bxcachy-catalog'),'validate'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0,p.stderr)
 def test_catalog_lists_all_tools(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/bxcachy-catalog'),'list'],capture_output=True,text=True,check=True)
  for key in ('podman','sdkman','java21','maven','gradle','boxlang','bvm','mvm','windows-vm'):self.assertIn(key,p.stdout)
 def test_catalog_dry_run(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/bxcachy-catalog'),'plan','windows-vm'],capture_output=True,text=True)
  self.assertEqual(p.returncode,0,p.stderr);self.assertIn('podman run',p.stdout)
 def test_vm_plan_has_local_ports(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/bxcachy-vm'),'plan'],capture_output=True,text=True,check=True)
  self.assertIn('127.0.0.1:8006:8006',p.stdout)
 def test_vm_remove_does_not_delete_data(self):
  s=(ROOT/'bin/bxcachy-vm').read_text();self.assertNotIn('shutil.rmtree',s)
 def test_config_plan_is_read_only(self):
  p=subprocess.run([sys.executable,str(ROOT/'bin/bxcachy-config'),'plan'],capture_output=True,text=True,check=True)
  self.assertIn('bxcachy-keys.conf',p.stdout)
 def test_menu_ids_unique(self):
  d=json.loads((ROOT/'menu/default.json').read_text());ids=[x['id'] for x in d['sections']]
  self.assertEqual(len(ids),len(set(ids)))
  for section in d['sections']:
   names=[x['id'] for x in section['items']];self.assertEqual(len(names),len(set(names)))
 def test_dispatcher_has_new_actions(self):
  p=(ROOT/'bin/bxcachy').read_text()
  for x in ('vm','config','catalog'):self.assertIn("'"+x+"'",p)
if __name__=='__main__':unittest.main()
