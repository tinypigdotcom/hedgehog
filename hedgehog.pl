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
    # MVC - model, view, controller - separate
    #

    # CONFIG
    my $DEBUG=0;
    my $random=1;
    my $corner_home=0;

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

    my %token = (
        space => 'A',
        move  => 'X',
        hog   => 'B',
        home  => 'C',
    );
    my %tmap = reverse %token;

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
            token     => \%token,
            DEBUG     => $DEBUG,
        );

        my $display = Text_Display->new();

        my ($hx,$hy) = $field->get_hedgie();
        my ($ox,$oy) = $field->get_home();

        my $hedgie = Hedgehog->new(token => $token{hog});
        my $home = Home->new(token => $token{home});

        if ( defined $hx and !$random ) {
            $hedgie->set_position($hx,$hy);
            $home->set_position($ox,$oy);
        }
        else {
            $hedgie->set_position(coords());
            $home->set_position(coords());
            $home->set_position(9,9) if $corner_home;
        }

        $field->init();

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
            $field->place($hx,$hy,$token{move});
        }
        $field->place($home);
        $display->draw($field,\%tmap);
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

        my %display_tokens = (
            space => 'Y',
            move  => 'X',
            hog   => 'H',
            home  => 'O',
        );

        my @keys = qw( );

        sub new {
            my ($class,@args) = @_;

            my $self = {@args};
            bless $self, $class;
            lock_keys( %$self, @keys );

            return $self;
        }

        sub draw {
            my ( $self, $field, $token_map ) = @_;
            my $pmap=$field->get_pmap();
            for my $i (@$pmap) {
                for my $j (@$i) {
                    print $display_tokens{$token_map->{$j}};
                }
                print "\n";
            }
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
            token
            pmap
            hxx
            hyy
            oxx
            oyy
            parsed_flag
            DEBUG
        );

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
            my ($self) = @_;
            my $space = $self->{token}->{space};
            my @pmap;
            for my $y (0..9) {
                for my $x (0..9) {
                    push @{$pmap[$y]}, $space;
                }
            }
            $self->{pmap} = \@pmap;
        }
        sub place {
            my ($self,$x,$y,$token) = @_;
            if ( ref $x ) {
                my $piece = $x;
                ($x,$y) = $piece->get_position();
                $token = $piece->get_token();
            }
            $self->{pmap}->[$y]->[$x]=$token;
            return ($x,$y);
        }
        sub parse {
            my ($self) = @_;

            return if $self->{parsed_flag};

            my $token = $self->{token};

            my @lines = split "\n", $self->{input_map};
            my $cl=0;
            for (@lines) {
                next unless $_;
                my $l=length;
                for(my $i=0;$i<$l;$i++){
                    my $c=substr($_,$i,1);
                    if($c eq $token->{space}){
                        dprint(" , ");
                    }
                    elsif($c eq $token->{hog}) {
                        dprint(" ; ");
                        $self->{hxx}=$i;
                        $self->{hyy}=$cl;
                    }
                    elsif($c eq $token->{home}) {
                        $self->{oxx}=$i;
                        $self->{oyy}=$cl;
                        dprint(" ! ");
                    }
                    else {
                        dprint("???");
                    }
                }
                dprint("\n");
                $cl++;
            }
            dexit();
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
        sub dprint {
            print @_ if $DEBUG;
        }
        sub dexit {
            exit if $DEBUG;
        }
    }

    package main;

    my $app = MyHedgehogScript->new();
    exit $app->run();
