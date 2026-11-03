# Installer source choice

There is intentionally no independently compiled NSIS fallback in r3.
The official PortableApps.com Installer 3.9.22 is downloaded, checked against a
vendor-published SHA-256, extracted using 7-Zip and invoked with the staged
portable application's full directory path. A validated `.paf.exe` is emitted
only if that original vendor tool succeeds. Otherwise the fully verified
ready-to-extract PortableApps ZIP remains the sole release artifact.

No generic NSIS installer is renamed or described as a certified official PAF.
