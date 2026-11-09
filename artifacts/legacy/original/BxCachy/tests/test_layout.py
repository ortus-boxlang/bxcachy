import importlib.machinery, importlib.util, pathlib, unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
loader=importlib.machinery.SourceFileLoader('bxcachy_layout',str(ROOT/'bin/bxcachy-layout'))
spec=importlib.util.spec_from_loader(loader.name,loader)
mod=importlib.util.module_from_spec(spec);loader.exec_module(mod)
class LayoutTests(unittest.TestCase):
 def test_window_toggle(self):
  with patch.object(mod,'dispatch') as dispatch:
   with patch('sys.argv',['bxcachy-layout','window','toggle']):mod.main()
   dispatch.assert_called_once_with('togglefloating')
 def test_workspace_float(self):
  clients=[{'address':'0xabc','floating':False},{'address':'0xdef','floating':True}]
  with patch.object(mod,'workspace_clients',return_value=clients),patch.object(mod,'dispatch') as dispatch:
   mod.workspace_mode('float');dispatch.assert_called_once_with('setfloating','address:0xabc')
 def test_workspace_tile(self):
  clients=[{'address':'0xabc','floating':True},{'address':'0xdef','floating':False}]
  with patch.object(mod,'workspace_clients',return_value=clients),patch.object(mod,'dispatch') as dispatch:
   mod.workspace_mode('tile');dispatch.assert_called_once_with('settiled','address:0xabc')
 def test_workspace_toggle_mixed_goes_float(self):
  clients=[{'address':'0xabc','floating':True},{'address':'0xdef','floating':False}]
  with patch.object(mod,'workspace_clients',return_value=clients),patch.object(mod,'dispatch') as dispatch:
   mod.workspace_mode('toggle');dispatch.assert_called_once_with('setfloating','address:0xdef')
 def test_workspace_toggle_all_float_goes_tile(self):
  clients=[{'address':'0xabc','floating':True}]
  with patch.object(mod,'workspace_clients',return_value=clients),patch.object(mod,'dispatch') as dispatch:
   mod.workspace_mode('toggle');dispatch.assert_called_once_with('settiled','address:0xabc')
if __name__=='__main__':unittest.main()
