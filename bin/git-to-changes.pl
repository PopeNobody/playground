#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use strict;
use warnings;
use common::sense;
use Nobody::Util;
use Path::Tiny;
use Getopt::WonderBra;
use Time::Piece;
use Text::Wrap;

our(@VERSION) = qw( 0 1 0 );

# Configuration
my %cfg = (
  output => 'Changes',
  since => '',
  format => '%ad [%h] %an: %s%n%b',
  date_format => '%Y-%m-%d %H:%M:%S',
  sections => 1,
  skip_pattern => '^\s*x\s*$',
  replace_x => 'Minor changes',
  commit_count => 0,
  repo_path => '.',
  line_width => 78,  # Maximum line width for wrapped text
);

sub help {
  print <<HELP;
Usage: $0 [options]

Exports git logs to a Changes file in a formatted way.

Options:
  -o, --output FILE       Output file (default: Changes)
  -s, --since DATE        Only include commits since DATE (e.g., '1 week ago', '2023-01-01')
  -f, --format FORMAT     Git log format (default: '$cfg{format}')
  -d, --date-format FMT   Date format for git log (default: '$cfg{date_format}')
  --no-sections           Don't add version sections (just append all logs)
  --skip-pattern REGEX    Skip commits matching this pattern (default: '$cfg{skip_pattern}')
  --replace-x TEXT        Replace 'x' commits with this text (default: '$cfg{replace_x}')
  -p, --path PATH         Path to git repository (default: current directory)
  -w, --width WIDTH       Maximum line width (default: $cfg{line_width})
  -h, --help              Show this help message
  -v, --version           Show version information

Examples:
  $0 --since '1 week ago'
  $0 --output CHANGELOG.md --date-format '%Y-%m-%d'
HELP
  exit(0);
}

sub version {
  print "$0 version ", join('.', @VERSION), "\n";
  exit(0);
}

# Parse command line options
@ARGV = getopt("o:s:f:d:p:w:hv", @ARGV);
while (@ARGV && $ARGV[0] ne '--') {
  my $arg = shift @ARGV;
  if ($arg eq '-o' || $arg eq '--output') {
    $cfg{output} = shift @ARGV;
  } elsif ($arg eq '-s' || $arg eq '--since') {
    $cfg{since} = shift @ARGV;
  } elsif ($arg eq '-f' || $arg eq '--format') {
    $cfg{format} = shift @ARGV;
  } elsif ($arg eq '-d' || $arg eq '--date-format') {
    $cfg{date_format} = shift @ARGV;
  } elsif ($arg eq '-w' || $arg eq '--width') {
    $cfg{line_width} = shift @ARGV;
  } elsif ($arg eq '--no-sections') {
    $cfg{sections} = 0;
  } elsif ($arg eq '--skip-pattern') {
    $cfg{skip_pattern} = shift @ARGV;
  } elsif ($arg eq '--replace-x') {
    $cfg{replace_x} = shift @ARGV;
  } elsif ($arg eq '-p' || $arg eq '--path') {
    $cfg{repo_path} = shift @ARGV;
  } elsif ($arg eq '-h' || $arg eq '--help') {
    help();
  } elsif ($arg eq '-v' || $arg eq '--version') {
    version();
  } else {
    die "Unknown option: $arg\n";
  }
}

# Get current HEAD commit
my $head_commit = qx(cd $cfg{repo_path} && git rev-parse --short HEAD);
chomp $head_commit;

# Get current version from a VERSION file, if it exists
my $version = '';
if (-e "$cfg{repo_path}/VERSION") {
  $version = path("$cfg{repo_path}/VERSION")->slurp;
  chomp $version;
} else {
  # Try to find version in other common files
  my @version_files = qw(lib/*/VERSION lib/VERSION);
  for my $file (@version_files) {
    my @matches = glob("$cfg{repo_path}/$file");
    if (@matches && -e $matches[0]) {
      $version = path($matches[0])->slurp;
      chomp $version;
      last;
    }
  }
}

# Get version from package if still not found
if (!$version) {
  for my $file (glob("$cfg{repo_path}/lib/*/*.pm")) {
    my $content = path($file)->slurp;
    if ($content =~ /\$VERSION\s*=\s*['"]?([0-9\.]+)['"]?/) {
      $version = $1;
      last;
    }
  }
}

$version ||= 'development';

# Build git log command
my $since_opt = $cfg{since} ? "--since='$cfg{since}'" : "";
my $git_cmd = "cd $cfg{repo_path} && git log --date=format:'$cfg{date_format}' --pretty=format:'$cfg{format}' $since_opt";
my @log_entries = qx($git_cmd);

# Set up line wrapping
$Text::Wrap::columns = $cfg{line_width};

# Count commits and filter out empty/skipped ones
my @filtered_entries;
my $skip_pattern = qr/$cfg{skip_pattern}/;
foreach my $entry (@log_entries) {
  # Skip empty lines at the beginning of entries
  next if $entry =~ /^\s*$/;
  
  # Replace 'x' commits with better description
  if ($entry =~ $skip_pattern) {
    $entry =~ s/$skip_pattern/$cfg{replace_x}/g;
  }
  
  # Wrap long lines
  $entry = wrap('', '    ', $entry);
  
  push @filtered_entries, $entry;
  $cfg{commit_count}++;
}

# Read existing Changes file, if any
my $changes_file = path($cfg{output});
my $existing_content = '';
if (-e $changes_file) {
  $existing_content = $changes_file->slurp;
}

# Format the output
my $now = localtime->strftime('%Y-%m-%d %H:%M:%S');
my $output = '';

if ($cfg{sections} && $cfg{commit_count} > 0) {
  $output = "Version $version ($now) [$head_commit]\n\n";
  $output .= join("\n", @filtered_entries);
  $output .= "\n\n";
  $output .= $existing_content;
} else {
  # Just append the new entries at the beginning
  $output = join("\n", @filtered_entries);
  $output .= "\n\n";
  $output .= $existing_content;
}

# Write the output file
$changes_file->spew($output);
print "Exported $cfg{commit_count} git commits to $cfg{output}\n";

# Add an entry in the git config to use this script
if (!$ENV{NO_GIT_CONFIG}) {
  my $script_path = path($0)->absolute;
  my $hook_cmd = "cd $cfg{repo_path} && git config --local alias.changelog '!$script_path'";
  system($hook_cmd);
  print "Added git alias: You can now use 'git changelog' to update your Changes file\n";
  
  # Offer to set up a post-commit hook
  print "Would you like to set up a post-commit hook to automatically update the Changes file? [y/N] ";
  my $response = <STDIN>;
  chomp $response;
  if (lc($response) eq 'y') {
    my $hooks_dir = "$cfg{repo_path}/.git/hooks";
    my $post_commit_file = "$hooks_dir/post-commit";
    
    # Create hooks directory if it doesn't exist
    mkdir $hooks_dir unless -d $hooks_dir;
    
    # Create or append to post-commit hook
    my $hook_content = "#!/bin/sh\n$script_path --replace-x 'Changes made' || true\n";
    
    if (-e $post_commit_file) {
      # Check if our hook already exists
      my $existing_hook = path($post_commit_file)->slurp;
      if ($existing_hook !~ /\Q$script_path\E/) {
        path($post_commit_file)->append($hook_content);
      } else {
        print "Hook already exists in $post_commit_file\n";
      }
    } else {
      path($post_commit_file)->spew($hook_content);
      chmod 0755, $post_commit_file;
    }
    
    print "Post-commit hook installed to automatically update Changes file\n";
  }
}

exit(0);