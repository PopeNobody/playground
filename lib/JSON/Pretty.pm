package JSON::Pretty;
require Exporter;
our(@EXPORT) = qw(encode_json decode_json);
our(@ISA) = qw(Exporter);
use JSON::PP;
 
our ($json) = JSON::PP->new->ascii->pretty->allow_nonref->convert_blessed;

sub encode_json($) {
  my @copy=@_;
  local($_);
  eval {
    ($_)=$json->encode(@_);
  };
  return $_ if defined;
  die  join("\n\n",$@,pp(@copy));
};
sub decode_json {
  my @copy=@_;
  local($_);
  eval {
    ($_)=$json->decode(@_);
  };
  return $_ if defined;
  die  join("\n\n",$@,pp(@copy));
};

1;
