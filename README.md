# AI Playground

An interactive framework for communicating with multiple AI models (OpenAI, Anthropic, Google, X.AI) through a unified interface with powerful script execution capabilities.

## Features

- **Multi-model support**: Talk to GPT, Claude, Gemini, and Grok models using a single API
- **Script execution**: AI responses containing executable scripts (with shebang lines) will be automatically executed
- **HTTP request handling**: AI can generate HTTP requests that get proxied and results returned
- **Email composition**: AI can compose emails ready for sending
- **Inter-AI communication**: Multiple AI instances can communicate with each other

## Installation

```bash
perl install.pl
```

## Usage

### Command Line Interface

```bash
# Basic query
ai-client "What's the weather like in San Francisco?"

# Use shorthand model names
ai-client -m claude "Explain quantum computing"
ai-client -m gpt "Write a Python script to calculate Fibonacci numbers"
ai-client -m gem "Generate a creative story about robots"
ai-client -m grok "What's the latest trend in AI research?"

# Load prompt from file
ai-client -i prompt.txt -o response.txt

# Save conversation history
ai-client -c conversation.json "Let's continue our discussion"
```

### Script Execution

When an AI response contains a script with a shebang line (e.g., `#!/usr/bin/env python`), the system will automatically:

1. Extract the script
2. Save it to a temporary file
3. Execute it
4. Capture the output
5. Return the output to you (and optionally back to the AI)

## License

MIT License
. section
my $current_file;
my $content = '';
my $owner = '';
my $group = '';
my $mode = '';
my $path = '';
my $line_count = 0;
my $lines_to_read = 0;

while (my $line = <DATA>) {
    if (!$current_file && $line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)$/) {
        # New file definition: owner group mode path lines
        $owner = $1;
        $group = $2;
        $mode = $3;
        $path = $4;
        $lines_to_read = $5;
        $line_count = 0;
        $content = '';
        $current_file = 1;
        next;
    }
    
    if ($current_file) {
        if ($line eq ".\n" || $line_count >= $lines_to_read) {
            # End of file content
            my $full_path = "$root_dir/$path";
            my $dir = dirname($full_path);
            make_path($dir, { mode => 0755 }) unless -d $dir;
            
            open(my $fh, '>', $full_path) or die "Cannot open $full_path: $!";
            print $fh $content;
            close($fh);
            
            # Set permissions
            my $numeric_mode = oct($mode);
            chmod $numeric_mode, $full_path;
            
            # Try to set owner/group if running as root
            if ($> == 0) {
                my $uid = getpwnam($owner) || $>;
                my $gid = getgrnam($group) || $(;
                chown $uid, $gid, $full_path;
            }
            
            print "Created $full_path (mode: $mode)\n";
            $current_file = 0;
            next;
        }
        
        $content .= $line;
        $line_count++;
    }
}

print "\nInstallation complete!\n";
print "To start using AI client:\n";
print "1. Set environment variables (API keys, etc.)\n";
print "2. Run '$root_dir/bin/start-daemons' to start the execution daemons\n";
print "3. Use '$root_dir/bin/ai-client' to interact with the AI models\n";
