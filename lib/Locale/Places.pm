package Locale::Places;

use strict;
use warnings;

use Carp;
use CHI;
use File::Spec;
use Locale::Places::DB::GB;
use Module::Info;

our %gb_cache;

=head1 NAME

Locale::Places - Translate places using http://download.geonames.org/

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 METHODS

=head2 new

Create a Locale::Places object.

Takes one optional parameter, directory,
which tells the object where to find the file GB.csv.
If that parameter isn't given,
the module will attempt to find the databases,
but that can't be guaranteed.

=cut

sub new {
	my($proto, %param) = @_;
	my $class = ref($proto) || $proto;

	# Use Locale::Places->new, not Locale::Places::new
	return unless($class);

	my $directory = $param{'directory'} || Module::Info->new_from_loaded(__PACKAGE__)->file();
	$directory =~ s/\.pm$//;

	Locale::Places::DB::init({
		directory => File::Spec->catfile($directory, 'databases'),
		no_entry => 1,
		cache => $param{cache} || CHI->new(driver => 'Memory', datastore => {})
	});

	return bless { }, $class;
}

=head2 translate

Translate a city into a different language.

   print Locale::Places->new()->translate({ place => 'Dover', language => 'fr' });	# Prints "Douvres"

=cut

sub translate {
	my $self = shift;

	my %params;
	if(ref($_[0]) eq 'HASH') {
		%params = %{$_[0]};
	} elsif(scalar(@_) % 2 == 0) {
		%params = @_;
	} else {
		$params{'place'} = shift;
	}

	my $place = $params{'place'};
	if(!defined($place)) {
		Carp::croak(__PACKAGE__, 'Usage: translate(place => $place)');
	}

	my $language = $params{'language'} // $self->_get_language();
	if(!defined($language)) {
		Carp::carp(__PACKAGE__, ": can't work out which language to translate to");
		return;
	}

	$self->{'gb'} //= Locale::Places::DB::GB->new(no_entry => 1);

	if($place = $self->{'gb'}->fetchrow_hashref({ data => $place })) {
		if($place = $self->{'gb'}->selectall_hashref({ code2 => $place->{'code2'} })) {
			foreach my $entry(@{$place}) {
				next if(!defined($entry->{'type'}));

				if($entry->{'type'} eq $language) {
					return $entry->{'data'};
				}
			}
		}
	}
}

# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
# https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
sub _get_language {
	if($ENV{'LANGUAGE'}) {
		if($ENV{'LANGUAGE'} =~ /^([a-z]{2})/i) {
			return lc($1);
		}
	}
	foreach my $variable('LC_ALL', 'LC_MESSAGES', 'LANG') {
		my $val = $ENV{$variable};
		next unless(defined($val));

		if($val =~ /^([a-z]{2})/i) {
			return lc($1);
		}
	}
}

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 BUGS

is_tablet() only currently detects the iPad and Windows PCs. Android strings

=head1 SEE ALSO

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Locale::Places

You can also look for information at:

=over 4

=item * MetaCPAN

L<https://metacpan.org/release/Locale-Places>

=item * RT: CPAN's request tracker

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Locale-Places>

=item * CPANTS

L<http://cpants.cpanauthors.org/dist/Locale-Places>

=item * CPAN Testers' Matrix

L<http://matrix.cpantesters.org/?dist=Locale-Places>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Locale-Places>

=item * CPAN Testers Dependencies

L<http://deps.cpantesters.org/?module=Locale::Places>

=back

=head1 LICENCE AND COPYRIGHT

Copyright 2020 Nigel Horne.

This program is released under the following licence: GPL2

This product uses data from geonames, L<http://download.geonames.org>.

=cut

1;
