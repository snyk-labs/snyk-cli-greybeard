package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Build information (set by linker flags)
var (
	Version   = "dev"
	BuildTime = "unknown"
)

// OpenAIRequest represents the request to OpenAI API
type OpenAIRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Temperature float64   `json:"temperature"`
}

// Message represents a message in the OpenAI chat
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// OpenAIResponse represents the response from OpenAI API
type OpenAIResponse struct {
	ID      string `json:"id"`
	Object  string `json:"object"`
	Created int64  `json:"created"`
	Choices []struct {
		Index   int `json:"index"`
		Message struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

func main() {
	// Handle version flag
	if len(os.Args) > 1 && (os.Args[1] == "-v" || os.Args[1] == "--version") {
		fmt.Printf("Snyk CLI Greybeard v%s (built %s)\n", Version, BuildTime)
		os.Exit(0)
	}

	// Check for OpenAI API key
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		fmt.Println("Error: OPENAI_API_KEY environment variable is not set.")
		fmt.Println("Please set it with: export OPENAI_API_KEY='your-api-key'")
		os.Exit(1)
	}

	// Check if Snyk CLI is available
	if !isCommandAvailable("snyk") {
		fmt.Println("Error: 'snyk' command not found. Please install the Snyk CLI.")
		fmt.Println("Visit https://docs.snyk.io/snyk-cli/install-the-snyk-cli for installation instructions.")
		os.Exit(1)
	}

	// Execute Snyk command with all passed arguments
	snykOutput, exitCode := executeSnyk(os.Args[1:])

	// Print the raw Snyk output first
	fmt.Println("\n\033[1mRaw Snyk CLI Output:\033[0m")
	fmt.Println(snykOutput)

	// Add a separator
	fmt.Println("\n-----------------------------------------------------------\n")

	// If output is empty, provide a message
	if strings.TrimSpace(snykOutput) == "" {
		snykOutput = "No output returned from Snyk CLI. This could be due to a successful run with no findings or an error."
	}

	// Define the prompt for the grumpy security expert
	systemPrompt := "You are a grumpy, experienced security 'greybeard' with decades of experience. You're tired of seeing the same security mistakes over and over again. Transform the Snyk CLI output into a response that sounds like it's coming from an irritated, knowledgeable security expert who's seen it all. Be condescending yet educational, frustrated yet helpful. Use colorful language (but keep it professional), analogies, and references that an old-school sysadmin might use. FOCUS ONLY ON THE IMPORTANT SECURITY FINDINGS AND VULNERABILITIES - ignore any trivial warnings, licensing issues, or boilerplate messages unless they have actual security implications. Provide context on why the vulnerabilities matter and what could happen if they're exploited. Keep it concise but impactful."

	// Call OpenAI API
	greybeardResponse, err := callOpenAI(apiKey, systemPrompt, snykOutput)
	if err != nil {
		fmt.Printf("🧔‍♂️ \033[1mSecurity Greybeard says:\033[0m\n\n")
		fmt.Printf("Error calling OpenAI API: %v\n", err)
		os.Exit(exitCode)
	}

	// Print the transformed response
	fmt.Printf("🧔‍♂️ \033[1mSecurity Greybeard says:\033[0m\n\n")
	fmt.Println(greybeardResponse)

	// Exit with the same exit code as the Snyk command
	os.Exit(exitCode)
}

// isCommandAvailable checks if a command is available in PATH
func isCommandAvailable(command string) bool {
	_, err := exec.LookPath(command)
	return err == nil
}

// executeSnyk executes the Snyk CLI with given arguments and returns its output and exit code
func executeSnyk(args []string) (string, int) {
	// Create command with snyk
	cmd := exec.Command("snyk", args...)

	// Capture both stdout and stderr
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	// Run the command
	cmd.Run()

	// Combine stdout and stderr
	output := stdout.String() + stderr.String()

	// Return output and exit code
	return output, cmd.ProcessState.ExitCode()
}

// callOpenAI sends a request to the OpenAI API and returns the response
func callOpenAI(apiKey, systemPrompt, snykOutput string) (string, error) {
	// Create request body
	requestBody := OpenAIRequest{
		Model: "gpt-4o",
		Messages: []Message{
			{
				Role:    "system",
				Content: systemPrompt,
			},
			{
				Role:    "user",
				Content: "Here is the Snyk CLI output:\n" + snykOutput,
			},
		},
		Temperature: 0.7,
	}

	// Marshal request body to JSON
	jsonBytes, err := json.Marshal(requestBody)
	if err != nil {
		return "", fmt.Errorf("error marshaling JSON: %v", err)
	}

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// Create request
	req, err := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewBuffer(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("error creating HTTP request: %v", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	// Send request
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("error calling OpenAI API: %v", err)
	}
	defer resp.Body.Close()

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("error reading API response: %v", err)
	}

	// Parse response
	var openAIResp OpenAIResponse
	if err := json.Unmarshal(body, &openAIResp); err != nil {
		return "", fmt.Errorf("error parsing API response: %v (response: %s)", err, string(body))
	}

	// Check for API error
	if openAIResp.Error.Message != "" {
		return "", fmt.Errorf("API error: %s", openAIResp.Error.Message)
	}

	// Check if we have choices
	if len(openAIResp.Choices) == 0 {
		return "", fmt.Errorf("no response content returned from API (response: %s)", string(body))
	}

	// Return content
	return openAIResp.Choices[0].Message.Content, nil
}
