# Release signing

`release.pub` is the Ed25519 public key that verifies BxRig releases (made with `scripts/gen-signing-key.sh`). The private key is the GitHub secret `BXRIG_SIGNING_KEY` and never lives in the repository.
