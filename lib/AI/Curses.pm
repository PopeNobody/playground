use Curses::UI::AnyVent;

sub new {
  my ($class)=shift;
  my ($self)={};
  $self->{cui} = Curses::UI::AnyEvent->new(-color_support=>1);
  $self->{win} = $cui->add(
    'win', 'Window',
    -border=>1,
    bfg=>'red'
  );
  $self->{clock}=$win->add(
    'clock','TextViewer',
    -text=>''
  );
  $self->{tv}=$win->add(
    tv => 'TextVeiwer', 
    -text=> "This space intentionally left blank"
  );
  $self->{spring} = AE::timer 1, 1, sub {
    $self->{clock}->{-text} = text;
    $self->{clock}->draw;
  };

  $self->{tv}->focus();

  $cui->mainloop();
};
sub text {
  return join("\n",localtime() , $self->{tv}->{-text} );
};
