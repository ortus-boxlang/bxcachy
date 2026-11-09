import importlib.machinery,json,pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
I=importlib.machinery.SourceFileLoader('icons',str(R/'bin/bxcachy-icons')).load_module()
M=importlib.machinery.SourceFileLoader('menu',str(R/'bin/bxcachy-menu')).load_module()
class IconsTests(unittest.TestCase):
 def test_every_menu_item_has_icon(self):
  for s in json.loads((R/'menu/default.json').read_text())['sections']:
   self.assertTrue(s.get('icon'))
   for i in s['items']:self.assertTrue(i.get('icon'))
 def test_phosphor_names(self):
  self.assertIn('coffee',I.names());self.assertIn('cube',I.names())
 def test_menu_load(self):
  self.assertTrue(any(s['id']=='jvm-toolchain' for s in M.load()))
 def test_safe_icon_fallback(self):
  self.assertEqual(I.resolve('../bad'),'')
if __name__=='__main__':unittest.main()
