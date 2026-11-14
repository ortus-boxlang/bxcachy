#!/usr/bin/env python3
"""Records BxTimeMachine (bxrig timemachine --demo): runs it in a pseudo-terminal, plays scripted keystrokes, emulates the screen with pyte and
draws every frame with Pillow, then encodes a video (and a GIF) with ffmpeg.
Usage: python3 tools/record-timemachine.py [--out DIR] [--cols 120] [--rows 38] [--bin PATH]   (needs Pillow, pyte, ffmpeg)"""
import argparse, codecs, os, pty, select, struct, fcntl, termios, time, subprocess, sys, shutil
import pyte
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))  # tools/
ap = argparse.ArgumentParser()
ap.add_argument('--out', default=os.path.join(here, '..', 'recording', 'timemachine'))
ap.add_argument('--cols', type=int, default=120)
ap.add_argument('--rows', type=int, default=38)
ap.add_argument('--fps', type=int, default=12)
ap.add_argument('--bin', default='bxrig')
ap.add_argument('--shots', action='store_true', help='also save a PNG of the last frame of each step')
args = ap.parse_args()

KEYS = {'enter': '\r', 'down': '\x1b[B', 'up': '\x1b[A', 'left': '\x1b[D', 'right': '\x1b[C', 'space': ' ', 'tab': '\t', 'esc': '\x1b', 'backtab': '\x1b[Z', 'bs': '\x7f'}
# scenario: (seconds to wait after, action[, screenshot name]). action is a key name, "wait", or "text:..." typed char by char
SCENARIO = [
    (2.2, 'wait', '01-timeline'),
    (0.7, 'left'), (0.7, 'left'), (0.7, 'left'), (0.9, 'left'),          # back through the system snapshots
    (0.9, 'down'), (0.9, 'down'), (0.8, 'left'), (0.8, 'left'), (0.8, 'left'),   # to the NAS files, a few backups back
    (1.4, 'wait', '02-nas-card'),
    (0.9, '-'), (1.5, 'wait', '03-zoomed-out'), (0.9, '-'), (1.2, '+'), (0.9, '+'),
    (0.9, 'enter'), (1.6, 'wait', '04-browse'),
    (0.5, 'down'), (0.5, 'down'), (0.5, 'down'),
    (0.7, '/'), (0.35, 'text:tax'), (1.4, 'wait', '05-filter'),
    (0.8, 'esc'), (0.8, 'esc'),
    (0.9, 'r'), (1.8, 'wait', '06-restore-plan'), (0.7, 'n'),
    (0.9, 's'), (1.5, 'wait', '07-send'), (0.7, 'esc'),
    (0.8, 'down'), (0.8, 'down'), (0.9, 'left'), (1.4, 'wait', '08-cloud-and-usb'),
    (0.8, '?'), (1.8, 'wait', '09-help'), (0.7, 'x'),
    (0.8, 'right'), (0.8, 'right'), (1.5, 'wait'),
    (0.5, 'q'),
]

cols, rows = args.cols, args.rows
os.makedirs(args.out, exist_ok=True)
frames_dir = os.path.join(args.out, 'frames')
shutil.rmtree(frames_dir, ignore_errors=True); os.makedirs(frames_dir)

# --- run the wizard in a pty and capture timestamped output ---
pid, fd = pty.fork()
if pid == 0:
    env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor')
    cmd = [args.bin, 'timemachine', '--demo']
    os.execvpe(cmd[0], cmd, dict(env, LANG='C.UTF-8'))
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
t0 = time.time(); chunks = []
def pump(until):
    while time.time() < until:
        r, _, _ = select.select([fd], [], [], 0.02)
        if r:
            try: data = os.read(fd, 65536)
            except OSError: return False
            if not data: return False
            chunks.append((time.time() - t0, data))
    return True
alive = pump(t0 + 0.8)
shots = []
for step in SCENARIO:
    delay, action = step[0], step[1]
    if not alive: break
    if action.startswith('text:'):
        for ch in action[5:]:
            os.write(fd, ch.encode()); alive = pump(time.time() + 0.12)
    elif action != 'wait':
        os.write(fd, (KEYS.get(action) or action).encode())
    alive = pump(time.time() + delay)
    if len(step) > 2: shots.append((step[2], time.time() - t0))
