//! bxcachy-wizard: the BxCachy setup wizard. It shows pages from a JSON file and writes the answers as JSON.
//! It runs nothing itself; `bxcachy init` starts it and acts on the answers.
//!
//!   bxcachy-wizard --pages FILE --out FILE [--answers FILE]
//!   bxcachy-wizard --demo [--out FILE]
//!
//! Exit codes: 0 answers written, 130 cancelled (nothing written), 2 usage error, 1 failure.
mod app;
mod art;
mod demo;
mod model;
mod theme;
mod ui;

use app::{App, Outcome};
use ratatui::crossterm::event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyEventKind, MouseButton, MouseEventKind};
use ratatui::crossterm::execute;
use std::collections::BTreeMap;
use std::time::Duration;
use std::{fs, io, process};

fn usage() -> ! {
    eprintln!("Usage: bxcachy-wizard --pages FILE --out FILE [--answers FILE]\n       bxcachy-wizard --demo [--out FILE]");
    process::exit(2);
}

fn read_json<T: serde::de::DeserializeOwned>(path: &str) -> T {
    let text = fs::read_to_string(path).unwrap_or_else(|e| {
        eprintln!("bxcachy-wizard: cannot read {path}: {e}");
        process::exit(1);
    });
    serde_json::from_str(&text).unwrap_or_else(|e| {
        eprintln!("bxcachy-wizard: {path} is not valid: {e}");
        process::exit(1);
    })
}

fn main() {
    let mut pages = None;
    let mut out = None;
    let mut answers = None;
    let mut demo = false;
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--pages" => pages = args.next(),
            "--out" => out = args.next(),
            "--answers" => answers = args.next(),
            "--demo" => demo = true,
            _ => usage(),
        }
    }
    if !demo && (pages.is_none() || out.is_none()) {
        usage();
    }
    let spec = if demo { demo::spec() } else { read_json(pages.as_deref().unwrap()) };
    let preset: BTreeMap<String, serde_json::Value> = answers.as_deref().map(read_json).unwrap_or_default();
    let mut app = App::new(spec, preset);

    let mut terminal = ratatui::init();
    let _ = execute!(io::stdout(), EnableMouseCapture);
    let result = run(&mut terminal, &mut app);
    let _ = execute!(io::stdout(), DisableMouseCapture);
    ratatui::restore();

    if let Err(e) = result {
        eprintln!("bxcachy-wizard: {e}");
        process::exit(1);
    }
    match app.outcome {
        Outcome::Done => {
            if let Some(path) = out {
                if let Err(e) = fs::write(&path, app.answers_json() + "\n") {
                    eprintln!("bxcachy-wizard: cannot write {path}: {e}");
                    process::exit(1);
                }
            }
        }
        _ => process::exit(130),
    }
}

fn run(terminal: &mut ratatui::DefaultTerminal, app: &mut App) -> io::Result<()> {
    while app.outcome == Outcome::Running {
        terminal.draw(|f| ui::draw(f, app))?;
        if event::poll(Duration::from_millis(50))? {
            match event::read()? {
                Event::Key(k) if k.kind == KeyEventKind::Press => app.on_key(k),
                Event::Mouse(m) if m.kind == MouseEventKind::Down(MouseButton::Left) => app.on_click(m.column, m.row),
                _ => {}
            }
        }
        app.tick += 1;
    }
    Ok(())
}
