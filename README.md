# snyk-cli-greybeard

Want to make your security findings feel more "real"? We're excited to announce the official public release of Snyk CLI Greybeard edition! Unlike the normal Snyk CLI which will help you find security issues in your code, containers, dependencies, and IaC, this special "Greybeard" edition of the CLI will give you the same information, but with much more personality.

Snyk Greybeard is experienced, knowledgeable, and tired of your security ignorance. Greybeard has a more sarcastic, dry, and endearing grumpiness that transforms your boring security scans into a heated roast, with lots of fun commentary to brighten your day.

## Installation

### Prerequisites
1. [Go](https://golang.org/doc/install) (1.19 or later)
2. [Snyk CLI](https://docs.snyk.io/snyk-cli/install-the-snyk-cli)
3. OpenAI API key

### Installation Steps
1. Clone this repository:
   ```
   git clone https://github.com/snyk-labs/snyk-cli-greybeard.git
   cd snyk-cli-greybeard
   ```

2. Build the executable:
   ```
   go build -o greybeard
   ```

3. Set your OpenAI API key as an environment variable:
   ```
   export OPENAI_API_KEY='your-api-key'
   ```

4. (Optional) Add to your PATH for easier access:
   ```
   sudo mv greybeard /usr/local/bin/
   ```

## Usage

Use `greybeard` exactly as you would use the regular `snyk` command:

```
./greybeard test
./greybeard test --json
./greybeard container test alpine:latest
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

## Requirements

- Go 1.19+
- Snyk CLI
- OpenAI API key

## License

MIT
