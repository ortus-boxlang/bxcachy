#!/usr/bin/env python3
"""Generates the BxRig brand SVGs (icon, logo, four wallpapers). The mark is drawn here; the Ortus icons in assets/brand/ stay for the Powered by BoxLang note.
Run: python3 assets/build.py && node assets/render.js
Palette: Ortus Brand Book 2025 (main #00FF78, second #00DBFF, accent #FFF500, dark #303446) on Catppuccin Frappe neutrals."""
import base64, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
G1, G2, YEL = "#00FF78", "#00DBFF", "#FFF500"
BASE, MANTLE, CRUST, TEXT, SUB = "#303446", "#292c3c", "#232634", "#c6d0f5", "#a5adce"

def uri(path):
    return "data:image/svg+xml;base64," + base64.b64encode(open(path, 'rb').read()).decode()
BOXLANG, BOXLANG_MONO, MATCHBOX = uri('brand/boxlang-icon-full.svg'), uri('brand/boxlang-icon-mono-dark.svg'), uri('brand/matchbox-icon-full.svg')

def img(href, x, y, size):
    return f'<image href="{href}" x="{x}" y="{y}" width="{size}" height="{size}"/>'

defs = f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{G2}"/><stop offset="1" stop-color="{G1}"/></linearGradient></defs>'
FONT = "font-family=\"Inter, 'Noto Sans', 'DejaVu Sans', sans-serif\""

LAPTOP = uri('brand/bxrig-laptop.svg')

def mark(x, y, size, mono=False):
    """The BxRig mark: the laptop with the BoxLang emblem (assets/brand/bxrig-laptop.svg, drawn by the owner). `size` is its width; it is 4:3.
    mono is kept for callers that wanted a quiet version; the laptop has one look."""
    h = size * 0.75
    return f'<image href="{LAPTOP}" x="{x}" y="{y + (size - h) / 2:.1f}" width="{size}" height="{h:.1f}"/>'
def word(x, y, size, anchor="middle", extra=""):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" {FONT} font-size="{size}" font-weight="700" fill="url(#g)" {extra}>Bx<tspan fill="{TEXT}">Rig</tspan></text>'
def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{defs}{body}</svg>\n'

W, H = 2560, 1440
# app icon: the BxRig laptop on a rounded dark tile
open('icon.svg', 'w').write(svg(256, 256, f'<rect width="256" height="256" rx="56" fill="{BASE}"/>{mark(48, 48, 160)}'))
# logo: icon + wordmark, for dark backgrounds
open('logo.svg', 'w').write(svg(720, 200, f'{mark(14, 20, 160)}{word(200, 124, 96, "start")}'))
# 1 icon: centered icon, wordmark and tagline
open('wallpapers/box.svg', 'w').write(svg(W, H, f'''<defs><radialGradient id="bg" cx="0.5" cy="0.42" r="0.85"><stop offset="0" stop-color="#3a3f58"/><stop offset="0.55" stop-color="{BASE}"/><stop offset="1" stop-color="{CRUST}"/></radialGradient></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
{mark(1280-260, 230, 520)}
{word(1280, 1010, 130)}
<text x="1280" y="1090" text-anchor="middle" {FONT} font-size="34" fill="{SUB}" letter-spacing="9">YOUR DEV RIG. BEAUTIFUL BY DEFAULT.</text>
<text x="1280" y="1370" text-anchor="middle" {FONT} font-size="26" fill="{SUB}" opacity="0.7" letter-spacing="5">BOXLANG  +  MATCHBOX  +  CACHYOS</text>'''))
# 2 grid: perspective grid in the brand gradient
lines = ''
for i in range(-20, 21):
    lines += f'<line x1="{1280+i*60}" y1="800" x2="{1280+i*420}" y2="{H}" stroke="url(#g)" stroke-opacity="0.38" stroke-width="2"/>'
for k in range(1, 12):
    y = 800 + (k / 11) ** 2 * (H - 800)
    lines += f'<line x1="0" y1="{y:.1f}" x2="{W}" y2="{y:.1f}" stroke="url(#g)" stroke-opacity="{0.16+0.03*k:.2f}" stroke-width="2"/>'
open('wallpapers/grid.svg', 'w').write(svg(W, H, f'''<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{CRUST}"/><stop offset="0.55" stop-color="{BASE}"/><stop offset="1" stop-color="{CRUST}"/></linearGradient></defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>{lines}
{mark(1280-170, 180, 340)}
<text x="1280" y="660" text-anchor="middle" {FONT} font-size="62" font-weight="700" fill="{TEXT}" letter-spacing="16">BXRIG</text>'''))
# 3 aurora: soft brand-colour glows, icon and name bottom right
def blob(i, cx, cy, rx, ry, color, op):
    return f'<radialGradient id="a{i}"><stop offset="0" stop-color="{color}" stop-opacity="{op}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient><ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#a{i})"/>'
open('wallpapers/aurora.svg', 'w').write(svg(W, H, f'''<rect width="{W}" height="{H}" fill="{CRUST}"/>
{blob(1, 700, 520, 950, 580, G1, 0.42)}{blob(2, 1800, 900, 1000, 600, G2, 0.42)}{blob(3, 1500, 200, 700, 300, "#ca9ee6", 0.22)}
{mark(2060, 1170, 150)}{word(2040, 1275, 58, "end")}'''))
# 4 minimal: mono icon, nearly flat
open('wallpapers/minimal.svg', 'w').write(svg(W, H, f'''<rect width="{W}" height="{H}" fill="{CRUST}"/>
{mark(1280-170, 420, 340, mono=True)}
<text x="1280" y="900" text-anchor="middle" {FONT} font-size="40" fill="{SUB}" letter-spacing="12">BXRIG</text>'''))
