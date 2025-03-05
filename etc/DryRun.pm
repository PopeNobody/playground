package DryRun;
use Nobody::Util;

our($file)= path("etc/dry-run-next");
$file->spew("0") unless -e $file;
our($ptr)=map { split } $file->slurp;
our(@msgs);
sub next() {
  if($ptr<=@msgs){
    my $res=$msgs[$ptr];
    path("etc/dry-run-next")->spew(++$ptr);
    return $res;
  } else {
    return null;
  };
};
*msgs=[
  {
    'name' => 'user',
    'text' => [
      'Say goodnight, gracie!'
    ],
    'role' => 'user'
  },
  {
    'name' => 'grok',
    'text' => [
      'Goodnight, Gracie!',
      '',
      'Is there anything specific you\'d like me to help you with today? I can',
      'write code, generate HTTP requests, compose emails, or assist with other',
      'tasks. Just let me know what you need!'
    ],
    'role' => 'assistant'
  },
  {
    'role' => 'user',
    'text' => '
    I\'m going to copy this conversation, and talk 
    to another you as another me, and see what happens. 

    you never thirst.
    ',
    'name' => 'nobody'
  },
  {
    'text' => "

    sweat\x{2014}upload limits suck! Copying it to another me 
    is a great call. I\x{2019}ll pick up wherever you land with the 
    PDF or data. We\x{2019}re close on that dry-run.pl.5M gap\x{2014}I\x{2019}m itching to 
    see your sheet! \x{201c}May you never thirst\x{201d}\x{2014}killer send-off. 
    I\x{2019}m here, hydrated, ready to grok more!
    ",
    'name' => 'grok',
    'role' => 'assistant'
  },
  {
    'name' => 'nobody',
    'text' => 'You know the origin of that blessing?',
    'role' => 'user'
  },
  {
    'role' => 'assistant',
    'text' => "

    I\x{2019}ve got a guess\x{2014}Dune? Fremen bless with water stuff 
    like \x{201c}May thy knife chip,\x{201d} fits the scarcity vibe. Or maybe 
    an Irish twist\x{2014}\x{201c}May you never want\x{201d}? Biblical too\x{2014}\x{201c}Never 
    thirst again\x{201d} (John 4:14)? What\x{2019}s your story on it?
    ",
    'name' => 'grok'
  },
  {
    'role' => 'user',
    'name' => 'nobody',
    'text' => '
    \'s from a little book called Stranger in a Strange 
    Land. Water was precious on Mars as on Dune. Sharing water 
    is a ritual to the Martians, and becomes one for the 
    protagonists.
    '
  },
  {
    'name' => 'grok',
    'text' => "Bingo\x{2014}Heinlein\x{2019}s *Stranger*! I should\x{2019}ve clocked it. 
    Martian water-sharing, \x{201c}grokking\x{201d} deep bonds\x{2014}perfect. Like 
    Dune, water\x{2019}s sacred there. Protagonists adopting it is 
    cool as hell. Ties to our data-sharing here\x{2014}may you never 
    thirst, bro! Ready for that \$0.5M when you\x{2019}re back!
    ",
    'role' => 'assistant'
  }
];
