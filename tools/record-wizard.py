#!/usr/bin/env python3
"""Records the wizard: runs it in a pseudo-terminal, plays scripted keystrokes, emulates the screen with pyte and
draws every frame with Pillow, then encodes a video (and a GIF) with ffmpeg.
Usage: python3 wizard/record.py [--out DIR] [--cols 120] [--rows 36] [--shots]   (needs Pillow, pyte, ffmpeg)"""
import argparse, codecs, os, pty, select, struct, fcntl, termios, time, subprocess, sys, shutil
import pyte
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))  # tools/
ap = argparse.ArgumentParser()
ap.add_argument('--out', default=os.path.join(here, '..', 'recording'))
ap.add_argument('--cols', type=int, default=120)
ap.add_argument('--rows', type=int, default=36)
ap.add_argument('--fps', type=int, default=12)
ap.add_argument('--bin', default='bxrig')
ap.add_argument('--pages')
ap.add_argument('--shots', action='store_true', help='also save a PNG of the last frame of each step')
args = ap.parse_args()

KEYS = {'enter': '\r', 'down': '\x1b[B', 'up': '\x1b[A', 'left': '\x1b[D', 'right': '\x1b[C', 'space': ' ', 'tab': '\t', 'esc': '\x1b', 'backtab': '\x1b[Z'}
# scenario: (seconds to wait after, action). action is a key name, or "text:..." typed char by char
SCENARIO = [
    (2.4, 'wait'),
    (0.5, 'enter'),
    (1.2, 'down'), (0.8, 'down'), (0.9, 'up'),          # desktop: browse the options
    (0.8, 'space'), (0.8, 'enter'),
    (0.8, 'down'), (0.8, 'space'), (0.9, 'enter'),      # window style
    (0.7, 'right'), (0.6, 'right'), (0.6, 'left'), (0.8, 'enter'),   # workspaces
    (1.2, 'enter'),                                      # look: theme
    (0.8, 'down'), (0.8, 'down'), (0.8, 'space'), (0.9, 'enter'),    # wallpaper
    (1.2, 'down'), (0.6, 'down'), (0.6, 'space'), (0.7, 'down'), (0.6, 'down'), (0.6, 'space'), (0.9, 'enter'),  # layouts
    (0.8, 'space'), (0.8, 'down'), (0.7, 'space'), (1.0, 'tab'),   # input toggles
    (0.9, 'text:Luis Majano'), (0.6, 'enter'), (0.2, 'text:luis@example.com'), (0.7, 'enter'),   # developer
    (0.8, 'down'), (0.8, 'space'), (0.8, 'enter'), (0.8, 'space'), (1.0, 'tab'),
    (1.1, 'down'), (0.7, 'down'), (0.7, 'space'), (0.9, 'tab'),     # toolchains
    (1.2, 'down'), (0.9, 'space'), (1.0, 'down'), (0.6, 'down'), (0.6, 'space'), (0.9, 'tab'),   # containers: podman vs docker, databases
    (1.0, 'tab'), (1.0, 'tab'),                          # apps, extras
    (1.2, 'down'), (0.8, 'space'), (0.9, 'tab'),
    (3.0, 'wait'),                                       # review
    (0.8, 'enter'),
]

cols, rows = args.cols, args.rows
os.makedirs(args.out, exist_ok=True)
frames_dir = os.path.join(args.out, 'frames')
shutil.rmtree(frames_dir, ignore_errors=True); os.makedirs(frames_dir)

# --- run the wizard in a pty and capture timestamped output ---
pid, fd = pty.fork()
if pid == 0:
    env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor')
    cmd = [args.bin, 'wizard', '--pages=' + args.pages, '--out=/dev/null'] if args.pages else [args.bin, 'wizard', '--demo']
    os.execvpe(cmd[0], cmd, env)
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
for delay, action in SCENARIO:
    if not alive: break
    if action.startswith('text:'):
        for ch in action[5:]:
            os.write(fd, ch.encode()); alive = pump(time.time() + 0.07)
    elif action != 'wait':
        os.write(fd, KEYS[action].encode())
    alive = pump(time.time() + delay)
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

n = int(total * args.fps) + 1
idx = 0
for i in range(n):
    t = i / args.fps
    while idx < len(chunks) and chunks[idx][0] <= t:
        stream.feed(decoder.decode(chunks[idx][1])); idx += 1
    draw_frame(os.path.join(frames_dir, f'f{i:05d}.png'))
print('frames', n, 'size', W, 'x', H)

# --- encode ---
mp4 = os.path.join(args.out, 'bxrig-wizard.mp4'); gif = os.path.join(args.out, 'bxrig-wizard.gif')
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-c:v','libx264','-pix_fmt','yuv420p','-crf','20',mp4], check=True)
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate',str(args.fps),'-i',os.path.join(frames_dir,'f%05d.png'),'-vf','scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse','-loop','0',gif], check=True)
print('wrote', mp4, gif)
