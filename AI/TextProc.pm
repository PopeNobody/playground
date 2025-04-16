package AI::TextProc;
our(@EXPORT_OK)=qw(text_wrap);
require Exporter;
sub import {
  $DB::single=1;
  goto &Exporter::import;
};
use AI::Util;

1;
