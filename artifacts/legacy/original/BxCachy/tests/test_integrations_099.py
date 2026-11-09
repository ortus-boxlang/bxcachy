import importlib.util,pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Integrations(unittest.TestCase):
 def test_dispatch(self):
  s=(ROOT/'bin/bxcachy').read_text();self.assertIn("'cloud-services':'bxcachy-cloud-services'",s);self.assertIn("'integrations':'bxcachy-integrations'",s)
 def test_safe_cloud_names(self):
  spec=importlib.util.spec_from_file_location('cloud_services',ROOT/'bin/bxcachy-cloud-services');m=__import__('types').ModuleType('cloud_services');exec((ROOT/'bin/bxcachy-cloud-services').read_text().split("if __name__=='__main__':")[0],m.__dict__);self.assertEqual(m.safe('drive_1'),'drive_1')
  for s in ('../etc','hello world','x/abc'):
   with self.assertRaises(ValueError):m.safe(s)
 def test_service_menu(self):
  s=(ROOT/'integrations/dolphin/bxcachy-quicklook.desktop').read_text();self.assertIn('Exec=bxcachy-quicklook %f',s)
 def test_default_dictation(self):
  s=(ROOT/'bin/bxcachy-dictation').read_text();self.assertIn("else 'superwhisper'",s);self.assertIn('voxtype',s)
