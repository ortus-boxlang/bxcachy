import importlib.machinery,importlib.util,pathlib,unittest,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def load(name):
 path=ROOT/'bin'/name
 loader=importlib.machinery.SourceFileLoader(name.replace('-','_'),str(path))
 spec=importlib.util.spec_from_loader(loader.name,loader)
 mod=importlib.util.module_from_spec(spec);loader.exec_module(mod);return mod
class IntegrationTests(unittest.TestCase):
 def test_safe_cloud_remote_names(self):
  m=load('bxcachy-cloud-services')
  for name in ['drive','my_drive','my-drive','S3']:self.assertEqual(m.safe(name),name)
  for name in ['../bad','bad name','bad:remote','', 'a'*65]:
   with self.assertRaises(ValueError):m.safe(name)
 def test_systemd_unit(self):
  m=load('bxcachy-cloud-services');s=m.render('drive','/usr/bin/rclone','/usr/bin/fusermount3')
  self.assertIn('Type=simple',s);self.assertIn('Restart=on-failure',s)
  self.assertIn('ExecStart=/usr/bin/rclone mount drive:',s)
  self.assertIn('WantedBy=default.target',s)
 def test_installer_idempotent_and_collision_safe(self):
  m=load('bxcachy-integrations')
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);src=p/'src';dst=p/'dst';src.write_text('v1')
   m.copy_owned(src,dst);m.copy_owned(src,dst)
   dst.write_text('custom')
   with self.assertRaises(RuntimeError):m.copy_owned(src,dst)
 def test_dolphin_service_menu(self):
  m=load('bxcachy-integrations');s=m.SERVICE.read_text()
  self.assertIn('Exec=bxcachy-quicklook %f',s)
  self.assertIn('Type=Service',s)
if __name__=='__main__':unittest.main()
