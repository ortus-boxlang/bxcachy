import json,pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ExpandedCatalogTests(unittest.TestCase):
 def test_entries(self):
  apps=json.loads((ROOT/'catalog/apps.json').read_text())['apps'];self.assertGreaterEqual(len(apps),300);self.assertEqual(len(apps),len({a['id'] for a in apps}))
 def test_new_omarchy(self):
  a={x['id']:x for x in json.loads((ROOT/'catalog/apps.json').read_text())['apps']}
  for x in ('hype','signed','disktree','monologue','gliff','elsewhen','omacut','omasnap','superwhisper'):self.assertIn(x,a);self.assertFalse(a[x]['default'])
 def test_existing_optional(self):
  a={x['id']:x for x in json.loads((ROOT/'catalog/apps.json').read_text())['apps']}
  for x in ('obs','kdenlive','pinta','chromium','obsidian','libreoffice'):self.assertFalse(a[x]['default'])
if __name__=='__main__':unittest.main()
