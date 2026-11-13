# Release signing

`release.pub` is the Ed25519 public key that verifies BxCachy releases (made with `scripts/gen-signing-key.sh`). The private key is the GitHub secret `BXCACHY_SIGNING_KEY` and never lives in the repository.
