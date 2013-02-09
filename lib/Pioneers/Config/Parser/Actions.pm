package Pioneers::Config::Parser::Actions;
use strict; use warnings; use re 'taint';
our $VERSION = 0.0000;# Created: 2013-02-09

=pod

=head1 NAME

Pioneers::Config::Parser::Actions - Parser Action Class

=head1 USAGE

=cut

sub _1 { return $_[1] }
sub _2 { return $_[2] }
sub _3 { return $_[3] }

sub gather_list {
    my $scratch = shift;
    return [ @_ ];
}

sub gather_nosetup {
    return [ @_[1,3,5] ];
}

sub set_parameter {
    my ($scratch, $param, undef, $value) = @_;
    (my $name = $param) =~ tr/-/_/;

    if ($name eq 'nosetup') {
        push @{$$scratch{parameters}{$name}}, $value;
    } elsif ($name eq 'desc') {
        $$scratch{parameters}{$name} .= "\n" if defined($$scratch{parameters}{$name});
        $$scratch{parameters}{$name} .= $value;
    } else {
        $$scratch{parameters}{$name} = $value;
    }
}

sub build_config {
    my $scratch = shift;
    # Pioneers::Config sets reasonable defaults, but that is not reasonable when loading a file!
    # Clear the defaults (set to undef) of everything before setting the loaded values.
    my %clear_defaults = map +($$_{name} => undef), values %Pioneers::Config::parameters;
    Pioneers::Config->new( %clear_defaults, %{$$scratch{parameters}} );
}

sub step_map_row {
    my $scratch = shift;
    push @{$$scratch{map_parameters}{hex_map}}, delete($$scratch{map_row});
}

sub build_map {
    my $scratch = shift;
    $$scratch{parameters}{map} = Pioneers::Map->new( %{$$scratch{map_parameters}} );
}

sub add_resource_hex {
    my ($scratch, $type, $chit, $pin) = @_;
    push @{$$scratch{map_row}}, Pioneers::Map::LandHex->new(
        type => $type,
        pin  => ($pin ? 1 : 0),
    );
}

sub add_sea_hex {
    my ($scratch, $type, $port, $direction) = @_;
    # XXX: TODO: We don't currently support placing the pirate
    undef($port) if $port and $port eq 'R';
    push @{$$scratch{map_row}}, Pioneers::Map::SeaHex->new(
        type => $type,
        ( $port ? (
            port => $port,
            port_orientation => $direction,
        ) : () ),
    );
}

sub add_desert_hex {
    my ($scratch, $type, $chit, $pin) = @_;
    push @{$$scratch{map_row}}, Pioneers::Map::LandHex->new(
        type => $type,
        pin  => ($pin ? 1 : 0),
    );
}

sub add_empty_hex {
    my ($scratch) = @_;
    push @{$$scratch{map_row}}, undef;
}



1;

__END__

=head1 AUTHOR

 Dean Serenevy
 dean@serenevy.net
 http://dean.serenevy.net/

=head1 COPYRIGHT

This module is Copyright (c) 2013 Dean Serenevy. All rights reserved.

You may distribute under the terms of either the GNU General Public License
or the Artistic License, as specified in the Perl README file.
