#!/usr/bin/perl

    use 5.14.0;
    use autodie;
    use warnings FATAL => 'all';
    use Data::Dumper;
    use Test::More;

    our $VERSION = 'v0.4.7';

    package MyHedgehogScript {

        use Carp;
        use Data::Dumper;
        use Hash::Util qw(lock_keys);






# ------------------ MAIN -----------------------------------------------------
    # TODO
    # 3 representations: input map, storage, display
    #

    # CONFIG
    my $DEBUG       = 0;
    my $random      = 1;
    my $corner_home = 0;
    my $no_mono     = 1;

    my $field_txt = <<'EOF';
AAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAA
BAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAC
EOF


    my @pieces_a         = ( 'hedgehog', 'home', 'space', 'move', );
    my @map_tokens_a     = ( 'B',        'C',    'A',     'X',    );
    my @display_tokens_a = ( 'H',        'O',    ' ',     'X',    );

    my %tokens;
    @tokens{@pieces_a} =  @map_tokens_a;

    my %token_map;
    @token_map{@map_tokens_a} =  @pieces_a;

    my %display_map;
    @display_map{@pieces_a} = @display_tokens_a;

    my @keys = qw( );

    sub run {
        my ( $self ) = @_;

        $self->play_hedgehog();

        return 0; # return for entire script template
    }

    sub play_hedgehog {
        my ($self) = @_;

        my $field = Field->new(
            input_map => $field_txt,
            token_map => \%token_map,
            DEBUG     => $DEBUG,
        );

        my $display;

        if ( $no_mono ) {
            $display = No_Mono_Display->new();
        }
        else {
            $display = Text_Display->new();
        }

        my ($hx,$hy) = $field->get_hedgie();
        my ($ox,$oy) = $field->get_home();

        my $hedgie = Hedgehog->new(token => $tokens{hedgehog});
        my $home = Home->new(token => $tokens{home});

        if ( defined $hx and !$random ) {
            $hedgie->set_position($hx,$hy);
            $home->set_position($ox,$oy);
        }
        else {
            $hedgie->set_position(coords());
            $home->set_position(coords());
            $home->set_position(9,9) if $corner_home;
        }

        $field->init('space');

        ($hx,$hy) = $field->place($hedgie);
        ($ox,$oy) = $field->place($home);

        my $step=1;
        while($hx != $ox or
              $hy != $oy) {
            if ( $hx > $ox ) {
                $hx--;
            }
            elsif ( $hx < $ox ) {
                $hx++;
            }
            if ( $hy > $oy ) {
                $hy--;
            }
            elsif ( $hy < $oy ) {
                $hy++;
            }
            $field->place($hx,$hy,'move');
        }
        $field->place($home);
        $display->draw($field->get_pmap(),\%display_map);
    }

    sub coord {
        return int(rand(9));
    }

    sub coords {
        return (coord(),coord());
    }

# ------------------ END MAIN -------------------------------------------------






        sub new {
            my ($class) = @_;

            do_macros();

            my $self = {};
            bless $self, $class;
            lock_keys( %$self, @keys );

            return $self;
        }

        my $ms = '#' . 'm' . '{';
        my $me = '#' . '}' . 'm';

        my $expr;
        my $default_print=1;
        my $line_num=0;

        sub process_line {
            my ($line) = @_;
            if ( /^\s*$ms(.*)/ ) {
                $expr=$1;
                $expr =~ s/\s*$//;
                if ( $expr =~ /i(-?\d*)/ ) {
                    my $num = $1;
                    if ( $num eq '-' ) {
                        $num = -1;
                    }
                    $num ||= 1;
                    my $spc = '    ' x abs($num);
                    if ( $num < 0 ) {
                        $expr = "s/^$spc//";
                    }
                    else {
                        $expr = "s/^/$spc/";
                    }
                }
            }
            elsif ( /^\s*$me/ ) {
                undef $expr;
            }
            else {
                my $do_print = $default_print;
                my $do_num=0;
                if ( $expr ) {
                    if ( $expr eq "cp" ) {
                        $do_print=1;
                    }
                    elsif ( $expr eq "l" ) {
                        $do_num=1;
                    }
                    elsif ( $expr eq "rm" ) {
                        $do_print=0;
                    }
                    else {
                        eval $expr;
                    }
                }
                print "$line_num: " if $do_num;
                print "$_\n" if $do_print;
            }
            ++$line_num;
        }
        sub do_macros {
            my $ifh = IO::File->new( $0, '<' );
            die "no file handle: $!" if ( !defined $ifh );

            my $code = do { local $/; <$ifh> };
            $ifh->close;
            if ( $code =~ /^\s*$ms(.*)$/m ){

                my $e = $1;
                $e =~ s/\s*$//;


                if ( $e eq 'cp' ) {
                    $default_print=0;
                }

                if ( $e eq 'mv' ) {
                    if ( $code =~ s/${ms}mv(.*)$me//ms ) {
                        my $cap = $1;
                        $code =~ s/${ms}x}/$cap/;
                        print $code;
                        exit;
                    }
                }

                for ( split "\n", $code ) {
                    process_line($_);
                }
                exit;
            }
        }
    }

    package Text_Display
    {
        use Carp;
        use Data::Dumper;
        use Hash::Util qw(lock_keys);

        my @keys = qw( );

        sub new {
            my ($class,@args) = @_;

            my $self = {@args};
            bless $self, $class;
            lock_keys( %$self, @keys );

            return $self;
        }

        sub draw {
            my ( $self, $map, $translation ) = @_;

            for my $i (@$map) {
                for my $j (@$i) {
                    print $translation->{$j};
                }
                print "\n";
            }
        }
    }

    package No_Mono_Display
    {
        use Carp;
        use Data::Dumper;

        use base 'Text_Display';
        my @equiv = qw( a b d e g h n o p q u );
        @equiv = qw( V T S P N K H F E B A U );

        sub draw {
            my ( $self, $map, $translation ) = @_;

            my $equiv_idx = 0;
            my %xlat;

            for my $i (@$map) {
                for my $j (@$i) {
                    if ( !$xlat{$j} ) {
                        $xlat{$j} = $equiv[$equiv_idx++];
                    }
                    print $xlat{$j};
                }
                print "\n";
            }
            print "Legend: ";
            for ( sort { $a cmp $b } keys %xlat ) {
                print "$_=$xlat{$_}  ";
            }
            print "\n";
        }
    }

    package Piece
    {
        use Carp;
        use Data::Dumper;
        use Hash::Util qw(lock_keys);

        my @keys = qw( x y token );

        sub new {
            my ($class,@args) = @_;

            my $self = {@args};
            bless $self, $class;
            lock_keys( %$self, @keys );

            return $self;
        }

        sub set_position {
            my ( $self, $x, $y ) = @_;
            $self->{x} = $x;
            $self->{y} = $y;
        }
        sub get_position {
            my ( $self ) = @_;
            return ( $self->{x}, $self->{y} );
        }
        sub get_token {
            return shift->{token};
        }
    }

    package Hedgehog
    {
        use base 'Piece';
    }

    package Home
    {
        use base 'Piece';
    }

    package Field
    {
        use Carp;
        use Data::Dumper;
        use Hash::Util qw(lock_keys);

        my $DEBUG = 0;
        my @keys = qw(
            input_map
            token_map
            pmap
            hxx
            hyy
            oxx
            oyy
            parsed_flag
            DEBUG
        );
        my $default_token = '';

        sub new {
            my ($class,@args) = @_;

            my $self = {@args};
            $self->{parsed_flag}=0;
            $DEBUG = $self->{DEBUG};
            bless $self, $class;
            lock_keys( %$self, @keys );

            return $self;
        }
        sub get_pmap {
            return shift->{pmap};
        }
        sub init {
            my ($self,$token) = @_;
            $token //= $default_token;
            my @pmap;
            for my $y (0..9) {
                for my $x (0..9) {
                    push @{$pmap[$y]}, $token;
                }
            }
            $self->{pmap} = \@pmap;
        }
        sub place {
            my ($self,$x,$y,$label) = @_;
            if ( ref $x ) {
                my $piece = $x;
                ($x,$y) = $piece->get_position();
                $label = lc(ref $piece);
            }
            $self->{pmap}->[$y]->[$x]=$label;
            return ($x,$y);
        }
        sub parse {
            my ($self) = @_;

            return if $self->{parsed_flag};

            my $token_map = $self->{token_map};

            my @lines = split "\n", $self->{input_map};
            my @pmap;
            my $cl=0;
            for (@lines) {
                next unless $_;
                my $l=length;
                for(my $i=0;$i<$l;$i++){
                    my $c=substr($_,$i,1);
                    if($token_map->{$c} eq 'hedgehog') {
                        $self->{hxx}=$i;
                        $self->{hyy}=$cl;
                    }
                    elsif($token_map->{$c} eq 'home') {
                        $self->{oxx}=$i;
                        $self->{oyy}=$cl;
                    }
                    push @{$pmap[$cl]}, $token_map->{$c} || $default_token;
                }
                $cl++;
            }
            $self->{parsed_flag}=1;
            return;
        }
        sub get_hedgie {
            my ($self) = @_;
            $self->parse();
            return ($self->{hxx},$self->{hyy});
        }
        sub get_home {
            my ($self) = @_;
            $self->parse();
            return ($self->{oxx},$self->{oyy});
        }
    }

    package main;

    my $app = MyHedgehogScript->new();
    exit $app->run();
