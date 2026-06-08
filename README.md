# PrintX iOS Flutter Port

This is a Flutter iOS port scaffold of the current PrintX Android receipt logic.

## GitHub Actions IPA build

The workflow lives at `.github/workflows/ios_build.yml` and runs:

```bash
flutter build ipa --release --no-codesign
```

Upload this project to a GitHub repository, enable **Settings → Actions → General → Workflow permissions → Read and write permissions**, then run **iOS IPA Build** from the Actions tab.

The generated IPA is unsigned and must be signed/sideloaded using your chosen iOS workflow.
