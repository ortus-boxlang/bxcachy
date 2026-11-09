import importlib.machinery, pathlib, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
mod=importlib.machinery.SourceFileLoader('bxcachy_runner_092',str(ROOT/'bin/bxcachy-runner')).load_module()
class RunnerTests(unittest.TestCase):
 def test_menu_providers(self):
  self.assertTrue({'vicinae','hyprrunner','rofi','walker'}<=mod.MENU_PROVIDERS)
 def test_menu_commands(self):
  data={'runner':{}}
  self.assertEqual(mod.menu_command('vicinae',data,'Apps')[0],'vicinae')
  self.assertEqual(mod.menu_command('hyprrunner',data,'Apps')[0],'hyprrunner')
 def test_override(self):
  data={'runner':{'menu_commands':{'vicinae':['test-menu','--title','{prompt}']}}}
  self.assertEqual(mod.menu_command('vicinae',data,'My Apps'),['test-menu','--title','My Apps'])
 def test_launcher(self):
  self.assertEqual(mod.resolve('vicinae',{'runner':{}}),['vicinae','toggle'])
 def test_bad_command(self):
  with self.assertRaises(ValueError):mod.menu_command('vicinae',{'runner':{'menu_commands':{'vicinae':'bad'}}},'Apps')
if __name__=='__main__':unittest.main()
