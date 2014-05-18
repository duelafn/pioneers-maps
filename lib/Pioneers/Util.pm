package Pioneers::Util;
use strict; use warnings; use re 'taint';
use 5.010;
our $VERSION = 1.0309;# Created: 2013-02-09
require Moose::Meta::TypeConstraint;
use List::Util qw/ sum max shuffle first /;
use Sort::Key::Maker sort_chit_info => sub { $$_[1], $$_[2], $$_[3] }, qw/ -num int num /;

use parent "Exporter";
our %EXPORT_TAGS = (
    hash => [qw/ subhash /],
    stat => [qw/ distribute_chits random_chits chit_deviation /],
);
our @EXPORT_OK = map @$_, values %EXPORT_TAGS;
$EXPORT_TAGS{all} = \@EXPORT_OK;


=pod

=head1 NAME

Pioneers::Util - Utilities for Pioneers modules

=head1 USAGE

=head3 subhash

 my %shallow = subhash( \%orig, @keys );

Extract keys from a hash. Similar to:

 @shallow{@keys} = @orig{@keys};

But does not auto-vivify when key does not B<exist> in %orig (and does not
create key in %shallow).

=cut

#BEGIN: subhash
sub subhash {
  my $h = shift;
  map { exists($$h{$_}) ? ($_, $$h{$_}) : () } @_;
}
#END: subhash



=head3 distribute_chits

=head3 random_chits

 my @chits = distribute_chits( $N );
 my @chits = distribute_chits( $N, $score );

 my @chits = random_chits( $N, %options );
 my @chits = random_chits( $N, $score, %options );

Distributes chits. The score parameter can be used to affect the
"difficulty" of the game. A score of 100 will yield an optimal distribution
which will result in a quicker game. A score of 50 will result in an even
distribution of chits (there will be roughly as many 12's as 6's on the
board). A score less than 100 will over-emphasize the less-likely chits. A
score greater than 100 will over emphasize the more-likely numbers (more
6's and 8's - yes this will actually make the game harder/slower).

The C<distribute_chits> function will generate a "perfect" distribution -
it obeys the distribution as well as it can. The C<random_chits> function
will only statistically obey the "perfect" distribution (actual
distribution will vary significantly).

Chits returned will always be shuffled.

Options accepted by the random_chits function

=over 4

=item ensure_all_numbers

If true, ensures that at least one of each number is present in the
distribution (if $N is at least 10).

=item best_of

If positive, will select the best distribution of requested number of
attempts.

=back

=cut

sub _build_dist {
    my $score = shift // 100;
    my $b = $score / 10 - 4;
    my $dy = ($b - 1)/5;
    my @vals = map max( 0, 1 + $_ * $dy ), 0..4;
    my @prob = (0, 0, @vals, 0, reverse(@vals));
    my $sum = sum(@prob);
    return map $_/$sum, @prob;
}

sub distribute_chits {
    my ($N, $score) = @_;
    my @dist = _build_dist($score);
    my @chit_dist = map int($N * $_), @dist;
    my $missing = $N - sum(@chit_dist);
    my @d = sort_chit_info map [ $_, $N*$dist[$_] - $chit_dist[$_], $chit_dist[$_], rand ], 2..12;
    my @chits = (
        (map +( ($_)x($chit_dist[$_]) ), 2..12),
        (map +( $$_[0] ), @d[0..($missing-1)]),
    );
    return shuffle @chits;
}

sub _has_all_numbers {
    my %all = map +($_,1), 2..6, 8..12;
    delete $all{$_} for @_;
    return !%all;
}

sub random_chits {
    my $N = shift;
    my $score = (@_ % 2) ? shift() : undef;
    my %opt = @_;
    my $psum = 0;
    my @dist = map +($psum += $_), _build_dist($score);
    die "Broken cumulative distribution: @dist" unless 1 == "$dist[-1]";
    my ($best, $best_score);
    my @init;
    if ($opt{ensure_all_numbers} and $N < 15) {
        @init = (2..6, 8..12);
    }
    $N -= @init;
    $opt{best_of} //= 1;

    while (1) {
        my @chits = @init;
        for (1..$N) {
            my $r = rand;
            push @chits, first { $r < $dist[$_] } 2..12;
        }

        redo if $opt{ensure_all_numbers} and not _has_all_numbers(@chits);

        if ($opt{best_of} > 1) {
            $opt{best_of}--;
            my $score = chit_deviation(\@chits, \@dist);
            ($best, $best_score) = (\@chits, $score) if !$best or $best_score > $score;
        }

        return shuffle( $best ? @$best : @chits );
    }
}


=head3

 my $n = chit_deviation(\@chits, $score);
 my $n = chit_deviation(\@chits, \@target);

Compute a root mean squared deviation from the target chit distribution.
Can be used in estimating game difficulty. If the target distribution is
already known, you can pass that in as an array reference instead of
passing a score.

=cut

sub chit_deviation {
    my ($chits, $score) = @_;
    $score //= 100;
    my (%actual, %perfect);
    $actual{$_}++  for @$chits;
    $perfect{$_}++ for (ref($score) ? @$score : distribute_chits(0+@$chits, $score));

    my $var = 0;
    for (2..6,8..12) {
        $var += ($actual{$_}//0 - $perfect{$_}//0) ** 2;
    }

    return sqrt($var / 10);
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
