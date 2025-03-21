# snyk-cli-greybeard

Want to make your security findings feel more "real"? We're excited to announce the official public release of Snyk CLI Greybeard edition! Unlike the normal Snyk CLI which will help you find security issues in your code, containers, dependencies, and IaC, this special "Greybeard" edition of the CLI will give you the same information, but with much more personality.

Snyk Greybeard is experienced, knowledgeable, and tired of your security ignorance. Greybeard has a more sarcastic, dry, and endearing grumpiness that transforms your boring security scans into a heated roast, with lots of fun commentary to brighten your day.

## Installation

### Option 1: One-line Installer (Linux, macOS, Windows)

The easiest way to install is with the following command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/snyk-labs/snyk-cli-greybeard/refs/heads/main/install.sh)"
```

This will download and install the latest version for your platform. You'll still need to set your OpenAI API key after installation.

### Option 2: Download pre-built binary

Download the appropriate binary for your platform from the [Releases](https://github.com/snyk-labs/snyk-cli-greybeard/releases) page.

### Option 3: Build from source

#### Prerequisites
1. [Go](https://golang.org/doc/install) (1.22.5 or later)
2. [Snyk CLI](https://docs.snyk.io/snyk-cli/install-the-snyk-cli)
3. OpenAI API key

#### Building Steps
1. Clone this repository:
   ```
   git clone https://github.com/snyk-labs/snyk-cli-greybeard.git
   cd snyk-cli-greybeard
   ```

2. Build and install:
   ```
   # Build for your current platform
   go build -o greybeard
   
   # Or build and install to your system (platform-aware)
   make install  # May require sudo on Linux/macOS
   
   # Or cross-compile for multiple platforms
   make compile
   ```

   **Platform-specific installation details:**
   - **Linux/macOS**: Installs to `/usr/local/bin/greybeard`
   - **Windows**: Installs to `%APPDATA%\snyk-cli-greybeard\greybeard.exe` and provides instructions for adding to PATH

3. Set your OpenAI API key as an environment variable:
   ```
   # Linux/macOS
   export OPENAI_API_KEY='your-api-key'
   
   # Windows
   setx OPENAI_API_KEY "your-api-key"
   ```

## Usage

Use `greybeard` exactly as you would use the regular `snyk` command:

```
./greybeard test
./greybeard test --json
./greybeard container test alpine:latest
```

Check the version:
```
./greybeard --version
```

The tool will:
1. Run the Snyk CLI with all your arguments
2. Display the raw Snyk CLI output first
3. Follow with a grumpy security expert's commentary on the important findings

## Example Output

```
Raw Snyk CLI Output:
[The original Snyk CLI output appears here]

-----------------------------------------------------------

🧔‍♂️ Security Greybeard says:

Listen up, youngster! I see you've got a critical RCE vulnerability in that package. 
Back in my day, we'd have been fired for leaving something this obvious in production. 
You better fix this ASAP unless you want your servers to become someone else's bitcoin miner...
```

## Features

- Displays both raw Snyk output and Greybeard commentary
- Focuses on important security findings and ignores noise
- Proper handling of command timeouts
- Robust JSON parsing
- Same exit codes as the original Snyk command
- Colorful output formatting
- Cross-platform support (Linux, macOS, Windows)

## Development

### Requirements
- Go 1.22.5+
- Snyk CLI
- OpenAI API key
- Make (for using the Makefile)

### Makefile Commands
The included Makefile provides several useful targets:

```
make compile    # Cross-compile for all platforms
make install    # Build and install to the system (platform-specific)
make clean      # Clean build artifacts
make help       # Show help information
```

Individual platform targets:
```
make linux-amd64
make linux-arm64
make darwin-amd64
make darwin-arm64
make windows-amd64
make windows-arm64
```

## License

MIT
