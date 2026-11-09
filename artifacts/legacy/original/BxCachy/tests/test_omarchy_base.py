import importlib.machinery
import importlib.util
import pathlib
import unittest
from unittest.mock import patch

PATH = pathlib.Path(__file__).resolve().parents[1] / 'bin/bxcachy-omarchy-base'
loader = importlib.machinery.SourceFileLoader('omarchy_base', str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

class OmarchyBaseTests(unittest.TestCase):
    def test_package_uniqueness(self):
        self.assertEqual(len(module.packages()), len(set(module.packages())))
    def test_core_packages(self):
        for name in ('github-cli', 'lazygit', 'tmux', 'fzf', 'ripgrep', 'wl-clipboard', 'grim', 'wf-recorder'):
            self.assertIn(name, module.packages())
    @patch.object(module.shutil, 'which', return_value='/usr/bin/pacman')
    @patch.object(module, 'installed', return_value=False)
    def test_plan_never_installs(self, *_):
        with patch.object(module.subprocess, 'run') as run:
            self.assertEqual(module.main(['plan']), 0)
            run.assert_not_called()
    @patch.object(module.shutil, 'which', return_value='/usr/bin/pacman')
    @patch.object(module, 'installed', return_value=True)
    def test_installed_noop(self, *_):
        with patch.object(module.subprocess, 'run') as run:
            self.assertEqual(module.main(['install', '--yes']), 0)
            run.assert_not_called()
