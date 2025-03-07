package AI::TextProc;
use FindBin;
our($prefix);
use Path::Tiny;
BEGIN {
  ($prefix)=path($FindBin::Bin);
  if($prefix->basename =~ m{s?bin} ){
    $prefix=$prefix->parent;
  };
};
BEGIN {
  use lib "$prefix/lib";
};
use common::sense;
use Nobody::Util;
use Data::Dumper;
use Carp qw(confess carp croak cluck);
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns);

# Set columns dynamically based on terminal width if possible
BEGIN {
  eval {
    require Term::ReadKey;
    my ($wchar, $hchar, $wpixels, $hpixels) = Term::ReadKey::GetTerminalSize();
    $columns = $wchar - 2 if $wchar > 5;  # Subtract 2 for safety
  };
  # Default if we can't determine terminal width
  $columns = 80 unless defined $columns;
};

# Format text from various input types into a unified text representation
sub format {
  my @args = @_;
  my @result;
  my $i = 0;
  
  # Process elements while handling their different types
  while ($i < @args) {
    my $elem = $args[$i];
    
    # Skip undefined values
    if (!defined $elem) {
      $i++;
      next;
    }
    
    # Path::Tiny object: slurp file contents
    elsif (blessed($elem) && $elem->isa("Path::Tiny")) {
      my $content = eval { $elem->slurp };
      if ($@) {
        carp "Failed to read file " . $elem->stringify . ": $@";
        $i++;
        next;
      }
      
      if ($content =~ /\n/) {
        push @result, split(/\n/, $content);
      } else {
        push @result, $content if length($content);
      }
    }
    
    # Array reference: add all elements
    elsif (ref($elem) eq 'ARRAY') {
      foreach my $line (@$elem) {
        if (defined $line) {
          if (ref($line) eq '') {  # Simple scalar
            if ($line =~ /\n/) {
              push @result, split(/\n/, $line);
            } else {
              push @result, $line if length($line);
            }
          }
          # For nested arrays or other types - could add recursion here
        }
      }
    }
    
    # Regular scalar containing newlines
    elsif (!ref($elem) && $elem =~ /\n/) {
      push @result, split(/\n/, $elem);
    }
    
    # Regular scalar (simple string)
    elsif (!ref($elem)) {
      push @result, $elem if length($elem);
    }
    
    # Increment only after processing the current element
    $i++;
  }
  
  # Remove empty lines from the beginning and end
  while (@result && $result[0] =~ /^\s*$/) {
    shift @result;
  }
  while (@result && $result[-1] =~ /^\s*$/) {
    pop @result;
  }
  
  # Return array or string based on context
  return wantarray ? @result : join("\n", @result);
}

1;
