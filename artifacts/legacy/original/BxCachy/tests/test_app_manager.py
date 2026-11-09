import importlib.machinery,pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
mod=importlib.machinery.SourceFileLoader('appmanager',str(ROOT/'bin/bxcachy-app-manager')).load_module()
class AppManagerTests(unittest.TestCase):
 def test_catalog_large_and_unique(self):
  apps=mod.catalog();self.assertGreaterEqual(len(apps),120);self.assertEqual(len(apps),len({a['id'] for a in apps}))
 def test_three_kinds(self):self.assertEqual({a['kind'] for a in mod.catalog()},{'desktop','tui','web'})
 def test_search(self):self.assertIn('lazygit',[a['id'] for a in mod.filter_apps(mod.catalog(),search='lazygit')])
 def test_optional_apps(self):
  apps={a['id']:a for a in mod.catalog()}
  for name in ('obs','kdenlive','pinta','chromium','obsidian','libreoffice'):self.assertFalse(apps[name]['default'])
 def test_base_apps(self):
  apps={a['id']:a for a in mod.catalog()}
  for name in ('localsend','mpv','neovim','lazygit','btop'):self.assertTrue(apps[name]['default'])
 def test_web_url_restriction(self):
  for bad in ('javascript:alert(1)','http://example.com','https://user:pass@example.com','https://foo.com\nExec=evil'):
   with self.assertRaises(ValueError):mod.safe_url(bad)
 def test_web_launcher(self):
  a={x['id']:x for x in mod.catalog()}['github'];s=mod.desktop_file(a)
  self.assertIn('Exec=chromium --app=https://github.com',s)
 def test_invalid_ids(self):
  with self.assertRaises(ValueError):mod.find(mod.catalog(),['not-an-app'])
if __name__=='__main__':unittest.main()
