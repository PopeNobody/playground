package AI::Playground;

# ABSTRACT: Allow many AI's to develp on your system


sub new {
  my ($class) = map { ref || $_ } shift;
  my ($self) = { splice @_ };

  bless($self,$class);
};
