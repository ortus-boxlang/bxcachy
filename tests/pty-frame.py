# Runs a command in a pseudo-terminal of COLSxROWS for a moment, presses q, prints what it drew. Usage: pty-frame.py BINARY COLS ROWS ARGS...
import os, pty, sys, select, struct, fcntl, termios, time
binary, cols, rows, *args = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvpe(binary, [binary, *args], dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor', LANG='C.UTF-8', BXRIG_ICONS='off'))
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', int(rows), int(cols), 0, 0))
out = b''; end = time.time() + 2.5
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.05)
    if r:
        try: d = os.read(fd, 65536)
        except OSError: break
        if not d: break
        out += d
try: os.write(fd, b'q')
except OSError: pass
time.sleep(0.3)
try: os.kill(pid, 9)
except OSError: pass
sys.stdout.write(out.decode('utf-8', 'replace'))
