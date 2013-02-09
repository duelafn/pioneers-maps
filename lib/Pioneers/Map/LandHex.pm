package Pioneers::Map::LandHex;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

extends 'Pioneers::Map::Hex';

=pod

=head1 NAME

Pioneers::Map::LandHex - Pioneers LandHex object

=head1 SYNOPSIS

 use strict;
 use Pioneers::Map::LandHex;

=head1 DESCRIPTION

=head1 USAGE

=cut

has "+type" => (
    isa        => 'Pioneers::Types::LandHexType',
);

has "+pin" => (
    default    => 0,
);


method is_resource_hex() {
    my $type = $self->type;
    return 1 if $type =~ /[pmfht]/;
    return 0 if $type =~ /[dg]/;
    die "Unknown type";
}

method is_production_hex() {
    my $type = $self->type;
    return 1 if $type =~ /[gpmfht]/;
    return 0 if $type =~ /[d]/;
    die "Unknown type";
}


method consumes_chit() {
    my $type = $self->type;
    return 1 if $type =~ /[gpmfht]/;
    return 0 if $type =~ /[d]/;
    die "Unknown type";
}

method increments_chit() {
    return 1
}


method to_map_string($map) {
    my $str = $self->type;
    $str .= $map->_step_chit_index if $self->increments_chit;
    $str .= "+" if $self->pin;
    return $str;
}



no Moose;
__PACKAGE__->meta->make_immutable;

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
