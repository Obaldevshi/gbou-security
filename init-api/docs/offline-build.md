# Offline Python dependencies for Timeweb

The Docker build installs only CPython 3.12/Linux x86_64 wheels from
`deploy-wheels`, using `--no-index --require-hashes`. It does not upgrade pip
or contact PyPI. Base-image and Debian package downloads still require network.
The native wheelhouse is **not** for Raspberry/ARM or Windows.

To deliberately refresh it, update `constraints-production.txt` to the tested
API versions and run `python tools/prepare_api_wheels.py` from the repository.
The generator fetches official PyPI wheels, validates published SHA-256 values,
and generates `deploy-wheels/requirements.lock`. Keep the wheel files intact,
including their bundled third-party licences. Review the complete artifact and
its offline dependency-resolution check before committing a new bundle.

References: [pip download](https://pip.pypa.io/en/stable/cli/pip_download/),
[hash-checked installs](https://pip.pypa.io/en/stable/topics/secure-installs/).