pump(time.time() + 0.5)
total = chunks[-1][0] if chunks else 1
try: os.waitpid(pid, os.WNOHANG)
except ChildProcessError: pass
print(f'captured {len(chunks)} chunks over {total:.1f}s')

# --- render frames ---
FS = 18
def font(path, size=FS):
    return ImageFont.truetype(path, size)
JB = '/usr/share/fonts/truetype/jetbrains-mono/'
f_reg = font(JB + 'JetBrainsMono-Regular.ttf'); f_bold = font(JB + 'JetBrainsMono-Bold.ttf')
f_fb = font('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'); f_fbb = font('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf')
bbox = f_reg.getbbox('M'); cw = int(round(f_reg.getlength('M'))); ch_h = int(FS * 1.25)
W, H = cols * cw, rows * ch_h
cache = {}
def has_glyph(f, c):
    key = (id(f), c)
    if key not in cache:
        try:
            m = f.getmask(c); cache[key] = m.getbbox() is not None or c == ' '
        except Exception: cache[key] = False
    return cache[key]
NAMED = {'black':(0,0,0),'red':(205,49,49),'green':(13,188,121),'brown':(229,229,16),'blue':(36,114,200),'magenta':(188,63,188),'cyan':(17,168,205),'white':(229,229,229),
         'brightblack':(102,102,102),'brightred':(241,76,76),'brightgreen':(35,209,139),'brightbrown':(245,245,67),'brightblue':(59,142,234),'brightmagenta':(214,112,214),'brightcyan':(41,184,219),'brightwhite':(255,255,255)}
DEF_FG, DEF_BG = (0xc6,0xd0,0xf5), (0x30,0x34,0x46)
def color(c, default):
    if c == 'default': return default
    if c in NAMED: return NAMED[c]
    if len(c) == 6:
        try: return (int(c[0:2],16), int(c[2:4],16), int(c[4:6],16))
        except ValueError: pass
    return default

screen = pyte.Screen(cols, rows); stream = pyte.Stream(screen)
decoder = codecs.getincrementaldecoder('utf-8')('replace')
def draw_frame(path):
    img = Image.new('RGB', (W, H), DEF_BG); d = ImageDraw.Draw(img)
    for y in range(rows):
        line = screen.buffer[y]
        for x in range(cols):
            c = line[x]
            bg = color(c.bg, DEF_BG); fgc = color(c.fg, DEF_FG)
            if c.reverse: bg, fgc = fgc, bg
            if bg != DEF_BG: d.rectangle([x*cw, y*ch_h, (x+1)*cw, (y+1)*ch_h], fill=bg)
            if c.data != ' ':
                f = f_bold if c.bold else f_reg
                if not has_glyph(f, c.data): f = f_fbb if c.bold else f_fb
                d.text((x*cw, y*ch_h + 1), c.data, font=f, fill=fgc)
    img.save(path)

shots_dir = os.path.join(args.out, 'screenshots'); os.makedirs(shots_dir, exist_ok=True)
for f in os.listdir(shots_dir): os.remove(os.path.join(shots_dir, f))
shot_times = sorted(shots, key=lambda s: s[1])
n = int(total * args.fps) + 1
idx = 0; si = 0
for i in range(n):
    t = i / args.fps
    while idx < len(chunks) and chunks[idx][0] <= t:
        stream.feed(decoder.decode(chunks[idx][1])); idx += 1
    draw_frame(os.path.join(frames_dir, f'f{i:05d}.png'))
    while si < len(shot_times) and shot_times[si][1] <= t + 1 / args.fps:
        shutil.copy(os.path.join(frames_dir, f'f{i:05d}.png'), os.path.join(shots_dir, shot_times[si][0] + '.png')); si += 1
print('frames', n, 'size', W, 'x', H, 'screenshots', len(os.listdir(shots_dir)))

# --- encode ---
mp4 = os.path.join(args.out, 'bxrig-timemachine.mp4'); gif = os.path.join(args.out, 'bxrig-timemachine.gif')
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-c:v','libx264','-pix_fmt','yuv420p','-crf','20',mp4], check=True)
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-vf','scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer',gif], check=True)
shutil.rmtree(frames_dir, ignore_errors=True)
print('wrote', mp4, gif)
