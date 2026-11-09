import importlib.machinery
import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

PATH = pathlib.Path(__file__).resolve().parents[1] / 'bin/bxcachy-extras'
loader = importlib.machinery.SourceFileLoader('bxcachy_extras', str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)

class TestExtras(unittest.TestCase):
    def test_wrapper_contents(self):
        self.assertIn('exec podman "$@"', mod.WRAPPERS['docker'])
        self.assertIn('exec podman-compose "$@"', mod.WRAPPERS['docker-compose'])
    def test_preserve_existing_neovim(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mod, 'NVIM', pathlib.Path(tmp)):
                mod.lazyvim('install')
    def test_plan_does_not_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mod, 'BIN', pathlib.Path(tmp) / 'bin'):
                with patch.object(mod.shutil, 'which', return_value=None):
                    mod.aliases('plan')
                self.assertFalse((pathlib.Path(tmp) / 'bin').exists())
    def test_install_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mod, 'BIN', pathlib.Path(tmp) / 'bin'):
                with patch.object(mod.shutil, 'which', return_value=None):
                    mod.aliases('install')
                    mod.aliases('install')
                self.assertEqual((mod.BIN / 'docker').read_text(), mod.WRAPPERS['docker'])
    def test_existing_wrapper_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mod, 'BIN', pathlib.Path(tmp)):
                (mod.BIN / 'docker').write_text('original')
                with patch.object(mod.shutil, 'which', return_value=None):
                    mod.aliases('install')
                self.assertEqual((mod.BIN / 'docker').read_text(), 'original')

if __name__ == '__main__': unittest.main()
