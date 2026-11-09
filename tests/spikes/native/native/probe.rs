// Native Fusion probe: the file operations a safe config writer needs, done in Rust (std + one crate)
// instead of shelling out. BIFs use the manual signature so they can return strings and numbers.
use matchbox_vm::types::{BxNativeFunction, BxValue, BxVM};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

/// Strings are created through the VM: `BxValue::new_ptr(vm.string_new(..))` (there is no `new_string`).
fn string(vm: &mut dyn BxVM, value: String) -> BxValue {
    BxValue::new_ptr(vm.string_new(value))
}

fn text(vm: &mut dyn BxVM, args: &[BxValue], i: usize, name: &str) -> Result<String, String> {
    if args.len() <= i {
        return Err(format!("{}: missing argument {}", name, i + 1));
    }
    Ok(vm.to_string(args[i]))
}

/// 1 = symlink, 0 = something else, -1 = does not exist. Never follows the link.
pub fn bx_is_symlink(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let p = text(vm, args, 0, "bxIsSymlink")?;
    let v = match fs::symlink_metadata(&p) {
        Ok(m) => if m.file_type().is_symlink() { 1.0 } else { 0.0 },
        Err(_) => -1.0,
    };
    Ok(BxValue::new_number(v))
}

/// Permission bits as an octal string, for example "644".
pub fn bx_file_mode(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let p = text(vm, args, 0, "bxFileMode")?;
    let m = fs::metadata(&p).map_err(|e| format!("bxFileMode: {}: {}", p, e))?;
    Ok(string(vm, format!("{:o}", m.permissions().mode() & 0o7777)))
}

pub fn bx_read_text(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let p = text(vm, args, 0, "bxReadText")?;
    let s = fs::read_to_string(&p).map_err(|e| format!("bxReadText: {}: {}", p, e))?;
    Ok(string(vm, s))
}

pub fn bx_count_files(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let p = text(vm, args, 0, "bxCountFiles")?;
    let n = fs::read_dir(&p).map_err(|e| format!("bxCountFiles: {}: {}", p, e))?.count();
    Ok(BxValue::new_number(n as f64))
}

pub fn bx_sha256(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let p = text(vm, args, 0, "bxSha256")?;
    let bytes = fs::read(&p).map_err(|e| format!("bxSha256: {}: {}", p, e))?;
    Ok(string(vm, format!("{:x}", Sha256::digest(&bytes))))
}

/// Atomic replace: write a temp file in the same directory, flush it to disk, set the mode,
/// then rename over the destination. Refuses to write through a symlink.
pub fn bx_write_atomic(vm: &mut dyn BxVM, args: &[BxValue]) -> Result<BxValue, String> {
    let path = text(vm, args, 0, "bxWriteAtomic")?;
    let content = text(vm, args, 1, "bxWriteAtomic")?;
    let mode = text(vm, args, 2, "bxWriteAtomic")?;
    let bits = u32::from_str_radix(&mode, 8).map_err(|_| format!("bxWriteAtomic: invalid mode {}", mode))?;
    let dest = Path::new(&path);
    if let Ok(m) = fs::symlink_metadata(dest) {
        if m.file_type().is_symlink() {
            return Err(format!("bxWriteAtomic: refusing to write through a symlink: {}", path));
        }
    }
    let dir = dest.parent().filter(|d| !d.as_os_str().is_empty()).unwrap_or_else(|| Path::new("."));
    let tmp = dir.join(format!(".bxcachy.{}.tmp", std::process::id()));
    let result = (|| -> std::io::Result<()> {
        let mut f = fs::File::create(&tmp)?;
        f.write_all(content.as_bytes())?;
        f.sync_all()?;
        fs::set_permissions(&tmp, fs::Permissions::from_mode(bits))?;
        fs::rename(&tmp, dest)
    })();
    if let Err(e) = result {
        let _ = fs::remove_file(&tmp);
        return Err(format!("bxWriteAtomic: {}: {}", path, e));
    }
    Ok(string(vm, "ok".to_string()))
}

pub fn register_bifs() -> HashMap<String, BxNativeFunction> {
    let mut map = HashMap::new();
    map.insert("bxIsSymlink".to_string(), bx_is_symlink as BxNativeFunction);
    map.insert("bxFileMode".to_string(), bx_file_mode as BxNativeFunction);
    map.insert("bxReadText".to_string(), bx_read_text as BxNativeFunction);
    map.insert("bxCountFiles".to_string(), bx_count_files as BxNativeFunction);
    map.insert("bxSha256".to_string(), bx_sha256 as BxNativeFunction);
    map.insert("bxWriteAtomic".to_string(), bx_write_atomic as BxNativeFunction);
    map
}
