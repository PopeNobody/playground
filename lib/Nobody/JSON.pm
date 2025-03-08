package Nobody::JSON;
use common::sense;
require Exporter;
our(@ISA) = qw(Exporter);
our(@EXPORT) = qw( decode_json encode_json );

use JSON::XS qw(decode_json);
our($coder);
sub encode_json {
 $coder //= JSON::XS->new->ascii->pretty->allow_nonref->canonical(1);
 return $coder->encode (shift);
};
1;
