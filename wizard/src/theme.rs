//! Colours: Catppuccin Frappe neutrals with the Ortus brand gradient (cyan #00DBFF to green #00FF78).
use ratatui::style::Color;

pub const BASE: Color = Color::Rgb(0x30, 0x34, 0x46);
pub const MANTLE: Color = Color::Rgb(0x29, 0x2c, 0x3c);
pub const CRUST: Color = Color::Rgb(0x23, 0x26, 0x34);
pub const SURFACE0: Color = Color::Rgb(0x41, 0x45, 0x59);
pub const SURFACE1: Color = Color::Rgb(0x51, 0x57, 0x6d);
pub const OVERLAY: Color = Color::Rgb(0x73, 0x79, 0x94);
pub const TEXT: Color = Color::Rgb(0xc6, 0xd0, 0xf5);
pub const SUB: Color = Color::Rgb(0xa5, 0xad, 0xce);
pub const GREEN: Color = Color::Rgb(0x00, 0xff, 0x78);
pub const CYAN: Color = Color::Rgb(0x00, 0xdb, 0xff);
pub const YELLOW: Color = Color::Rgb(0xe5, 0xc8, 0x90);
pub const RED: Color = Color::Rgb(0xe7, 0x82, 0x84);

fn rgb(c: Color) -> (f32, f32, f32) {
    match c {
        Color::Rgb(r, g, b) => (r as f32, g as f32, b as f32),
        _ => (255.0, 255.0, 255.0),
    }
}

/// Linear blend of two colours, t in 0..=1.
pub fn lerp(a: Color, b: Color, t: f32) -> Color {
    let (a, b, t) = (rgb(a), rgb(b), t.clamp(0.0, 1.0));
    Color::Rgb((a.0 + (b.0 - a.0) * t) as u8, (a.1 + (b.1 - a.1) * t) as u8, (a.2 + (b.2 - a.2) * t) as u8)
}

/// The brand gradient at t in 0..=1 (cyan to green).
pub fn gradient(t: f32) -> Color {
    lerp(CYAN, GREEN, t)
}

/// A gradient that sweeps back and forth, for shimmer: position x of width w at animation phase.
pub fn shimmer(x: f32, w: f32, phase: f32) -> Color {
    let base = (x / w.max(1.0)).clamp(0.0, 1.0);
    let band = (1.0 - ((x / w.max(1.0)) - phase).abs() * 4.0).clamp(0.0, 1.0);
    lerp(gradient(base), Color::Rgb(0xff, 0xff, 0xff), band * 0.45)
}
