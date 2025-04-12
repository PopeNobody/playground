package LoveHandle;
use Tie::Handle;
our(@ISA)=qw(Tie::StdHandle);
use Carp qw( croak carp confess cluck );
use warnings::register;

sub TIEHANDLE {
  my $class = shift;
  my ($buf)="";
  my $self={rl=>shift,buf=>\$buf};
  bless($self,$class);
}
#    
#    sub PRINT {
#      my($self)=shift;
#      local($\)=defined($\)?$\:"";
#      my $buf = join(defined $, ? $, : "",@_)."$\";
#      $self->WRITE($buf,length($buf),0);
#    }
#    
#    sub PRINTF {
#      my($self)=shift;
#      my $buf = sprintf(shift,@_);
#      $self->WRITE($buf,length($buf),0);
#    }
#    
#    sub READLINE {
#      my $pkg = ref $_[0];
#      croak "$pkg doesn't define a READLINE method";
#    }
#    
#    sub GETC {
#      croak ref($self)," doesn't define a GETC method";
#    }
#    
#    sub READ {
#      my $pkg = ref $_[0];
#      croak "$pkg doesn't define a READ method";
#    }
#    use Nobody::Util qw(pp);
#    sub WRITE {
#      my ($self,$wbuf,$len,$off)=@_;
#      my ($rl)=$self->{rl};
#      my ($buf)=$self->{buf};
#      warn(pp({ self=>"$self", wbuf=>$wbuf,len=>$len,off=>$off,rl=>"$rl",
#          buf=>"$buf",text=>"$$buf"})."\n");
#      substr($$buf,length($$buf),0,substr($wbuf,$off,$len));
#      warn(pp({ self=>"$self", wbuf=>$wbuf,len=>$len,off=>$off,rl=>"$rl",
#          buf=>"$buf",text=>"$$buf"})."\n");
#      while($$buf =~ /\n/) {
#        my($write,$res)=m{(.*\n)(.*)};
#        $rl->print($write);
#        $_=$res;
#      };
#    }
#    
#    sub CLOSE {
#      my $pkg = ref $_[0];
#    }
1;
