import os, pathlib, subprocess, sys, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'bin/provision'
class ProvisionTests(unittest.TestCase):
    def test_plan(self):
        r=subprocess.run([sys.executable,str(SCRIPT),'plan'],capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn('Preserve KDE',r.stdout)
    def test_stage_and_rollback(self):
        with tempfile.TemporaryDirectory() as home:
            env={**os.environ,'HOME':home}
            # stage requires pacman/CachyOS, so test safe behavior via isolated fake pacman.
            binpath=pathlib.Path(home)/'bin'; binpath.mkdir()
            fake=binpath/'pacman'; fake.write_text('#!/bin/sh\nexit 0\n'); fake.chmod(0o755)
            env['PATH']=str(binpath)+':'+os.environ['PATH']
            first=subprocess.run([sys.executable,str(SCRIPT),'stage'],env=env,capture_output=True,text=True)
            self.assertEqual(first.returncode,0,first.stderr)
            config=pathlib.Path(home)/'.config/hypr/omarchy-keys.conf'
            self.assertTrue(config.exists())
            second=subprocess.run([sys.executable,str(SCRIPT),'stage'],env=env,capture_output=True,text=True)
            self.assertEqual(second.returncode,0,second.stderr)
            backups=list((pathlib.Path(home)/'.local/state/cachyos-omarchy-pack/backups').iterdir())
            self.assertEqual(len(backups),1)
            rollback=subprocess.run([sys.executable,str(SCRIPT),'rollback',str(backups[0])],env=env,capture_output=True,text=True)
            self.assertEqual(rollback.returncode,0,rollback.stderr)
            self.assertFalse(config.exists())
    def test_modified_file_protected(self):
        with tempfile.TemporaryDirectory() as home:
            env={**os.environ,'HOME':home}
            binpath=pathlib.Path(home)/'bin'; binpath.mkdir()
            fake=binpath/'pacman'; fake.write_text('#!/bin/sh\nexit 0\n'); fake.chmod(0o755)
            env['PATH']=str(binpath)+':'+os.environ['PATH']
            subprocess.run([sys.executable,str(SCRIPT),'stage'],env=env,check=True,capture_output=True)
            config=pathlib.Path(home)/'.config/hypr/omarchy-keys.conf'
            config.write_text('my changes')
            backup=next((pathlib.Path(home)/'.local/state/cachyos-omarchy-pack/backups').iterdir())
            r=subprocess.run([sys.executable,str(SCRIPT),'rollback',str(backup)],env=env,capture_output=True,text=True)
            self.assertNotEqual(r.returncode,0)
            self.assertEqual(config.read_text(),'my changes')
if __name__=='__main__': unittest.main()
