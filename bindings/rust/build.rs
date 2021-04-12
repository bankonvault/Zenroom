extern crate bindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rustc-link-lib=static=zenroom");
    println!("cargo:rustc-link-lib=static=lua");
    println!("cargo:rustc-link-search=../../build_meson");
    println!("cargo:rustc-link-lib=static=amcl_bls_BLS383");
    println!("cargo:rustc-link-lib=static=amcl_core");
    println!("cargo:rustc-link-lib=static=amcl_curve_BLS383");
    println!("cargo:rustc-link-lib=static=amcl_curve_SECP256K1");
    println!("cargo:rustc-link-lib=static=amcl_pairing_BLS383");
    println!("cargo:rustc-link-search=../../build_meson/milagro-crypto-c/lib");

    println!("cargo:rerun-if-changed=wrapper.h");

    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .clang_arg("-I../../src")
        .clang_arg("-I../../build_meson")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}