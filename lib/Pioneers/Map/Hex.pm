package Pioneers::Map::Hex;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

use Pioneers::Types;

=pod

=head1 NAME

Pioneers::Map::Hex - Pioneers Hex object

=head1 SYNOPSIS

 use strict;
 use Pioneers::Map::Hex;

=head1 DESCRIPTION

=head1 USAGE

=cut

has type => (
    is         => 'rw',
    required   => 1,
);

has pin => (
    is         => 'rw',
    isa        => 'Bool',
);

has map => (
    is         => 'rw',
    isa        => 'Pioneers::Map',
);








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